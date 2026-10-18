# 設計書

## アーキテクチャ概要

```
App（オートロード）
  _ready: catalog = ContentRepository.load_catalog()
          library = LibraryService.new(catalog)
          config = ConfigRepository.new()
          rng = RandomNumberGenerator.new(); rng.randomize()
          match_controller = MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng), request_screen)
MatchController（RefCounted）
  start_match / user_options / user_hints / submit_turn / continue_after_reveal / submit_style_change / submit_halftime
  ├─ ドメイン: MatchRules・MoveRules・MoveHints
  ├─ OpponentPolicy（CpuOpponent → CpuPlanner）
  └─ ViewConverter（利用者の視点への変換。BoardSnapshot・RevealView を作る）
ConfigRepository（データ層）: game/config/*.tres → MatchRuleConfig・CpuConfig（範囲外なら初期値）
```

## コンポーネント設計

### 1. `ConfigRepository`（`data/config_repository.gd`）
- `_init(config_dir: String = "res://config")`。
- `match_rules()`・`cpu()`: `ResourceLoader.load` で読み、型を `as` で確かめる。
  - 無い・型が違う → 初期値（`MatchRuleConfig.new()` など）と `push_error("ConfigRepository: ...")`。
  - 範囲外 → 初期値と `push_error`。範囲は内側を肯定形で確かめる（NaN でも拒否）。
  - 1回読んだら持っておく（呼ぶたびに読み直さない）。
- `.tres` は `game/config/match_rule_config.tres`・`cpu_config.tres`（`script = ExtResource(...)` と値）。

### 2. 視点の変換（`application/view_converter.gd`。`class_name ViewConverter`）
- 利用者 = `HOME`。
- `to_user(area, from_side)`: `from_side` の視点のエリアを利用者の視点に（`HOME` はそのまま、`AWAY` は鏡像）。
- 選択の運ぶ先: 判定時の攻撃側（保持側）の視点 ↔ 利用者の視点。保持側が `HOME` なら同じ、`AWAY` なら鏡像。
- `options_to_user(options, possession)`・`hints_to_user(hints, possession)`・`choice_to_domain(choice, possession)`。
- `snapshot(state, catalog, last_movements, last_goal_by, turns_per_half) -> BoardSnapshot`（配置は `MatchRules.current_layouts` で求める）。
- `reveal(record, catalog) -> RevealView`。
  - `user_role`: 攻守ターンは保持側なら `ATTACK`、そうでなければ `DEFENSE`。トランジションは奪取側なら `POS_TRANSITION`、喪失側なら `NEG_TRANSITION`。
  - 人数: 利用者が攻撃側（奪取側）なら `user_count = attacker_count`、そうでなければ逆。
  - 背番号は陣形データ（`FormationDef.players` の `id` → `number`）から引く。

### 3. `BoardSnapshot`・`RevealView`（`application/`）
- フィールドは `component-design.md` §3.5 のとおり。選手は `{"player_id", "number", "area"}` の Dictionary の配列。人数は `PitchArea` のキー → 人数。
- `RevealView.user_choice`・`opponent_choice` は `TurnChoice`（運ぶ先は利用者の視点）。

### 4. `OpponentPolicy`・`CpuOpponent`
- `OpponentPolicy`（基底。各関数は `push_error` して null を返す。直接使わない）。
- `CpuOpponent._init(catalog, cpu_config, rng)`。`CpuPlanner.choose_turn` などを呼ぶ。
- テスト用には、決まった手を返す相手（テストの中のクラス）を使う。

### 5. `MatchController`
- 持つ値: `_state: MatchState`・`_last_record: TurnRecord`・`_last_goal_by: int`（無ければ -1）。
- `start_match(user_setup)`:
  - `cpu_setup = opponent.choose_setup()`。
  - `kickoff = HOME if rng.randi_range(0, 1) == 0 else AWAY`。
  - `match_id = "%s-%04d" % [日時（YYYYMMDD-HHMMSS）, rng.randi_range(0, 9999)]`。
  - `MatchRules.create_match`。失敗（陣形が無い）なら `push_error`。
  - `state_changed` を出す。
- `user_options()`: `MoveRules.options_for(state, HOME)` を利用者の視点に。
- `user_hints()`: `MoveHints.evaluate(state, HOME, 攻撃側の視点の options)` を利用者の視点に。
- `submit_turn(user_choice)`:
  1. `stage != TURN`・試合が終わっている・前の開示を確認する前 → `false`。選択不可 → `false`（`push_error`）。
  2. `domain_choice = choice_to_domain(user_choice, possession)`。
  3. `cpu_choice = opponent.choose_turn(state, AWAY)`。`is_allowed` が偽なら `assert(false, ...)`（開発時）。書き出し版（`OS.is_debug_build()` が偽）では `push_error` して、選べる手の先頭に置き換える。
     - テストで置き換えの経路を通すため、置き換えは関数 `_first_choice(options)` に分け、開発時の `assert` をするかは引数 `assert_on_invalid_cpu`（`_init` の省略可能な引数。既定は `OS.is_debug_build()`）で決める。
  4. `MatchRules.resolve_turn`。得点なら `_last_goal_by` を記録する。
  5. 開示の確認待ちにして（`continue_after_reveal` まで、`submit_*` は `false`）、`turn_resolved(reveal, snapshot)` を出して `true`。
     盤面に出す動きはこのターンの動き。方式の選び直し・ハーフタイムで配置を作り直したら空にする（コミット前レビューの指摘）。
- `continue_after_reveal()`（確認待ちの開示が無ければ何もしない）:
  - `is_play_complete` → `request_screen(S06_RESULT)`。
  - `stage == STYLE_CHANGE` → `stage_changed` と `request_screen(S04_STYLE_CHANGE)`。
  - `stage == HALFTIME` → `stage_changed` と `request_screen(S05_HALFTIME)`。
  - それ以外 → `state_changed(snapshot)`。
- `submit_style_change(user_styles)`: `MatchRules.apply_style_change(state, user_styles, opponent.choose_styles())` → `state_changed`。
- `submit_halftime(user_setup)`: `MatchRules.apply_halftime(state, user_setup, opponent.choose_setup(), catalog)` → `state_changed`。
- `snapshot()`: 現在の状態（`StyleLayoutCalculator.turn_start`）と、直前のターンの動き。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/data/config_repository_test.gd`: 同梱の値、ファイル無し・範囲外（壊れた `.tres` を gdUnit4 の一時ディレクトリ（`create_temp_dir`）に書いて読ませる）で初期値と `push_error`。
- `tests/application/view_converter_test.gd`: 鏡像の変換、選択の往復、役割、人数の向き。
- `tests/application/match_controller_test.gd`: `start_match`、視点の変換、`submit_turn`（拒否・解決・シグナル・`RevealView`）、`continue_after_reveal`（段階ごとの要求）、選び直し、CPU の手の置き換え、通しの試合（S-06 まで）。
- `tests/application/app_test.gd` に `App.match_controller` を足す。
- 期待値は仕様から手で書く。

## ディレクトリ構造

```
game/config/{match_rule_config.tres, cpu_config.tres}
game/data/config_repository.gd
game/application/{match_controller.gd, opponent_policy.gd, cpu_opponent.gd, board_snapshot.gd, reveal_view.gd, view_converter.gd}
game/tests/data/config_repository_test.gd
game/tests/application/{view_converter_test.gd, match_controller_test.gd}
```

## 実装の順序

1. `ConfigRepository` と `.tres`（テスト先行）
2. `BoardSnapshot`・`RevealView`・`ViewConverter`（テスト先行）
3. `OpponentPolicy`・`CpuOpponent`
4. `MatchController`（テスト先行）
5. `App` への組み込み
6. 変異で確かめる（スクリプトは Write/Edit で書き、Git Bash を明示）
7. 文書の更新（`component-design.md` §3.1〜3.3・§3.5・§4.2、`repository-structure.md` の game/config/）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。`ConfigRepository` は同梱の `res://config` だけを読む。
- 1ターンにつきドメインの計算を数回（選べる手・ヒント・解決・盤面）。問題にならない。

# 設計書

## アーキテクチャ概要

```
MatchRules（match/。アルゴリズム7）
  create_match(match_id, home, away, kickoff_side, catalog, started_at) -> MatchState（陣形が無ければ null）
  current_layouts(state) -> LayoutStep
  resolve_turn(state, home_choice, away_choice, rules) -> TurnResolution（選択不可・進行段階違いなら null）
    1. current_layouts → 局面に応じて MoveRules で両者の手を確かめる
    2. OpenPlayJudge / TransitionJudge
    3. _apply_open_play / _apply_transition（結果の反映）
    4. ターン番号を進め、ハーフの終わりを処理する
    5. TurnRecord を作る
  apply_style_change(state, home_styles, away_styles) -> MatchState（STYLE_CHANGE 以外は null）
  apply_halftime(state, home_setup, away_setup, catalog) -> MatchState（HALFTIME 以外・陣形が無ければ null）
  is_play_complete(state, rules) -> bool
  finish(state) -> MatchState
MoveRules.options_for(state, side) -> MoveOptions
```

ドメイン層の中の依存の向きは `match/` → `layout/`・`judge/`（`component-design.md` §7）。`MoveRules.options_for` は `judge/` にあり、`MatchState`（値オブジェクト）と `TransitionJudge.counter_layout`（同じ `judge/`）を使う。`match/` は呼ばない。

## コンポーネント設計

### 1. 値オブジェクト
- `TeamSetup`: `_init(formation_id, styles)`・`duplicate_deep()`。
- `MatchState`: フィールドはすべて公開の `var`。`duplicate_deep()` で写し、`MatchRules` は写しを書き換えて返す（入力を書き換えない）。
  - `match_id: String`・`status: MatchStatus`・`stage: MatchStage`・`half: int`・`turn_number: int`・`turn_kind: TurnKind`
  - `possession: TeamSide`・`ball_area: PitchArea`（保持側の視点）・`first_half_kickoff: TeamSide`
  - `home_score: int`・`away_score: int`
  - `home_setup: TeamSetup`・`away_setup: TeamSetup`
  - `home_players: Array[PlayerState]`・`away_players: Array[PlayerState]`
  - `transition_origin: LayoutPair`（攻守ターンでは null）
  - `started_at: String`
  - `turn_records: Array[TurnRecord]`
  - 便利関数: `setup_of(side)`・`players_of(side)`・`score_of(side)`・`static other(side)`。
- `TurnRecord`: `seq`・`half`・`turn_number`・`turn_kind`・`attacker`・`home_setup`・`away_setup`・`home_choice`・`away_choice`（攻撃側の視点）・`ball_before`・`ball_after`（攻撃側の視点）・`pair_before`・`pair_at_judgement`（`LayoutPair`）・`movements`・`judge: JudgeDetail`（`NO_CONTEST` は null）・`outcome`。`duplicate_deep()`。
- `TurnResolution`: `next_state`・`record`。
- `MatchRuleConfig`（`domain/config/match_rule_config.gd`。`extends Resource`）: `@export var turns_per_half: int = 12`（`functional-overview.md`「設定値として外部化する値」の初期値）。

### 2. `MatchRules`
- 配置の組み立て: `TeamLayout.at_base(players)` を起点に、攻守ターンは `StyleLayoutCalculator.compute(attacker, attacker_styles, defender, defender_styles, ball, possession)`。`compute` は固定された選手を固定先に置き、それ以外を基本エリアから動かすので、`MatchState` は基本エリアと固定先だけを持てばよい。
- キックオフ（`_kickoff(state, side)`）: `possession = side`・`ball_area = M-C`・`turn_kind = OPEN_PLAY`・`transition_origin = null`・両チームの選手の固定を解除。
- `resolve_turn` の手の確かめ:
  - 攻守ターン: 保持側に `attack_options(start.pair, ball)`、相手に `defense_options(start.pair)`。
  - トランジション: 保持側に `pos_transition_options(counter_layout(origin.attacker, 保持側の方式), ball)`、相手に `neg_transition_options()`。
  - `MoveRules.is_allowed` が偽なら null。
- 結果の反映（`requirements.md` の表）:
  - 選手の固定は `output.pair` の各チームの `players` から写す（維持）。リセットのときは `fixed_area = null`。
  - 保持が入れ替わるときは、ボール位置を鏡像にする（新しい保持側の視点）。
  - トランジションへ入るとき: `transition_origin = LayoutPair(新しい保持側の配置, 相手の配置, 新しい保持側)`。配置は `output.pair` の各チーム。
- ハーフ: `turn_number += 1`。`turn_number > rules.turns_per_half` なら、
  - 前半: `stage = HALFTIME`（得点でも `STYLE_CHANGE` にしない）。
  - 後半: `stage` は `TURN` のまま、`is_play_complete` が真になる。
  - それ以外で得点なら `stage = STYLE_CHANGE`・`possession = 失点側`。
- ターン記録: `seq = turn_records.size() + 1`。動きは `start.movements`（方式の動き）＋ `output.movements`。
- `apply_halftime`: `half = 2`・`turn_number = 1`・陣形と方式を差し替え、選手を新しい陣形の基本配置にして、`_kickoff(state, other(first_half_kickoff))`。
- `finish`: `status = FINISHED`。

### 3. `MoveRules.options_for(state, side)`
- `state.turn_kind` と `side == state.possession` で、上の `resolve_turn` と同じ組み立てをする。両者で同じ関数を使い、手の確かめと選べる手の表示がずれないようにする（`resolve_turn` は `options_for` を呼ぶ）。
- 配置の組み立て（`current_layouts`）は `match/` にあるため、`options_for` から呼ぶと `judge/` → `match/` の向きになる。そこで、配置の組み立て（`TeamLayout.at_base` → `compute`、トランジションは起点）は `layout/` の `StyleLayoutCalculator.turn_start(state) -> LayoutStep` に置く。`MatchRules.current_layouts` はそれを返すだけにする（最初は `MatchState.layouts_at_turn_start` に置いたが、実装レビューの提案で値オブジェクトからアルゴリズムへの依存を外した）。

### 4. `MoveOptions` の組み合わせ違いの検出
- `add_target` を運ぶ先を持たない手に、`allow` を運ぶ先を持つ手に呼んだら、`push_error` して受け付けない。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/match_values_test.gd`: `TeamSetup`・`MatchState`・`TurnRecord`・`TurnResolution` の `duplicate_deep`、`MatchState` の便利関数、`MatchRuleConfig` の初期値。
- `tests/domain/match/match_rules_test.gd`:
  - キックオフ、`current_layouts`（攻守ターンはアルゴリズム2を適用、トランジションは起点）。
  - 結果の反映の表のすべての行（局面を組み立てて、各結果になる手を選ぶ）。
  - ハーフ・最終ターンの得点・後半のキックオフ側・試合終了。
  - 方式の選び直し・ハーフタイム（陣形の変更・存在しない陣形）。
  - 選択不可の手・範囲外の手の値・進行段階違いで null。
  - 通しの試合（決まった手の並びで2ハーフ）、対称性（HOME/AWAY の入れ替え）、入力を書き換えない。
- `tests/domain/judge/move_rules_test.gd` に `options_for` のテスト、`move_values_test.gd` に組み合わせ違いの `push_error` のテスト。
- 期待値は仕様の規則から手で書く。

## ディレクトリ構造

```
game/domain/{team_setup.gd, match_state.gd, turn_record.gd, turn_resolution.gd}
game/domain/config/match_rule_config.gd
game/domain/match/match_rules.gd
game/tests/domain/{match_values_test.gd, match/match_rules_test.gd}
（変更）game/domain/judge/move_rules.gd, game/domain/move_options.gd, 各テスト
```

## 実装の順序

1. 値オブジェクト（テスト先行）
2. `MatchState.layouts_at_turn_start` と `MoveRules.options_for`、`MoveOptions` の検出（テスト先行）
3. `MatchRules`（テスト先行。キックオフ → 攻守ターンの反映 → トランジションの反映 → ハーフ → 選び直し → 通し）
4. 変異で確かめる（スクリプトは Git Bash を明示し、件数の無い結果は無効）
5. 文書の更新（`component-design.md` §2.2・§2.4・§2.5、`data-definition.md` への申し送りは振り返りに）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。1ターンの解決は配置計算と判定の数回分。通しの試合のテストでも24ターンで、問題にならない。

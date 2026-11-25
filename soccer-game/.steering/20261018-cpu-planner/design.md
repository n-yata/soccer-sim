# 設計書

## アーキテクチャ概要

```
MoveHints.evaluate(state, side, options) -> Array[ChoiceHint]       （judge/）
  攻守ターン: start = StyleLayoutCalculator.turn_start(state)
    保持側: 攻撃の手 → OpenPlayJudge.apply_attack（ドリブル・付け直し）→ OpenPlayJudge.detail_at
    相手:   守備の手 → OpenPlayJudge.detail_at(start.pair, T, false)（適用前の人数）
  トランジション: origin = state.transition_origin
    奪取側: COUNTER → TransitionJudge.counter_layout → detail_at、SECURE → 比べない
    喪失側: COUNTER_PRESS → X と上下左右の合計、RETREAT → 比べない
CpuPlanner（cpu/）
  choose_turn(state, side, cpu, rng): options_for → evaluate → 評価値 → probabilities → rng で抽選
  probabilities(scores, cpu)
  choose_setup(catalog, rng) / choose_styles(rng)
```

依存の向き: `cpu/` → `judge/`（`MoveHints`・`MoveRules`）。`judge/` は `cpu/` を呼ばない（`component-design.md` §7）。

## コンポーネント設計

### 1. `ChoiceHint`（`domain/choice_hint.gd`）
- `family`・`action`・`target`（攻撃側の視点。無ければ null）・`is_compared`・`own_count`・`opponent_count`・`cover`。
- `diff() -> int`（`own_count - opponent_count`。札の `+1` などに使う）。`duplicate_deep()`。
- 推奨の印・評価値は持たない。

### 2. `OpenPlayJudge.apply_attack(pair, defender_styles, ball, attack) -> LayoutStep`
- `judge` の手順3（ドリブルなら選手を動かし、マンツーマンなら付け直す。ドリブル以外は配置の写し）を切り出して公開する。`judge` もこれを呼ぶ。

### 3. `MoveHints.evaluate`
- 人数は、その手を選ぶ側から見た値で入れる。
  - 攻撃・カウンター: `own = attacker_count`・`opponent = defender_count`（`detail_at` の値）。
  - 守備: `own = defender_count`・`opponent = attacker_count`。
  - 即時奪回: `own = 喪失側の合計`・`opponent = 奪取側の合計`（`TransitionJudge` と同じ数え方。合計の関数を公開して共有する: `TransitionJudge.total_around(layout, center)`）。
- 並び: `options` の手の並び（攻撃: SHORT_PASS・DRIBBLE・LONG_BEHIND・SWITCH・SHOT の enum の順、運ぶ先は `PitchArea.all()` の順）。

### 4. `CpuPlanner`
- 評価値（`_score(hint)`）
  - 比べない手: 0
  - 守備の手: `opponent_count - own_count`（脅威度）
  - それ以外: `own_count - opponent_count`
- `probabilities(scores, cpu)`:
  - `N = scores.size()`。0 なら空。
  - softmax は `exp((s_i - max) / τ)` で計算し、オーバーフローを防ぐ。
  - `p_i = floor / N + (1 - floor) * soft_i`。
- 抽選: `r = rng.randf()`。累積確率が `r` を超えた最初の手を選ぶ。浮動小数の誤差で最後まで超えなければ最後の手。
- `choose_turn` は、選べる手が1つも無ければ null（呼び出し側の誤り。通常は起きない）。
- `choose_setup`: 陣形は `catalog.formations` から `rng.randi_range(0, n - 1)`、方式はそれぞれ `randi_range(0, 1)`。陣形が無ければ null。
- `choose_styles`: 守備・攻撃をそれぞれ `randi_range(0, 1)`。

### 5. `CpuConfig`（`domain/config/cpu_config.gd`。`extends Resource`）
- `@export var temperature: float = 1.0`・`@export var floor_probability: float = 0.1`（`functional-overview.md`「設定値として外部化する値」の初期値）。
- 範囲（τ > 0、0 ≤ floor < 1）の検査はデータ層（`ConfigRepository`）が行う。ドメインは渡された値を使う。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/judge/move_hints_test.gd`: 攻撃（パス・ドリブル・シュート・マンツーマンの追従）、守備（適用前の人数・カバー）、カウンター（飛び出し後）、即時奪回（合計）、リトリート・保持（比べない）、判定の内訳との一致（相手の手が影響しない場面）、選べない手は出さない。
- `tests/domain/cpu/cpu_planner_test.gd`: `probabilities`（等確率・単調・下限・合計1・極端な値）、`choose_turn`（多くのシードで `is_allowed` を通る・固定シードで再現・評価値の高い手が多く選ばれる）、`choose_setup`・`choose_styles`（範囲・全組み合わせが出る）。
- `match_values_test.gd` に `CpuConfig` の初期値、`choice_hint` の値オブジェクトのテスト（新しいテストファイル `hint_values_test.gd`）。
- 期待値は仕様から手で書く。

## ディレクトリ構造

```
game/domain/choice_hint.gd
game/domain/config/cpu_config.gd
game/domain/judge/move_hints.gd
game/domain/cpu/cpu_planner.gd
game/tests/domain/{hint_values_test.gd, judge/move_hints_test.gd, cpu/cpu_planner_test.gd}
（変更）game/domain/judge/open_play_judge.gd, game/domain/judge/transition_judge.gd
```

## 実装の順序

1. `ChoiceHint`・`CpuConfig`（テスト先行）
2. `OpenPlayJudge.apply_attack`・`TransitionJudge.total_around` の公開（既存のテストが通ること）
3. `MoveHints.evaluate`（テスト先行）
4. `CpuPlanner`（テスト先行）
5. 変異で確かめる（Git Bash を明示、件数と落ちたテストの名前を出す）
6. 文書の更新（`component-design.md` §2.2・§2.4・§2.6）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。乱数は注入されたものだけを使う。
- ヒントは選べる手の数（最大で数十）× 配置計算1回程度。問題にならない。

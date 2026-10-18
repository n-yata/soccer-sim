# 設計書

## アーキテクチャ概要

```
MoveRules（judge/。アルゴリズム3）  局面の値 → MoveOptions
  attack_options(pair, ball)          攻撃側の視点
  defense_options(pair)               T_d は攻撃側の視点
  neg_transition_options()            常に2つ
  pos_transition_options(winner, ball) 奪った側の視点
  is_allowed(options, choice)

DefenseMover（layout/。アルゴリズム4）
  apply(pair, action, target) → LayoutStep（選べない手なら null）
```

すべて `static` の純粋関数。ドメイン層の禁止依存を使わない。
人数は `TeamLayout.count_at`（現在エリア）で数える。相手チームの人数は鏡像で変換して数える。

## コンポーネント設計

### 1. `TurnChoice`（`domain/turn_choice.gd`）
- `_init(family, action, target = null)`・`duplicate_deep()`。

### 2. `MoveOptions`（`domain/move_options.gd`）
- 内部: `"family:action"` → `Array[PitchArea]`（運ぶ先を持つ手）、`"family:action"` → `true`（運ぶ先を持たない手で、選べるもの）。
- `add_target(family, action, area)`・`allow(family, action)`（運ぶ先を持たない手）。
- `is_available(family, action) -> bool`: 運ぶ先を持つ手は一覧が1件以上、持たない手は `allow` 済み。
- `targets(family, action) -> Array[PitchArea]`（コピー。無ければ空）。
- `static needs_target(family, action) -> bool`: `ATTACK` は `SHOT` 以外、`DEFENSE` はすべて、`NEG_TRANS` はなし、`POS_TRANS` は `COUNTER`。
- `duplicate_deep()`。

### 3. `MoveRules`（`domain/judge/move_rules.gd`）
- 運ぶ先は `PitchArea.all()` の順に並べる（決定的にするため）。
- `attack_options`: 下表。`味方` は `pair.attacker.count_at(T) >= 1`。

  | 手 | 条件 |
  |---|---|
  | `SHORT_PASS` | `T ∈ ball.neighbors8()` かつ味方 |
  | `DRIBBLE` | `T` が `ball.forward()`、または同じゾーンでレーンが1つ違う |
  | `LONG_BEHIND` | `ball.zone == D`、`T.zone == A`、レーン差 ≤ 1、味方 |
  | `SWITCH` | 同じゾーン、レーン差 ≥ 3、味方 |
  | `SHOT` | `ball.zone == A` かつ `ball.lane ∈ {C, L1, R1}` |

- `defense_options`: `T` を15エリアから選ぶ。守備側から見た `T_d = T.mirrored()`。守備側の人数は `pair.defender.count_at(...)`。
  - `PRESS`: `T_d.neighbors4()` のどこかに守備側が1人以上。
  - `COVER`: `T_d.zone != D`、かつ `T_d` か `T_d.neighbors4()` に守備側が1人以上。
- `pos_transition_options(winner, ball)`: `SECURE` は `allow`。`COUNTER` は `ball.zone + 1`・`+ 2` のゾーン（盤内）の全レーンのうち、`winner.count_at(T) >= 1`。
- `is_allowed`: `is_available` が偽なら拒否。`needs_target` なら `target` が一覧にあること、そうでなければ `target == null` であること。

### 4. `DefenseMover`（`domain/layout/defense_mover.gd`）
- `apply(pair, action, target)`:
  1. `T_d = target.mirrored()`（守備側の視点）。
  2. 動かす元のエリアを選ぶ。
     - `PRESS`: `_press_source(pair, T_d)`。
     - `COVER`: `T_d` に守備側がいれば `T_d`、いなければ `_press_source`。
  3. 行き先: `PRESS` は `T_d`、`COVER` は `T_d.backward()`（null なら選べない手 → `null`）。
  4. 元のエリアから選手を1人選ぶ（固定されていない選手を優先、配置の順で先）。いなければ `null`。
  5. その選手の `fixed_area` と現在エリアを行き先にした配置と、`Movement(defender_side, id, 元, 行き先, PRESS/COVER)` を返す。元と行き先が同じ（`COVER` で背後にいた選手）なら、固定だけして `Movement` は出さない（実装レビューの指摘）。
- `_press_source(pair, T_d)`: `T_d.neighbors4()` のうち守備側が1人以上いるエリアを、次の優先順で並べ、余りが最大のもの。
  - 余り = 守備側人数(n) − 攻撃側人数(n.mirrored())。
  - 優先順（守備側の視点）: 前方（`zone + 1`）→ 横（`absi(lane - C)` が小さい順、同じなら左）→ 背後（`zone - 1`）。
- 優先順・余りの比較はルールの定義そのもので、調整値ではない。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/move_values_test.gd`: `TurnChoice`・`MoveOptions`（`needs_target`、`is_available`、`targets` のコピー、`duplicate_deep`）。
- `tests/domain/judge/move_rules_test.gd`: 手ごとの条件（盤の中央・辺・角、味方の有無）、`SHOT` のレーン、守備の手の条件と視点の変換、トランジション、`is_allowed` の正常と拒否。
- `tests/domain/layout/defense_mover_test.gd`: 余りが最大のエリア、余りが負でも動かす、同率の優先順（前方・横の中央寄り・左・背後）、固定されていない選手を優先、固定された選手の固定先の更新、`COVER`（`T_d` にいる／いない）、選べない手で `null`、入力を書き換えない、`Movement` の値、マンツーマンでプレスの後の `remark`。
- 期待値は仕様から手で書く。

## ディレクトリ構造

```
game/domain/{turn_choice.gd, move_options.gd}
game/domain/judge/move_rules.gd
game/domain/layout/defense_mover.gd
game/tests/domain/{move_values_test.gd, judge/move_rules_test.gd, layout/defense_mover_test.gd}
```

## 実装の順序

1. 値オブジェクト（テスト先行）
2. `MoveRules`（テスト先行）
3. `DefenseMover`（テスト先行）
4. 変異で、重要なテストが落ちることを確かめる
5. 文書の更新（`component-design.md` §2.2〜2.4）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。1回の計算は15エリア × 隣接エリア程度で、問題にならない。

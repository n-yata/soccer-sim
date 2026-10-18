# 設計書

## アーキテクチャ概要

```
TransitionJudge.judge(origin, winner_styles, loser_styles, ball, winner_choice, loser_choice) -> JudgeOutput（選べない手なら null）
  1. 手の種類を確かめる（winner は POS_TRANS、loser は NEG_TRANS。COUNTER は運ぶ先が要る）
  2. 奪取側: COUNTER なら counter_layout（カウンター型の飛び出し）。SECURE は origin のまま
  3. 喪失側: RETREAT なら StyleLayoutCalculator.retreat（2 の後の奪取側の配置に対して）。COUNTER_PRESS は origin のまま
  4. 判定: COUNTER → OpenPlayJudge.detail_at / outcome_of（T で手順5〜6）
           COUNTER_PRESS × SECURE → X と上下左右の人数合計
           RETREAT × SECURE → NO_CONTEST
```

すべて `static` の純粋関数。ドメイン層の禁止依存を使わない。動きは、奪取側 → 喪失側の順に並べる。

## コンポーネント設計

### 1. `TransitionJudge`（`domain/judge/transition_judge.gd`）
- `counter_layout(winner: TeamLayout, winner_styles) -> TeamLayout`（公開。`MoveRules.pos_transition_options` に渡す配置を作るのにも使う）
  - カウンター型: 固定されていない選手のうち、現在エリアのレーンが `L2`・`R2` で `forward()` が盤内の選手を1ゾーン前へ。固定はしない。
  - 保持型: 配置のコピー。
  - 動き（理由 `COUNTER_BREAKOUT`）は、`judge` の中で `origin` と `counter_layout` の結果を比べて作る（`LayoutStep` は両チームの組を持つ型なので、1チームの配置の関数では返さない）。
- 即時奪回×保持: `_total_around(layout, x)` = `x` と `x.neighbors4()` の人数の合計。奪取側は `x`、喪失側は `x.mirrored()` の視点で数える。喪失側の合計 > 奪取側の合計 → `REGAIN`、そうでなければ `REGAIN_FAILED`。`JudgeDetail(x, 奪取側の合計, 喪失側の合計, NONE)`。
- カウンター: `OpenPlayJudge.detail_at(pair, T, false)` と `OpenPlayJudge.outcome_of(detail, false)`。
- リトリート×保持: `JudgeOutput(NO_CONTEST, null, pair, movements)`。

### 2. `StyleLayoutCalculator.retreat(pair, defender_styles, ball) -> LayoutStep`
- `reset_segment(pair.defender)` を起点に、`ZONE` は `_slide`（ボールは `ball.mirrored()`）、`MAN` は `_mark`（対象は `pair.attacker` の現在エリア）。
- 動き: `pair.defender` の現在エリア → 最終のエリアが違う選手だけ。理由 `RETREAT_RESET`。チームは `pair.defender_side()`。
- 戻り値の `pair` は、攻撃側のコピーと新しい守備側。

### 3. `OpenPlayJudge` の公開
- `_detail` → `detail_at(pair, compare, is_shot)`、`_outcome` → `outcome_of(detail, is_shot)` に改名して公開する（中身は変えない）。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/judge/transition_judge_test.gd`:
  - JE-07 の2つ（`formations.json` → アルゴリズム1・2 → 直前の配置 → `TransitionJudge.judge`）。カウンター型の飛び出し後の奪取側の配置も確かめる。
  - 即時奪回×保持: 喪失側が上回る → `REGAIN`、同数 → `REGAIN_FAILED`。
  - カウンターの同数のカバー判定（敵陣の大外・中央）。
  - リトリート×保持 → `NO_CONTEST`。リトリート×カウンター → 戻った後の配置で比較する。
  - 保持型の奪取側は飛び出さない、固定された選手は飛び出さない。
  - 選べない手で `null`、入力を書き換えない、対称性。
- `tests/domain/layout/style_layout_calculator_test.gd` に `retreat` のテスト: 固定の解除、ゾーンのスライドの向き、マンツーマンのマーク、動きの理由、入力を書き換えない。
- 期待値は仕様の判定例と規則から手で書く。

## ディレクトリ構造

```
game/domain/judge/transition_judge.gd
game/tests/domain/judge/transition_judge_test.gd
（変更）game/domain/layout/style_layout_calculator.gd, game/domain/judge/open_play_judge.gd, game/tests/domain/layout/style_layout_calculator_test.gd
```

## 実装の順序

1. `retreat`（テスト先行）
2. `OpenPlayJudge` の比較の公開
3. `TransitionJudge`（テスト先行。JE-07 を先に）
4. 変異で、重要なテストが落ちることを確かめる
5. 文書の更新（`component-design.md` §2.3・§2.4）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。1回の判定は配置計算の数回分で、問題にならない。

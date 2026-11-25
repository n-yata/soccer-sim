# 設計書

## アーキテクチャ概要

```
StyleLayoutCalculator.reset_segment(layout) → TeamLayout（固定なし・全員が基本エリア）
StyleLayoutCalculator.compute(attacker, attacker_styles, defender, defender_styles, ball, attacker_side) → LayoutStep
  1. 両チームとも: 固定された選手は固定先、それ以外は基本エリアに置く
  2. 攻撃側: 攻撃方式の動き（POSSESSION の前進）
  3. 守備側: 守備方式の動き（ZONE のスライド／MAN のマーク。MAN は 2 の後の攻撃側の位置を使う）
  4. 起点（基本エリア）から変わった選手を Movement にする
StyleLayoutCalculator.remark(pair, defender_styles) → LayoutStep（MAN だけ。起点は pair の現在エリア）
```

すべて `static` の純粋関数。ドメイン層の禁止依存（ノード・ファイル・時刻・乱数）を使わない。

## コンポーネント設計

### 1. 値オブジェクト
- `TeamStyles`（`domain/team_styles.gd`）: `_init(defense, attack)`・`duplicate_deep()`。
- `LayoutPair`（`domain/layout_pair.gd`）: `_init(attacker, defender, attacker_side)`。`defender_side()` は `attacker_side` の反対。`duplicate_deep()`。
  - 仕様の `attacker`・`defender` に `attacker_side` を足した。`Movement.side` を埋めるため（`compute` も同じ理由で `attacker_side` を受け取る）。
- `Movement`（`domain/movement.gd`）: `_init(side, player_id, from, to, reason)`。座標は動いた選手のチーム自身から見た値（§1.2）。`duplicate_deep()`。
- `LayoutStep`（`domain/layout/layout_step.gd`）: `_init(pair, movements)`。配列はコピーして持つ。`duplicate_deep()`。

### 2. `StyleLayoutCalculator`（`domain/layout/style_layout_calculator.gd`）

#### `reset_segment(layout: TeamLayout) -> TeamLayout`
- 各選手を `PlayerState.new(id, base_area)`（固定なし）で作り直し、`TeamLayout.at_base` で返す。

#### `compute(...) -> LayoutStep`
- 選手ごとの起点: 固定された選手は `fixed_area`、それ以外は `base_area`。
- 攻撃側 `POSSESSION`: 固定されていない選手のうち、起点のレーンが `L2`/`R2` で `forward()` が null でない選手を、1ゾーン前へ動かす（理由 `POSSESSION_ADVANCE`）。
- 守備側 `ZONE`: ボールを守備側の視点にする（`ball.mirrored()`）。
  - そのレーンが `L1`/`L2` なら向き −1、`R1`/`R2` なら +1、`C` なら 0。
  - 固定されていない選手のレーンを向きの分ずらし、`L2`〜`R2` に収める（ボールサイドの大外の選手はそのまま）。動いた選手の理由は `SLIDE`。
- 守備側 `MAN`（`_mark` を `compute` と `remark` で共有）:
  - 対象: 攻撃側の各選手の現在エリアを鏡像にして（守備側の視点）、ゾーンが `D`・`M` のもの。
  - 対象の優先順: ゾーン（`D` → `M`）→ レーンの順位（`C`=0、`L1`=1、`R1`=2、`L2`=3、`R2`=4）→ 攻撃側の選手の順。
  - マーカー: 固定されていない守備側の選手のうち、基本エリアのゾーンが `D`・`M` の選手。
  - マークする対象は、優先順の上からマーカーの人数分。
  - 割り当て: 対象と同じエリアに起点があるマーカーをそのまま残す（実装レビューの指摘。`remark` での入れ替わりを防ぐ）。残りは優先順に、起点とのゾーン差＋レーン差が最小のマーカーを選ぶ（同じなら配置の選手の順）。マーカーを対象のエリアに置く（理由 `MARK`）。
  - 余ったマーカーは `D-C` に置く（理由 `MARK`。カバー役）。基本エリアが `A` の選手は起点に残る。
- `Movement` は、起点と結果のエリアが違う選手だけ。順序は攻撃側 → 守備側、各チーム内は配置の選手の順。

#### `remark(pair: LayoutPair, defender_styles: TeamStyles) -> LayoutStep`
- `MAN` のとき: 守備側の起点を pair の現在エリアにして `_mark` を回す。攻撃側は動かさない。
- `ZONE` のとき: pair のコピーをそのまま返す（`movements` は空）。

### 3. 定数
- 余りのマーカーの置き場所 `D-C`、レーンの順位はルールの定義そのもので、調整値ではない。定数で持つ（`BaseLayoutDeriver` と同じ扱い）。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/layout_values_test.gd`: `TeamStyles`・`LayoutPair`（`defender_side`）・`Movement`・`LayoutStep` の `duplicate_deep` と、受け取った配列のコピー。
- `tests/domain/layout/style_layout_calculator_test.gd`:
  - `reset_segment`: 固定の解除・基本エリアへ戻す・入力を変えない。
  - `POSSESSION`／`COUNTER`。
  - `ZONE`: ボールが `C`（ずれない）、守備側から見て左・右（大外が2レーン分集まる）、鏡像の向き。
  - `MAN`: ちょうど足りる、余る（`D-C`）、足りない（優先順）、`A` のマーカーは残る、保持型の前進の後の位置を対象にする。
  - 固定された選手が巻き込まれない（3方式）、`compute` が固定を解除しない。
  - `remark`: 対象が動くとマーカーがついていく、`ZONE` は変わらない。
  - 人数の合計が10のまま（4陣形 × 方式の全組み合わせ × 15のボール位置。実データの陣形で）。
  - 入力の配置を書き換えない。
- 期待値は仕様の規則から手で書く（実装の式を使わない）。

## ディレクトリ構造

```
game/domain/{team_styles.gd, layout_pair.gd, movement.gd}
game/domain/layout/{layout_step.gd, style_layout_calculator.gd}
game/tests/domain/{layout_values_test.gd, layout/style_layout_calculator_test.gd}
```

## 実装の順序

1. 値オブジェクト（テスト先行）
2. `reset_segment` と攻撃方式（テスト先行）
3. `ZONE`（テスト先行）
4. `MAN` と `remark`（テスト先行）
5. 人数の合計の網羅テスト・入力を書き換えないテスト
6. 文書の更新（`component-design.md` §2.2・§2.3 の `LayoutPair`・`compute` の引数、マーカーの割り当て）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。1回の計算は20人程度で、問題にならない。

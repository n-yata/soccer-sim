# 要求内容

## 概要

アルゴリズム2「現在配置の算出（方式による動き方）」をドメイン層に作る（`functional-overview.md`・`component-design.md` §2.3）。
ターンの開始時に、両チームの選手を次の4つから配置し直す。
- 基本配置
- 方式（攻撃方式・守備方式）
- ボール位置
- 固定された選手

あわせて、配置の変化を返すための値オブジェクトを作る。
- `TeamStyles`
- `LayoutPair`
- `Movement`
- `LayoutStep`

## 背景

- ルールの土台（`../20261018-rule-foundation/`）で、基本配置（アルゴリズム1）までができた。
- 試合画面（S-03）の作戦ボードに出す「ターン開始時の配置」は、アルゴリズム2で決まる。次の3つがすべて、この配置の上に乗る。
  - 守備の手（アルゴリズム4）
  - 判定（アルゴリズム5・6）
  - 試合進行（アルゴリズム7）
- シャビの指示（2026-10-18「アルゴリズム2に進んで」）。

## 実装対象の機能

### 1. 値オブジェクト（`game/domain/`）
- `TeamStyles`（`team_styles.gd`）: `defense: DefenseStyle`・`attack: AttackStyle`
- `LayoutPair`（`layout_pair.gd`）: 判定中の両チームの `TeamLayout`（`attacker`・`defender`）と、攻撃側のチーム `attacker_side`（`TeamSide`）。`defender_side()` を持つ
- `Movement`（`movement.gd`）: `side`・`player_id`・`from`・`to`・`reason: MovementReason`。座標は、動いた選手のチーム自身から見た値
- `LayoutStep`（`layout/layout_step.gd`）: `pair: LayoutPair` と `movements: Array[Movement]`
- どれも `RefCounted` を継承し、`duplicate_deep()` を持つ。受け取った値はコピーして持つ。

### 2. `StyleLayoutCalculator`（`game/domain/layout/style_layout_calculator.gd`）
- `reset_segment(layout)`: アルゴリズム2の手順1。全選手を基本エリアに戻し、固定を解除する。
- `compute(attacker, attacker_styles, defender, defender_styles, ball, attacker_side)`: 手順2〜4。ターン開始時の両チームの配置と、方式の動きを返す。`ball` は攻撃側から見た座標。
  - 固定された選手: 固定先に置き、方式の動きの対象外にする。
  - 固定されていない選手: 基本エリアを起点に、方式の動きを適用する。前のターンの方式の動きは持ち越さない。
  - 攻撃側 `POSSESSION`: 基本エリアが大外（`L2`/`R2`）の選手が1ゾーン前へ出る（`A` はそのまま）。`COUNTER`: 基本エリアのまま。
  - 守備側 `ZONE`: ボールが守備側から見て左（`L1`/`L2`）なら全員が左へ1レーン、右なら右へ1レーンずれる。ボールサイドの大外の選手はそのまま。ボールが `C` レーンならずれない。
  - 守備側 `MAN`: 仕様どおりにマークをつける（対象・マーカー・優先順・余りは `D-C`）。
- `remark(pair, defender_styles)`: マンツーマンのマークを付け直す（ドリブル・プレス・カバーの後に呼ぶ）。`ZONE` では何も動かさない（ずれる基準はターン開始時のボール位置のため）。
- 入力を書き換えない（`component-design.md` §1.1）。

## 受け入れ条件

- テストは先に失敗する状態から書く（Red→Green）。`bash tools/run-tests.sh` が成功する（件数が増え、失敗0）。
- 各チームの人数の合計は、どの方式の組み合わせでも10のまま。
- `reset_segment`: 固定された選手の固定が解除され、全員が基本エリアに戻る。入力の配置は変わらない。
- `POSSESSION`: 大外の選手だけが1ゾーン前へ出て、`A` の大外の選手はそのまま。`COUNTER` は基本配置のまま。
- `ZONE`
  - ボールが `C` レーンならずれない。
  - ボールが守備側から見て左・右のハーフスペース／大外のとき、全員が1レーンずれる。ボールサイドの大外の選手が2レーン分集まる。
  - ボールの向きは鏡像で守備側の視点に変換する。攻撃側から見た右（`R1`）は、守備側から見た左（`L1`）。
- `MAN`
  - マーカーがちょうど足りる／余る（余りは `D-C`）／足りない（守備側ゴールに近い対象から、優先順のとおり）の各場合。
  - 基本エリアが `A` のマーカーは基本エリアに残る。
  - 攻撃側の保持型の前進の後の位置を、マークの対象に使う。
- 固定された選手は、`ZONE`・`MAN`・`POSSESSION` の動きに巻き込まれない。`compute` は固定を解除しない（トランジションターンで解除されないことは、呼び出し側が `reset_segment` を呼ばないことで守る）。
- `remark`: 攻撃側の選手が動いたあと、マーカーがついていく。`ZONE` では配置が変わらない。
- `movements` には、配置が変わった選手だけが、理由（`SLIDE`・`MARK`・`POSSESSION_ADVANCE`）とチームつきで入る。
- 禁止依存の検査で 0 件、型の警告 0 件。

## 成功指標

- アルゴリズム2のエッジケース（4項目）すべてに、対応するテストがある（NFR-14 のこの範囲）。

## スコープ外

- アルゴリズム3以降（選択可能な手・守備の手・判定・試合進行・CPU）
- 試合画面（S-03）と作戦ボード
- `MatchState` など試合の状態

## 参照ドキュメント

- `docs/specs/1_requirements/functional-overview.md`（ドメイン上の制約・アルゴリズム2）
- `docs/specs/2_basic-design/component-design.md`（§1.1・§1.2・§2.2・§2.3）

## 未決事項（設計で既定を決めた）

- `Movement.side` を埋めるため、`compute` に `attacker_side` を足し、`LayoutPair` に `attacker_side` を持たせる（仕様の引数には無かった）。
- マンツーマンで、どのマーカーをどの対象につけるか（仕様は人数だけを決めている）。優先順の高い対象から順に、起点のエリアがいちばん近い（ゾーン差＋レーン差が最小）マーカーを割り当てる。同じ距離なら配置の選手の順。エリアごとの人数は、割り当てによらず同じ。

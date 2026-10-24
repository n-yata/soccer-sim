# 設計

## 1. 基本配置の散らし（`BaseLayoutDeriver`）
- `derive` は、GK を除く選手の座標のエリアを出したあと、D・M・A のゾーンごとに `_spread_zone` をかける。
- `_spread_zone`: そのゾーンで同じレーンに2人以上いて、人数が5人以下なら、x の昇順（同じ x は陣形データの順）に並べ、`_spread_lanes` で左から別々のレーンへ置く。
- `_spread_lanes`: 人数ぶんの増加するレーンの組み合わせ（最大 C(5,n) ≤ 10 通り）を辞書順にすべて調べ、レーンの中心 `SPREAD_LANE_CENTERS`（10・30・50・70・90）との差の合計が最小、同じなら中心の平均と x の平均の差が最小、同じなら先に見つけたものを選ぶ。
- 結果（列: L2 / L1 / C / R1 / R2）:
  - 4-4-2: A 0 1 0 1 0 / M 1 1 0 1 1 / D 1 1 0 1 1
  - 4-3-3: A 1 0 1 0 1 / M 0 1 1 1 0 / D 1 1 0 1 1
  - 4-2-3-1: A 0 0 1 0 0 / M 1 1 1 1 1 / D 1 1 0 1 1
  - 3-5-2: A 0 1 0 1 0 / M 1 1 1 1 1 / D 0 1 1 1 0

## 2. 判定例の場面
- 判定例 JE-01〜07 は陣形の基本配置から場面を組んでいた。判定の規則は変えていないので、場面は座標のエリア（散らす前）のまま残す。
- テストの補助 `JudgeExampleLayouts.at_coordinates(formation)` で、座標のエリアにそのまま置いた配置を作る。仕様書の判定例に、その旨と座標のエリアの表を書く。

## 3. ドリブル（`MoveRules.attack_options`）
- 運ぶ先は `_is_neighbor8(ball, target)`（周り8エリア）。味方の有無は問わない（今と同じ）。

## 4. 保持の表示（`MatchScreen`）
- 上部バーのスコア表示の右に `PossessionLabel` を置く。文は `MatchTexts.possession_text(user_has_ball)`、地はテーマの `YouChipLabel`／`OpponentChipLabel`。
- ターン開始（`turn_started`）と判定の表示（`result_shown`）で、そのときの `BoardSnapshot` から替える。開示中も隠さない。

## 5. 仕様書
- functional-overview（アルゴリズム1の規則と表・エッジケース、アルゴリズム3のドリブル、判定例の前書き、CPU の根拠の実測）、glossary（ドリブル）、screen-design と screen-03（上部バー）。

# 設計

## 方針
- 列（`GameEnums.Zone`）を6つにする。規則の多くは列の差・隣のマス・`forward()`/`backward()`・`mirrored()` で書かれているので、そのまま6列で動く。列の名前を直接使っている規則だけを、要求書の読み替えで書き直す。
- テストのエリアのキーは、機械的に置き換えない。3列の D・M・A をどう写しても、相手の視点（D↔A、M↔M）の対称が保てないため。場面ごとに6列で組み直し、期待値を手で書き直す。

## 1. 盤面（`GameEnums`・`PitchArea`）
- `enum Zone { D1, D2, M1, M2, A1, A2 }`。`PitchArea.ZONE_COUNT = 6`、キーの列名は `D1`〜`A2`（`M1-C` の形）。
- `mirrored()` は今の式（`ZONE_COUNT - 1 - zone`）のまま（D1↔A2、D2↔A1、M1↔M2）。
- 自陣（1〜3列目）かを `PitchArea.is_own_half()` で表す（ロングボール・キックオフ・テストで使う）。

## 2. 基本配置とキックオフ（`BaseLayoutDeriver`）
- `_zone_of(y)`: `floor(y / (100/6))`（上限 5）。境界ちょうどは前の列。
- 重なりを散らす規則は列ごとにそのまま（`_spread_zone` を6列で回す）。
- **キックオフの位置** `kickoff_areas(players) -> Dictionary`（選手 ID → エリア）:
  - 列は、基本エリアの列番号を2で割って切り捨てたもの（D1・D2→D1、M1・M2→D2、A1・A2→M1）。座標の y を半分にした列と一致する（列 r の y は [r·h, (r+1)·h)、その半分は [r·h/2, (r+1)·h/2) で、どちらも列 floor(r/2) に入る。h = 100/6）。そのため座標を持ち回らずに、基本エリアだけから決まる。
  - レーンは、同じキックオフの列に重なりがあれば、基本エリアのレーンの中心（`SPREAD_LANE_CENTERS`）を座標の代わりに使って、`_spread_lanes` で散らす（並びは基本エリアのレーン → 配置の順）。
- `MatchPositions.place_for_kickoff`（実装で reset_to_base から改名）（キックオフ）は、`kickoff_areas` の位置に置き、全員に `moved_in_turn` を立てる。キックオフのターン開始では誰も動かさず、縮めた陣形を盤面に見せる。次のターン開始から、方式の動き（目標は基本エリアなど）で1マスずつ上がる。

## 3. 規則の読み替え
| 箇所 | 今 | 6列 |
|---|---|---|
| `MatchRules._kickoff` のボール | `M-C` | `M1-C`（キックオフ側の視点） |
| `MatchRules._ball_after` の SAVE | 攻撃側の視点の `A-C` | 攻撃側の視点の `A2-C`（守備側の `D1-C`） |
| `MoveRules.attack_options` ショートパス | 周り8・味方あり | レーン差・列差が2以内（同じエリアを除く）・味方あり |
| 同 ロングボール | D → A、レーン差1以内 | ボールが1〜3列目、運ぶ先が5・6列目、レーン差1以内 |
| 同 シュート | A の C・L1・R1 | A1・A2 の C・L1・R1 |
| `MoveRules.defense_options` カバー | 制限エリア（守備側の視点）が D なら不可 | D1 なら不可 |
| `MoveRules.pos_transition_options` カウンター | 1〜2ゾーン前 | 1〜4列前（`_COUNTER_MAX_ZONES_AHEAD = 4`） |
| `StyleLayoutCalculator` マンツーマン | 対象・マーカーは D・M | 1〜4列目（`zone <= M2`） |
| 同 余りのマーカー | `D-C` | `D2-C` |
| `CpuConfig` forward_bonus・anticipation_bonus | 1.5・2.0（1ゾーンあたり） | 0.75・1.0（1列あたり。距離あたりは同じ） |
- 保持型の大外の前進・カウンター型の飛び出し・ゾーンのスライド・プレス・カバーの選手の探し方・読み（同じ列でレーン1つ隣）は、列の差・隣で書かれているので変えない。

## 4. 画面
- `TacticsBoard`・`MiniPitch` は `PitchArea.ZONE_COUNT` で描くので、6列になる。`BoardPainter` のピッチの線（ハーフウェーライン・ペナルティエリア）を6列に合わせる。ハーフウェーラインは M1 と M2 の境。
- `MatchTexts.ZONE_NAMES`: 自陣ゴール前／自陣／中盤（自陣）／中盤（敵陣）／敵陣／敵陣ゴール前。
- 押せる範囲（NFR-19。1エリア 96×56dp 以上）を、試合画面の実寸のテストで確かめる。足りなければ、作戦ボードの列の高さの配り方を見直す。

## 5. テストと仕様書
- テストは場面ごとに6列で組み直す。期待値は規則から手で出す。
- 判定例 JE-01〜08 は、陣形の名前を使わない6列の場面で書き直す（JudgeExampleLayouts は使わなくなるので消す）。
- 仕様書: functional-overview（アルゴリズム1〜8・判定例・設定値・ピッチ分割）、glossary、requirements-definition、component-design、screen-design・screen-03・screen-common・screen-02（陣形カード）、data-definition（エリアのキー・範囲）、repository-structure、.drawio（文言の例）。

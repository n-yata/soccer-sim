# 設計

## 結果の演出の区分（`ResultEffect`、新規 `ui/board2d/result_effect.gd`）

見せ方だけの区分なので UI 層に置く（`BallFlight` と同じ考え方）。静的関数だけ。

```gdscript
class_name ResultEffect extends RefCounted
enum Kind { NONE, GOAL, SAVE, WIN_BALL, OFFSIDE, STALL }
## {"kind": Kind, "area": String, "is_user": bool, "toward": String}
static func for_reveal(reveal: RevealView) -> Dictionary
```

| 結果 | kind | area | is_user（色の側） | toward |
|---|---|---|---|---|
| GOAL | GOAL | ball_after（シュートしたエリア） | 決めた側（turn_winner） | — |
| SAVE | SAVE | ball_after（GK の位置） | 止めた側（turn_winner） | — |
| LOSS・REGAIN | WIN_BALL | ball_after | 奪った側（turn_winner） | — |
| OFFSIDE | OFFSIDE | compare_area | 守備側（turn_winner） | — |
| STALL（ボールを持つ側の手に運ぶ先がある） | STALL | ball_after | 止めた側（turn_winner） | 運ぶ先のキー |
| ほか・STALL で運ぶ先が無い | NONE | "" | — | — |

- 得点したゴールは、`is_user` が真なら上（利用者が攻める側）、偽なら下。

## ボールの軌道の追加（`BallFlight`）

- `Kind.BOUNCE`（膠着の跳ね返り）を足す。`along(BOUNCE, t) = 0.4 × sin(π t)`（運ぶ先の方へ4割まで進んで戻る）。高さ 0。
- ほかの種類の「t=1 で 1」は変えない。BOUNCE だけは t=1 で 0（元の位置）。

## 作戦ボード（`TacticsBoard`）

- `start_shift(keyframes, result: Dictionary = {})`。result は `ResultEffect.for_reveal` の値。
  - GOAL: 1拍目のボールの道筋の行き先をゴールの口（`goal_mouth(is_top)`）にし、軌道を強いシュートにする。2拍目のボールの道筋の元もゴールの口にする（2拍目にボールの道筋が無ければ、ゴールの口からいまの位置への道筋を作る）。
  - STALL: 1拍目のボールの道筋を `{"from": いまの位置, "to": 運ぶ先の位置, "flight": BOUNCE}` にする（1拍目の拍が残るように）。
- **着地（`play_landed` シグナル）**: 1拍目（keyframes[0] の拍）が終わったときに1回だけ出す。1拍目の拍が無ければ `start_shift` の中ですぐ出す。動きを途中で止めたとき（`_stop_shift`）、まだ出していなければ出す。
- **演出**: 着地のときに始め、`result_sec` 秒で進み具合を 0→1 にして消す。2拍目と並べて動かす（別の Tween）。`show_snapshot`・`clear_overlays` で消す。
  - 問い合わせ: `result_effect() -> Dictionary`（出していなければ空）、`result_progress() -> float`。
  - `set_result_sec(sec)`（パネルが bind で入れる）。
- `goal_mouth(is_top: bool) -> Vector2`（平面図のゴールの口の中央）と `goal_rect(is_top)` を公開し、`BoardPainter` のゴールの描画もこれを使う（ゴールの位置の正本を1つにする）。

## 描画（`BoardPainter`）

立っているものの後（⑤.5）に描く。色は `you`／`opponent`、進み具合 p で薄くする（α = 1 − p）。
- GOAL: ゴールの四角を決めた側の色で塗り、ゴールの口から輪を広げる。
- SAVE・WIN_BALL: エリアの中央から輪を広げる（半径はエリアの幅の 0.15 → 0.45 倍、幅 4px）。
- OFFSIDE: エリアの中央に旗（ポールと三角）を立てる。
- STALL: 盤面の印は出さない（跳ね返りが演出）。

## 調整値

| 値 | 初期値 | 範囲 |
|---|---|---|
| `board_result_sec`（結果の演出を出す時間） | 0.8 秒 | 0 より大きく 2 以下 |

`MatchController.board_result_sec()` を足す。

## パネル（`MatchBoardPanel`）

- `bind` で `_board.set_result_sec(_controller.board_result_sec())`、`_board.play_landed` をつなぐ。
- `_on_turn_resolved`: テロップの中身と状態（SHOW_RESULT）を先に作ってテロップを隠しておき、`start_shift(keyframes, ResultEffect.for_reveal(reveal))`（着地は `start_shift` の中ですぐ届くことがある）。
- `play_landed` を受けたら、開示中（`_reveal != null`）のときだけテロップを出す。
- `start_turn` は `_reveal = null` にしてから盤面を消すので、前のターンの動きを止めたときに届く着地ではテロップを出さない。
- （実装の途中で、待つ印 `_telop_pending` を持つ形から変えた。変異で確かめたところ、印は `start_turn` が後でテロップを隠すため効いておらず、`_reveal` の有無で足りた。）

## テスト
- `result_effect_test`（新規）: 結果ごとの kind・area・is_user・toward（利用者が攻撃・守備の両方）、STALL で運ぶ先が無いと NONE、NO_CONTEST・ADVANCE・REGAIN_FAILED は NONE。
- `ball_flight_test`: BOUNCE の進み方（0 と 1 で 0、途中で 0.4 まで）。
- `tactics_board_test`: GOAL のボールの道筋（1拍目の行き先・2拍目の元がゴールの口、上下）、STALL の跳ね返りの道筋、着地のシグナル（1拍目の後に1回・1拍目が無ければすぐ・止めたら出る・二重に出ない）、演出の始まり・終わり・消去、`goal_mouth` と描画の一致。
- `match_board_panel_test`: テロップが開示の瞬間は隠れ、着地で出る。次のターンへ進んだ後に前のテロップを出さない。既存のテロップのテストは着地を待つ形に直す。
- `config_repository_test`・`match_controller_test`: `board_result_sec`。

## 変更するドキュメント
- functional-overview.md（設定値の表・表示仕様のテロップの時刻）、component-design.md、screen-design.md、screen-common.md、screen-03-match.md、requirements-definition.md（FR-24 の文）。docs/specs 全体を検索し .drawio も見る。

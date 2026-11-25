# 設計

## 軌道の種類（`BallFlight`、新規 `ui/board2d/ball_flight.gd`）

見せ方だけの区分なので UI 層に置く（ドメインの `GameEnums` には足さない）。`RefCounted` の静的関数だけ。

```gdscript
class_name BallFlight extends RefCounted
enum Kind { STRAIGHT, GROUND, LOFTED, CARRIED, DRIVEN }
static func kind_for(choice: TurnChoice) -> Kind      # null・運ぶ先の無い手は STRAIGHT
static func holder_choice(reveal: RevealView) -> TurnChoice   # ATTACK か POS_TRANS の手。どちらにも無ければ null
static func along(kind: Kind, t: float) -> float       # 道筋に沿った進み具合（0〜1）
static func lift(kind: Kind, t: float, style: Dictionary) -> float   # 高さ（ボールの半径の何倍か）
```

| 手 | Kind | along(t) | lift(t) |
|---|---|---|---|
| SHORT_PASS・THROUGH_PASS・COUNTER | GROUND | 1 − (1 − t)²（蹴り出しが速い） | 0 |
| LONG_BEHIND・SWITCH | LOFTED | t | loft × 4t(1 − t) |
| DRIBBLE | CARRIED | t | touch × \|sin(touches·π·t)\| |
| SHOT | DRIVEN | 1 − (1 − t)³ | 0 |
| ほか（SECURE など）・手が無い | STRAIGHT | t | 0 |

- `style` は `{"loft": float, "touch": float, "touches": int}`（設定の値）。

## `BoardShift`

- ボールの道筋に `"flight": BallFlight.Kind` を持たせる（無ければ STRAIGHT）。
- `ball_position` は、いまの拍なら `from.lerp(to, BallFlight.along(kind, progress))`。
- `ball_lift() -> float`: いまの拍のボールの高さ。いまの拍でボールが動かなければ 0。
- `ball_style: Dictionary` を持つ（ボードが設定から入れる）。
- 拍の組み立て（いまの `TacticsBoard.start_shift` の中身）を `static func build_beats(keyframes, end, center: Callable, ball_point: Callable) -> Array[Dictionary]` として移す。`end` は `{"user", "opponent", "ball"}`（いまの盤面）。keyframe の `"flight"`（任意）をその拍のボールの道筋に入れる。

## `TacticsBoard`

- `start_shift(keyframes)` は `BoardShift.build_beats` を呼んで Tween を組むだけにする。
- `set_ball_style(style: Dictionary)` を足す（パネルが bind のときに設定から入れる）。
- `ball_lift()` を足し、`standing_order()` のボールに `"lift"` を入れる。`BoardPainter._draw_lifted_ball` は lift の分だけボールを持ち上げる（影は地面）。

## 調整値（`PresentationConfig`）

| 値 | 初期値 | 範囲 |
|---|---|---|
| `ball_loft_height`（浮き球の最大の高さ。ボールの半径の何倍か） | 6.0 | 0 以上 20 以下 |
| `ball_touch_height`（ドリブルの弾みの高さ。同じ単位） | 1.0 | 0 以上 5 以下 |
| `ball_dribble_touches`（ドリブルの弾みの回数） | 3 | 1 以上 8 以下 |

- `MatchController.ball_style() -> Dictionary` を足す（`{"loft", "touch", "touches"}`）。
- 範囲外ならデータ層が初期値に戻す（いまの値と同じ扱い）。

## `MatchBoardPanel`

- `bind` で `_board.set_ball_style(_controller.ball_style())`。
- `_on_turn_resolved` の1拍目の keyframe に `"flight": BallFlight.kind_for(BallFlight.holder_choice(reveal))`。

## テスト
- `ball_flight_test`（新規）: 手 → 種類（6つの攻撃の手・トランジションの2つ・守備の手・null）、`holder_choice`（利用者が攻撃・守備・奪取・喪失）、`along` の両端と途中（GROUND・DRIVEN は t より先、ほかは t）、`lift` の両端と途中（LOFTED の頂点、CARRIED の回数、ほかは 0）。
- `tactics_board_test`: 1拍目のボールの道筋が flight を持つ。途中で `ball_lift()` が浮く・`ball_center()` が等速より先。2拍目は STRAIGHT で高さ 0。止まったら高さ 0。
- `match_board_panel_test`: 開示で、1拍目のボールの flight がボールを持つ側の手に対応する。
- `config_repository_test`・`match_controller_test`: 3つの値の同梱値・範囲・範囲外。

## 変更するドキュメント
- functional-overview.md（設定値の表）、component-design.md（`ball_style()`・`PresentationConfig`・§5.3 の注記）、screen-common.md（TacticsBoard・BoardShift）、screen-03-match.md（開示）、screen-design.md（開示の動き）、glossary.md（必要なら）。docs/specs 全体を検索し .drawio も見る。

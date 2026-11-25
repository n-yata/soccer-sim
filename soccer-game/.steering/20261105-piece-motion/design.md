# 設計

## 駒の進み方（`PieceMotion`、新規 `ui/board2d/piece_motion.gd`。静的関数）

```gdscript
class_name PieceMotion extends RefCounted
## 拍の進み具合 progress（0〜1）と、駒のずらしの順 order（0 = ボールにいちばん近い 〜 1 = いちばん遠い）・ずらしの幅 stagger から、
## その駒の進み具合（0〜1）。駒は stagger × order だけ遅れて出て、拍の終わりにそろって着く。
static func local_t(progress: float, order: float, stagger: float) -> float
static func smooth(t: float) -> float            # smoothstep（3t² − 2t³）。0 と 1 で止まる（組み込みの ease() とぶつかるので smooth）
static func hop(t: float, height: float) -> float # height × sin(πt)。始めと終わりは地面
```

- `local_t = clamp((progress − stagger·order) / (1 − stagger), 0, 1)`。stagger が 0 なら progress のまま。

## `BoardShift`
- `piece_style: Dictionary = {}`（`{"stagger", "hop"}`）。
- `build_beats` が、各拍の駒の道筋に `"order"`（その拍の始まりのボールの位置からの距離の順。0〜1。1人なら 0）を入れる。ボールが読めない拍では 0。
- `piece_position`: いまの拍の道筋は `from.lerp(to, smooth(local_t(...)))`。ずらしの順は、同じ距離の駒を同じ順にする。後の拍の道筋は `from`、どれにも出てこなければ `rest`（いまと同じ）。
- `piece_lift(player_id) -> float`: いまの拍で動いている駒の高さ（駒の半径の何倍か）。ほかは 0。
- ボールの位置（`ball_position`・`_point_on`）は変えない。

## `BoardReveal`
- `beat_gap_sec`（`set_beat_gap_sec`）。拍の Tween の、拍と拍の間に `tween_interval(gap)` を置く。1拍目の着地の callback は、1拍目の進み具合の直後（小休止の前）のまま。

## `TacticsBoard`・`BoardPainter`
- `set_piece_style(style)`・`set_beat_gap_sec(sec)` を足す（パネルが bind で入れる）。
- `shifting_piece_lift(player_id) -> float` を足し、`standing_order()` の駒に `"lift"` を入れる（動いていない駒は 0）。
- `BoardPainter._draw_chess_piece` は、影を足元に描き、駒の体を lift × 半径だけ持ち上げる。

## 調整値（`PresentationConfig`）
| 値 | 初期値 | 範囲 |
|---|---|---|
| `piece_stagger`（ずらしの幅。拍の時間の何割を遅れに使うか） | 0.35 | 0 以上 0.8 以下 |
| `piece_hop_height`（弾みの高さ。駒の半径の何倍か） | 0.35 | 0 以上 1.5 以下 |
| `board_beat_gap_sec`（拍の間の小休止。秒） | 0.12 | 0 以上 0.5 以下 |

`MatchController.piece_style() -> Dictionary`（`{"stagger", "hop"}`）・`board_beat_gap_sec()` を足す。範囲外ならデータ層が初期値に戻す。

## テスト
- `piece_motion_test`（新規）: `local_t`（ずらし 0・先頭・末尾・範囲外）、`smooth`（両端・中央 0.5・途中が等速より遅く出る）、`hop`（両端 0・中央が高さ）。
- `board_shift_test`: ボールに近い駒が先に進む、拍の終わりにそろって着く、`piece_lift` が途中で浮き両端と動かない駒は 0、ずらし 0 なら全員同じ進み具合。`build_beats` の order。
- `tactics_board_test`: `standing_order` の駒に lift。小休止で2拍目の始まりが遅れ、着地は待たない。
- `match_board_panel_test`: bind で駒の値と小休止を入れる。
- `config_repository_test`・`match_controller_test`: 3つの値。

## 変更するドキュメント
- functional-overview.md（設定値の表）、component-design.md（`piece_style()`・`board_beat_gap_sec()`・`PresentationConfig`・§5.3 の注記）、screen-common.md（TacticsBoard の開示と描き方）、screen-design.md（開示の動き）、repository-structure.md（board2d/・presentation_config）。docs/specs 全体を検索し .drawio も見る。

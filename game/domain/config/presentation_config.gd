## 表示の調整値（component-design.md §4.2）。値の正本は functional-overview.md「設定値として外部化する値」。
## .tres の読み込みはデータ層（ConfigRepository）が行う。3D 演出の上限は、3D 演出をやめたので持たない（2026-10-23）。
class_name PresentationConfig
extends Resource

## 開示の1拍目で駒とボールを動かす時間（秒）。ふつうは判定前 → 次のターン開始時、得点は判定前 → 判定時（シュート）
## （2026-11-06 に開示を1拍にした）。範囲は board_settle_sec と同じ
@export var board_play_sec: float = 0.6
## 得点の開示の2拍目（判定時 → キックオフの配置）で駒を動かす時間（秒。2026-11-06 から得点のときだけ使う）。0 より大きく 2 以下
## （毎ターン見る動きなので、長いとテンポが落ちる。範囲外の値はデータ層が初期値に戻す）
@export var board_settle_sec: float = 0.6
## 開示の1拍目の終わりから、結果の演出（ゴールの光・奪った場所の輪・オフサイドの旗）を出す時間（秒）。範囲は拍の長さと同じ
@export var board_result_sec: float = 0.8
## 得点のカットイン（選手がシュートを決める絵。開示の1拍目の着地で出す）の時間（秒）。0 以上 6 以下。0 ならカットインを出さない
## （2026-11-06。毎試合見るので、長いとテンポが落ちる。範囲外の値はデータ層が初期値に戻す）
@export var goal_cut_in_sec: float = 3.6
## 開示の拍で、ボールに近い駒から順に動き出すときの遅れの幅（拍の時間の何割を遅れに使うか）。0 以上 0.8 以下（0 なら全員同時）
@export var piece_stagger: float = 0.35
## 開示で動いている駒が浮く高さ（駒の半径の何倍か）。0 以上 1.5 以下（0 なら浮かない）
@export var piece_hop_height: float = 0.35
## 開示の拍と拍の間の小休止（秒）。0 以上 0.5 以下（長いとテンポが落ちる）
@export var board_beat_gap_sec: float = 0.12
## 決定前のプレビューで、半透明の駒が配置から次の配置へ動く1区間の時間（秒）。0 より大きく 2 以下
@export var preview_move_sec: float = 0.6
## 決定前のプレビューで、動き終えて止めてから元へ戻すまでの時間（秒）。0 以上 2 以下
@export var preview_hold_sec: float = 0.6
## 開示の1拍目で、浮き球（ロングボール・サイドチェンジ）がいちばん高く上がるときの高さ（ボールの半径の何倍か）。0 以上 20 以下
## （高すぎると盤面の上へはみ出す）
@export var ball_loft_height: float = 6.0
## 開示の1拍目で、ドリブルのボールが弾む高さ（同じ単位）。0 以上 5 以下
@export var ball_touch_height: float = 1.0
## 開示の1拍目で、ドリブルのボールが弾む回数（タッチの数）。1 以上 8 以下（多いと震えて見える）
@export var ball_dribble_touches: int = 3
## 振り返り（FR-18）で、得点のターンの直前に遡る最大のターン数。0 以上（0 なら得点のターンだけを出す）
@export var review_lookback_turns: int = 3

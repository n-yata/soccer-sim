## 表示の調整値（component-design.md §4.2）。値の正本は functional-overview.md「設定値として外部化する値」。
## .tres の読み込みはデータ層（ConfigRepository）が行う。3D 演出の上限は、3D 演出をやめたので持たない（2026-10-23）。
class_name PresentationConfig
extends Resource

## 開示の1拍目（プレー）で、ターン前の配置から判定時の配置へ駒とボールを動かす時間（秒）。範囲は board_settle_sec と同じ
@export var board_play_sec: float = 0.6
## 開示の2拍目（詰め直し）で、判定時の配置から次のターン開始時の配置へ駒を動かす時間（秒）。0 より大きく 2 以下
## （毎ターン見る動きなので、長いとテンポが落ちる。範囲外の値はデータ層が初期値に戻す）
@export var board_settle_sec: float = 0.6
## 振り返り（FR-18）で、得点のターンの直前に遡る最大のターン数。0 以上（0 なら得点のターンだけを出す）
@export var review_lookback_turns: int = 3

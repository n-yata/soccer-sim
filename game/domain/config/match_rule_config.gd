## 試合進行の調整値（component-design.md §4.2）。値の正本は functional-overview.md「設定値として外部化する値」。
## ドメインは引数で受け取った値を読むだけで、.tres の読み込みはデータ層（ConfigRepository）が行う。
class_name MatchRuleConfig
extends Resource

## 1ハーフのターン数。1以上（範囲外の値はデータ層が初期値に戻す）
@export var turns_per_half: int = 15
## アディショナルタイムの最大ターン数（2026-10-24）。0以上、1ハーフのターン数以下。ハーフの最終ターンで続いている攻撃を、シュートするか
## ボールを失うまで、このターン数まで続ける。0 なら最終ターンでハーフを終える
@export var max_additional_turns: int = 5

## CPU の選択の調整値（component-design.md §4.2。アルゴリズム8）。値の正本は functional-overview.md「設定値として外部化する値」。
## ドメインは引数で受け取った値を読むだけで、.tres の読み込みと範囲の検査はデータ層（ConfigRepository）が行う。
class_name CpuConfig
extends Resource

## softmax の温度 τ。0 より大きい。小さいほど評価値の高い手に偏る
@export var temperature: float = 0.5
## 下限確率 floor。0 以上 1 未満。どの選択可能な手にも floor / N 以上の確率を残す
@export var floor_probability: float = 0.05
## 方式の癖の加点。0 以上。CPU の方式が好む手の評価値に足す（0 なら癖なし）
@export var style_bonus: float = 1.0

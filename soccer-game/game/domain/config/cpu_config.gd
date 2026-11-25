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
## 前へ運ぶ加点（1列あたり）。0 以上。攻撃の手・奪取側の手の評価値に 加点 × 前へ進む列数 を足す（後ろへ運ぶ手は負）。
## 2026-10-25 に盤面を6列にしたとき、距離あたりの強さを保つため 1ゾーンあたり 1.5 を1列あたり 0.75 にした
@export var forward_bonus: float = 0.75
## シュートの加点。0 以上。シュートの評価値に足す
@export var shot_bonus: float = 1.5
## 守備の先読みの加点（1列あたり）。0 以上。守備の手の評価値に 加点 × (制限するエリアの列 − ボールの列) を足す
## （攻撃側の視点で、ボールより前のエリアほど大きく、後ろは負）。2026-10-25 に 2.0（1ゾーンあたり）を 1.0 にした
@export var anticipation_bonus: float = 1.0
## オフサイドの減点（2026-10-25）。0 以上。今の配置のままだと受け手がオフサイドになる攻撃の手の評価値から引く
## （ボールを失う手なので避けるが、守備の手でラインが動くので、選ばないわけではない。0 なら避けない）
@export var offside_penalty: float = 3.0
## マーク注意の減点（2026-10-29）。0 以上。相手が何もしなくても、マンツーマンの付け直しで守備の選手が運ぶ先へ入ってくる
## スルーパス（ChoiceHint.is_marked。判定は読みに関係なくロスト）の評価値から引く。守備の手でマーカーの割り当てが
## 変わると外れることがあるので、選ばないわけではない（0 なら避けない）
@export var marked_penalty: float = 3.0

## 1ターンの判定の結果（component-design.md §2.4）。判定時の配置と、そこに至る選手の動きをいっしょに返す
## （作戦ボードの矢印・振り返りに使う）。
class_name JudgeOutput
extends RefCounted

var outcome: GameEnums.TurnOutcome
## 判定の内訳。判定なし（NO_CONTEST）のときだけ null
var detail: JudgeDetail
## 両者の手を適用した後の配置
var pair: LayoutPair
var movements: Array[Movement]


## 受け取った配列はコピーして持つ（component-design.md §1.1）。
func _init(p_outcome: GameEnums.TurnOutcome, p_detail: JudgeDetail, p_pair: LayoutPair,
		p_movements: Array[Movement]) -> void:
	outcome = p_outcome
	detail = p_detail
	pair = p_pair
	movements = p_movements.duplicate()


## 内訳・配置・動きまで写す。
func duplicate_deep() -> JudgeOutput:
	var copied_movements: Array[Movement] = []
	for movement: Movement in movements:
		copied_movements.append(movement.duplicate_deep())
	var copied_detail: JudgeDetail = null if detail == null else detail.duplicate_deep()
	return JudgeOutput.new(outcome, copied_detail, pair.duplicate_deep(), copied_movements)

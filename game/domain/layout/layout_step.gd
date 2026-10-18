## 配置の変化と、その理由（component-design.md §2.3）。配置計算の関数が返す。
class_name LayoutStep
extends RefCounted

var pair: LayoutPair
## 配置が変わった選手の動き
var movements: Array[Movement]


## 受け取った配列はコピーして持つ（component-design.md §1.1）。
func _init(p_pair: LayoutPair, p_movements: Array[Movement]) -> void:
	pair = p_pair
	movements = p_movements.duplicate()


func duplicate_deep() -> LayoutStep:
	var copied: Array[Movement] = []
	for movement: Movement in movements:
		copied.append(movement.duplicate_deep())
	return LayoutStep.new(pair.duplicate_deep(), copied)

## 陣形の選手配置（functional-overview.md の ER 図「選手配置」。component-design.md §2.2）。
## 値は静的データ（formations.json）から ContentRepository が作る。
class_name PlayerSlotDef
extends RefCounted

const GOALKEEPER_TYPE: String = "GK"

var id: String
## ポジション種別（"GK"・"DF"・"MF"・"FW"）。静的データと同じ文字列で持つ
var position_type: String
var label: String
## 背番号（陣形の中で一意）
var number: int
## 座標（0〜100。y が大きいほど相手ゴール側。functional-overview.md「確定事項」）
var x: float
var y: float


func _init(p_id: String, p_position_type: String, p_label: String, p_number: int,
		p_x: float, p_y: float) -> void:
	id = p_id
	position_type = p_position_type
	label = p_label
	number = p_number
	x = p_x
	y = p_y


## アルゴリズム1で GK をエリアの人数から除くために使う。
func is_goalkeeper() -> bool:
	return position_type == GOALKEEPER_TYPE


func duplicate_deep() -> PlayerSlotDef:
	return PlayerSlotDef.new(id, position_type, label, number, x, y)

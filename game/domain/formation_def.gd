## フォーメーション（functional-overview.md の ER 図。component-design.md §2.2）。
class_name FormationDef
extends RefCounted

var id: String
var name: String
var description: String
## 座標から導出できない特徴タグ（移植元の extraTags）
var extra_tags: Array[String]
## GK を含む11人
var players: Array[PlayerSlotDef]


func _init(p_id: String, p_name: String, p_description: String, p_extra_tags: Array[String],
		p_players: Array[PlayerSlotDef]) -> void:
	id = p_id
	name = p_name
	description = p_description
	# 受け取った配列はコピーして持つ（呼び出し側が後で変えても、この陣形は変わらない）
	extra_tags = p_extra_tags.duplicate()
	players = p_players.duplicate()


func duplicate_deep() -> FormationDef:
	var copied_players: Array[PlayerSlotDef] = []
	for slot: PlayerSlotDef in players:
		copied_players.append(slot.duplicate_deep())
	return FormationDef.new(id, name, description, extra_tags.duplicate(), copied_players)

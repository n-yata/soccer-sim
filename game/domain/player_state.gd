## 選手単位の配置状態（component-design.md §2.2）。座標はその選手のチーム自身から見た値（§1.2）。
class_name PlayerState
extends RefCounted

var player_id: String
## 陣形から導いたエリア（アルゴリズム1）
var base_area: PitchArea
## プレス・カバー・ドリブルで動いて固定されたエリア。固定されていなければ null（アルゴリズム2の手順2）
var fixed_area: PitchArea


func _init(p_player_id: String, p_base_area: PitchArea, p_fixed_area: PitchArea = null) -> void:
	player_id = p_player_id
	base_area = p_base_area
	fixed_area = p_fixed_area


func is_fixed() -> bool:
	return fixed_area != null


func duplicate_deep() -> PlayerState:
	var copied_fixed: PitchArea = null if fixed_area == null else fixed_area.duplicate_deep()
	return PlayerState.new(player_id, base_area.duplicate_deep(), copied_fixed)

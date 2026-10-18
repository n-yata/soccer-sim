## 選手の動き1つ（component-design.md §2.2）。from・to は、動いた選手のチーム自身から見た座標（§1.2）。
## 作戦ボードの矢印・3D 演出・振り返りに使う。
class_name Movement
extends RefCounted

var side: GameEnums.TeamSide
var player_id: String
var from: PitchArea
var to: PitchArea
var reason: GameEnums.MovementReason


func _init(p_side: GameEnums.TeamSide, p_player_id: String, p_from: PitchArea, p_to: PitchArea,
		p_reason: GameEnums.MovementReason) -> void:
	side = p_side
	player_id = p_player_id
	from = p_from
	to = p_to
	reason = p_reason


func duplicate_deep() -> Movement:
	return Movement.new(side, player_id, from.duplicate_deep(), to.duplicate_deep(), reason)

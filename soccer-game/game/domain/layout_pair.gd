## 判定中の両チームの配置（component-design.md §2.2）。各チームの配置は、そのチーム自身から見た座標で持つ（§1.2）。
##
## attacker_side は、動き（Movement.side）にどちらのチームかを書くために持つ。
class_name LayoutPair
extends RefCounted

var attacker: TeamLayout
var defender: TeamLayout
var attacker_side: GameEnums.TeamSide


func _init(p_attacker: TeamLayout, p_defender: TeamLayout, p_attacker_side: GameEnums.TeamSide) -> void:
	attacker = p_attacker
	defender = p_defender
	attacker_side = p_attacker_side


func defender_side() -> GameEnums.TeamSide:
	if attacker_side == GameEnums.TeamSide.HOME:
		return GameEnums.TeamSide.AWAY
	return GameEnums.TeamSide.HOME


func duplicate_deep() -> LayoutPair:
	return LayoutPair.new(attacker.duplicate_deep(), defender.duplicate_deep(), attacker_side)

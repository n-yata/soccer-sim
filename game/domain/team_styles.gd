## 1チームの守備方式と攻撃方式（component-design.md §2.2）。
class_name TeamStyles
extends RefCounted

var defense: GameEnums.DefenseStyle
var attack: GameEnums.AttackStyle


func _init(p_defense: GameEnums.DefenseStyle, p_attack: GameEnums.AttackStyle) -> void:
	defense = p_defense
	attack = p_attack


func duplicate_deep() -> TeamStyles:
	return TeamStyles.new(defense, attack)

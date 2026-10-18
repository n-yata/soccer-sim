## 1チームの1ターンの手の選択（component-design.md §2.2）。
## action は family が示す enum（PlayType・DefenseAction・NegTransAction・PosTransAction）の値。
class_name TurnChoice
extends RefCounted

var family: GameEnums.ChoiceFamily
var action: int
## 運ぶ先。運ぶ先を持たない手（シュート・即時奪回・リトリート・保持）では null
var target: PitchArea


func _init(p_family: GameEnums.ChoiceFamily, p_action: int, p_target: PitchArea = null) -> void:
	family = p_family
	action = p_action
	target = p_target


## family の手として判定に使える形か（family が合い、運ぶ先を伴う手なら運ぶ先がある）。
## 運ぶ先が一覧にあるかは見ない（それは MoveRules.is_allowed の役目）。攻守ターン・トランジションの判定で共有する。
func is_complete_for(expected_family: GameEnums.ChoiceFamily) -> bool:
	if family != expected_family:
		return false
	return target != null or not MoveOptions.needs_target(family, action)


## 運ぶ先の PitchArea まで写す。
func duplicate_deep() -> TurnChoice:
	var copied_target: PitchArea = null if target == null else target.duplicate_deep()
	return TurnChoice.new(family, action, copied_target)

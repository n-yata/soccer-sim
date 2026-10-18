## 手の選択と選べる手の値オブジェクト（TurnChoice・MoveOptions）のテスト。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func test_turn_choice_keeps_values_and_copies_target() -> void:
	var choice := TurnChoice.new(ATTACK, GameEnums.PlayType.DRIBBLE, _area("M-C"))
	var copy: TurnChoice = choice.duplicate_deep()
	assert_int(copy.family).is_equal(ATTACK)
	assert_int(copy.action).is_equal(GameEnums.PlayType.DRIBBLE)
	assert_str(copy.target.to_key()).is_equal("M-C")
	assert_object(copy.target).is_not_same(choice.target)


func test_turn_choice_without_target_copies_null() -> void:
	var copy: TurnChoice = TurnChoice.new(ATTACK, GameEnums.PlayType.SHOT).duplicate_deep()
	assert_object(copy.target).is_null()


func test_needs_target_matches_the_moves_that_carry_a_target() -> void:
	# screen-03-match.md: 運ぶ先を持つ手は SHORT_PASS・DRIBBLE・LONG_BEHIND・SWITCH・PRESS・COVER・COUNTER
	for play: GameEnums.PlayType in [GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.DRIBBLE,
			GameEnums.PlayType.LONG_BEHIND, GameEnums.PlayType.SWITCH]:
		assert_bool(MoveOptions.needs_target(ATTACK, play)).is_true()
	assert_bool(MoveOptions.needs_target(ATTACK, GameEnums.PlayType.SHOT)).is_false()
	assert_bool(MoveOptions.needs_target(DEFENSE, GameEnums.DefenseAction.PRESS)).is_true()
	assert_bool(MoveOptions.needs_target(DEFENSE, GameEnums.DefenseAction.COVER)).is_true()
	assert_bool(MoveOptions.needs_target(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)).is_false()
	assert_bool(MoveOptions.needs_target(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_false()
	assert_bool(MoveOptions.needs_target(POS_TRANS, GameEnums.PosTransAction.COUNTER)).is_true()
	assert_bool(MoveOptions.needs_target(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_false()


func test_move_with_target_is_available_only_when_it_has_targets() -> void:
	var options := MoveOptions.new()
	assert_bool(options.is_available(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_false()
	options.add_target(ATTACK, GameEnums.PlayType.SHORT_PASS, _area("M-C"))
	assert_bool(options.is_available(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_true()
	# 同じ値の別の手（DEFENSE の 0 = PRESS）とは区別する
	assert_bool(options.is_available(DEFENSE, GameEnums.DefenseAction.PRESS)).is_false()


func test_move_without_target_is_available_only_after_allow() -> void:
	var options := MoveOptions.new()
	assert_bool(options.is_available(ATTACK, GameEnums.PlayType.SHOT)).is_false()
	options.allow(ATTACK, GameEnums.PlayType.SHOT)
	assert_bool(options.is_available(ATTACK, GameEnums.PlayType.SHOT)).is_true()
	assert_array(options.targets(ATTACK, GameEnums.PlayType.SHOT)).is_empty()


func test_targets_returns_a_copy() -> void:
	var options := MoveOptions.new()
	options.add_target(ATTACK, GameEnums.PlayType.DRIBBLE, _area("M-C"))
	options.targets(ATTACK, GameEnums.PlayType.DRIBBLE).clear()
	assert_int(options.targets(ATTACK, GameEnums.PlayType.DRIBBLE).size()).is_equal(1)


func test_duplicate_deep_does_not_share_targets_or_allowed_moves() -> void:
	var options := MoveOptions.new()
	options.add_target(DEFENSE, GameEnums.DefenseAction.COVER, _area("M-L1"))
	var copy: MoveOptions = options.duplicate_deep()
	copy.add_target(DEFENSE, GameEnums.DefenseAction.COVER, _area("M-C"))
	copy.allow(NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	assert_int(options.targets(DEFENSE, GameEnums.DefenseAction.COVER).size()).is_equal(1)
	assert_bool(options.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_false()
	assert_int(copy.targets(DEFENSE, GameEnums.DefenseAction.COVER).size()).is_equal(2)

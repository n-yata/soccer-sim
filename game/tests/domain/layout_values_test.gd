## 配置の変化を返す値オブジェクト（TeamStyles・LayoutPair・Movement・LayoutStep）のテスト。
extends GdUnitTestSuite


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _layout() -> TeamLayout:
	var players: Array[PlayerState] = [
		PlayerState.new("p1", _area("D1-C")),
		PlayerState.new("p2", _area("M1-L2"), _area("M1-L1")),
	]
	return TeamLayout.at_base(players)


func _movement() -> Movement:
	return Movement.new(GameEnums.TeamSide.AWAY, "p2", _area("M1-L2"), _area("A1-L2"),
			GameEnums.MovementReason.POSSESSION_ADVANCE)


func test_team_styles_keeps_both_styles_and_copies_independently() -> void:
	var styles := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	var copy: TeamStyles = styles.duplicate_deep()
	copy.defense = GameEnums.DefenseStyle.ZONE
	assert_int(styles.defense).is_equal(GameEnums.DefenseStyle.MAN)
	assert_int(styles.attack).is_equal(GameEnums.AttackStyle.COUNTER)
	assert_int(copy.attack).is_equal(GameEnums.AttackStyle.COUNTER)


func test_layout_pair_defender_side_is_the_other_team() -> void:
	var home_attacks := LayoutPair.new(_layout(), _layout(), GameEnums.TeamSide.HOME)
	var away_attacks := LayoutPair.new(_layout(), _layout(), GameEnums.TeamSide.AWAY)
	assert_int(home_attacks.defender_side()).is_equal(GameEnums.TeamSide.AWAY)
	assert_int(away_attacks.defender_side()).is_equal(GameEnums.TeamSide.HOME)


func test_layout_pair_duplicate_deep_does_not_share_layouts() -> void:
	var pair := LayoutPair.new(_layout(), _layout(), GameEnums.TeamSide.HOME)
	var copy: LayoutPair = pair.duplicate_deep()
	copy.attacker.players[0].fixed_area = _area("A1-C")
	copy.attacker_side = GameEnums.TeamSide.AWAY
	assert_bool(pair.attacker.players[0].is_fixed()).is_false()
	assert_int(pair.attacker_side).is_equal(GameEnums.TeamSide.HOME)
	assert_object(copy.defender).is_not_same(pair.defender)
	assert_str(copy.defender.current_area_of("p2").to_key()).is_equal("M1-L2")


func test_movement_keeps_its_values_and_copies_areas() -> void:
	var movement: Movement = _movement()
	var copy: Movement = movement.duplicate_deep()
	assert_int(copy.side).is_equal(GameEnums.TeamSide.AWAY)
	assert_str(copy.player_id).is_equal("p2")
	assert_str(copy.from.to_key()).is_equal("M1-L2")
	assert_str(copy.to.to_key()).is_equal("A1-L2")
	assert_int(copy.reason).is_equal(GameEnums.MovementReason.POSSESSION_ADVANCE)
	assert_object(copy.from).is_not_same(movement.from)
	assert_object(copy.to).is_not_same(movement.to)


func test_layout_step_copies_the_given_movements_array() -> void:
	var movements: Array[Movement] = [_movement()]
	var step := LayoutStep.new(LayoutPair.new(_layout(), _layout(), GameEnums.TeamSide.HOME), movements)
	movements.clear()
	assert_int(step.movements.size()).is_equal(1)


func test_layout_step_duplicate_deep_does_not_share_pair_or_movements() -> void:
	var movements: Array[Movement] = [_movement()]
	var step := LayoutStep.new(LayoutPair.new(_layout(), _layout(), GameEnums.TeamSide.HOME), movements)
	var copy: LayoutStep = step.duplicate_deep()
	copy.movements[0].player_id = "changed"
	copy.movements.append(_movement())
	copy.pair.defender.players[0].fixed_area = _area("D1-L1")
	assert_str(step.movements[0].player_id).is_equal("p2")
	assert_int(step.movements.size()).is_equal(1)
	assert_bool(step.pair.defender.players[0].is_fixed()).is_false()

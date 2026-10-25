## 判定の結果の値オブジェクト（JudgeDetail・JudgeOutput）のテスト。
extends GdUnitTestSuite


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _pair() -> LayoutPair:
	var players: Array[PlayerState] = [PlayerState.new("p1", _area("M1-C"))]
	return LayoutPair.new(TeamLayout.at_base(players), TeamLayout.at_base(players), GameEnums.TeamSide.HOME)


func _detail() -> JudgeDetail:
	return JudgeDetail.new(_area("A1-L2"), 1, 1, GameEnums.CoverKind.DEFENDER, GameEnums.ReadKind.NEAR)


func _movement() -> Movement:
	return Movement.new(GameEnums.TeamSide.HOME, "p1", _area("M1-C"), _area("A1-C"), GameEnums.MovementReason.DRIBBLE)


func test_judge_detail_keeps_values_and_copies_the_area() -> void:
	var detail: JudgeDetail = _detail()
	var copy: JudgeDetail = detail.duplicate_deep()
	assert_str(copy.compare_area.to_key()).is_equal("A1-L2")
	assert_int(copy.attacker_count).is_equal(1)
	assert_int(copy.defender_count).is_equal(1)
	assert_int(copy.cover).is_equal(GameEnums.CoverKind.DEFENDER)
	assert_int(copy.read).is_equal(GameEnums.ReadKind.NEAR)
	assert_object(copy.compare_area).is_not_same(detail.compare_area)


func test_judge_output_copies_the_given_movements_array() -> void:
	var movements: Array[Movement] = [_movement()]
	var output := JudgeOutput.new(GameEnums.TurnOutcome.ADVANCE, _detail(), _pair(), movements)
	movements.clear()
	assert_int(output.movements.size()).is_equal(1)
	assert_int(output.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)


func test_judge_output_duplicate_deep_does_not_share_parts() -> void:
	var movements: Array[Movement] = [_movement()]
	var output := JudgeOutput.new(GameEnums.TurnOutcome.STALL, _detail(), _pair(), movements)
	var copy: JudgeOutput = output.duplicate_deep()
	copy.detail.attacker_count = 9
	copy.movements[0].player_id = "changed"
	copy.pair.attacker.players[0].fixed_area = _area("A1-C")
	assert_int(output.detail.attacker_count).is_equal(1)
	assert_str(output.movements[0].player_id).is_equal("p1")
	assert_bool(output.pair.attacker.players[0].is_fixed()).is_false()


func test_judge_output_without_detail_copies_null() -> void:
	var no_movements: Array[Movement] = []
	var output := JudgeOutput.new(GameEnums.TurnOutcome.NO_CONTEST, null, _pair(), no_movements)
	assert_object(output.duplicate_deep().detail).is_null()

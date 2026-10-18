## 試合の値オブジェクト（TeamSetup・MatchState・TurnRecord・TurnResolution・MatchRuleConfig）のテスト。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _setup(formation_id: String) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER))


func _players(prefix: String) -> Array[PlayerState]:
	var players: Array[PlayerState] = [
		PlayerState.new(prefix + "1", _area("D-C")),
		PlayerState.new(prefix + "2", _area("M-L2"), _area("M-L1")),
	]
	return players


func _state() -> MatchState:
	var state := MatchState.new()
	state.match_id = "20261018-120000-0001"
	state.home_setup = _setup("4-4-2")
	state.away_setup = _setup("3-5-2")
	state.home_players = _players("h")
	state.away_players = _players("a")
	state.ball_area = _area("M-C")
	state.home_score = 2
	state.away_score = 1
	return state


func _record() -> TurnRecord:
	var record := TurnRecord.new()
	record.seq = 1
	record.home_setup = _setup("4-4-2")
	record.away_setup = _setup("3-5-2")
	record.home_choice = TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)
	record.away_choice = TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.PRESS, _area("A-C"))
	record.ball_before = _area("A-C")
	record.ball_after = _area("A-C")
	var pair := LayoutPair.new(TeamLayout.at_base(_players("h")), TeamLayout.at_base(_players("a")), HOME)
	record.pair_before = pair
	record.pair_at_judgement = pair.duplicate_deep()
	var movements: Array[Movement] = [
		Movement.new(AWAY, "a1", _area("D-C"), _area("D-L1"), GameEnums.MovementReason.PRESS),
	]
	record.movements = movements
	record.judge = JudgeDetail.new(_area("A-C"), 2, 1, GameEnums.CoverKind.NONE)
	record.outcome = GameEnums.TurnOutcome.GOAL
	return record


func test_team_setup_copies_its_styles() -> void:
	var setup: TeamSetup = _setup("4-4-2")
	var copy: TeamSetup = setup.duplicate_deep()
	copy.styles.defense = GameEnums.DefenseStyle.MAN
	copy.formation_id = "3-5-2"
	assert_str(setup.formation_id).is_equal("4-4-2")
	assert_int(setup.styles.defense).is_equal(GameEnums.DefenseStyle.ZONE)


func test_match_state_reads_each_side() -> void:
	var state: MatchState = _state()
	assert_str(state.setup_of(HOME).formation_id).is_equal("4-4-2")
	assert_str(state.setup_of(AWAY).formation_id).is_equal("3-5-2")
	assert_str(state.players_of(AWAY)[0].player_id).is_equal("a1")
	assert_int(state.score_of(HOME)).is_equal(2)
	assert_int(state.score_of(AWAY)).is_equal(1)
	assert_int(MatchState.other(HOME)).is_equal(AWAY)
	assert_int(MatchState.other(AWAY)).is_equal(HOME)


func test_match_state_duplicate_deep_does_not_share_parts() -> void:
	var state: MatchState = _state()
	state.transition_origin = LayoutPair.new(TeamLayout.at_base(_players("h")), TeamLayout.at_base(_players("a")), HOME)
	state.turn_records.append(_record())
	var copy: MatchState = state.duplicate_deep()
	copy.home_players[0].fixed_area = _area("A-C")
	copy.home_setup.formation_id = "4-3-3"
	copy.transition_origin.attacker.players[0].fixed_area = _area("A-C")
	copy.turn_records[0].seq = 99
	copy.turn_records.append(_record())
	copy.ball_area = _area("A-C")
	assert_bool(state.home_players[0].is_fixed()).is_false()
	assert_str(state.home_setup.formation_id).is_equal("4-4-2")
	assert_bool(state.transition_origin.attacker.players[0].is_fixed()).is_false()
	assert_int(state.turn_records[0].seq).is_equal(1)
	assert_int(state.turn_records.size()).is_equal(1)
	assert_str(state.ball_area.to_key()).is_equal("M-C")
	assert_str(copy.match_id).is_equal("20261018-120000-0001")
	assert_int(copy.home_score).is_equal(2)


func test_match_state_duplicate_deep_keeps_a_null_origin() -> void:
	assert_object(_state().duplicate_deep().transition_origin).is_null()


func test_turn_record_duplicate_deep_does_not_share_parts() -> void:
	var record: TurnRecord = _record()
	var copy: TurnRecord = record.duplicate_deep()
	copy.movements[0].player_id = "changed"
	copy.judge.attacker_count = 9
	copy.away_choice.target = _area("M-C")
	copy.pair_before.attacker.players[0].fixed_area = _area("A-C")
	assert_str(record.movements[0].player_id).is_equal("a1")
	assert_int(record.judge.attacker_count).is_equal(2)
	assert_str(record.away_choice.target.to_key()).is_equal("A-C")
	assert_bool(record.pair_before.attacker.players[0].is_fixed()).is_false()
	assert_object(copy.home_choice.target).is_null()


func test_turn_record_without_judge_detail_copies_null() -> void:
	var record: TurnRecord = _record()
	record.judge = null
	assert_object(record.duplicate_deep().judge).is_null()


func test_turn_resolution_holds_the_next_state_and_record() -> void:
	var resolution := TurnResolution.new(_state(), _record())
	assert_int(resolution.next_state.home_score).is_equal(2)
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.GOAL)


func test_turn_start_applies_algorithm_2_in_open_play() -> void:
	# 保持側 HOME（カウンター型）。守備側 AWAY はゾーンで、ボールは HOME から見て M-L1（AWAY から見て M-R1）
	var state: MatchState = _state()
	state.possession = HOME
	state.ball_area = _area("M-L1")
	var away: Array[PlayerState] = [PlayerState.new("a1", _area("D-C")), PlayerState.new("a2", _area("M-L2"), _area("A-L2"))]
	state.away_players = away
	var step: LayoutStep = StyleLayoutCalculator.turn_start(state)
	assert_int(step.pair.attacker_side).is_equal(HOME)
	# a1 は右（AWAY から見て）へ1レーンずれる。a2 は固定先にいる
	assert_str(step.pair.defender.current_area_of("a1").to_key()).is_equal("D-R1")
	assert_str(step.pair.defender.current_area_of("a2").to_key()).is_equal("A-L2")
	# HOME の h2 は固定先（M-L1）
	assert_str(step.pair.attacker.current_area_of("h2").to_key()).is_equal("M-L1")
	assert_int(step.movements.size()).is_equal(1)


func test_turn_start_returns_a_copy_of_the_origin_in_transition() -> void:
	var state: MatchState = _state()
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.possession = AWAY
	state.transition_origin = LayoutPair.new(TeamLayout.at_base(_players("a")), TeamLayout.at_base(_players("h")), AWAY)
	var step: LayoutStep = StyleLayoutCalculator.turn_start(state)
	assert_object(step.pair).is_not_same(state.transition_origin)
	assert_int(step.pair.attacker_side).is_equal(AWAY)
	assert_str(step.pair.attacker.current_area_of("a2").to_key()).is_equal("M-L2")
	assert_array(step.movements).is_empty()


func test_match_rule_config_defaults_to_twelve_turns_per_half() -> void:
	# functional-overview.md「設定値として外部化する値」の初期値
	assert_int(MatchRuleConfig.new().turns_per_half).is_equal(12)

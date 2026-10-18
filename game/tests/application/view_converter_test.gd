## 利用者の視点への変換（ViewConverter）と、画面に渡す値（BoardSnapshot・RevealView）のテスト。
## 利用者 = HOME、CPU = AWAY（component-design.md §1.3）。視点の規則は §1.2。
## 期待値は「AWAY の視点のエリアは、HOME の視点では鏡像（L2↔R2, L1↔R1, D↔A）」から手で書いた。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _styles() -> TeamStyles:
	return TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)


## 利用者 4-4-2、CPU 4-3-3 の試合（キックオフ側は kickoff）
func _state(kickoff: GameEnums.TeamSide) -> MatchState:
	return MatchRules.create_match("20261019-120000-0001", TeamSetup.new("4-4-2", _styles()),
			TeamSetup.new("4-3-3", _styles()), kickoff, _catalog, "")


func _player(players: Array[Dictionary], player_id: String) -> Dictionary:
	for player: Dictionary in players:
		if player["player_id"] == player_id:
			return player
	return {}


# --- エリアと選択 ---

func test_to_user_keeps_home_areas_and_mirrors_away_areas() -> void:
	assert_str(ViewConverter.to_user(_area("D-L2"), HOME).to_key()).is_equal("D-L2")
	assert_str(ViewConverter.to_user(_area("D-L2"), AWAY).to_key()).is_equal("A-R2")
	assert_str(ViewConverter.to_user(_area("M-L1"), AWAY).to_key()).is_equal("M-R1")


func test_choice_targets_convert_by_the_holder_and_round_trip() -> void:
	# CPU（AWAY）が保持: 攻撃側の視点は AWAY の視点。利用者が選んだ M-L1 は、攻撃側の視点では M-R1
	var user_choice := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("M-L1"))
	var domain_choice: TurnChoice = ViewConverter.choice_to_domain(user_choice, AWAY)
	assert_str(domain_choice.target.to_key()).is_equal("M-R1")
	assert_str(ViewConverter.choice_to_user(domain_choice, AWAY).target.to_key()).is_equal("M-L1")
	# 利用者（HOME）が保持なら変えない
	assert_str(ViewConverter.choice_to_domain(user_choice, HOME).target.to_key()).is_equal("M-L1")
	# 運ぶ先を持たない手はそのまま
	var retreat := TurnChoice.new(NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	assert_object(ViewConverter.choice_to_domain(retreat, AWAY).target).is_null()


func test_options_convert_targets_and_keep_targetless_moves() -> void:
	var options := MoveOptions.new()
	options.add_target(DEFENSE, GameEnums.DefenseAction.PRESS, _area("A-L1"))
	options.add_target(DEFENSE, GameEnums.DefenseAction.PRESS, _area("M-C"))
	options.allow(NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	var converted: MoveOptions = ViewConverter.options_to_user(options, AWAY)
	var keys: Array[String] = []
	for area: PitchArea in converted.targets(DEFENSE, GameEnums.DefenseAction.PRESS):
		keys.append(area.to_key())
	assert_array(keys).is_equal(["D-R1", "M-C"])
	assert_bool(converted.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_true()
	assert_bool(converted.is_available(ATTACK, GameEnums.PlayType.SHOT)).is_false()


func test_hints_convert_targets_and_keep_counts() -> void:
	var hints: Array[ChoiceHint] = [ChoiceHint.new(DEFENSE, GameEnums.DefenseAction.COVER, _area("A-L1"),
			true, 1, 2, GameEnums.CoverKind.GOALKEEPER)]
	var converted: Array[ChoiceHint] = ViewConverter.hints_to_user(hints, AWAY)
	assert_str(converted[0].target.to_key()).is_equal("D-R1")
	assert_int(converted[0].own_count).is_equal(1)
	assert_int(converted[0].opponent_count).is_equal(2)
	assert_int(converted[0].cover).is_equal(GameEnums.CoverKind.GOALKEEPER)
	# 入力は書き換えない
	assert_str(hints[0].target.to_key()).is_equal("A-L1")


func test_movements_convert_by_the_side_that_moved() -> void:
	var movements: Array[Movement] = [
		Movement.new(HOME, "h", _area("D-L2"), _area("M-L2"), GameEnums.MovementReason.POSSESSION_ADVANCE),
		Movement.new(AWAY, "a", _area("D-L2"), _area("D-L1"), GameEnums.MovementReason.SLIDE),
	]
	var converted: Array[Movement] = ViewConverter.movements_to_user(movements)
	assert_str("%s>%s" % [converted[0].from.to_key(), converted[0].to.to_key()]).is_equal("D-L2>M-L2")
	assert_str("%s>%s" % [converted[1].from.to_key(), converted[1].to.to_key()]).is_equal("A-R2>A-R1")


# --- BoardSnapshot ---

func test_snapshot_shows_both_teams_from_the_user_view_with_numbers() -> void:
	var state: MatchState = _state(AWAY)
	var snapshot: BoardSnapshot = ViewConverter.snapshot(state, _catalog, [], -1, 12)
	# 利用者の 4-4-2 の左SB（3番）は D-L2。CPU の 4-3-3 の左WG（11番）は CPU の視点で A-L2 → 利用者の視点で D-R2
	assert_dict(_player(snapshot.user_players, "4-4-2-lb")).is_equal({"player_id": "4-4-2-lb", "number": 3, "area": "D-L2"})
	assert_dict(_player(snapshot.opponent_players, "4-3-3-lw")).is_equal({"player_id": "4-3-3-lw", "number": 11, "area": "D-R2"})
	assert_int(snapshot.user_players.size()).is_equal(10)
	assert_int(snapshot.opponent_players.size()).is_equal(10)
	# 人数は駒の位置を数えた値と一致する。CPU の 4-3-3 の前線（A: L2・C・R2）は、利用者の視点で D の R2・C・L2
	assert_int(snapshot.opponent_counts["D-R2"] as int).is_equal(1)
	assert_int(snapshot.opponent_counts["D-C"] as int).is_equal(1)
	assert_int(snapshot.user_counts["D-C"] as int).is_equal(2)
	var total: int = 0
	for key: String in snapshot.opponent_counts:
		total += snapshot.opponent_counts[key] as int
	assert_int(total).is_equal(10)


func test_snapshot_converts_the_ball_and_reports_possession_and_score() -> void:
	var state: MatchState = _state(AWAY)
	# CPU（AWAY）が保持し、CPU の視点で D-C にボール → 利用者の視点で A-C
	state.ball_area = _area("D-C")
	state.home_score = 2
	state.away_score = 1
	state.turn_number = 5
	var snapshot: BoardSnapshot = ViewConverter.snapshot(state, _catalog, [], AWAY, 12)
	assert_str(snapshot.ball_area).is_equal("A-C")
	assert_bool(snapshot.user_has_ball).is_false()
	assert_int(snapshot.score_user).is_equal(2)
	assert_int(snapshot.score_opponent).is_equal(1)
	assert_int(snapshot.last_goal_by).is_equal(AWAY)
	assert_int(snapshot.half).is_equal(1)
	assert_int(snapshot.turn_number).is_equal(5)
	assert_int(snapshot.turns_per_half).is_equal(12)
	assert_int(snapshot.turn_kind).is_equal(GameEnums.TurnKind.OPEN_PLAY)
	assert_str(snapshot.user_setup.formation_id).is_equal("4-4-2")
	assert_str(snapshot.opponent_setup.formation_id).is_equal("4-3-3")


func test_snapshot_converts_the_last_movements() -> void:
	var movements: Array[Movement] = [Movement.new(AWAY, "4-3-3-lw", _area("A-L2"), _area("A-L1"), GameEnums.MovementReason.PRESS)]
	var snapshot: BoardSnapshot = ViewConverter.snapshot(_state(HOME), _catalog, movements, -1, 12)
	assert_str("%s>%s" % [snapshot.movements[0].from.to_key(), snapshot.movements[0].to.to_key()]).is_equal("D-R2>D-R1")
	assert_bool(snapshot.user_has_ball).is_true()


# --- RevealView ---

## CPU（AWAY）が攻撃側の攻守ターンを1つ解決した記録（判定は攻撃側 = AWAY の視点）
func _away_attack_record() -> TurnRecord:
	var state: MatchState = _state(AWAY)
	var options: MoveOptions = MoveRules.options_for(state, AWAY)
	var dribble := TurnChoice.new(ATTACK, GameEnums.PlayType.DRIBBLE, options.targets(ATTACK, GameEnums.PlayType.DRIBBLE)[0])
	var defense_options: MoveOptions = MoveRules.options_for(state, HOME)
	var press := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, defense_options.targets(DEFENSE, GameEnums.DefenseAction.PRESS)[0])
	var rules := MatchRuleConfig.new()
	return MatchRules.resolve_turn(state, press, dribble, rules).record


func test_reveal_shows_the_user_as_defender_in_the_user_view() -> void:
	var record: TurnRecord = _away_attack_record()
	var reveal: RevealView = ViewConverter.reveal(record, _catalog)
	assert_int(reveal.user_role).is_equal(GameEnums.Phase.DEFENSE)
	assert_int(reveal.outcome).is_equal(record.outcome)
	# 選択の運ぶ先・比較エリア・ボール位置は、攻撃側（AWAY）の視点の鏡像
	assert_str(reveal.user_choice.target.to_key()).is_equal(record.home_choice.target.mirrored().to_key())
	assert_str(reveal.opponent_choice.target.to_key()).is_equal(record.away_choice.target.mirrored().to_key())
	assert_str(reveal.compare_area).is_equal(record.judge.compare_area.mirrored().to_key())
	assert_str(reveal.ball_before).is_equal(record.ball_before.mirrored().to_key())
	assert_str(reveal.ball_after).is_equal(record.ball_after.mirrored().to_key())
	# 利用者は守備側なので、利用者の人数は守備側の人数
	assert_int(reveal.user_count).is_equal(record.judge.defender_count)
	assert_int(reveal.opponent_count).is_equal(record.judge.attacker_count)
	assert_bool(reveal.has_detail).is_true()
	assert_array(reveal.simplification_ids).is_empty()


func test_reveal_shows_the_user_as_attacker_without_mirroring() -> void:
	# 利用者（HOME）が攻撃側のターン。運ぶ先・比較エリア・ボール位置は鏡像にしない。CPU の選手は鏡像
	var state: MatchState = _state(HOME)
	var options: MoveOptions = MoveRules.options_for(state, HOME)
	var dribble := TurnChoice.new(ATTACK, GameEnums.PlayType.DRIBBLE, options.targets(ATTACK, GameEnums.PlayType.DRIBBLE)[0])
	var defense_options: MoveOptions = MoveRules.options_for(state, AWAY)
	var press := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, defense_options.targets(DEFENSE, GameEnums.DefenseAction.PRESS)[0])
	var record: TurnRecord = MatchRules.resolve_turn(state, dribble, press, MatchRuleConfig.new()).record
	var reveal: RevealView = ViewConverter.reveal(record, _catalog)
	assert_int(reveal.user_role).is_equal(GameEnums.Phase.ATTACK)
	assert_int(reveal.turn_kind).is_equal(GameEnums.TurnKind.OPEN_PLAY)
	assert_str(reveal.user_choice.target.to_key()).is_equal(record.home_choice.target.to_key())
	assert_str(reveal.opponent_choice.target.to_key()).is_equal(record.away_choice.target.to_key())
	assert_str(reveal.compare_area).is_equal(record.judge.compare_area.to_key())
	assert_str(reveal.ball_before).is_equal(record.ball_before.to_key())
	# 利用者は攻撃側なので、利用者の人数は攻撃側の人数（人数が違うことを先に確かめ、取り違えを検出できるようにする）
	assert_int(record.judge.attacker_count).is_not_equal(record.judge.defender_count)
	assert_int(reveal.user_count).is_equal(record.judge.attacker_count)
	assert_int(reveal.opponent_count).is_equal(record.judge.defender_count)
	# 判定時の CPU の選手は、CPU 自身の視点の鏡像
	var away_layout: TeamLayout = record.pair_at_judgement.defender
	for player: Dictionary in reveal.opponent_players_at_judgement:
		var expected: PitchArea = away_layout.current_area_of(player["player_id"] as String).mirrored()
		assert_str(player["area"] as String).is_equal(expected.to_key())


func test_reveal_players_are_in_the_user_view_with_numbers() -> void:
	var record: TurnRecord = _away_attack_record()
	var reveal: RevealView = ViewConverter.reveal(record, _catalog)
	# 判定前の CPU の左WG（11番）は利用者の視点で D-R2。利用者の左SB（3番）は D-L2
	assert_dict(_player(reveal.opponent_players_before, "4-3-3-lw")).is_equal({"player_id": "4-3-3-lw", "number": 11, "area": "D-R2"})
	assert_dict(_player(reveal.user_players_before, "4-4-2-lb")).is_equal({"player_id": "4-4-2-lb", "number": 3, "area": "D-L2"})
	assert_int(reveal.user_players_at_judgement.size()).is_equal(10)
	assert_int(reveal.movements.size()).is_equal(record.movements.size())


func test_reveal_roles_follow_the_turn_kind_and_attacker() -> void:
	var record := TurnRecord.new()
	record.turn_kind = GameEnums.TurnKind.TRANSITION
	record.attacker = HOME
	assert_int(ViewConverter.role_of(record)).is_equal(GameEnums.Phase.POS_TRANSITION)
	record.attacker = AWAY
	assert_int(ViewConverter.role_of(record)).is_equal(GameEnums.Phase.NEG_TRANSITION)
	record.turn_kind = GameEnums.TurnKind.OPEN_PLAY
	assert_int(ViewConverter.role_of(record)).is_equal(GameEnums.Phase.DEFENSE)
	record.attacker = HOME
	assert_int(ViewConverter.role_of(record)).is_equal(GameEnums.Phase.ATTACK)


func test_reveal_without_judge_detail_has_no_counts() -> void:
	var record: TurnRecord = _away_attack_record()
	record.judge = null
	record.outcome = GameEnums.TurnOutcome.NO_CONTEST
	var reveal: RevealView = ViewConverter.reveal(record, _catalog)
	assert_bool(reveal.has_detail).is_false()
	assert_str(reveal.compare_area).is_equal("")

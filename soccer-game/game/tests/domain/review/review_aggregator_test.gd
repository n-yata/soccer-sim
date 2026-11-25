## アルゴリズム10: 振り返り集計（ReviewAggregator）のテスト。期待値は functional-overview.md アルゴリズム10 の
## 数え方の表とエッジケースから手で書いた。ターン記録は集計が読む項目（通し番号・ハーフ・ターン・種類・攻撃側・
## 陣形と方式・比較エリア・結果）だけを持つ。比較エリアは攻撃側（トランジションは奪取側）の視点。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const OPEN := GameEnums.TurnKind.OPEN_PLAY
const TRANSITION := GameEnums.TurnKind.TRANSITION
const O := GameEnums.TurnOutcome
const WIN := GameEnums.JudgeTally.WIN
const LOSE := GameEnums.JudgeTally.LOSE
const STALL := GameEnums.JudgeTally.STALL
const EXCLUDED := GameEnums.JudgeTally.EXCLUDED


func _setup(formation_id: String = "4-4-2", defense: GameEnums.DefenseStyle = GameEnums.DefenseStyle.ZONE,
		attack: GameEnums.AttackStyle = GameEnums.AttackStyle.POSSESSION) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(defense, attack))


## 記録を1件作る。seq は呼び出し側が試合の順に振る。compare_key が空なら判定なし（NO_CONTEST）
func _record(seq: int, half: int, turn_number: int, attacker: GameEnums.TeamSide, outcome: GameEnums.TurnOutcome,
		compare_key: String = "M2-C", kind: GameEnums.TurnKind = OPEN,
		home_setup: TeamSetup = null, away_setup: TeamSetup = null) -> TurnRecord:
	var record := TurnRecord.new()
	record.seq = seq
	record.half = half
	record.turn_number = turn_number
	record.turn_kind = kind
	record.attacker = attacker
	record.home_setup = _setup() if home_setup == null else home_setup
	record.away_setup = _setup("4-3-3") if away_setup == null else away_setup
	record.outcome = outcome
	if outcome != O.NO_CONTEST:
		record.judge = JudgeDetail.new(PitchArea.from_key(compare_key), 2, 1, GameEnums.CoverKind.NONE)
	return record


## 前半の turns 件の記録（seq と turn_number は 1 から）。outcomes[i] がそのターンの結果、攻撃側は HOME
func _first_half(outcomes: Array) -> Array[TurnRecord]:
	var records: Array[TurnRecord] = []
	for index: int in range(outcomes.size()):
		records.append(_record(index + 1, 1, index + 1, HOME, outcomes[index] as GameEnums.TurnOutcome))
	return records


# --- 数え方の表 ---


func test_tally_follows_the_table_for_the_attacker_and_the_defender() -> void:
	# [結果, 攻撃側・奪取側, 守備側・喪失側]（アルゴリズム10 の表の全行）
	var table: Array = [
		[O.ADVANCE, WIN, LOSE], [O.GOAL, WIN, LOSE],
		[O.LOSS, LOSE, WIN], [O.SAVE, LOSE, WIN],
		[O.STALL, STALL, STALL],
		[O.REGAIN, LOSE, WIN], [O.REGAIN_FAILED, WIN, LOSE],
		[O.NO_CONTEST, EXCLUDED, EXCLUDED],
		[O.OFFSIDE, LOSE, WIN],
	]
	assert_int(table.size()).is_equal(GameEnums.TurnOutcome.size())
	for row: Array in table:
		var outcome: GameEnums.TurnOutcome = row[0] as GameEnums.TurnOutcome
		var label: String = GameEnums.TurnOutcome.find_key(outcome)
		assert_int(ReviewAggregator.tally_of(outcome, true)).override_failure_message("攻撃側 %s" % label) \
				.is_equal(row[1] as int)
		assert_int(ReviewAggregator.tally_of(outcome, false)).override_failure_message("守備側 %s" % label) \
				.is_equal(row[2] as int)


func test_phase_depends_on_the_turn_kind_and_the_viewer_side() -> void:
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, HOME, O.ADVANCE), HOME)).is_equal(GameEnums.Phase.ATTACK)
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, AWAY, O.ADVANCE), HOME)).is_equal(GameEnums.Phase.DEFENSE)
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, HOME, O.REGAIN, "M1-C", TRANSITION), HOME)) \
			.is_equal(GameEnums.Phase.POS_TRANSITION)
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, AWAY, O.REGAIN, "M1-C", TRANSITION), HOME)) \
			.is_equal(GameEnums.Phase.NEG_TRANSITION)
	# viewer が AWAY なら入れ替わる
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, HOME, O.ADVANCE), AWAY)).is_equal(GameEnums.Phase.DEFENSE)
	assert_int(ReviewAggregator.phase_of(_record(1, 1, 1, HOME, O.REGAIN, "M1-C", TRANSITION), AWAY)) \
			.is_equal(GameEnums.Phase.NEG_TRANSITION)


# --- エリア別・局面別 ---


func test_area_and_phase_tallies_are_counted_from_the_viewer() -> void:
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.ADVANCE, "M2-C"),
		_record(2, 1, 2, HOME, O.STALL, "M2-C"),
		_record(3, 1, 3, HOME, O.LOSS, "A1-L1"),
		# 相手の攻撃。相手の視点の M2-L1 は、利用者の視点の M1-R1
		_record(4, 1, 4, AWAY, O.LOSS, "M2-L1"),
		_record(5, 1, 5, AWAY, O.ADVANCE, "M2-L1"),
		# 利用者の奪取（奪ったエリア。奪取側の視点）
		_record(6, 1, 6, HOME, O.REGAIN_FAILED, "M1-C", TRANSITION),
		# 相手の奪取で、利用者が奪い返された（喪失側の勝ち）
		_record(7, 1, 7, AWAY, O.REGAIN, "D2-R2", TRANSITION),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_array(summary.area_tallies["M2-C"]).is_equal([1, 0, 1])
	assert_array(summary.area_tallies["A1-L1"]).is_equal([0, 1, 0])
	assert_array(summary.area_tallies["M1-R1"]).is_equal([1, 1, 0])
	assert_array(summary.area_tallies["M1-C"]).is_equal([1, 0, 0])
	# 相手の視点の D2-R2 は、利用者の視点の A1-L2
	assert_array(summary.area_tallies["A1-L2"]).is_equal([1, 0, 0])
	assert_int(summary.area_tallies.size()).is_equal(5)
	assert_array(summary.phase_tallies[GameEnums.Phase.ATTACK]).is_equal([1, 1, 1])
	assert_array(summary.phase_tallies[GameEnums.Phase.DEFENSE]).is_equal([1, 1, 0])
	assert_array(summary.phase_tallies[GameEnums.Phase.POS_TRANSITION]).is_equal([1, 0, 0])
	assert_array(summary.phase_tallies[GameEnums.Phase.NEG_TRANSITION]).is_equal([1, 0, 0])
	assert_int(summary.area_count("M1-R1", LOSE)).is_equal(1)
	assert_int(summary.area_count("D1-C", WIN)).is_equal(0)
	assert_int(summary.phase_count(GameEnums.Phase.ATTACK, STALL)).is_equal(1)
	assert_int(summary.turn_count).is_equal(7)


func test_the_same_records_seen_from_the_other_side_swap_wins_and_losses() -> void:
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.ADVANCE, "M2-C"),
		_record(2, 1, 2, HOME, O.LOSS, "A1-L1"),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, AWAY, 3)
	# 利用者の M2-C は相手の視点の M1-C、A1-L1 は D2-R1
	assert_array(summary.area_tallies["M1-C"]).is_equal([0, 1, 0])
	assert_array(summary.area_tallies["D2-R1"]).is_equal([1, 0, 0])
	assert_array(summary.phase_tallies[GameEnums.Phase.DEFENSE]).is_equal([1, 1, 0])
	assert_array(summary.phase_tallies[GameEnums.Phase.ATTACK]).is_equal([0, 0, 0])


func test_no_contest_only_match_returns_zero_tallies_without_error() -> void:
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.NO_CONTEST, "", TRANSITION),
		_record(2, 1, 2, AWAY, O.NO_CONTEST, "", TRANSITION),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_dict(summary.area_tallies).is_empty()
	for phase: int in GameEnums.Phase.values():
		assert_array(summary.phase_tallies[phase]).is_equal([0, 0, 0])
	assert_array(summary.goals).is_empty()
	assert_int(summary.turn_count).is_equal(2)


func test_no_records_returns_an_empty_summary() -> void:
	var summary: ReviewSummary = ReviewAggregator.aggregate([] as Array[TurnRecord], HOME, 3)
	assert_dict(summary.area_tallies).is_empty()
	assert_int(summary.phase_tallies.size()).is_equal(GameEnums.Phase.size())
	assert_array(summary.goals).is_empty()
	assert_array(summary.segments).is_empty()
	assert_int(summary.turn_count).is_equal(0)


# --- 得失点の流れ ---


func test_goal_looks_back_at_most_lookback_turns_in_order() -> void:
	var records: Array[TurnRecord] = _first_half([O.STALL, O.ADVANCE, O.ADVANCE, O.ADVANCE, O.ADVANCE, O.GOAL])
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_int(summary.goals.size()).is_equal(1)
	var goal: ReviewGoal = summary.goals[0]
	assert_int(goal.seq).is_equal(6)
	assert_int(goal.half).is_equal(1)
	assert_int(goal.turn_number).is_equal(6)
	assert_int(goal.scorer).is_equal(HOME)
	assert_array(goal.lead_up_seqs).is_equal([3, 4, 5] as Array[int])
	assert_int(goal.home_score).is_equal(1)
	assert_int(goal.away_score).is_equal(0)


func test_lookback_zero_keeps_only_the_goal_turn() -> void:
	var records: Array[TurnRecord] = _first_half([O.ADVANCE, O.GOAL])
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 0)
	assert_array(summary.goals[0].lead_up_seqs).is_empty()


func test_goal_on_the_first_turn_of_a_half_has_no_lead_up() -> void:
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.ADVANCE),
		_record(2, 1, 2, HOME, O.STALL),
		_record(3, 2, 1, AWAY, O.GOAL),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_int(summary.goals.size()).is_equal(1)
	assert_int(summary.goals[0].half).is_equal(2)
	assert_int(summary.goals[0].scorer).is_equal(AWAY)
	assert_array(summary.goals[0].lead_up_seqs).is_empty()
	assert_int(summary.goals[0].home_score).is_equal(0)
	assert_int(summary.goals[0].away_score).is_equal(1)


func test_lead_up_stops_at_the_previous_goal_and_scores_accumulate() -> void:
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.ADVANCE),
		_record(2, 1, 2, HOME, O.GOAL),
		_record(3, 1, 3, AWAY, O.ADVANCE),
		_record(4, 1, 4, AWAY, O.GOAL),
		_record(5, 1, 5, HOME, O.GOAL),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_int(summary.goals.size()).is_equal(3)
	assert_array(summary.goals[0].lead_up_seqs).is_equal([1] as Array[int])
	assert_array(summary.goals[1].lead_up_seqs).is_equal([3] as Array[int])
	# 続けての得点では、前の得点より前のターンを含めない
	assert_array(summary.goals[2].lead_up_seqs).is_empty()
	assert_array([summary.goals[2].home_score, summary.goals[2].away_score]).is_equal([2, 1])
	assert_array([summary.goals[1].home_score, summary.goals[1].away_score]).is_equal([1, 1])


# --- 時間帯 ---


func test_segments_group_same_setups_and_split_at_the_half_and_style_changes() -> void:
	var home_a: TeamSetup = _setup("4-4-2")
	var home_b: TeamSetup = _setup("4-4-2", GameEnums.DefenseStyle.MAN)
	var away: TeamSetup = _setup("4-3-3")
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.ADVANCE, "M2-C", OPEN, home_a, away),
		_record(2, 1, 2, HOME, O.GOAL, "M2-C", OPEN, home_a, away),
		# 得点後に利用者が守備方式を変えた
		_record(3, 1, 3, AWAY, O.STALL, "M2-C", OPEN, home_b, away),
		_record(4, 1, 4, AWAY, O.LOSS, "M2-C", OPEN, home_b, away),
		# 後半は同じ陣形・方式でも別の時間帯
		_record(5, 2, 1, HOME, O.STALL, "M2-C", OPEN, home_b, away),
		_record(6, 2, 17, HOME, O.STALL, "M2-C", OPEN, home_b, away),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_int(summary.segments.size()).is_equal(3)
	var spans: Array = []
	for segment: ReviewSegment in summary.segments:
		spans.append([segment.half, segment.from_turn, segment.to_turn, segment.home_setup.styles.defense])
	assert_array(spans).is_equal([
		[1, 1, 2, GameEnums.DefenseStyle.ZONE],
		[1, 3, 4, GameEnums.DefenseStyle.MAN],
		[2, 1, 17, GameEnums.DefenseStyle.MAN],
	])
	assert_str(summary.segments[0].away_setup.formation_id).is_equal("4-3-3")


func test_segments_split_when_only_the_opponent_changes_formation_or_attack_style() -> void:
	var home: TeamSetup = _setup("4-4-2")
	var records: Array[TurnRecord] = [
		_record(1, 1, 1, HOME, O.STALL, "M2-C", OPEN, home, _setup("4-3-3")),
		_record(2, 1, 2, HOME, O.STALL, "M2-C", OPEN, home, _setup("4-2-3-1")),
		_record(3, 1, 3, HOME, O.STALL, "M2-C", OPEN, home,
				_setup("4-2-3-1", GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)),
		_record(4, 1, 4, HOME, O.STALL, "M2-C", OPEN, home,
				_setup("4-2-3-1", GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)),
	]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	assert_int(summary.segments.size()).is_equal(3)
	assert_int(summary.segments[2].from_turn).is_equal(3)
	assert_int(summary.segments[2].to_turn).is_equal(4)


func test_segments_hold_copies_of_the_setups() -> void:
	var home: TeamSetup = _setup("4-4-2")
	var records: Array[TurnRecord] = [_record(1, 1, 1, HOME, O.STALL, "M2-C", OPEN, home, _setup("4-3-3"))]
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, HOME, 3)
	home.formation_id = "3-5-2"
	assert_str(summary.segments[0].home_setup.formation_id).is_equal("4-4-2")

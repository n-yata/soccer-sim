## MatchRecord.of（試合の状態 → 戦績1件）のテスト。期待値は data-definition.md §2.2 と
## アルゴリズム10「時間帯ごとの陣形・方式」から手で書いた。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER


func _setup(formation_id: String, defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(defense, attack))


func _record(seq: int, half: int, turn_number: int, home_setup: TeamSetup, away_setup: TeamSetup) -> TurnRecord:
	var record := TurnRecord.new()
	record.seq = seq
	record.half = half
	record.turn_number = turn_number
	record.attacker = HOME
	record.outcome = GameEnums.TurnOutcome.STALL
	record.home_setup = home_setup
	record.away_setup = away_setup
	return record


func _state(home_score: int, away_score: int) -> MatchState:
	var state := MatchState.new()
	state.match_id = "20261029-101500-0042"
	state.home_score = home_score
	state.away_score = away_score
	state.home_setup = _setup("4-3-3", ZONE, POSSESSION)
	state.away_setup = _setup("4-4-2", MAN, COUNTER)
	return state


func test_ids_scores_and_time_come_from_the_state() -> void:
	var record: MatchRecord = MatchRecord.of(_state(2, 1), "2026-10-29T10:42:00")
	assert_str(record.record_id).is_equal("20261029-101500-0042")
	assert_str(record.match_id).is_equal("20261029-101500-0042")
	assert_str(record.finished_at).is_equal("2026-10-29T10:42:00")
	assert_int(record.score_user).is_equal(2)
	assert_int(record.score_cpu).is_equal(1)


func test_result_is_seen_from_the_user() -> void:
	assert_int(MatchRecord.of(_state(2, 1), "").result).is_equal(GameEnums.MatchResult.WIN)
	assert_int(MatchRecord.of(_state(1, 1), "").result).is_equal(GameEnums.MatchResult.DRAW)
	assert_int(MatchRecord.of(_state(0, 3), "").result).is_equal(GameEnums.MatchResult.LOSE)


## 前半の途中で CPU が守備方式を変え、ハーフタイムで利用者が陣形を変えた試合。区切りは3つ
func test_timeline_starts_a_period_at_each_change_and_each_half() -> void:
	var user_first := _setup("4-3-3", ZONE, POSSESSION)
	var cpu_first := _setup("4-4-2", MAN, COUNTER)
	var cpu_zone := _setup("4-4-2", ZONE, COUNTER)
	var user_second := _setup("3-5-2", ZONE, POSSESSION)
	var state: MatchState = _state(0, 0)
	state.turn_records = [
		_record(1, 1, 1, user_first, cpu_first),
		_record(2, 1, 2, user_first, cpu_first),
		_record(3, 1, 3, user_first, cpu_zone),
		_record(4, 1, 4, user_first, cpu_zone),
		_record(5, 2, 1, user_second, cpu_zone),
	]
	var timeline: Array[RecordPeriod] = MatchRecord.of(state, "").timeline
	assert_int(timeline.size()).is_equal(3)
	assert_array([timeline[0].half, timeline[0].from_turn, timeline[1].half, timeline[1].from_turn,
			timeline[2].half, timeline[2].from_turn]).is_equal([1, 1, 1, 3, 2, 1])
	assert_int(timeline[1].cpu_setup.styles.defense).is_equal(ZONE)
	assert_str(timeline[2].user_setup.formation_id).is_equal("3-5-2")
	assert_str(timeline[0].user_setup.formation_id).is_equal("4-3-3")


func test_timeline_without_turns_uses_the_current_setups() -> void:
	var timeline: Array[RecordPeriod] = MatchRecord.of(_state(0, 0), "").timeline
	assert_int(timeline.size()).is_equal(1)
	assert_array([timeline[0].half, timeline[0].from_turn]).is_equal([1, 1])
	assert_str(timeline[0].cpu_setup.formation_id).is_equal("4-4-2")

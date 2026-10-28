## アルゴリズム10: 振り返り集計（component-design.md §2.8。正本は functional-overview.md アルゴリズム10）。
## ターン記録から、viewer から見たエリア別・局面別の勝ち／負け／膠着と、得失点の流れ・時間帯ごとの陣形と方式をまとめる。
class_name ReviewAggregator
extends RefCounted


## records は試合の順。lookback_turns は得点の直前に遡る最大のターン数（0 以上）。
static func aggregate(records: Array[TurnRecord], viewer: GameEnums.TeamSide, lookback_turns: int) -> ReviewSummary:
	var summary := ReviewSummary.new()
	summary.turn_count = records.size()
	for phase: int in GameEnums.Phase.values():
		summary.phase_tallies[phase] = [0, 0, 0]
	for record: TurnRecord in records:
		_count(summary, record, viewer)
	summary.goals = _goals(records, lookback_turns)
	summary.segments = _segments(records)
	return summary


## 1ターンの数え方（攻撃側・奪取側から見た値。相手側は勝ちと負けが入れ替わる）。
static func tally_of(outcome: GameEnums.TurnOutcome, viewer_is_attacker: bool) -> GameEnums.JudgeTally:
	var attacker_tally: GameEnums.JudgeTally
	match outcome:
		GameEnums.TurnOutcome.ADVANCE, GameEnums.TurnOutcome.GOAL, GameEnums.TurnOutcome.REGAIN_FAILED:
			attacker_tally = GameEnums.JudgeTally.WIN
		GameEnums.TurnOutcome.LOSS, GameEnums.TurnOutcome.SAVE, GameEnums.TurnOutcome.REGAIN, \
				GameEnums.TurnOutcome.OFFSIDE:
			attacker_tally = GameEnums.JudgeTally.LOSE
		GameEnums.TurnOutcome.STALL:
			return GameEnums.JudgeTally.STALL
		_:
			# NO_CONTEST は両者が争わないことを選んだ結果で、どちらかの判断の誤りではない
			return GameEnums.JudgeTally.EXCLUDED
	if viewer_is_attacker:
		return attacker_tally
	return GameEnums.JudgeTally.LOSE if attacker_tally == GameEnums.JudgeTally.WIN else GameEnums.JudgeTally.WIN


## viewer の局面。攻守ターンは攻撃側か守備側、トランジションは奪取側か喪失側。
static func phase_of(record: TurnRecord, viewer: GameEnums.TeamSide) -> GameEnums.Phase:
	var is_attacker: bool = record.attacker == viewer
	if record.turn_kind == GameEnums.TurnKind.TRANSITION:
		return GameEnums.Phase.POS_TRANSITION if is_attacker else GameEnums.Phase.NEG_TRANSITION
	return GameEnums.Phase.ATTACK if is_attacker else GameEnums.Phase.DEFENSE


static func _count(summary: ReviewSummary, record: TurnRecord, viewer: GameEnums.TeamSide) -> void:
	var is_attacker: bool = record.attacker == viewer
	var tally: GameEnums.JudgeTally = tally_of(record.outcome, is_attacker)
	if tally == GameEnums.JudgeTally.EXCLUDED or record.judge == null:
		return
	(summary.phase_tallies[phase_of(record, viewer)] as Array)[tally] += 1
	# 比較エリアは攻撃側の視点なので、viewer が攻撃側でなければ鏡像にする
	var area: PitchArea = record.judge.compare_area if is_attacker else record.judge.compare_area.mirrored()
	var key: String = area.to_key()
	if not summary.area_tallies.has(key):
		summary.area_tallies[key] = [0, 0, 0]
	(summary.area_tallies[key] as Array)[tally] += 1


## 得点ごとに、同じハーフ内で直前の得点より後のターンを、最大 lookback_turns 件遡る。
static func _goals(records: Array[TurnRecord], lookback_turns: int) -> Array[ReviewGoal]:
	var goals: Array[ReviewGoal] = []
	var home_score: int = 0
	var away_score: int = 0
	# 遡ってよい最初の記録の位置（ハーフの初め、または直前の得点の次）
	var window_start: int = 0
	for index: int in range(records.size()):
		var record: TurnRecord = records[index]
		if index > 0 and record.half != records[index - 1].half:
			window_start = index
		if record.outcome != GameEnums.TurnOutcome.GOAL:
			continue
		if record.attacker == GameEnums.TeamSide.HOME:
			home_score += 1
		else:
			away_score += 1
		var goal := ReviewGoal.new()
		goal.seq = record.seq
		goal.half = record.half
		goal.turn_number = record.turn_number
		goal.scorer = record.attacker
		goal.home_score = home_score
		goal.away_score = away_score
		for lead_index: int in range(maxi(window_start, index - maxi(lookback_turns, 0)), index):
			goal.lead_up_seqs.append(records[lead_index].seq)
		goals.append(goal)
		window_start = index + 1
	return goals


## 両チームの陣形・方式が同じ連続したターンを1つの時間帯にする。ハーフの境では必ず区切る。
static func _segments(records: Array[TurnRecord]) -> Array[ReviewSegment]:
	var segments: Array[ReviewSegment] = []
	var current: ReviewSegment = null
	for record: TurnRecord in records:
		if current != null and current.half == record.half and _same_setup(current.home_setup, record.home_setup) \
				and _same_setup(current.away_setup, record.away_setup):
			current.to_turn = record.turn_number
			continue
		current = ReviewSegment.new()
		current.half = record.half
		current.from_turn = record.turn_number
		current.to_turn = record.turn_number
		current.home_setup = record.home_setup.duplicate_deep()
		current.away_setup = record.away_setup.duplicate_deep()
		segments.append(current)
	return segments


static func _same_setup(a: TeamSetup, b: TeamSetup) -> bool:
	return a.formation_id == b.formation_id and a.styles.defense == b.styles.defense \
			and a.styles.attack == b.styles.attack

## ドメインの値を、利用者の視点に揃えた画面向けの値へ変換する（component-design.md §1.2・§3.5）。
## 利用者 = HOME、CPU = AWAY（§1.3）。各チームの選手・動きはそのチーム自身の視点、選択の運ぶ先・比較エリア・
## ボール位置は判定時の攻撃側（保持側・奪取側）の視点で持たれているので、その側が AWAY なら鏡像にする。
## 変換は MatchController だけが使い、UI は座標を変換しない。
class_name ViewConverter
extends RefCounted


## side の視点のエリアを、利用者（HOME）の視点にする。null はそのまま。
static func to_user(area: PitchArea, side: GameEnums.TeamSide) -> PitchArea:
	if area == null:
		return null
	return area.duplicate_deep() if side == GameEnums.TeamSide.HOME else area.mirrored()


## 攻撃側（attacker）の視点の選択を、利用者の視点にする。
static func choice_to_user(choice: TurnChoice, attacker: GameEnums.TeamSide) -> TurnChoice:
	return TurnChoice.new(choice.family, choice.action, to_user(choice.target, attacker))


## 利用者の視点の選択を、判定時の攻撃側（attacker）の視点にする（鏡像は2回で元に戻るので、同じ変換になる）。
static func choice_to_domain(choice: TurnChoice, attacker: GameEnums.TeamSide) -> TurnChoice:
	return choice_to_user(choice, attacker)


## 攻撃側の視点の選べる手を、利用者の視点にする（運ぶ先を持たない手は選べるかだけを写す）。
static func options_to_user(options: MoveOptions, attacker: GameEnums.TeamSide) -> MoveOptions:
	var converted := MoveOptions.new()
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for family: int in range(action_counts.size()):
		var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
		for action: int in range(action_counts[family]):
			if not options.is_available(family_value, action):
				continue
			if not MoveOptions.needs_target(family_value, action):
				converted.allow(family_value, action)
				continue
			for target: PitchArea in options.targets(family_value, action):
				converted.add_target(family_value, action, to_user(target, attacker))
	return converted


## 攻撃側の視点のヒントを、利用者の視点にする（人数とカバーは選ぶ側から見た値なので変えない）。
static func hints_to_user(hints: Array[ChoiceHint], attacker: GameEnums.TeamSide) -> Array[ChoiceHint]:
	var converted: Array[ChoiceHint] = []
	for hint: ChoiceHint in hints:
		var copied := ChoiceHint.new(hint.family, hint.action, to_user(hint.target, attacker),
				hint.is_compared, hint.own_count, hint.opponent_count, hint.cover)
		copied.is_offside = hint.is_offside
		copied.is_marked = hint.is_marked
		converted.append(copied)
	return converted


## 動いた選手のチームの視点の動きを、利用者の視点にする。
static func movements_to_user(movements: Array[Movement]) -> Array[Movement]:
	var converted: Array[Movement] = []
	for movement: Movement in movements:
		converted.append(Movement.new(movement.side, movement.player_id,
				to_user(movement.from, movement.side), to_user(movement.to, movement.side), movement.reason))
	return converted


## 試合の現在の状態。選手の位置はターン開始時の配置（MatchRules.current_layouts）。
## last_goal_by は直前の得点の側（無ければ -1）。is_half_over はハーフを終えた後か（呼び出し側が規則から判断する）。
static func snapshot(state: MatchState, catalog: ContentCatalog, last_movements: Array[Movement],
		last_goal_by: int, turns_per_half: int, is_half_over: bool) -> BoardSnapshot:
	var view := BoardSnapshot.new()
	var pair: LayoutPair = MatchRules.current_layouts(state).pair
	var home_layout: TeamLayout = pair.attacker if pair.attacker_side == GameEnums.TeamSide.HOME else pair.defender
	var away_layout: TeamLayout = pair.defender if pair.attacker_side == GameEnums.TeamSide.HOME else pair.attacker
	view.user_players = _players(home_layout, GameEnums.TeamSide.HOME, _numbers(catalog, state.home_setup))
	view.opponent_players = _players(away_layout, GameEnums.TeamSide.AWAY, _numbers(catalog, state.away_setup))
	view.user_counts = _counts(view.user_players)
	view.opponent_counts = _counts(view.opponent_players)
	view.ball_area = to_user(state.ball_area, state.possession).to_key()
	view.user_has_ball = state.possession == GameEnums.TeamSide.HOME
	view.last_goal_by = last_goal_by
	view.turn_kind = state.turn_kind
	view.half = state.half
	view.turn_number = state.turn_number
	view.turns_per_half = turns_per_half
	view.is_half_over = is_half_over
	view.score_user = state.home_score
	view.score_opponent = state.away_score
	view.user_setup = state.home_setup.duplicate_deep()
	view.opponent_setup = state.away_setup.duplicate_deep()
	view.movements = movements_to_user(last_movements)
	# 利用者が攻撃側なので、攻撃側の視点の列がそのまま利用者の視点の列
	# 手を選ぶ場面（試合中の TURN）だけ。方式の選び直し・ハーフタイム・試合終了の盤面には出さない
	if view.user_has_ball and state.turn_kind == GameEnums.TurnKind.OPEN_PLAY \
			and state.stage == GameEnums.MatchStage.TURN and state.status == GameEnums.MatchStatus.IN_PROGRESS:
		view.offside_line_zone = OffsideRule.line_row(pair.defender, state.ball_area)
	return view


## 1ターンの記録を、利用者の視点の開示に変換する。背番号はそのターンの陣形（記録の陣形と方式）から引く。
static func reveal(record: TurnRecord, catalog: ContentCatalog) -> RevealView:
	var view := RevealView.new()
	var attacker: GameEnums.TeamSide = record.attacker
	var is_user_attacker: bool = attacker == GameEnums.TeamSide.HOME
	view.user_role = role_of(record)
	view.turn_kind = record.turn_kind
	view.half = record.half
	view.turn_number = record.turn_number
	view.user_choice = choice_to_user(record.home_choice, attacker)
	view.opponent_choice = choice_to_user(record.away_choice, attacker)
	view.outcome = record.outcome
	view.has_detail = record.judge != null
	if view.has_detail:
		view.compare_area = to_user(record.judge.compare_area, attacker).to_key()
		view.user_count = record.judge.attacker_count if is_user_attacker else record.judge.defender_count
		view.opponent_count = record.judge.defender_count if is_user_attacker else record.judge.attacker_count
		view.cover = record.judge.cover
		view.read = record.judge.read
	view.ball_before = to_user(record.ball_before, attacker).to_key()
	view.ball_after = to_user(record.ball_after, attacker).to_key()
	var home_numbers: Dictionary = _numbers(catalog, record.home_setup)
	var away_numbers: Dictionary = _numbers(catalog, record.away_setup)
	view.user_players_before = _players(_layout_of(record.pair_before, GameEnums.TeamSide.HOME), GameEnums.TeamSide.HOME, home_numbers)
	view.opponent_players_before = _players(_layout_of(record.pair_before, GameEnums.TeamSide.AWAY), GameEnums.TeamSide.AWAY, away_numbers)
	view.user_players_at_judgement = _players(_layout_of(record.pair_at_judgement, GameEnums.TeamSide.HOME), GameEnums.TeamSide.HOME, home_numbers)
	view.opponent_players_at_judgement = _players(_layout_of(record.pair_at_judgement, GameEnums.TeamSide.AWAY), GameEnums.TeamSide.AWAY, away_numbers)
	view.movements = movements_to_user(record.movements)
	return view


## 試合のターン記録を利用者（HOME）から集計し、得失点の流れの各ターンを開示の値にする（アルゴリズム10）。
## 集計は利用者を viewer にして行うので、エリア・局面はすでに利用者の視点。
static func review(records: Array[TurnRecord], catalog: ContentCatalog, lookback_turns: int) -> ReviewView:
	var summary: ReviewSummary = ReviewAggregator.aggregate(records, GameEnums.TeamSide.HOME, lookback_turns)
	var by_seq: Dictionary = {}
	for record: TurnRecord in records:
		by_seq[record.seq] = record
	var view := ReviewView.new()
	view.area_tallies = summary.area_tallies.duplicate(true)
	view.phase_tallies = summary.phase_tallies.duplicate(true)
	view.turn_count = summary.turn_count
	for goal: ReviewGoal in summary.goals:
		var turns: Array[RevealView] = []
		for seq: int in goal.lead_up_seqs:
			turns.append(reveal(by_seq[seq] as TurnRecord, catalog))
		turns.append(reveal(by_seq[goal.seq] as TurnRecord, catalog))
		view.goals.append({"is_user": goal.scorer == GameEnums.TeamSide.HOME, "half": goal.half,
				"turn_number": goal.turn_number, "score_user": goal.home_score, "score_opponent": goal.away_score,
				"turns": turns})
	for segment: ReviewSegment in summary.segments:
		view.segments.append({"half": segment.half, "from_turn": segment.from_turn, "to_turn": segment.to_turn,
				"user_setup": segment.home_setup, "opponent_setup": segment.away_setup})
	return view


## 利用者の役割。攻守ターンは攻撃側か守備側、トランジションは奪取側か喪失側。
static func role_of(record: TurnRecord) -> GameEnums.Phase:
	var is_user_attacker: bool = record.attacker == GameEnums.TeamSide.HOME
	if record.turn_kind == GameEnums.TurnKind.TRANSITION:
		return GameEnums.Phase.POS_TRANSITION if is_user_attacker else GameEnums.Phase.NEG_TRANSITION
	return GameEnums.Phase.ATTACK if is_user_attacker else GameEnums.Phase.DEFENSE


static func _layout_of(pair: LayoutPair, side: GameEnums.TeamSide) -> TeamLayout:
	return pair.attacker if pair.attacker_side == side else pair.defender


## 利用者（HOME）の選手の並び（BoardSnapshot.user_players と同じ形・利用者の視点）。決定前のプレビューの配置に使う。
static func user_players_of(pair: LayoutPair, catalog: ContentCatalog, setup: TeamSetup) -> Array[Dictionary]:
	return _players(_layout_of(pair, GameEnums.TeamSide.HOME), GameEnums.TeamSide.HOME, _numbers(catalog, setup))


## 選手 ID → 背番号（陣形データ）。陣形が見つからなければ空（背番号は 0 になる）。
static func _numbers(catalog: ContentCatalog, setup: TeamSetup) -> Dictionary:
	var numbers: Dictionary = {}
	var formation: FormationDef = catalog.formation(setup.formation_id)
	if formation == null:
		return numbers
	for slot: PlayerSlotDef in formation.players:
		numbers[slot.id] = slot.number
	return numbers


static func _players(layout: TeamLayout, side: GameEnums.TeamSide, numbers: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player: PlayerState in layout.players:
		result.append({
			"player_id": player.player_id,
			"number": numbers.get(player.player_id, 0) as int,
			"area": to_user(layout.current_area_of(player.player_id), side).to_key(),
		})
	return result


static func _counts(players: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for area: PitchArea in PitchArea.all():
		counts[area.to_key()] = 0
	for player: Dictionary in players:
		var key: String = player["area"] as String
		counts[key] = (counts[key] as int) + 1
	return counts

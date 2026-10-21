## アルゴリズム7: キックオフと試合進行（functional-overview.md。component-design.md §2.5）。
## 1ターンの解決（アルゴリズム2〜6の組み立て）と、結果の反映（アルゴリズム5の手順7・アルゴリズム6の結果の反映）、
## キックオフ・得点・ハーフ・試合終了の状態遷移を受け持つ。どの関数も入力を書き換えず、新しい状態を返す。
##
## 選択の運ぶ先は判定時の攻撃側（トランジションは奪取側）の視点で受け取る（変換は MatchController が行う。§1.2）。
class_name MatchRules
extends RefCounted


## 試合を作り、前半のキックオフを行う。kickoff_side は呼び出し側が注入した乱数で決めて渡す。
## started_at は呼び出し側が取得した時刻（ドメインでは時刻を取得しない）。陣形が静的データに無ければ null を返す。
static func create_match(match_id: String, home: TeamSetup, away: TeamSetup, kickoff_side: GameEnums.TeamSide,
		catalog: ContentCatalog, started_at: String) -> MatchState:
	var home_formation: FormationDef = catalog.formation(home.formation_id)
	var away_formation: FormationDef = catalog.formation(away.formation_id)
	if home_formation == null or away_formation == null:
		return null
	var state := MatchState.new()
	state.match_id = match_id
	state.started_at = started_at
	state.first_half_kickoff = kickoff_side
	state.home_setup = home.duplicate_deep()
	state.away_setup = away.duplicate_deep()
	state.home_players = BaseLayoutDeriver.derive(home_formation).players
	state.away_players = BaseLayoutDeriver.derive(away_formation).players
	_kickoff(state, kickoff_side)
	_place_holder(state)
	return state


## 盤面表示・選択肢の計算に使う、ターン開始時の両チームの配置（保持側を attacker として持つ）。
static func current_layouts(state: MatchState) -> LayoutStep:
	return StyleLayoutCalculator.turn_start(state)


## 1ターンを解決する。次の場合は null を返す（呼び出し側の誤り）。
## - どちらかの手が選択不可（MoveRules.is_allowed。範囲外の手の値も含む）
## - 進行段階が TURN でない、試合が終わっている、後半の最終ターンまで終えている
static func resolve_turn(state: MatchState, home_choice: TurnChoice, away_choice: TurnChoice,
		rules: MatchRuleConfig) -> TurnResolution:
	if state.status != GameEnums.MatchStatus.IN_PROGRESS or state.stage != GameEnums.MatchStage.TURN \
			or is_play_complete(state, rules) or home_choice == null or away_choice == null:
		return null
	if not MoveRules.is_allowed(MoveRules.options_for(state, GameEnums.TeamSide.HOME), home_choice) \
			or not MoveRules.is_allowed(MoveRules.options_for(state, GameEnums.TeamSide.AWAY), away_choice):
		return null
	var holder: GameEnums.TeamSide = state.possession
	var other: GameEnums.TeamSide = MatchState.other(holder)
	var holder_choice: TurnChoice = home_choice if holder == GameEnums.TeamSide.HOME else away_choice
	var other_choice: TurnChoice = away_choice if holder == GameEnums.TeamSide.HOME else home_choice
	var start: LayoutStep = StyleLayoutCalculator.turn_start(state)
	var output: JudgeOutput
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		output = TransitionJudge.judge(state.transition_origin, state.setup_of(holder).styles,
				state.setup_of(other).styles, state.ball_area, holder_choice, other_choice)
	else:
		output = OpenPlayJudge.judge(start.pair, state.setup_of(holder).styles, state.setup_of(other).styles,
				state.ball_area, holder_choice, other_choice)
	if output == null:
		return null
	var ball_after: PitchArea = _ball_after(state, output.outcome, holder_choice)
	var next: MatchState = state.duplicate_deep()
	_apply_outcome(next, state.turn_kind, output, ball_after)
	var record: TurnRecord = _record(state, start, output, home_choice, away_choice, ball_after)
	if state.turn_kind == GameEnums.TurnKind.OPEN_PLAY and holder_choice.action == GameEnums.PlayType.DRIBBLE \
			and output.outcome == GameEnums.TurnOutcome.STALL:
		record.movements.append_array(_stop_dribble(next, state, output))
	next.turn_number += 1
	# ハーフの最終ターン: 得点でも方式の選び直しを行わない。前半はハーフタイムへ、後半は試合終了（is_play_complete）
	if next.turn_number > rules.turns_per_half:
		next.stage = GameEnums.MatchStage.HALFTIME if next.half == 1 else GameEnums.MatchStage.TURN
		# 最終ターンの LOSS・SAVE でもトランジションには入らない（次のターンが無いため）
		next.turn_kind = GameEnums.TurnKind.OPEN_PLAY
		next.transition_origin = null
	# ハーフタイム・試合終了には次のターンが無い（配置は後半のキックオフで置き直すか、捨てる）。置くと起きなかった動きが記録に残る
	if next.stage != GameEnums.MatchStage.HALFTIME and not is_play_complete(next, rules):
		record.movements.append_array(_place_holder(next))
	next.turn_records.append(record)
	return TurnResolution.new(next, record)


## 得点後の方式の選び直し（STYLE_CHANGE → TURN）。失点側のキックオフは得点の時点で済ませてあり、
## ここでは方式を差し替えて再開する。進行段階が STYLE_CHANGE でなければ null を返す。
static func apply_style_change(state: MatchState, home: TeamStyles, away: TeamStyles) -> MatchState:
	if state.stage != GameEnums.MatchStage.STYLE_CHANGE:
		return null
	var next: MatchState = state.duplicate_deep()
	next.home_setup.styles = home.duplicate_deep()
	next.away_setup.styles = away.duplicate_deep()
	next.stage = GameEnums.MatchStage.TURN
	return next


## ハーフタイムの陣形・方式の選び直し（HALFTIME → TURN）。前半と反対側のキックオフで後半を始める
## （前半最後の得点の失点側ではない）。進行段階が HALFTIME でない、陣形が静的データに無ければ null を返す。
static func apply_halftime(state: MatchState, home: TeamSetup, away: TeamSetup, catalog: ContentCatalog) -> MatchState:
	if state.stage != GameEnums.MatchStage.HALFTIME:
		return null
	var home_formation: FormationDef = catalog.formation(home.formation_id)
	var away_formation: FormationDef = catalog.formation(away.formation_id)
	if home_formation == null or away_formation == null:
		return null
	var next: MatchState = state.duplicate_deep()
	next.half = 2
	next.turn_number = 1
	next.home_setup = home.duplicate_deep()
	next.away_setup = away.duplicate_deep()
	next.home_players = BaseLayoutDeriver.derive(home_formation).players
	next.away_players = BaseLayoutDeriver.derive(away_formation).players
	_kickoff(next, MatchState.other(next.first_half_kickoff))
	next.stage = GameEnums.MatchStage.TURN
	_place_holder(next)
	return next


## 後半の最終ターンまで終えたか（試合結果へ進む判断と、終了処理のやり直し判定に使う）。
static func is_play_complete(state: MatchState, rules: MatchRuleConfig) -> bool:
	return state.half == 2 and state.turn_number > rules.turns_per_half


## 試合を FINISHED にした状態を返す。
static func finish(state: MatchState) -> MatchState:
	var next: MatchState = state.duplicate_deep()
	next.status = GameEnums.MatchStatus.FINISHED
	return next


## キックオフ: ボールは M-C、side の保持で攻守ターンから始める。両チームの配置区間をリセットする。
static func _kickoff(state: MatchState, side: GameEnums.TeamSide) -> void:
	state.possession = side
	state.ball_area = PitchArea.new(GameEnums.Lane.C, GameEnums.Zone.M)
	state.turn_kind = GameEnums.TurnKind.OPEN_PLAY
	state.transition_origin = null
	_release_fixes(state)


static func _release_fixes(state: MatchState) -> void:
	for player: PlayerState in state.home_players + state.away_players:
		player.fixed_area = null


## 判定直後にボールがあるエリア（攻撃側の視点）。SAVE は守備側の自陣 D-C（攻撃側の視点で A-C）、
## GOAL はシュートしたエリア、保持したまま動かない結果は判定前の位置。
static func _ball_after(state: MatchState, outcome: GameEnums.TurnOutcome, holder_choice: TurnChoice) -> PitchArea:
	match outcome:
		GameEnums.TurnOutcome.ADVANCE, GameEnums.TurnOutcome.LOSS:
			return holder_choice.target.duplicate_deep()
		GameEnums.TurnOutcome.SAVE:
			return PitchArea.new(GameEnums.Lane.C, GameEnums.Zone.A)
	# STALL・GOAL（攻守ターン）、REGAIN・REGAIN_FAILED・NO_CONTEST・カウンターの STALL（トランジションの X）
	return state.ball_area.duplicate_deep()


## 結果を next に反映する（requirements.md の表）。next は判定前の状態の写し。
static func _apply_outcome(next: MatchState, kind: GameEnums.TurnKind, output: JudgeOutput, ball_after: PitchArea) -> void:
	var holder: GameEnums.TeamSide = next.possession
	var outcome: GameEnums.TurnOutcome = output.outcome
	_store_players(next, output.pair)
	if outcome == GameEnums.TurnOutcome.GOAL:
		if holder == GameEnums.TeamSide.HOME:
			next.home_score += 1
		else:
			next.away_score += 1
		# 失点側のキックオフをこの時点で済ませる（選び直しの間も、ボール位置が保持側の視点の M-C になるように）。
		# ハーフの最終ターンなら、下の resolve_turn でハーフタイム・試合終了に切り替わる
		_kickoff(next, MatchState.other(holder))
		next.stage = GameEnums.MatchStage.STYLE_CHANGE
		return
	var hands_over: bool = outcome in [GameEnums.TurnOutcome.LOSS, GameEnums.TurnOutcome.SAVE, GameEnums.TurnOutcome.REGAIN]
	var to_transition: bool = outcome == GameEnums.TurnOutcome.LOSS or outcome == GameEnums.TurnOutcome.SAVE
	if hands_over:
		next.possession = MatchState.other(holder)
		next.ball_area = ball_after.mirrored()
	else:
		next.ball_area = ball_after.duplicate_deep()
	if to_transition:
		# トランジションの間は配置区間が続く（固定は維持）。起点は判定時の配置で、新しい保持側（奪取側）を attacker に
		next.turn_kind = GameEnums.TurnKind.TRANSITION
		next.transition_origin = LayoutPair.new(output.pair.defender.duplicate_deep(),
				output.pair.attacker.duplicate_deep(), next.possession)
		return
	next.turn_kind = GameEnums.TurnKind.OPEN_PLAY
	next.transition_origin = null
	# トランジションが終わって攻守ターンが始まる時は、配置区間をリセットする（攻守ターンからの続きは固定を維持）
	if kind == GameEnums.TurnKind.TRANSITION:
		_release_fixes(next)


## 膠着したドリブル: 運んだ選手の固定を判定前に戻す（ボールは元のエリアに残るので、運んだ選手もそこへ戻る）。
## 判定と判定時の配置（ターン記録の pair_at_judgement）は運んだ後の位置のまま。戻る動きを返す。
## 判定前に固定されていなかった選手の次のターンの位置は、方式の動き（アルゴリズム2）で決まる。入力が判定前と同じなので
## B に戻る（テストで確かめている）。方式の動きが判定の結果に依存するように変わったら、記録の移動先 B とずれうる。
static func _stop_dribble(next: MatchState, state: MatchState, output: JudgeOutput) -> Array[Movement]:
	var result: Array[Movement] = []
	var holder: GameEnums.TeamSide = state.possession
	for movement: Movement in output.movements:
		if movement.reason != GameEnums.MovementReason.DRIBBLE:
			continue
		var before: PlayerState = _player_of(state.players_of(holder), movement.player_id)
		var carrier: PlayerState = _player_of(next.players_of(holder), movement.player_id)
		# 運んだ選手は保持側の選手なので通常は見つかる。見つからないのは状態が壊れているときで、何も戻さない
		if before == null or carrier == null:
			continue
		carrier.fixed_area = null if before.fixed_area == null else before.fixed_area.duplicate_deep()
		result.append(Movement.new(holder, movement.player_id, movement.to.duplicate_deep(), movement.from.duplicate_deep(),
				GameEnums.MovementReason.DRIBBLE_STOPPED))
	return result


## 次のターンの開始時の配置で、ボールのエリアに保持側の選手がいなければ、いちばん近い選手を1人置いて固定する。
## 近さはゾーン差＋レーン差で、同じなら配置の選手の順で先の選手（アルゴリズム2のマーカーの選び方と同じ）。
## トランジションは起点の配置も同じく変える。置いた動きを返す（置かなければ空）。
static func _place_holder(next: MatchState) -> Array[Movement]:
	var result: Array[Movement] = []
	var holders: TeamLayout = StyleLayoutCalculator.turn_start(next).pair.attacker
	if holders.count_at(next.ball_area) > 0:
		return result
	var nearest: PlayerState = null
	var nearest_distance: int = 0
	for player: PlayerState in holders.players:
		var distance: int = holders.current_area_of(player.player_id).distance_to(next.ball_area)
		if nearest == null or distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest == null:
		return result
	_player_of(next.players_of(next.possession), nearest.player_id).fixed_area = next.ball_area.duplicate_deep()
	if next.turn_kind == GameEnums.TurnKind.TRANSITION:
		next.transition_origin.attacker = next.transition_origin.attacker.with_fixed(nearest.player_id, next.ball_area)
	result.append(Movement.new(next.possession, nearest.player_id,
			holders.current_area_of(nearest.player_id).duplicate_deep(), next.ball_area.duplicate_deep(),
			GameEnums.MovementReason.BALL_HOLDER))
	return result


static func _player_of(players: Array[PlayerState], player_id: String) -> PlayerState:
	for player: PlayerState in players:
		if player.player_id == player_id:
			return player
	return null


## 判定時の配置の選手（基本エリア・固定先）を、保持側・相手の枠に写す。
static func _store_players(next: MatchState, pair: LayoutPair) -> void:
	var attacker_players: Array[PlayerState] = []
	for player: PlayerState in pair.attacker.players:
		attacker_players.append(player.duplicate_deep())
	var defender_players: Array[PlayerState] = []
	for player: PlayerState in pair.defender.players:
		defender_players.append(player.duplicate_deep())
	if pair.attacker_side == GameEnums.TeamSide.HOME:
		next.home_players = attacker_players
		next.away_players = defender_players
	else:
		next.away_players = attacker_players
		next.home_players = defender_players


static func _record(state: MatchState, start: LayoutStep, output: JudgeOutput, home_choice: TurnChoice,
		away_choice: TurnChoice, ball_after: PitchArea) -> TurnRecord:
	var record := TurnRecord.new()
	record.seq = state.turn_records.size() + 1
	record.half = state.half
	record.turn_number = state.turn_number
	record.turn_kind = state.turn_kind
	record.attacker = state.possession
	record.home_setup = state.home_setup.duplicate_deep()
	record.away_setup = state.away_setup.duplicate_deep()
	record.home_choice = home_choice.duplicate_deep()
	record.away_choice = away_choice.duplicate_deep()
	record.ball_before = state.ball_area.duplicate_deep()
	record.ball_after = ball_after.duplicate_deep()
	record.pair_before = start.pair.duplicate_deep()
	record.pair_at_judgement = output.pair.duplicate_deep()
	for movement: Movement in start.movements + output.movements:
		record.movements.append(movement.duplicate_deep())
	record.judge = null if output.detail == null else output.detail.duplicate_deep()
	record.outcome = output.outcome
	return record

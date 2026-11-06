## 決定前のプレビュー（MovePreview）のテスト。
## 期待値はアルゴリズム4〜6の規則から手で書き、あわせて、判定（OpenPlayJudge.judge・TransitionJudge.judge）で
## 相手が選手を動かさない手を選んだときの自チームの動きと一致することを確かめる。
## 運ぶ先は判定時の攻撃側（奪取側）の視点、選手のエリアと動きは各チーム自身の視点（component-design.md §1.2）。
## 盤面は6列（2026-10-25）。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS
const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## spec は [選手 ID, 基本エリア, 固定先（無ければ ""）]
func _players(spec: Array) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String),
				null if fixed_key == "" else _area(fixed_key)))
	return players


func _layout_of(players: Array[PlayerState]) -> TeamLayout:
	var current: Dictionary = {}
	for player: PlayerState in players:
		current[player.player_id] = player.fixed_area if player.is_fixed() else player.base_area
	return TeamLayout.new(players, current)


## HOME が保持する攻守ターン。どちらもカウンター型、AWAY の守備方式は away_defense
func _open_state(home_spec: Array, away_spec: Array, ball_key: String, away_defense: GameEnums.DefenseStyle = ZONE) -> MatchState:
	var state := MatchState.new()
	state.possession = HOME
	state.ball_area = _area(ball_key)
	state.home_setup = TeamSetup.new("x", TeamStyles.new(ZONE, GameEnums.AttackStyle.COUNTER))
	state.away_setup = TeamSetup.new("y", TeamStyles.new(away_defense, GameEnums.AttackStyle.COUNTER))
	state.home_players = _players(home_spec)
	state.away_players = _players(away_spec)
	return state


## HOME が奪取側のトランジション。ボールは HOME から見て D2-C
func _transition_state(home_spec: Array, away_spec: Array, away_defense: GameEnums.DefenseStyle = ZONE) -> MatchState:
	var state: MatchState = _open_state(home_spec, away_spec, "D2-C", away_defense)
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.transition_origin = LayoutPair.new(_layout_of(state.home_players), _layout_of(state.away_players), HOME)
	return state


func _choice(family: GameEnums.ChoiceFamily, action: int, target_key: String = "") -> TurnChoice:
	return TurnChoice.new(family, action, null if target_key == "" else _area(target_key))


## "側 選手 移動元>移動先 理由"
func _describe(movements: Array[Movement]) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in movements:
		result.append("%s %s %s>%s %s" % [GameEnums.TeamSide.keys()[movement.side], movement.player_id,
				movement.from.to_key(), movement.to.to_key(), GameEnums.MovementReason.keys()[movement.reason]])
	return result


func _preview(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[String]:
	return _describe(MovePreview.own_movements(state, side, choice))


## 判定で、相手が選手を動かさない手を選んだときの side の動き。
## 攻守ターンの攻撃側の相手は守備の手を必ず出すので、選べる守備の手の先頭を出させ、自チームの動きだけを比べる
## （守備の手は守備側の選手しか動かさず、ドリブルの選手の選び方に効かない）。
func _judged(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[String]:
	var holder_styles: TeamStyles = state.setup_of(state.possession).styles
	var other_styles: TeamStyles = state.setup_of(MatchState.other(state.possession)).styles
	var output: JudgeOutput
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		var secure := _choice(POS_TRANS, GameEnums.PosTransAction.SECURE)
		var counter_press := _choice(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
		var winner: TurnChoice = choice if side == state.possession else secure
		var loser: TurnChoice = counter_press if side == state.possession else choice
		output = TransitionJudge.judge(state.transition_origin, holder_styles, other_styles, state.ball_area, winner, loser)
	else:
		var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
		var attack: TurnChoice = choice if side == state.possession else _choice(ATTACK, GameEnums.PlayType.SHOT)
		var defense: TurnChoice = choice
		if side == state.possession:
			defense = _first_defense(MoveRules.options_for(state, MatchState.other(side)))
		output = OpenPlayJudge.judge(start, holder_styles, other_styles, state.ball_area, attack, defense)
	var own: Array[Movement] = []
	for movement: Movement in output.movements:
		if movement.side == side:
			own.append(movement)
	return _describe(own)


## 選べる守備の手の先頭（プレスを先に、運ぶ先は一覧の順）
func _first_defense(options: MoveOptions) -> TurnChoice:
	for action: int in GameEnums.DefenseAction.values():
		if options.is_available(DEFENSE, action):
			return TurnChoice.new(DEFENSE, action, options.targets(DEFENSE, action)[0])
	return null


func _assert_matches_judge(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice, expected: Array[String]) -> void:
	assert_array(_preview(state, side, choice)).is_equal(expected)
	assert_array(_judged(state, side, choice)).is_equal(expected)


# --- 守備の手 ---

func test_press_moves_the_neighbor_into_the_restricted_area() -> void:
	# 制限する M2-C（AWAY から見て M1-C）の隣で、守備側がいるのは a1 の D2-C だけ
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]], [["a1", "D2-C", ""], ["a2", "A2-L2", ""]], "M2-C")
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M2-C"), ["AWAY a1 D2-C>M1-C PRESS"])


func test_cover_drops_the_player_behind_the_restricted_area() -> void:
	# 制限する M2-C（AWAY から見て M1-C）にいる a1 が、背後（AWAY から見て D2-C）へ下がる
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]], [["a1", "M1-C", ""], ["a2", "A2-L2", ""]], "M2-C")
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "M2-C"), ["AWAY a1 M1-C>D2-C COVER"])


func test_man_marking_press_includes_the_remark() -> void:
	# マンツーマン。ターン開始で m1 は h2（AWAY から見て D2-C）、m2 は h1（M1-C）につく。
	# A1-L1（AWAY から見て D2-R1）へのプレスで隣の D2-C の m1 が寄せ、空いた h2 のマークに m2 が付け直す
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]],
			[["m1", "D2-C", ""], ["m2", "M1-L1", ""], ["far", "A2-L2", ""]], "M2-C", MAN)
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "A1-L1"),
			["AWAY m1 D2-C>D2-R1 PRESS", "AWAY m2 M1-C>D2-C MARK"])


func test_man_marking_cover_includes_the_remark() -> void:
	# マンツーマン。ターン開始で m1 は h2（AWAY から見て D2-C）に残り、m2 は h1（M1-C）へ付き、余った m3 は D2-C へ1マス
	# （D2-R1）近づく。M2-C のカバーで m2 が背後の D2-C へ下がり、空いた h1 のマークに、D2-R1 の m3 が付け直す（斜めに1マス）
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]],
			[["m1", "D2-C", ""], ["m2", "M1-L1", ""], ["m3", "M1-R2", ""]], "M2-C", MAN)
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "M2-C"),
			["AWAY m2 M1-C>D2-C COVER", "AWAY m3 D2-R1>M1-C MARK"])


# --- 攻撃の手 ---

func test_dribble_moves_only_the_carrier_and_leaves_out_the_opponent_remark() -> void:
	# 相手はマンツーマン。判定では m1 がドリブルについていくが、プレビューは自チームの動きだけ
	var state: MatchState = _open_state([["h1", "M2-C", ""]], [["m1", "M1-L1", ""], ["far", "A2-L2", ""]], "M2-C", MAN)
	_assert_matches_judge(state, HOME, _choice(ATTACK, GameEnums.PlayType.DRIBBLE, "A1-C"), ["HOME h1 M2-C>A1-C DRIBBLE"])


func test_passes_and_shots_move_nobody() -> void:
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]], [["a1", "D2-C", ""], ["a2", "A2-L2", ""]], "M2-C")
	assert_array(_preview(state, HOME, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "A1-C"))).is_empty()
	# シュートはペナルティエリア（A2-C）から（2026-10-25）
	var shot_state: MatchState = _open_state([["h1", "A2-C", ""]], [["a1", "D1-C", ""]], "A2-C")
	assert_array(_preview(shot_state, HOME, _choice(ATTACK, GameEnums.PlayType.SHOT))).is_empty()


func test_an_offside_through_pass_shows_no_run() -> void:
	# 相手の最終ラインは D2-C（攻撃側の視点で A1 = 4）。受け手 h2 は A2-L1（5）でオフサイドの位置。相手が何もしなければ
	# 判定でプレーが止まり、h2 は走り込まないので、プレビューにも走り込みを出さない（2026-10-25）
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A2-L1", ""]], [["a1", "D2-C", ""]], "M2-C")
	_assert_matches_judge(state, HOME, _choice(ATTACK, GameEnums.PlayType.THROUGH_PASS, "A1-C"), [])


func test_through_pass_shows_the_runner_moving_into_the_target() -> void:
	# スルーパス（2026-10-25）は受け手が走り込む。プレビューは判定と同じ受け手の動きを、自チームの分だけ見せる
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-L1", ""]], [["m1", "D2-R1", ""], ["far", "A2-L2", ""]],
			"M2-C", MAN)
	_assert_matches_judge(state, HOME, _choice(ATTACK, GameEnums.PlayType.THROUGH_PASS, "A1-C"), ["HOME h2 A1-L1>A1-C THROUGH_RUN"])


# --- トランジション ---

func test_counter_breaks_out_the_wide_player() -> void:
	# 奪取側 HOME（カウンター型）の h2 が大外 M1-L2 から M2-L2 へ飛び出す
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]], [["a1", "A1-C", ""], ["a2", "M2-C", ""]])
	_assert_matches_judge(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "M2-L2"),
			["HOME h2 M1-L2>M2-L2 COUNTER_BREAKOUT"])


func test_retreat_returns_the_fixed_player_to_the_base_area() -> void:
	# 喪失側 AWAY の a1 は M2-C に固定されていた（基本エリアは M1-C）。リトリートで基本エリアへ戻る
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]], [["a1", "M1-C", "M2-C"], ["a2", "M2-C", ""]])
	_assert_matches_judge(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT), ["AWAY a1 M2-C>M1-C RETREAT_RESET"])


func test_man_marking_retreat_resets_and_marks_in_one_movement_each() -> void:
	# 喪失側 AWAY はマンツーマン。AWAY の1〜4列目にいる奪取側は h2（AWAY から見て M2-R2）だけ。
	# 今いる位置で近い a1（M2-C。距離2）がつき、1マスの M2-R1 まで近づく。余った a2 は D2-C へ（M2-L1 から1マスの M1-C まで）。
	# 動きは直前の位置からの1本ずつ（2026-10-24。1ターン1マス）
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]],
			[["a1", "M1-C", "M2-C"], ["a2", "M2-L1", ""]], MAN)
	_assert_matches_judge(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT),
			["AWAY a1 M2-C>M2-R1 RETREAT_RESET", "AWAY a2 M2-L1>M1-C RETREAT_RESET"])


func test_secure_and_counter_press_move_nobody() -> void:
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]], [["a1", "M1-C", "M2-C"], ["a2", "M2-C", ""]])
	assert_array(_preview(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.SECURE))).is_empty()
	assert_array(_preview(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS))).is_empty()


# --- 入力 ---

func test_preview_does_not_modify_the_state() -> void:
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]], [["a1", "M1-C", "M2-C"], ["a2", "M2-C", ""]])
	MovePreview.own_movements(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT))
	MovePreview.own_movements(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "M2-L2"))
	assert_str(state.away_players[0].fixed_area.to_key()).is_equal("M2-C")
	assert_str(state.transition_origin.defender.current_area_of("a1").to_key()).is_equal("M2-C")
	assert_str(state.transition_origin.attacker.current_area_of("h2").to_key()).is_equal("M1-L2")
	var open: MatchState = _open_state([["h1", "M2-C", ""]], [["a1", "D2-C", ""]], "M2-C")
	MovePreview.own_movements(open, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M2-C"))
	MovePreview.own_movements(open, HOME, _choice(ATTACK, GameEnums.PlayType.DRIBBLE, "A1-C"))
	assert_object(open.away_players[0].fixed_area).is_null()
	assert_object(open.home_players[0].fixed_area).is_null()


func test_an_inapplicable_defense_returns_no_movements() -> void:
	# A2-C（AWAY から見て D1-C。ゴール前の1列目）のカバーは背後が盤外で適用できない
	var state: MatchState = _open_state([["h1", "M2-C", ""]], [["a1", "D1-C", ""]], "M2-C")
	assert_array(_preview(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "A2-C"))).is_empty()


# --- 相手が何もしないときの3つの配置（team_steps。2026-11-05） ---

## 配置の選手 ID → エリアのキー
func _areas(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


func _home_areas(pair: LayoutPair) -> Dictionary:
	return _areas(pair.attacker if pair.attacker_side == HOME else pair.defender)


## 1拍で見せる（2026-11-06。シャビ「2拍で動くのいらない」）ので、判定時の配置は入れず、ターン開始時と次のターン開始時の2つ
func test_a_pass_shows_the_turn_start_and_the_next_turn_start_after_it_goes_through() -> void:
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""], ["h3", "D2-L2", ""]],
			[["a1", "D2-C", ""], ["a2", "A2-L2", ""]], "M2-C")
	var pass_choice := _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "A1-C")
	var steps: Array[LayoutPair] = MovePreview.team_steps(state, HOME, pass_choice)
	assert_int(steps.size()).is_equal(2)
	var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
	assert_dict(_home_areas(steps[0])).is_equal(_home_areas(start))
	# 次のターン開始時は、パスが通った（前進。ボールは A1-C、HOME の保持のまま）後の詰め直し
	var judged: LayoutPair = OpenPlayJudge.apply_attack(start, state.setup_of(AWAY).styles, state.ball_area, pass_choice).pair
	var next: MatchState = MatchRules.preview_next(state, JudgeOutput.new(GameEnums.TurnOutcome.ADVANCE, null, judged,
			[] as Array[Movement]), pass_choice)
	assert_str(next.ball_area.to_key()).is_equal("A1-C")
	assert_int(next.possession).is_equal(HOME)
	assert_dict(_home_areas(steps[1])).is_equal(_home_areas(StyleLayoutCalculator.turn_start(next).pair))


func test_a_shot_or_an_offside_pass_shows_no_reshape() -> void:
	# シュートは決まるかで置き直しが変わるので、判定時まで（2つ）
	var shot_state: MatchState = _open_state([["h1", "A2-C", ""]], [["a1", "D1-C", ""]], "A2-C")
	assert_int(MovePreview.team_steps(shot_state, HOME, _choice(ATTACK, GameEnums.PlayType.SHOT)).size()).is_equal(2)
	# オフサイドのパスはプレーが止まるので、ターン開始時だけ（1つ）。受け手 h2 は A2-L1 でオフサイドの位置
	var offside_state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A2-L1", ""]], [["a1", "D2-C", ""]], "M2-C")
	var through := _choice(ATTACK, GameEnums.PlayType.THROUGH_PASS, "A1-C")
	assert_int(MovePreview.team_steps(offside_state, HOME, through).size()).is_equal(1)


func test_a_defense_shows_the_next_turn_start_with_the_ball_where_it_is() -> void:
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]], [["a1", "D2-C", ""], ["a2", "A2-L2", ""]], "M2-C")
	var press := _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M2-C")
	var steps: Array[LayoutPair] = MovePreview.team_steps(state, AWAY, press)
	assert_int(steps.size()).is_equal(2)
	# プレスで寄せた a1 は固定され、膠着（ボールは M2-C のまま）の次のターン開始時もそこにいる
	var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
	var defended: LayoutStep = OpenPlayJudge.apply_defense(start, state.setup_of(AWAY).styles, press)
	var next: MatchState = MatchRules.preview_next(state, JudgeOutput.new(GameEnums.TurnOutcome.STALL, null, defended.pair,
			defended.movements), _choice(ATTACK, GameEnums.PlayType.SHORT_PASS))
	assert_dict(_areas(steps[1].defender)).is_equal(_areas(StyleLayoutCalculator.turn_start(next).pair.defender))
	assert_str(_areas(steps[1].defender)["a1"] as String).is_equal("M1-C")


func test_a_transition_shows_the_next_turn_start_against_a_side_that_does_not_move() -> void:
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M1-R1", ""]], [["a1", "M2-C", ""]])
	var steps: Array[LayoutPair] = MovePreview.team_steps(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "M2-R1"))
	assert_int(steps.size()).is_equal(2)


func test_an_offside_counter_shows_only_the_turn_start() -> void:
	# 喪失側の最終ラインは a1 の M2-C（HOME から見て M1-C = 2）。M2-C の h2 へのカウンターはオフサイドでプレーが止まる（2026-11-06）
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M2-C", ""]], [["a1", "M2-C", ""]])
	var counter := _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "M2-C")
	assert_int(MovePreview.team_steps(state, HOME, counter).size()).is_equal(1)


func test_preview_next_builds_the_same_next_state_as_resolving_the_turn() -> void:
	# 本物の試合のキックオフで、選べる最初の攻撃の手と守備の手でターンを解決し、その判定の結果から preview_next が
	# 同じ次の状態（ボール・保持・両チームの選手のエリア）を作ることを確かめる（試合の進め方を二重に持たない）
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var state: MatchState = MatchRules.create_match("p", TeamSetup.new("4-4-2", TeamStyles.new(ZONE, GameEnums.AttackStyle.POSSESSION)),
			TeamSetup.new("4-4-2", TeamStyles.new(MAN, GameEnums.AttackStyle.COUNTER)), HOME, catalog, "")
	var attack_options: MoveOptions = MoveRules.options_for(state, HOME)
	var attack := TurnChoice.new(ATTACK, GameEnums.PlayType.SHORT_PASS,
			attack_options.targets(ATTACK, GameEnums.PlayType.SHORT_PASS)[0])
	var defense: TurnChoice = _first_defense(MoveRules.options_for(state, AWAY))
	var resolution: TurnResolution = MatchRules.resolve_turn(state, attack, defense, MatchRuleConfig.new())
	var record: TurnRecord = resolution.record
	var output := JudgeOutput.new(record.outcome, record.judge, record.pair_at_judgement, [] as Array[Movement])
	var next: MatchState = MatchRules.preview_next(state, output, attack)
	assert_str(next.ball_area.to_key()).is_equal(resolution.next_state.ball_area.to_key())
	assert_int(next.possession).is_equal(resolution.next_state.possession)
	for side: GameEnums.TeamSide in [HOME, AWAY]:
		var expected: Dictionary = {}
		var actual: Dictionary = {}
		for player: PlayerState in resolution.next_state.players_of(side):
			expected[player.player_id] = player.base_area.to_key() + "/" + (player.fixed_area.to_key() if player.is_fixed() else "")
		for player: PlayerState in next.players_of(side):
			actual[player.player_id] = player.base_area.to_key() + "/" + (player.fixed_area.to_key() if player.is_fixed() else "")
		assert_dict(actual).override_failure_message(str(side)).is_equal(expected)

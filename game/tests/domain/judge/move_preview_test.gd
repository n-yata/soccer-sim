## 決定前のプレビュー（MovePreview）のテスト。
## 期待値はアルゴリズム4〜6の規則から手で書き、あわせて、判定（OpenPlayJudge.judge・TransitionJudge.judge）で
## 相手が選手を動かさない手を選んだときの自チームの動きと一致することを確かめる。
## 運ぶ先は判定時の攻撃側（奪取側）の視点、選手のエリアと動きは各チーム自身の視点（component-design.md §1.2）。
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


## HOME が奪取側のトランジション。ボールは HOME から見て D-C
func _transition_state(home_spec: Array, away_spec: Array, away_defense: GameEnums.DefenseStyle = ZONE) -> MatchState:
	var state: MatchState = _open_state(home_spec, away_spec, "D-C", away_defense)
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
	# 制限する M-C（AWAY から見ても M-C）の隣で、守備側がいるのは a1 の D-C だけ
	var state: MatchState = _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]], [["a1", "D-C", ""], ["a2", "A-L2", ""]], "M-C")
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M-C"), ["AWAY a1 D-C>M-C PRESS"])


func test_cover_drops_the_player_behind_the_restricted_area() -> void:
	# 制限する M-C にいる a1 が、背後（AWAY から見て D-C）へ下がる
	var state: MatchState = _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]], [["a1", "M-C", ""], ["a2", "A-L2", ""]], "M-C")
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "M-C"), ["AWAY a1 M-C>D-C COVER"])


func test_man_marking_press_includes_the_remark() -> void:
	# マンツーマン。ターン開始で m1 は h2（AWAY から見て D-C）、m2 は h1（M-C）につく。
	# A-L1（AWAY から見て D-R1）へのプレスで隣の D-C の m1 が寄せ、空いた h2 のマークに m2 が付け直す
	var state: MatchState = _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]],
			[["m1", "D-C", ""], ["m2", "M-L1", ""], ["far", "A-L2", ""]], "M-C", MAN)
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "A-L1"),
			["AWAY m1 D-C>D-R1 PRESS", "AWAY m2 M-C>D-C MARK"])


func test_man_marking_cover_includes_the_remark() -> void:
	# マンツーマン。ターン開始で m1 は h2（AWAY から見て D-C）に残り、m2 は h1（M-C）へ付き、余った m3 は D-C へ1マス（D-R1）近づく。
	# M-C のカバーで m2 が背後の D-C へ下がり、空いた h1 のマークに、D-R1 の m3 が付け直す（斜めに1マス）
	var state: MatchState = _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]],
			[["m1", "D-C", ""], ["m2", "M-L1", ""], ["m3", "M-R2", ""]], "M-C", MAN)
	_assert_matches_judge(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "M-C"),
			["AWAY m2 M-C>D-C COVER", "AWAY m3 D-R1>M-C MARK"])


# --- 攻撃の手 ---

func test_dribble_moves_only_the_carrier_and_leaves_out_the_opponent_remark() -> void:
	# 相手はマンツーマン。判定では m1 がドリブルについていくが、プレビューは自チームの動きだけ
	var state: MatchState = _open_state([["h1", "M-C", ""]], [["m1", "M-L1", ""], ["far", "A-L2", ""]], "M-C", MAN)
	_assert_matches_judge(state, HOME, _choice(ATTACK, GameEnums.PlayType.DRIBBLE, "A-C"), ["HOME h1 M-C>A-C DRIBBLE"])


func test_passes_and_shots_move_nobody() -> void:
	var state: MatchState = _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]], [["a1", "D-C", ""], ["a2", "A-L2", ""]], "M-C")
	assert_array(_preview(state, HOME, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "A-C"))).is_empty()
	var shot_state: MatchState = _open_state([["h1", "A-C", ""]], [["a1", "D-C", ""]], "A-C")
	assert_array(_preview(shot_state, HOME, _choice(ATTACK, GameEnums.PlayType.SHOT))).is_empty()


# --- トランジション ---

func test_counter_breaks_out_the_wide_player() -> void:
	# 奪取側 HOME（カウンター型）の h2 が大外 M-L2 から A-L2 へ飛び出す
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "A-C", ""], ["a2", "M-C", ""]])
	_assert_matches_judge(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "A-L2"),
			["HOME h2 M-L2>A-L2 COUNTER_BREAKOUT"])


func test_retreat_returns_the_fixed_player_to_the_base_area() -> void:
	# 喪失側 AWAY の a1 は M-C に固定されていた（基本エリアは D-C）。リトリートで基本エリアへ戻る
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "D-C", "M-C"], ["a2", "M-C", ""]])
	_assert_matches_judge(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT), ["AWAY a1 M-C>D-C RETREAT_RESET"])


func test_man_marking_retreat_resets_and_marks_in_one_movement_each() -> void:
	# 喪失側 AWAY はマンツーマン。自陣・中盤にいる奪取側は h2（AWAY から見て M-R2）だけ。
	# 今いる位置で近い a1（M-C。距離2）がつき、1マスの M-R1 まで近づく。余った a2 は D-C へ（M-L1 から斜めに1マス）。
	# 動きは直前の位置からの1本ずつ（2026-10-24。1ターン1マス）
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]],
			[["a1", "D-C", "M-C"], ["a2", "M-L1", ""]], MAN)
	_assert_matches_judge(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT),
			["AWAY a1 M-C>M-R1 RETREAT_RESET", "AWAY a2 M-L1>D-C RETREAT_RESET"])


func test_secure_and_counter_press_move_nobody() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "D-C", "M-C"], ["a2", "M-C", ""]])
	assert_array(_preview(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.SECURE))).is_empty()
	assert_array(_preview(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS))).is_empty()


# --- 入力 ---

func test_preview_does_not_modify_the_state() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "D-C", "M-C"], ["a2", "M-C", ""]])
	MovePreview.own_movements(state, AWAY, _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT))
	MovePreview.own_movements(state, HOME, _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, "A-L2"))
	assert_str(state.away_players[0].fixed_area.to_key()).is_equal("M-C")
	assert_str(state.transition_origin.defender.current_area_of("a1").to_key()).is_equal("M-C")
	assert_str(state.transition_origin.attacker.current_area_of("h2").to_key()).is_equal("M-L2")
	var open: MatchState = _open_state([["h1", "M-C", ""]], [["a1", "D-C", ""]], "M-C")
	MovePreview.own_movements(open, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M-C"))
	MovePreview.own_movements(open, HOME, _choice(ATTACK, GameEnums.PlayType.DRIBBLE, "A-C"))
	assert_object(open.away_players[0].fixed_area).is_null()
	assert_object(open.home_players[0].fixed_area).is_null()


func test_an_inapplicable_defense_returns_no_movements() -> void:
	# A-C（AWAY から見て D-C）のカバーは背後が盤外で適用できない
	var state: MatchState = _open_state([["h1", "M-C", ""]], [["a1", "D-C", ""]], "M-C")
	assert_array(_preview(state, AWAY, _choice(DEFENSE, GameEnums.DefenseAction.COVER, "A-C"))).is_empty()

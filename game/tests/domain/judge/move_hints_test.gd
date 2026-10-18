## ヒント（FR-19）・CPU の評価値の材料（MoveHints）のテスト。
## 期待値は functional-overview.md アルゴリズム3〜6・8の規則から手で書いた。運ぶ先は判定時の攻撃側の視点、
## 選手のエリアは各チーム自身の視点（component-design.md §1.2）。
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


## HOME が保持する攻守ターン。どちらもカウンター型、守備方式は away_defense
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
func _transition_state(home_spec: Array, away_spec: Array) -> MatchState:
	var state: MatchState = _open_state(home_spec, away_spec, "D-C")
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.transition_origin = LayoutPair.new(_layout_of(state.home_players), _layout_of(state.away_players), HOME)
	return state


func _hints(state: MatchState, side: GameEnums.TeamSide) -> Array[ChoiceHint]:
	return MoveHints.evaluate(state, side, MoveRules.options_for(state, side))


## "手の名前 運ぶ先 自分-相手 カバー"（比べない手は "手の名前 -"）
func _describe(hint: ChoiceHint) -> String:
	var names: Array = [GameEnums.PlayType.keys(), GameEnums.DefenseAction.keys(),
			GameEnums.NegTransAction.keys(), GameEnums.PosTransAction.keys()][hint.family]
	var target: String = "-" if hint.target == null else hint.target.to_key()
	if not hint.is_compared:
		return "%s %s" % [names[hint.action], target]
	return "%s %s %d-%d %s" % [names[hint.action], target, hint.own_count, hint.opponent_count,
			GameEnums.CoverKind.keys()[hint.cover]]


func _describe_all(hints: Array[ChoiceHint]) -> Array[String]:
	var result: Array[String] = []
	for hint: ChoiceHint in hints:
		result.append(_describe(hint))
	return result


## 攻守ターンの共通の場面: h1 がボールの M-C、h2 が A-C。相手の a1 は自陣 D-C（HOME から見て A-C）、a2 は A-L2
func _scene() -> MatchState:
	return _open_state([["h1", "M-C", ""], ["h2", "A-C", ""]], [["a1", "D-C", ""], ["a2", "A-L2", ""]], "M-C")


# --- 攻撃の手 ---

func test_attack_hints_count_the_target_after_applying_only_the_attack() -> void:
	assert_array(_describe_all(_hints(_scene(), HOME))).is_equal([
		# パス: A-C は1対1で、敵陣の中央なので GK のカバー
		"SHORT_PASS A-C 1-1 GOALKEEPER",
		# ドリブル: h1 が運ぶ先へ動いた後の人数（A-C は h1 と h2 で2対1）
		"DRIBBLE M-L1 1-0 NONE", "DRIBBLE M-R1 1-0 NONE", "DRIBBLE A-C 2-1 NONE",
	])


func test_shot_hint_compares_the_ball_area_without_a_cover_check() -> void:
	var state: MatchState = _open_state([["h1", "A-C", ""]], [["a1", "D-C", ""], ["a2", "A-L2", ""]], "A-C")
	var shots: Array[String] = []
	for hint: ChoiceHint in _hints(state, HOME):
		if hint.action == GameEnums.PlayType.SHOT:
			shots.append(_describe(hint))
	assert_array(shots).is_equal(["SHOT - 1-1 NONE"])


func test_dribble_hint_lets_the_man_marker_follow() -> void:
	# 相手はマンツーマン。m1 は h1 につく（AWAY から見て M-C）。far は基本エリアが A なのでマーカーにならない
	var state: MatchState = _open_state([["h1", "M-C", ""]], [["m1", "M-L1", ""], ["far", "A-L2", ""]], "M-C", MAN)
	var hints: Array[String] = _describe_all(_hints(state, HOME))
	# A-C へのドリブルにマーカーがついていき、1対1。敵陣の中央なので GK のカバー
	assert_array(hints).contains(["DRIBBLE A-C 1-1 GOALKEEPER"])
	assert_array(hints).not_contains(["DRIBBLE A-C 1-0 NONE"])


# --- 守備の手 ---

func test_defense_hints_count_the_restricted_area_before_applying_the_move() -> void:
	var hints: Array[String] = _describe_all(_hints(_scene(), AWAY))
	# M-C: 守備側（AWAY）0・攻撃側1。守備側から見て 0-1
	assert_array(hints).contains(["PRESS M-C 0-1 NONE"])
	# A-L1（AWAY から見て D-R1）は0対0。敵陣のハーフスペースなので GK のカバー
	assert_array(hints).contains(["PRESS A-L1 0-0 GOALKEEPER"])
	# A-C は守備側1・攻撃側1（隣接に守備側がいないのでプレスは選べず、カバーだけ）
	assert_array(hints).not_contains(["PRESS A-C 1-1 GOALKEEPER"])


# --- トランジション ---

func test_counter_hint_uses_the_layout_after_the_breakout() -> void:
	# 奪取側 HOME（カウンター型）の h2 は M-L2 から A-L2 へ飛び出す。喪失側の a1 は自陣の大外（HOME から見て A-L2）にいない
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "A-C", ""], ["a2", "M-C", ""]])
	assert_array(_describe_all(_hints(state, HOME))).is_equal(["COUNTER A-L2 1-0 NONE", "SECURE -"])


func test_counter_press_hint_totals_around_the_ball_and_retreat_is_not_compared() -> void:
	# X は HOME から見て D-C（AWAY から見て A-C）。周りに AWAY は a1（A-C）と a2（M-C）の2人、HOME は h1 の1人
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "A-C", ""], ["a2", "M-C", ""]])
	assert_array(_describe_all(_hints(state, AWAY))).is_equal(["COUNTER_PRESS - 2-1 NONE", "RETREAT -"])


# --- 判定との一致・選べる手との一致 ---

func test_attack_hint_matches_the_judgement_when_the_defense_does_not_touch_the_target() -> void:
	var state: MatchState = _scene()
	var dribble := TurnChoice.new(ATTACK, GameEnums.PlayType.DRIBBLE, _area("A-C"))
	# 攻撃側の視点の D-R1 へのプレス（AWAY の A-L2 の a2 が A-L1 へ）は A-C に関わらない
	var press := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("D-R1"))
	var output: JudgeOutput = OpenPlayJudge.judge(StyleLayoutCalculator.turn_start(state).pair,
			state.home_setup.styles, state.away_setup.styles, state.ball_area, dribble, press)
	var hint: ChoiceHint = null
	for candidate: ChoiceHint in _hints(state, HOME):
		if candidate.action == GameEnums.PlayType.DRIBBLE and candidate.target.equals(_area("A-C")):
			hint = candidate
	assert_int(hint.own_count).is_equal(output.detail.attacker_count)
	assert_int(hint.opponent_count).is_equal(output.detail.defender_count)
	assert_int(hint.cover).is_equal(output.detail.cover)


func test_counter_hint_matches_the_judgement_against_counter_press() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]], [["a1", "A-C", ""], ["a2", "M-C", ""]])
	var output: JudgeOutput = TransitionJudge.judge(state.transition_origin, state.home_setup.styles,
			state.away_setup.styles, state.ball_area,
			TurnChoice.new(POS_TRANS, GameEnums.PosTransAction.COUNTER, _area("A-L2")),
			TurnChoice.new(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS))
	var hint: ChoiceHint = _hints(state, HOME)[0]
	assert_int(hint.own_count).is_equal(output.detail.attacker_count)
	assert_int(hint.opponent_count).is_equal(output.detail.defender_count)
	assert_int(hint.cover).is_equal(output.detail.cover)


func test_hints_cover_exactly_the_selectable_moves() -> void:
	# 攻守ターンとトランジションの両方で、両チームのヒントが選べる手（運ぶ先を持つ手は運ぶ先ごと）と1対1になる
	var transition: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-L2", ""]],
			[["a1", "A-C", ""], ["a2", "M-C", ""]])
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for state: MatchState in [_scene(), transition]:
		for side: GameEnums.TeamSide in [HOME, AWAY]:
			var options: MoveOptions = MoveRules.options_for(state, side)
			var hints: Array[ChoiceHint] = MoveHints.evaluate(state, side, options)
			var expected: int = 0
			for family: GameEnums.ChoiceFamily in [ATTACK, DEFENSE, NEG_TRANS, POS_TRANS]:
				for action: int in range(action_counts[family]):
					if not options.is_available(family, action):
						continue
					expected += options.targets(family, action).size() if MoveOptions.needs_target(family, action) else 1
			var label: String = "kind %d side %d" % [state.turn_kind, side]
			assert_int(hints.size()).override_failure_message(label).is_equal(expected)
			assert_int(expected).override_failure_message(label).is_greater(0)
			for hint: ChoiceHint in hints:
				assert_bool(MoveRules.is_allowed(options, TurnChoice.new(hint.family, hint.action, hint.target))) \
						.override_failure_message(_describe(hint)).is_true()


func test_evaluate_does_not_modify_the_state() -> void:
	var state: MatchState = _open_state([["h1", "M-C", ""]], [["m1", "M-L1", ""], ["far", "A-L2", ""]], "M-C", MAN)
	_hints(state, HOME)
	_hints(state, AWAY)
	for player: PlayerState in state.home_players + state.away_players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()
	assert_str(state.ball_area.to_key()).is_equal("M-C")

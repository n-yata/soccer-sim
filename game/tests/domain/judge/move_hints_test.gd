## ヒント（FR-19）・CPU の評価値の材料（MoveHints）のテスト。
## 期待値は functional-overview.md アルゴリズム3〜6・8の規則から手で書いた。運ぶ先は判定時の攻撃側の視点、
## 選手のエリアは各チーム自身の視点（component-design.md §1.2）。盤面は6列（2026-10-25）。
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


## HOME が奪取側のトランジション。ボールは HOME から見て D2-C
func _transition_state(home_spec: Array, away_spec: Array) -> MatchState:
	var state: MatchState = _open_state(home_spec, away_spec, "D2-C")
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


## 攻守ターンの共通の場面: h1 がボールの M2-C、h2 が A1-C。相手の a1 は自陣の D2-C（HOME から見て A1-C）、
## a2 は遠くの A2-L2（HOME から見て D1-R2）
func _scene() -> MatchState:
	return _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""]], [["a1", "D2-C", ""], ["a2", "A2-L2", ""]], "M2-C")


## トランジションの共通の場面: 奪取側 HOME（カウンター型）は h1 がボールの D2-C、大外の h2 が M1-L2。
## 喪失側 AWAY は a1 が A1-C（HOME から見て D2-C）、a2 が M2-C（HOME から見て M1-C）
func _transition_scene() -> MatchState:
	return _transition_state([["h1", "D2-C", ""], ["h2", "M1-L2", ""]], [["a1", "A1-C", ""], ["a2", "M2-C", ""]])


# --- 攻撃の手 ---

func test_attack_hints_count_the_target_after_applying_only_the_attack() -> void:
	assert_array(_describe_all(_hints(_scene(), HOME))).is_equal([
		# パス: 2マス以内で味方がいるのは A1-C だけ。1対1で、背後の A2-C も0対0なのでカバーなし
		"SHORT_PASS A1-C 1-1 NONE",
		# ドリブル: h1 が運ぶ先へ動いた後の人数（A1-C は h1 と h2 で2対1）。周り8エリアへ運べる
		"DRIBBLE M1-L1 1-0 NONE", "DRIBBLE M1-C 1-0 NONE", "DRIBBLE M1-R1 1-0 NONE",
		"DRIBBLE M2-L1 1-0 NONE", "DRIBBLE M2-R1 1-0 NONE",
		"DRIBBLE A1-L1 1-0 NONE", "DRIBBLE A1-C 2-1 NONE", "DRIBBLE A1-R1 1-0 NONE",
		# スルーパス: h2 が走り込める1〜2列前・レーン差1以内の6エリア。通るかは読みだけで決まるので、人数を比べない
		"THROUGH_PASS A1-L1", "THROUGH_PASS A1-C", "THROUGH_PASS A1-R1",
		"THROUGH_PASS A2-L1", "THROUGH_PASS A2-C", "THROUGH_PASS A2-R1",
	])


func test_attack_hints_mark_the_targets_offside_on_the_current_line() -> void:
	# 相手の最終ラインは a1 の M1-C（攻撃側の視点で M2 = 3）。A1-C の h2 へのパスと、h2 が走り込むスルーパスは、
	# 今の配置のままならオフサイド。ドリブル・後ろへのパスは対象外（2026-10-25）
	var state: MatchState = _open_state([["h1", "M2-C", ""], ["h2", "A1-C", ""], ["h3", "M1-L1", ""]],
			[["a1", "M1-C", ""]], "M2-C")
	var offside: Array[String] = []
	var onside_kinds: Dictionary = {}
	for hint: ChoiceHint in _hints(state, HOME):
		var name: String = GameEnums.PlayType.keys()[hint.action]
		if hint.is_offside:
			offside.append("%s %s" % [name, hint.target.to_key()])
		else:
			onside_kinds[name] = true
	assert_array(offside).contains(["SHORT_PASS A1-C", "THROUGH_PASS A2-C"])
	assert_bool(onside_kinds.has("DRIBBLE")).is_true()
	assert_array(offside).not_contains(["SHORT_PASS M1-L1"])
	for entry: String in offside:
		assert_bool(entry.begins_with("SHORT_PASS") or entry.begins_with("THROUGH_PASS")).override_failure_message(entry).is_true()


func test_through_pass_hint_marks_the_targets_a_man_marker_follows_into() -> void:
	# 相手はマンツーマン。m1 は h2（A1-L1 = AWAY から見て D2-R1）につく。h2 が A1-C へ走り込むと、相手が何もしなくても
	# m1 がついて入ってくるので、判定は読みに関係なくロスト（2026-10-28）。札で「マーク注意」を出す材料にする
	var spec_home: Array = [["h1", "M2-C", ""], ["h2", "A1-L1", ""]]
	var spec_away: Array = [["m1", "D2-R1", ""], ["m2", "M1-C", ""], ["far", "A2-L2", ""]]
	var marked: Array[String] = []
	for hint: ChoiceHint in _hints(_open_state(spec_home, spec_away, "M2-C", MAN), HOME):
		if hint.is_marked:
			marked.append("%s %s" % [GameEnums.PlayType.keys()[hint.action], hint.target.to_key()])
	assert_array(marked).contains(["THROUGH_PASS A1-C"])
	# 受け手がもう運ぶ先（A1-L1）にいれば走り込まず、マーカーも動かないので、マンツーマンでも注意は出ない
	var through_targets: Array[String] = []
	for hint: ChoiceHint in _hints(_open_state(spec_home, spec_away, "M2-C", MAN), HOME):
		if hint.action == GameEnums.PlayType.THROUGH_PASS:
			through_targets.append(hint.target.to_key())
	assert_array(through_targets).contains(["A1-L1"])
	assert_array(marked).not_contains(["THROUGH_PASS A1-L1"])
	for entry: String in marked:
		assert_bool(entry.begins_with("THROUGH_PASS")).override_failure_message(entry).is_true()
	# ゾーンなら誰もついてこないので、同じ配置でも注意は出ない
	for hint: ChoiceHint in _hints(_open_state(spec_home, spec_away, "M2-C", ZONE), HOME):
		assert_bool(hint.is_marked).override_failure_message(_describe(hint)).is_false()


func test_shot_hint_compares_the_ball_area_without_a_cover_check() -> void:
	var state: MatchState = _open_state([["h1", "A2-C", ""]], [["a1", "D1-C", ""], ["a2", "A2-L2", ""]], "A2-C")
	var shots: Array[String] = []
	for hint: ChoiceHint in _hints(state, HOME):
		if hint.action == GameEnums.PlayType.SHOT:
			shots.append(_describe(hint))
	assert_array(shots).is_equal(["SHOT - 1-1 NONE"])


func test_dribble_hint_lets_the_man_marker_follow() -> void:
	# 相手はマンツーマン。m1 は h1 につく（AWAY から見て M1-C）。far は基本エリアが6列目なのでマーカーにならない
	var state: MatchState = _open_state([["h1", "M2-C", ""]], [["m1", "M1-L1", ""], ["far", "A2-L2", ""]], "M2-C", MAN)
	var hints: Array[String] = _describe_all(_hints(state, HOME))
	# A1-C へのドリブルにマーカーがついていき、1対1。背後の A2-C は0対0でカバーなし
	assert_array(hints).contains(["DRIBBLE A1-C 1-1 NONE"])
	assert_array(hints).not_contains(["DRIBBLE A1-C 1-0 NONE"])


# --- 守備の手 ---

func test_defense_hints_count_the_restricted_area_before_applying_the_move() -> void:
	var hints: Array[String] = _describe_all(_hints(_scene(), AWAY))
	# M2-C: 守備側（AWAY）0・攻撃側1。守備側から見て 0-1
	assert_array(hints).contains(["PRESS M2-C 0-1 NONE"])
	# A1-L1（AWAY から見て D2-R1）は0対0。背後（攻撃側の視点の A2-L1）も0対0でカバーなし
	assert_array(hints).contains(["PRESS A1-L1 0-0 NONE"])
	# A1-C は守備側1・攻撃側1（隣に守備側がいないのでプレスは選べず、カバーだけ）
	assert_array(hints).not_contains(["PRESS A1-C 1-1 NONE"])


# --- トランジション ---

func test_counter_hint_uses_the_layout_after_the_breakout() -> void:
	# 奪取側 HOME（カウンター型）の h2 は M1-L2 から M2-L2 へ飛び出す。喪失側は HOME から見て M2-L2（自陣の M1-R2）にいない
	assert_array(_describe_all(_hints(_transition_scene(), HOME))).is_equal(["COUNTER M2-L2 1-0 NONE", "SECURE -"])


func test_a_carried_counter_hint_counts_the_ball_winner_at_the_target() -> void:
	# 奪取側 HOME は D2-C（ボール）の h1 だけで、前に味方がいない。自分で運ぶ先は M1-L1・M1-C・M1-R1（2026-11-05）。
	# 喪失側の a1 は AWAY から見て M2-C（HOME から見て M1-C）。運んだ後の人数で数えるので、M1-C は 1対1、ほかは 1対0
	var state: MatchState = _transition_state([["h1", "D2-C", ""]], [["a1", "M2-C", ""]])
	assert_array(_describe_all(_hints(state, HOME))).is_equal(
			["COUNTER M1-L1 1-0 NONE", "COUNTER M1-C 1-1 NONE", "COUNTER M1-R1 1-0 NONE", "SECURE -"])


func test_counter_hint_marks_a_pass_to_a_receiver_beyond_the_line_offside() -> void:
	# ボールは HOME から見て D2-C。喪失側の最終ラインは a1 の M2-C（HOME から見て M1-C = 2）。M2-C の h2 はラインより前で、
	# M1-L1 の h3 はラインと同じ列（2026-11-06。カウンターにもオフサイドを入れた）
	var state: MatchState = _transition_state([["h1", "D2-C", ""], ["h2", "M2-C", ""], ["h3", "M1-L1", ""]],
			[["a1", "M2-C", ""]])
	var offside: Array[String] = []
	for hint: ChoiceHint in _hints(state, HOME):
		if hint.is_offside:
			offside.append(hint.target.to_key())
	assert_array(offside).is_equal(["M2-C"])


func test_counter_press_hint_totals_around_the_ball_and_retreat_is_not_compared() -> void:
	# X は HOME から見て D2-C（AWAY から見て A1-C）。周りに AWAY は a1（A1-C）と a2（M2-C）の2人、HOME は h1 の1人
	assert_array(_describe_all(_hints(_transition_scene(), AWAY))).is_equal(["COUNTER_PRESS - 2-1 NONE", "RETREAT -"])


# --- 判定との一致・選べる手との一致 ---

func test_attack_hint_matches_the_judgement_when_the_defense_does_not_touch_the_target() -> void:
	var state: MatchState = _scene()
	var dribble := TurnChoice.new(ATTACK, GameEnums.PlayType.DRIBBLE, _area("A1-C"))
	# 攻撃側の視点の D1-R1 へのプレス（AWAY の A2-L2 の a2 が A2-L1 へ）は A1-C に関わらない
	var press := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("D1-R1"))
	var output: JudgeOutput = OpenPlayJudge.judge(StyleLayoutCalculator.turn_start(state).pair,
			state.home_setup.styles, state.away_setup.styles, state.ball_area, dribble, press)
	var hint: ChoiceHint = null
	for candidate: ChoiceHint in _hints(state, HOME):
		if candidate.action == GameEnums.PlayType.DRIBBLE and candidate.target.equals(_area("A1-C")):
			hint = candidate
	assert_int(hint.own_count).is_equal(output.detail.attacker_count)
	assert_int(hint.opponent_count).is_equal(output.detail.defender_count)
	assert_int(hint.cover).is_equal(output.detail.cover)


func test_counter_hint_matches_the_judgement_against_counter_press() -> void:
	var state: MatchState = _transition_scene()
	var output: JudgeOutput = TransitionJudge.judge(state.transition_origin, state.home_setup.styles,
			state.away_setup.styles, state.ball_area,
			TurnChoice.new(POS_TRANS, GameEnums.PosTransAction.COUNTER, _area("M2-L2")),
			TurnChoice.new(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS))
	var hint: ChoiceHint = _hints(state, HOME)[0]
	assert_int(hint.own_count).is_equal(output.detail.attacker_count)
	assert_int(hint.opponent_count).is_equal(output.detail.defender_count)
	assert_int(hint.cover).is_equal(output.detail.cover)


func test_hints_cover_exactly_the_selectable_moves() -> void:
	# 攻守ターンとトランジションの両方で、両チームのヒントが選べる手（運ぶ先を持つ手は運ぶ先ごと）と1対1になる
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for state: MatchState in [_scene(), _transition_scene()]:
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
	var state: MatchState = _open_state([["h1", "M2-C", ""]], [["m1", "M1-L1", ""], ["far", "A2-L2", ""]], "M2-C", MAN)
	_hints(state, HOME)
	_hints(state, AWAY)
	for player: PlayerState in state.home_players + state.away_players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()
	assert_str(state.ball_area.to_key()).is_equal("M2-C")

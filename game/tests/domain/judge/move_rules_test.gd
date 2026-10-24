## アルゴリズム3: 選択可能な手（MoveRules）のテスト。
## 期待値は functional-overview.md アルゴリズム3の表から手で書いた。運ぶ先は PitchArea.all() の順
## （D→M→A、ゾーン内は L2→R2）。攻撃側の配置とボール位置は攻撃側から見た座標、守備側の配置は守備側から見た座標。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS
const SHORT_PASS := GameEnums.PlayType.SHORT_PASS
const DRIBBLE := GameEnums.PlayType.DRIBBLE
const LONG_BEHIND := GameEnums.PlayType.LONG_BEHIND
const SWITCH := GameEnums.PlayType.SWITCH
const SHOT := GameEnums.PlayType.SHOT
const PRESS := GameEnums.DefenseAction.PRESS
const COVER := GameEnums.DefenseAction.COVER


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## エリアのキーの並びから、1エリア1人の配置を作る（選手 ID は p0, p1, ...）
func _team(keys: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	for index: int in range(keys.size()):
		players.append(PlayerState.new("p%d" % index, _area(keys[index] as String)))
	return TeamLayout.at_base(players)


func _pair(attacker_keys: Array, defender_keys: Array) -> LayoutPair:
	return LayoutPair.new(_team(attacker_keys), _team(defender_keys), GameEnums.TeamSide.HOME)


func _keys(areas: Array[PitchArea]) -> Array[String]:
	var result: Array[String] = []
	for area: PitchArea in areas:
		result.append(area.to_key())
	return result


func _attack_targets(attacker_keys: Array, ball_key: String, play: GameEnums.PlayType) -> Array[String]:
	var options: MoveOptions = MoveRules.attack_options(_pair(attacker_keys, []), _area(ball_key))
	return _keys(options.targets(ATTACK, play))


# --- 攻撃の手 ---

func test_short_pass_goes_to_neighbors8_with_a_teammate() -> void:
	# M-R2 はレーンが2つ離れ、隣接ではない
	var targets: Array[String] = _attack_targets(["M-C", "M-L1", "A-R1", "D-C", "M-R2", "A-C"], "M-C", SHORT_PASS)
	assert_array(targets).is_equal(["D-C", "M-L1", "A-C", "A-R1"])


func test_short_pass_from_a_corner_stays_on_the_board() -> void:
	var targets: Array[String] = _attack_targets(["D-L2", "D-L1", "M-L2", "M-L1", "A-L2"], "D-L2", SHORT_PASS)
	assert_array(targets).is_equal(["D-L1", "M-L2", "M-L1"])


func test_short_pass_is_unavailable_without_teammates_nearby() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["M-C", "A-L2"], []), _area("M-C"))
	assert_bool(options.is_available(ATTACK, SHORT_PASS)).is_false()


func test_dribble_goes_to_any_of_the_eight_neighbors_without_teammates() -> void:
	# 2026-10-24: 前・横だけでなく、斜めと後ろへも運べる（周り8エリア）。並びは PitchArea.all() の順（D→M→A）
	assert_array(_attack_targets(["M-C"], "M-C", DRIBBLE)) \
			.is_equal(["D-L1", "D-C", "D-R1", "M-L1", "M-R1", "A-L1", "A-C", "A-R1"])


func test_dribble_never_goes_off_the_board() -> void:
	# 隅では盤面の中の隣だけ（敵陣の大外は3つ、自陣の大外は3つ）
	assert_array(_attack_targets(["A-L2"], "A-L2", DRIBBLE)).is_equal(["M-L2", "M-L1", "A-L1"])
	assert_array(_attack_targets(["D-R2"], "D-R2", DRIBBLE)).is_equal(["D-R1", "M-R1", "M-R2"])


func test_long_behind_from_d_reaches_a_zone_within_one_lane() -> void:
	# A-R1 はレーンが2つ離れる。M-L1 は A ゾーンではない
	var targets: Array[String] = _attack_targets(
			["D-L1", "A-L2", "A-L1", "A-C", "A-R1", "M-L1"], "D-L1", LONG_BEHIND)
	assert_array(targets).is_equal(["A-L2", "A-L1", "A-C"])


func test_long_behind_is_unavailable_outside_d_zone() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["M-C", "A-C"], []), _area("M-C"))
	assert_bool(options.is_available(ATTACK, LONG_BEHIND)).is_false()


func test_switch_needs_three_or_more_lanes_in_the_same_zone() -> void:
	# M-C はレーンが2つ、A-R2 はゾーンが違う
	assert_array(_attack_targets(["M-L2", "M-R1", "M-R2", "M-C", "A-R2"], "M-L2", SWITCH)) \
			.is_equal(["M-R1", "M-R2"])
	assert_array(_attack_targets(["M-L1", "M-R1", "M-R2"], "M-L1", SWITCH)).is_equal(["M-R2"])


func test_switch_from_the_center_lane_is_unavailable() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["M-C", "M-L2", "M-R2"], []), _area("M-C"))
	assert_bool(options.is_available(ATTACK, SWITCH)).is_false()


func test_shot_is_available_only_from_a_zone_center_or_half_spaces() -> void:
	for key: String in ["A-C", "A-L1", "A-R1"]:
		var options: MoveOptions = MoveRules.attack_options(_pair([key], []), _area(key))
		assert_bool(options.is_available(ATTACK, SHOT)).override_failure_message(key).is_true()
	for key: String in ["A-L2", "A-R2", "M-C", "D-C"]:
		var options: MoveOptions = MoveRules.attack_options(_pair([key], []), _area(key))
		assert_bool(options.is_available(ATTACK, SHOT)).override_failure_message(key).is_false()


# --- 守備の手（運ぶ先は攻撃側の視点） ---

func test_press_needs_a_defender_next_to_the_restricted_area() -> void:
	# 守備側から見て D-C に1人。隣接の D-L1・D-R1・M-C を制限できる。攻撃側の視点では A-R1・A-L1・M-C
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["D-C"]))
	assert_array(_keys(options.targets(DEFENSE, PRESS))).is_equal(["M-C", "A-L1", "A-R1"])


func test_cover_excludes_the_defender_d_zone_and_counts_the_area_itself() -> void:
	# D-C の1人: 自陣の D-L1・D-R1・D-C は除かれ、M-C だけ
	var near_goal: MoveOptions = MoveRules.defense_options(_pair([], ["D-C"]))
	assert_array(_keys(near_goal.targets(DEFENSE, COVER))).is_equal(["M-C"])
	# M-L2 の1人: その場の M-L2 と、隣接の M-L1・A-L2（D-L2 は自陣）。攻撃側の視点では M-R2・M-R1・D-R2
	var wide: MoveOptions = MoveRules.defense_options(_pair([], ["M-L2"]))
	assert_array(_keys(wide.targets(DEFENSE, COVER))).is_equal(["D-R2", "M-R1", "M-R2"])
	# PRESS は隣接だけを見る（その場の M-L2 = 攻撃側の M-R2 は含まない）
	assert_array(_keys(wide.targets(DEFENSE, PRESS))).is_equal(["D-R2", "M-R1", "A-R2"])


func test_cover_needs_a_defender_within_one_area_of_the_area_behind() -> void:
	# 守備側から見て A-C に1人。その場の A-C と横の A-L1・A-R1 は選べるが、M-C は選べない
	# （A-C は M-C の前方で、M-C の背後 D-C まで2ゾーンあるため。1ターン1マス）。攻撃側の視点では D-L1・D-C・D-R1
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["A-C"]))
	assert_array(_keys(options.targets(DEFENSE, COVER))).is_equal(["D-L1", "D-C", "D-R1"])


func test_defense_moves_are_unavailable_without_defenders() -> void:
	var options: MoveOptions = MoveRules.defense_options(_pair(["M-C"], []))
	assert_bool(options.is_available(DEFENSE, PRESS)).is_false()
	assert_bool(options.is_available(DEFENSE, COVER)).is_false()


# --- トランジションの手 ---

func test_losing_side_can_always_counter_press_or_retreat() -> void:
	var options: MoveOptions = MoveRules.neg_transition_options()
	assert_bool(options.is_available(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)).is_true()
	assert_bool(options.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_true()


func test_counter_goes_one_or_two_zones_ahead_where_a_teammate_is() -> void:
	# ボールは D-C。M と A のゾーンで味方がいるところ（同じゾーンの D-C は含まない）
	var winner: TeamLayout = _team(["M-C", "A-L2", "A-R1", "D-C"])
	var options: MoveOptions = MoveRules.pos_transition_options(winner, _area("D-C"))
	assert_array(_keys(options.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))) \
			.is_equal(["M-C", "A-L2", "A-R1"])
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


func test_counter_from_m_zone_reaches_only_a_zone() -> void:
	var winner: TeamLayout = _team(["M-R2", "A-L2", "A-R1"])
	var options: MoveOptions = MoveRules.pos_transition_options(winner, _area("M-L1"))
	assert_array(_keys(options.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))).is_equal(["A-L2", "A-R1"])


func test_counter_from_a_zone_is_unavailable_but_secure_stays() -> void:
	var options: MoveOptions = MoveRules.pos_transition_options(_team(["A-C", "A-L1"]), _area("A-C"))
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.COUNTER)).is_false()
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


# --- options_for（局面から選べる手） ---

func _state(turn_kind: GameEnums.TurnKind) -> MatchState:
	var styles := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var state := MatchState.new()
	state.turn_kind = turn_kind
	state.possession = GameEnums.TeamSide.HOME
	state.ball_area = _area("D-C")
	state.home_setup = TeamSetup.new("x", styles)
	state.away_setup = TeamSetup.new("y", styles.duplicate_deep())
	var home: Array[PlayerState] = [PlayerState.new("h1", _area("D-C")), PlayerState.new("h2", _area("M-L2"))]
	var away: Array[PlayerState] = [PlayerState.new("a1", _area("D-C"))]
	state.home_players = home
	state.away_players = away
	return state


func test_options_for_open_play_gives_attack_to_the_holder_and_defense_to_the_other() -> void:
	var state: MatchState = _state(GameEnums.TurnKind.OPEN_PLAY)
	var holder: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.HOME)
	var other: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.AWAY)
	# ボールは D-C。ドリブルは盤面の中の周り5エリア、パスは隣接8エリアに味方（h2 は M-L2 でレーンが2つ離れる）がいないので選べない
	assert_array(_keys(holder.targets(ATTACK, DRIBBLE))).is_equal(["D-L1", "D-R1", "M-L1", "M-C", "M-R1"])
	assert_bool(holder.is_available(ATTACK, SHORT_PASS)).is_false()
	assert_bool(holder.is_available(ATTACK, LONG_BEHIND)).is_false()
	assert_bool(holder.is_available(DEFENSE, PRESS)).is_false()
	# 守備側の D-C（攻撃側の視点の A-C）の1人の隣接
	assert_array(_keys(other.targets(DEFENSE, PRESS))).is_equal(["M-C", "A-L1", "A-R1"])
	assert_bool(other.is_available(ATTACK, DRIBBLE)).is_false()


func test_options_for_transition_uses_the_counter_layout_for_the_winner() -> void:
	var state: MatchState = _state(GameEnums.TurnKind.TRANSITION)
	# 奪取側 HOME の h2 は M-L2（大外）。カウンター型なので A-L2 へ飛び出してから、運ぶ先を数える
	state.transition_origin = LayoutPair.new(TeamLayout.at_base(state.home_players),
			TeamLayout.at_base(state.away_players), GameEnums.TeamSide.HOME)
	var winner: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.HOME)
	var loser: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.AWAY)
	assert_array(_keys(winner.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))).is_equal(["A-L2"])
	assert_bool(winner.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()
	assert_bool(winner.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_false()
	assert_bool(loser.is_available(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)).is_true()
	assert_bool(loser.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_false()


# --- is_allowed ---

func test_is_allowed_accepts_listed_targets_and_targetless_moves() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A-C", "A-L1"], []), _area("A-C"))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHORT_PASS, _area("A-L1")))).is_true()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHOT))).is_true()


func test_is_allowed_rejects_unlisted_targets_and_unavailable_moves() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A-C", "A-L1"], []), _area("A-C"))
	# 味方のいないエリアへのパス
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHORT_PASS, _area("A-R1")))).is_false()
	# D ゾーン以外からの背後へのロングボール
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, LONG_BEHIND, _area("A-L1")))).is_false()
	# 攻撃の局面で守備の手
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("A-L1")))).is_false()


func test_is_allowed_checks_defense_targets_in_the_attacker_view() -> void:
	# 守備側の D-C に1人。PRESS の運ぶ先は攻撃側の視点で M-C・A-L1・A-R1
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["D-C"]))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("A-L1")))).is_true()
	# 守備側の視点のまま渡した D-R1（攻撃側の視点では A-L1）は一覧に無い
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("D-R1")))).is_false()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS))).is_false()
	# COVER は M-C だけ
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, COVER, _area("M-C")))).is_true()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, COVER, _area("A-L1")))).is_false()


func test_is_allowed_checks_transition_moves() -> void:
	var winner: MoveOptions = MoveRules.pos_transition_options(_team(["M-C"]), _area("D-C"))
	var counter := GameEnums.PosTransAction.COUNTER
	var secure := GameEnums.PosTransAction.SECURE
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, counter, _area("M-C")))).is_true()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, counter, _area("A-C")))).is_false()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, secure))).is_true()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, secure, _area("M-C")))).is_false()
	var loser: MoveOptions = MoveRules.neg_transition_options()
	assert_bool(MoveRules.is_allowed(loser,
			TurnChoice.new(NEG_TRANS, GameEnums.NegTransAction.RETREAT))).is_true()
	# 失った側に奪った側の手
	assert_bool(MoveRules.is_allowed(loser, TurnChoice.new(POS_TRANS, secure))).is_false()


func test_is_allowed_rejects_a_missing_or_unexpected_target() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A-C", "A-L1"], []), _area("A-C"))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, DRIBBLE))).is_false()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHOT, _area("A-C")))).is_false()

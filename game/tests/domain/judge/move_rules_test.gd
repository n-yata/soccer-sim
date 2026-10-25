## アルゴリズム3: 選択可能な手（MoveRules）のテスト。
## 期待値は functional-overview.md アルゴリズム3の表（6列の盤面。2026-10-25）から手で書いた。運ぶ先は PitchArea.all() の順
## （D1→A2、列の中は L2→R2）。攻撃側の配置とボール位置は攻撃側から見た座標、守備側の配置は守備側から見た座標。
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

func test_short_pass_reaches_two_areas_in_any_direction_with_a_teammate() -> void:
	# ボール M1-C から、列差・レーン差がどちらも2以内（斜めを含む）で味方のいるエリア。
	# A2-C は列が3つ離れて届かない。ボールのエリア（M1-C）自体は運ぶ先にしない
	var targets: Array[String] = _attack_targets(
			["M1-C", "M1-L1", "M2-R1", "A1-C", "A1-R2", "A2-C", "M1-R2", "D1-C", "D1-L2"], "M1-C", SHORT_PASS)
	assert_array(targets).is_equal(["D1-L2", "D1-C", "M1-L1", "M1-R2", "M2-R1", "A1-C", "A1-R2"])


func test_short_pass_from_a_corner_stays_within_two_areas() -> void:
	# D1-L2 から: M1-C は列差2・レーン差2でちょうど届く。M2-L2 は列差3、D1-R1 はレーン差3で届かない
	var targets: Array[String] = _attack_targets(
			["D1-L2", "D2-L1", "M1-L1", "M1-C", "M2-L2", "D1-R1"], "D1-L2", SHORT_PASS)
	assert_array(targets).is_equal(["D2-L1", "M1-L1", "M1-C"])


func test_short_pass_is_unavailable_without_teammates_within_reach() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["M1-C", "A2-L2"], []), _area("M1-C"))
	assert_bool(options.is_available(ATTACK, SHORT_PASS)).is_false()


func test_dribble_goes_to_any_of_the_eight_neighbors_without_teammates() -> void:
	# 前・横・斜め・後ろの周り8エリア（2026-10-24）。並びは PitchArea.all() の順
	assert_array(_attack_targets(["M1-C"], "M1-C", DRIBBLE)) \
			.is_equal(["D2-L1", "D2-C", "D2-R1", "M1-L1", "M1-R1", "M2-L1", "M2-C", "M2-R1"])


func test_dribble_never_goes_off_the_board() -> void:
	# 隅では盤面の中の隣だけ（敵陣ゴール前の大外は3つ、自陣ゴール前の大外は3つ）
	assert_array(_attack_targets(["A2-L2"], "A2-L2", DRIBBLE)).is_equal(["A1-L2", "A1-L1", "A2-L1"])
	assert_array(_attack_targets(["D1-R2"], "D1-R2", DRIBBLE)).is_equal(["D1-R1", "D2-R1", "D2-R2"])


func test_long_behind_from_the_own_half_reaches_the_last_two_rows_within_one_lane() -> void:
	# ボールは自陣の3列目（M1-L1）。運ぶ先は5・6列目でレーン差1以内。A2-R1 はレーンが2つ離れ、M2-L1 は4列目
	var targets: Array[String] = _attack_targets(
			["M1-L1", "A1-L2", "A1-L1", "A1-C", "A2-C", "A2-R1", "M2-L1"], "M1-L1", LONG_BEHIND)
	assert_array(targets).is_equal(["A1-L2", "A1-L1", "A1-C", "A2-C"])


func test_long_behind_is_unavailable_from_the_opponents_half() -> void:
	# 4列目（M2。ハーフウェーラインの先）からは出せない
	var options: MoveOptions = MoveRules.attack_options(_pair(["M2-C", "A2-C"], []), _area("M2-C"))
	assert_bool(options.is_available(ATTACK, LONG_BEHIND)).is_false()


func test_switch_needs_three_or_more_lanes_in_the_same_row() -> void:
	# M1-C はレーンが2つ、A1-R2 は列が違う
	assert_array(_attack_targets(["M1-L2", "M1-R1", "M1-R2", "M1-C", "A1-R2"], "M1-L2", SWITCH)) \
			.is_equal(["M1-R1", "M1-R2"])
	assert_array(_attack_targets(["M1-L1", "M1-R1", "M1-R2"], "M1-L1", SWITCH)).is_equal(["M1-R2"])


func test_switch_from_the_center_lane_is_unavailable() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["M1-C", "M1-L2", "M1-R2"], []), _area("M1-C"))
	assert_bool(options.is_available(ATTACK, SWITCH)).is_false()


func test_shot_is_available_only_from_the_last_two_rows_center_or_half_spaces() -> void:
	for key: String in ["A1-C", "A1-L1", "A1-R1", "A2-C", "A2-L1", "A2-R1"]:
		var options: MoveOptions = MoveRules.attack_options(_pair([key], []), _area(key))
		assert_bool(options.is_available(ATTACK, SHOT)).override_failure_message(key).is_true()
	# 大外、4列目（M2）より後ろからは打てない
	for key: String in ["A1-L2", "A2-R2", "M2-C", "D1-C"]:
		var options: MoveOptions = MoveRules.attack_options(_pair([key], []), _area(key))
		assert_bool(options.is_available(ATTACK, SHOT)).override_failure_message(key).is_false()


# --- 守備の手（運ぶ先は攻撃側の視点） ---

func test_press_needs_a_defender_next_to_the_restricted_area() -> void:
	# 守備側から見て D2-C に1人。隣の D1-C・D2-L1・D2-R1・M1-C を制限できる。攻撃側の視点では A2-C・A1-R1・A1-L1・M2-C
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["D2-C"]))
	assert_array(_keys(options.targets(DEFENSE, PRESS))).is_equal(["M2-C", "A1-L1", "A1-R1", "A2-C"])


func test_cover_excludes_the_defenders_first_row_and_counts_the_area_itself() -> void:
	# D1-C の1人: 1列目（ゴール前。背後が無い）の D1-L1・D1-C・D1-R1 は除かれ、背後に D1-C がある D2-C だけ。攻撃側の視点で A1-C
	var near_goal: MoveOptions = MoveRules.defense_options(_pair([], ["D1-C"]))
	assert_array(_keys(near_goal.targets(DEFENSE, COVER))).is_equal(["A1-C"])
	# M1-L2 の1人: その場の M1-L2 と、横の M1-L1、背後に M1-L2 がある M2-L2（前方の D2-L2 は除く）。
	# 攻撃側の視点では M2-R2・M2-R1・M1-R2
	var wide: MoveOptions = MoveRules.defense_options(_pair([], ["M1-L2"]))
	assert_array(_keys(wide.targets(DEFENSE, COVER))).is_equal(["M1-R2", "M2-R1", "M2-R2"])
	# PRESS は隣だけを見る（その場の M1-L2 = 攻撃側の M2-R2 は含まない）。D2-L2・M1-L1・M2-L2 → A1-R2・M2-R1・M1-R2
	assert_array(_keys(wide.targets(DEFENSE, PRESS))).is_equal(["M1-R2", "M2-R1", "A1-R2"])


func test_cover_needs_a_defender_within_one_area_of_the_area_behind() -> void:
	# 守備側から見て A2-C に1人。その場の A2-C と横の A2-L1・A2-R1 は選べるが、A1-C は選べない
	# （A2-C は A1-C の前方で、A1-C の背後 M2-C まで2列あるため。1ターン1マス）。攻撃側の視点では D1-L1・D1-C・D1-R1
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["A2-C"]))
	assert_array(_keys(options.targets(DEFENSE, COVER))).is_equal(["D1-L1", "D1-C", "D1-R1"])


func test_defense_moves_are_unavailable_without_defenders() -> void:
	var options: MoveOptions = MoveRules.defense_options(_pair(["M1-C"], []))
	assert_bool(options.is_available(DEFENSE, PRESS)).is_false()
	assert_bool(options.is_available(DEFENSE, COVER)).is_false()


# --- トランジションの手 ---

func test_losing_side_can_always_counter_press_or_retreat() -> void:
	var options: MoveOptions = MoveRules.neg_transition_options()
	assert_bool(options.is_available(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)).is_true()
	assert_bool(options.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_true()


func test_counter_goes_one_to_four_rows_ahead_where_a_teammate_is() -> void:
	# ボールは D1-C。1〜4列前（D2〜A1）で味方がいるところ。A2-L2 は5列前、同じ列の D1-R2 は含まない
	var winner: TeamLayout = _team(["D1-C", "D2-L1", "M2-C", "A1-R1", "A2-L2", "D1-R2"])
	var options: MoveOptions = MoveRules.pos_transition_options(winner, _area("D1-C"))
	assert_array(_keys(options.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))) \
			.is_equal(["D2-L1", "M2-C", "A1-R1"])
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


func test_counter_from_the_fourth_row_reaches_the_last_two_rows() -> void:
	var winner: TeamLayout = _team(["M2-R2", "A1-L2", "A2-R1"])
	var options: MoveOptions = MoveRules.pos_transition_options(winner, _area("M2-L1"))
	assert_array(_keys(options.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))).is_equal(["A1-L2", "A2-R1"])


func test_counter_from_the_last_row_is_unavailable_but_secure_stays() -> void:
	var options: MoveOptions = MoveRules.pos_transition_options(_team(["A2-C", "A2-L1"]), _area("A2-C"))
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.COUNTER)).is_false()
	assert_bool(options.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


# --- options_for（局面から選べる手） ---

func _state(turn_kind: GameEnums.TurnKind) -> MatchState:
	var styles := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var state := MatchState.new()
	state.turn_kind = turn_kind
	state.possession = GameEnums.TeamSide.HOME
	state.ball_area = _area("D2-C")
	state.home_setup = TeamSetup.new("x", styles)
	state.away_setup = TeamSetup.new("y", styles.duplicate_deep())
	var home: Array[PlayerState] = [PlayerState.new("h1", _area("D2-C")), PlayerState.new("h2", _area("A1-L2"))]
	var away: Array[PlayerState] = [PlayerState.new("a1", _area("D2-C"))]
	state.home_players = home
	state.away_players = away
	return state


func test_options_for_open_play_gives_attack_to_the_holder_and_defense_to_the_other() -> void:
	var state: MatchState = _state(GameEnums.TurnKind.OPEN_PLAY)
	var holder: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.HOME)
	var other: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.AWAY)
	# ボールは D2-C。ドリブルは周り8エリア。h2（A1-L2）は列が3つ離れてパスが届かず、レーン差2でロングボールも出せない
	assert_array(_keys(holder.targets(ATTACK, DRIBBLE))) \
			.is_equal(["D1-L1", "D1-C", "D1-R1", "D2-L1", "D2-R1", "M1-L1", "M1-C", "M1-R1"])
	assert_bool(holder.is_available(ATTACK, SHORT_PASS)).is_false()
	assert_bool(holder.is_available(ATTACK, LONG_BEHIND)).is_false()
	assert_bool(holder.is_available(DEFENSE, PRESS)).is_false()
	# 守備側の D2-C（攻撃側の視点の A1-C）の1人の隣
	assert_array(_keys(other.targets(DEFENSE, PRESS))).is_equal(["M2-C", "A1-L1", "A1-R1", "A2-C"])
	assert_bool(other.is_available(ATTACK, DRIBBLE)).is_false()


func test_options_for_transition_uses_the_counter_layout_for_the_winner() -> void:
	var state: MatchState = _state(GameEnums.TurnKind.TRANSITION)
	# 奪取側 HOME の h2 は A1-L2（大外）。カウンター型なので A2-L2 へ飛び出してから、運ぶ先を数える（ボールから4列前）
	state.transition_origin = LayoutPair.new(TeamLayout.at_base(state.home_players),
			TeamLayout.at_base(state.away_players), GameEnums.TeamSide.HOME)
	var winner: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.HOME)
	var loser: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.AWAY)
	assert_array(_keys(winner.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))).is_equal(["A2-L2"])
	assert_bool(winner.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()
	assert_bool(winner.is_available(NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_false()
	assert_bool(loser.is_available(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)).is_true()
	assert_bool(loser.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_false()


# --- is_allowed ---

func test_is_allowed_accepts_listed_targets_and_targetless_moves() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A1-C", "A1-L1"], []), _area("A1-C"))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHORT_PASS, _area("A1-L1")))).is_true()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHOT))).is_true()


func test_is_allowed_rejects_unlisted_targets_and_unavailable_moves() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A1-C", "A1-L1"], []), _area("A1-C"))
	# 味方のいないエリアへのパス
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHORT_PASS, _area("A1-R1")))).is_false()
	# 自陣の外からの背後へのロングボール
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, LONG_BEHIND, _area("A1-L1")))).is_false()
	# 攻撃の局面で守備の手
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("A1-L1")))).is_false()


func test_is_allowed_checks_defense_targets_in_the_attacker_view() -> void:
	# 守備側の D2-C に1人。PRESS の運ぶ先は攻撃側の視点で M2-C・A1-L1・A1-R1・A2-C
	var options: MoveOptions = MoveRules.defense_options(_pair([], ["D2-C"]))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("A1-L1")))).is_true()
	# 守備側の視点のまま渡した D2-R1（攻撃側の視点では A1-L1）は一覧に無い
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS, _area("D2-R1")))).is_false()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, PRESS))).is_false()
	# COVER は M2-C（背後が D2-C）を選べるが、守備側の1列目（攻撃側の視点の A2-C）は選べない
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, COVER, _area("M2-C")))).is_true()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(DEFENSE, COVER, _area("A2-C")))).is_false()


func test_is_allowed_checks_transition_moves() -> void:
	var winner: MoveOptions = MoveRules.pos_transition_options(_team(["M1-C"]), _area("D2-C"))
	var counter := GameEnums.PosTransAction.COUNTER
	var secure := GameEnums.PosTransAction.SECURE
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, counter, _area("M1-C")))).is_true()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, counter, _area("A1-C")))).is_false()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, secure))).is_true()
	assert_bool(MoveRules.is_allowed(winner, TurnChoice.new(POS_TRANS, secure, _area("M1-C")))).is_false()
	var loser: MoveOptions = MoveRules.neg_transition_options()
	assert_bool(MoveRules.is_allowed(loser,
			TurnChoice.new(NEG_TRANS, GameEnums.NegTransAction.RETREAT))).is_true()
	# 失った側に奪った側の手
	assert_bool(MoveRules.is_allowed(loser, TurnChoice.new(POS_TRANS, secure))).is_false()


func test_is_allowed_rejects_a_missing_or_unexpected_target() -> void:
	var options: MoveOptions = MoveRules.attack_options(_pair(["A1-C", "A1-L1"], []), _area("A1-C"))
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, DRIBBLE))).is_false()
	assert_bool(MoveRules.is_allowed(options, TurnChoice.new(ATTACK, SHOT, _area("A1-C")))).is_false()

## アルゴリズム2: 現在配置の算出（StyleLayoutCalculator）のテスト。
## 期待値は functional-overview.md アルゴリズム2の規則から手で書いた。
## ボール位置は攻撃側から見た座標、各チームの配置はそのチーム自身から見た座標（component-design.md §1.2）。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## spec は [選手 ID, 基本エリア, 固定先（無ければ ""）] の配列。現在エリアは基本エリア。
func _layout(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		var fixed: PitchArea = null if fixed_key == "" else _area(fixed_key)
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String), fixed))
	return TeamLayout.at_base(players)


func _styles(defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamStyles:
	return TeamStyles.new(defense, attack)


## 選手 ID → 現在エリアのキー
func _areas_of(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


## "選手 ID:移動元>移動先:理由" の並び（理由は MovementReason の名前）
func _moves(step: LayoutStep) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in step.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## 守備側の配置（ZONE 用）。左の大外から右の大外まで1人ずつと、敵陣の中央に1人
func _zone_defender() -> TeamLayout:
	return _layout([
		["d1", "D-L2", ""], ["d2", "D-L1", ""], ["d3", "D-C", ""],
		["d4", "M-R1", ""], ["d5", "M-R2", ""], ["d6", "A-C", ""],
	])


## 攻撃方式を COUNTER にした、動かない攻撃側
func _still_attacker() -> TeamLayout:
	return _layout([["a1", "M-C", ""]])


## MAN 用の攻撃側（攻撃側の視点）。守備側から見ると a1 は D-C、a2 は D-R1、a3 は M-L2、a4 は A-C（対象外）
func _man_attacker() -> TeamLayout:
	return _layout([
		["a1", "A-C", ""], ["a2", "A-L1", ""], ["a3", "M-R2", ""], ["a4", "D-C", ""],
	])


## layout の player_id を area_key へ動かして固定した配置（ドリブル・プレスの後の配置を作る）
func _moved(layout: TeamLayout, player_id: String, area_key: String) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for player: PlayerState in layout.players:
		var copied: PlayerState = player.duplicate_deep()
		current[copied.player_id] = layout.current_area_of(copied.player_id)
		if copied.player_id == player_id:
			copied.fixed_area = _area(area_key)
			current[copied.player_id] = _area(area_key)
		players.append(copied)
	return TeamLayout.new(players, current)


func _compute_zone_defense(ball_key: String) -> LayoutStep:
	return StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			_zone_defender(), _styles(ZONE, COUNTER), _area(ball_key), HOME)


# --- reset_segment（手順1） ---

func test_reset_segment_releases_fixes_and_returns_everyone_to_the_base_area() -> void:
	var players: Array[PlayerState] = [
		PlayerState.new("p1", _area("D-C"), _area("M-C")),
		PlayerState.new("p2", _area("M-L2")),
	]
	var layout := TeamLayout.new(players, {"p1": _area("M-C"), "p2": _area("M-L1")})
	var reset: TeamLayout = StyleLayoutCalculator.reset_segment(layout)
	assert_bool(reset.players[0].is_fixed()).is_false()
	assert_dict(_areas_of(reset)).is_equal({"p1": "D-C", "p2": "M-L2"})
	# 入力は書き換えない
	assert_bool(layout.players[0].is_fixed()).is_true()
	assert_dict(_areas_of(layout)).is_equal({"p1": "M-C", "p2": "M-L1"})


# --- 攻撃方式（手順3） ---

func test_possession_moves_only_wide_players_one_zone_forward() -> void:
	var attacker: TeamLayout = _layout([
		["a1", "D-L2", ""], ["a2", "M-R2", ""], ["a3", "A-L2", ""], ["a4", "M-C", ""], ["a5", "D-R1", ""],
	])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), AWAY)
	assert_dict(_areas_of(step.pair.attacker)).is_equal(
			{"a1": "M-L2", "a2": "A-R2", "a3": "A-L2", "a4": "M-C", "a5": "D-R1"})
	assert_array(_moves(step)).is_equal(["a1:D-L2>M-L2:POSSESSION_ADVANCE", "a2:M-R2>A-R2:POSSESSION_ADVANCE"])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)


func test_counter_keeps_base_areas_and_drops_last_turn_style_moves() -> void:
	var players: Array[PlayerState] = [PlayerState.new("a1", _area("M-L2")), PlayerState.new("a2", _area("M-C"))]
	# 前のターンの方式の動きで、現在エリアが基本エリアからずれている
	var attacker := TeamLayout.new(players, {"a1": _area("A-L2"), "a2": _area("A-C")})
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-L2", "a2": "M-C"})
	assert_array(_moves(step)).is_empty()


# --- ZONE（手順4） ---

func test_zone_does_not_slide_when_the_ball_is_in_the_center_lane() -> void:
	var step: LayoutStep = _compute_zone_defense("M-C")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L2", "d2": "D-L1", "d3": "D-C", "d4": "M-R1", "d5": "M-R2", "d6": "A-C"})
	assert_array(_moves(step)).is_empty()


func test_zone_slides_to_the_defender_left_when_the_ball_is_on_the_attacker_right() -> void:
	# 攻撃側から見た A-R1 は、守備側から見た D-L1（左のハーフスペース）
	var step: LayoutStep = _compute_zone_defense("A-R1")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L2", "d2": "D-L2", "d3": "D-L1", "d4": "M-C", "d5": "M-R1", "d6": "A-L1"})
	# ボールサイドの大外に、元の大外とずれてきた選手の2人が集まる
	assert_int(step.pair.defender.count_at(_area("D-L2"))).is_equal(2)
	assert_array(_moves(step)).is_equal([
		"d2:D-L1>D-L2:SLIDE", "d3:D-C>D-L1:SLIDE", "d4:M-R1>M-C:SLIDE", "d5:M-R2>M-R1:SLIDE", "d6:A-C>A-L1:SLIDE",
	])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)


func test_zone_slides_to_the_defender_right_when_the_ball_is_on_the_attacker_left_wing() -> void:
	# 攻撃側から見た M-L2 は、守備側から見た M-R2（右の大外）
	var step: LayoutStep = _compute_zone_defense("M-L2")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L1", "d2": "D-C", "d3": "D-R1", "d4": "M-R2", "d5": "M-R2", "d6": "A-R1"})
	assert_int(step.pair.defender.count_at(_area("M-R2"))).is_equal(2)


func test_zone_slide_follows_the_ball_lane_not_its_zone() -> void:
	# 同じレーンなら、ボールのゾーンが違ってもずれ方は同じ（A-R2 と D-R2 は守備側から見てどちらも左の大外）
	var near: LayoutStep = _compute_zone_defense("A-R2")
	var far: LayoutStep = _compute_zone_defense("D-R2")
	assert_dict(_areas_of(near.pair.defender)).is_equal(_areas_of(far.pair.defender))
	assert_str(near.pair.defender.current_area_of("d3").to_key()).is_equal("D-L1")


# --- MAN（手順4） ---

func test_man_with_spare_markers_sends_the_rest_to_d_c() -> void:
	var defender: TeamLayout = _layout([
		["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""], ["d4", "M-C", ""], ["d5", "A-C", ""],
	])
	var step: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# 対象は D-C・D-R1・M-L2 の3人。マーカー4人のうち1人が余り、D-C へ。基本エリアが A の d5 は残る
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-C", "d2": "D-R1", "d3": "M-L2", "d4": "D-C", "d5": "A-C"})
	assert_array(_moves(step)).is_equal(["d2:D-L1>D-R1:MARK", "d4:M-C>D-C:MARK"])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)


func test_man_with_exactly_enough_markers_marks_every_target() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d2": "D-R1", "d3": "M-L2"})


func test_man_without_enough_markers_marks_targets_nearest_the_own_goal_first() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d3", "M-L2", ""], ["d5", "A-C", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# D-C と D-R1 を先にマークし、M-L2 の対象は空く
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d3": "D-R1", "d5": "A-C"})
	assert_int(step.pair.defender.count_at(_area("M-L2"))).is_equal(0)


func test_man_priority_is_zone_then_center_then_half_space_then_wide_then_left() -> void:
	# 守備側から見ると M-C・D-R2・D-R1・D-L1・D-C の5人。選手の並びは優先順とわざと違えてある
	var attacker: TeamLayout = _layout([
		["a1", "M-C", ""], ["a2", "A-L2", ""], ["a3", "A-L1", ""], ["a4", "A-R1", ""], ["a5", "A-C", ""],
	])
	var defender: TeamLayout = _layout([
		["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""], ["m4", "M-C", ""],
	])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	var counts: Dictionary = step.pair.defender.counts()
	# 4人なら D-C → D-L1 → D-R1 → D-R2。M-C の対象（D より遠い）は空く
	assert_int(counts["D-C"] as int).is_equal(1)
	assert_int(counts["D-L1"] as int).is_equal(1)
	assert_int(counts["D-R1"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(1)
	assert_int(counts["M-C"] as int).is_equal(0)


func test_man_priority_with_three_markers_leaves_the_wide_target() -> void:
	var attacker: TeamLayout = _layout([
		["a1", "M-C", ""], ["a2", "A-L2", ""], ["a3", "A-L1", ""], ["a4", "A-R1", ""], ["a5", "A-C", ""],
	])
	var defender: TeamLayout = _layout([["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	var counts: Dictionary = step.pair.defender.counts()
	assert_int(counts["D-C"] as int).is_equal(1)
	assert_int(counts["D-L1"] as int).is_equal(1)
	assert_int(counts["D-R1"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(0)


func test_man_priority_marks_the_defender_left_first_on_a_tie() -> void:
	# 守備側から見ると D-R1・D-L1・D-R2・D-L2 の4人。マーカー2人ならハーフスペースの左右、1人なら左だけ
	var attacker: TeamLayout = _layout([
		["a1", "A-L1", ""], ["a2", "A-R1", ""], ["a3", "A-L2", ""], ["a4", "A-R2", ""],
	])
	var one: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "M-C", ""]]), _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_str(one.pair.defender.current_area_of("m1").to_key()).is_equal("D-L1")
	var three: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""]]), _styles(MAN, COUNTER),
			_area("M-C"), HOME)
	var counts: Dictionary = three.pair.defender.counts()
	assert_int(counts["D-L2"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(0)


func test_man_short_of_markers_does_not_keep_a_marker_on_a_lower_priority_target() -> void:
	# 対象は D-C と M-L2（守備側の視点）。マーカーは M-L2 にいる1人だけ。その場に残らず、優先の D-C へ
	var attacker: TeamLayout = _layout([["a1", "A-C", ""], ["a2", "M-R2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["d1", "M-L2", ""]]), _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_str(step.pair.defender.current_area_of("d1").to_key()).is_equal("D-C")


func test_man_targets_the_attacker_position_after_the_possession_advance() -> void:
	# 攻撃側の M-L2 の大外は保持型で A-L2 へ出る。守備側から見て D-R2
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""]])
	var defender: TeamLayout = _layout([["d1", "D-C", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_str(step.pair.defender.current_area_of("d1").to_key()).is_equal("D-R2")


func test_man_with_no_targets_sends_every_marker_to_d_c() -> void:
	# 攻撃側が全員自陣（守備側から見て A）にいると、マークの対象がいない
	var attacker: TeamLayout = _layout([["a1", "D-C", ""], ["a2", "D-L2", ""]])
	var defender: TeamLayout = _layout([["d1", "D-L2", ""], ["d2", "M-R1", ""], ["d3", "A-C", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d2": "D-C", "d3": "A-C"})


func test_movements_list_the_attacker_first_with_each_team_side() -> void:
	var step: LayoutStep = StyleLayoutCalculator.compute(_layout([["a1", "D-L2", ""], ["a2", "M-C", ""]]),
			_styles(ZONE, POSSESSION), _zone_defender(), _styles(ZONE, COUNTER), _area("A-R1"), HOME)
	assert_array(_moves(step)).is_equal([
		"a1:D-L2>M-L2:POSSESSION_ADVANCE",
		"d2:D-L1>D-L2:SLIDE", "d3:D-C>D-L1:SLIDE", "d4:M-R1>M-C:SLIDE", "d5:M-R2>M-R1:SLIDE", "d6:A-C>A-L1:SLIDE",
	])
	assert_int(step.movements[0].side).is_equal(HOME)
	for index: int in range(1, step.movements.size()):
		assert_int(step.movements[index].side).is_equal(AWAY)
	assert_int(step.pair.attacker_side).is_equal(HOME)


# --- 固定された選手（手順2） ---

func test_fixed_attacker_is_not_moved_by_possession_and_stays_fixed() -> void:
	# 固定先も大外（M-L2）。固定されていなければ A-L2 へ出るところ
	var attacker: TeamLayout = _layout([["a1", "D-L2", "M-L2"], ["a2", "D-R2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-L2", "a2": "M-R2"})
	assert_str(step.pair.attacker.players[0].fixed_area.to_key()).is_equal("M-L2")
	assert_array(_moves(step)).is_equal(["a2:D-R2>M-R2:POSSESSION_ADVANCE"])


func test_fixed_defender_is_not_moved_by_zone_slide() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", "D-C"]])
	var step: LayoutStep = StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(ZONE, COUNTER), _area("A-R1"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-L1", "d2": "D-C"})
	assert_bool(step.pair.defender.players[1].is_fixed()).is_true()
	assert_array(_moves(step)).is_equal(["d1:D-C>D-L1:SLIDE"])


func test_fixed_defender_is_not_a_man_marker() -> void:
	# d1 は M-R1 に固定されている。対象は D-C・D-R1・M-L2 の3人で、マーカーは d2・d3 の2人
	var defender: TeamLayout = _layout([["d1", "D-C", "M-R1"], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "M-R1", "d2": "D-C", "d3": "D-R1"})


# --- remark（マークの付け直し） ---

func test_remark_moves_the_marker_after_its_target_dribbles() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# a3 が M-R2 から A-R2 へドリブルして固定された（守備側から見て M-L2 → D-L2）
	var attacker_players: Array[PlayerState] = []
	var attacker_current: Dictionary = {}
	for player: PlayerState in start.pair.attacker.players:
		var moved: PlayerState = player.duplicate_deep()
		if moved.player_id == "a3":
			moved.fixed_area = _area("A-R2")
		attacker_players.append(moved)
		attacker_current[moved.player_id] = start.pair.attacker.current_area_of(moved.player_id)
	attacker_current["a3"] = _area("A-R2")
	var pair := LayoutPair.new(TeamLayout.new(attacker_players, attacker_current), start.pair.defender, HOME)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d2": "D-R1", "d3": "D-L2"})
	assert_array(_moves(step)).is_equal(["d3:M-L2>D-L2:MARK"])
	assert_str(step.pair.attacker.current_area_of("a3").to_key()).is_equal("A-R2")


func test_remark_keeps_a_marker_on_its_unmoved_target_instead_of_swapping() -> void:
	# m1 は D-L1、m2 は M-C の対象をマークしている（守備側の視点）。M-C の対象が D-C へドリブルした
	var attacker: TeamLayout = _layout([["a1", "A-R1", ""], ["a2", "M-C", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "D-L1", ""], ["m2", "M-C", ""]]), _styles(MAN, COUNTER), _area("M-C"), AWAY)
	assert_dict(_areas_of(start.pair.defender)).is_equal({"m1": "D-L1", "m2": "M-C"})
	var pair := LayoutPair.new(_moved(start.pair.attacker, "a2", "A-C"), start.pair.defender, AWAY)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	# m2 だけが対象についていく。m1 と m2 を入れ替えて矢印を交差させない
	assert_dict(_areas_of(step.pair.defender)).is_equal({"m1": "D-L1", "m2": "D-C"})
	assert_array(_moves(step)).is_equal(["m2:M-C>D-C:MARK"])
	assert_int(step.movements[0].side).is_equal(HOME)


func test_remark_skips_a_marker_fixed_by_press_and_keeps_inputs() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# d1 がプレスで M-C へ動いて固定された。マーカーは d2・d3 の2人で、対象は D-C・D-R1 の2人を先にマークする
	var pair := LayoutPair.new(start.pair.attacker, _moved(start.pair.defender, "d1", "M-C"), HOME)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "M-C", "d2": "D-R1", "d3": "D-C"})
	assert_array(_moves(step)).is_equal(["d3:M-L2>D-C:MARK"])
	# 入力は書き換えない
	assert_dict(_areas_of(pair.defender)).is_equal({"d1": "M-C", "d2": "D-R1", "d3": "M-L2"})


func test_remark_without_changes_moves_nobody() -> void:
	var defender: TeamLayout = _layout([
		["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""], ["d4", "M-C", ""], ["d5", "A-C", ""],
	])
	var start: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	var step: LayoutStep = StyleLayoutCalculator.remark(start.pair, _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal(_areas_of(start.pair.defender))
	assert_array(_moves(step)).is_empty()


func test_remark_does_nothing_for_zone() -> void:
	var start: LayoutStep = _compute_zone_defense("A-R1")
	var step: LayoutStep = StyleLayoutCalculator.remark(start.pair, _styles(ZONE, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal(_areas_of(start.pair.defender))
	assert_array(_moves(step)).is_empty()
	assert_object(step.pair).is_not_same(start.pair)


# --- 不変の性質 ---

func test_compute_does_not_modify_its_inputs() -> void:
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""], ["a2", "A-C", "A-L1"]])
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "M-R2", "M-C"]])
	StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION), defender, _styles(MAN, COUNTER),
			_area("A-R1"), HOME)
	assert_dict(_areas_of(attacker)).is_equal({"a1": "M-L2", "a2": "A-C"})
	assert_dict(_areas_of(defender)).is_equal({"d1": "D-C", "d2": "M-R2"})
	assert_str(defender.players[1].fixed_area.to_key()).is_equal("M-C")


func test_both_teams_keep_ten_players_for_every_formation_style_and_ball() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	assert_int(catalog.formations.size()).is_equal(4)
	var checked: int = 0
	for own: FormationDef in catalog.formations:
		for opponent: FormationDef in catalog.formations:
			for defense: GameEnums.DefenseStyle in [ZONE, MAN]:
				for attack: GameEnums.AttackStyle in [POSSESSION, COUNTER]:
					for ball: PitchArea in PitchArea.all():
						var step: LayoutStep = StyleLayoutCalculator.compute(
								BaseLayoutDeriver.derive(own), _styles(ZONE, attack),
								BaseLayoutDeriver.derive(opponent), _styles(defense, COUNTER), ball, HOME)
						var label: String = "%s vs %s %d/%d %s" % [own.id, opponent.id, defense, attack, ball.to_key()]
						assert_int(_total(step.pair.attacker)).override_failure_message(label).is_equal(10)
						assert_int(_total(step.pair.defender)).override_failure_message(label).is_equal(10)
						# MAN では基本エリアが A の選手はマーカーにならず、基本エリアに残る
						if defense == MAN:
							for player: PlayerState in step.pair.defender.players:
								if player.base_area.zone == GameEnums.Zone.A:
									assert_bool(player.base_area.equals(
											step.pair.defender.current_area_of(player.player_id))) \
											.override_failure_message(label).is_true()
						checked += 1
	assert_int(checked).is_equal(4 * 4 * 2 * 2 * 15)


func _total(layout: TeamLayout) -> int:
	var total: int = 0
	for count: int in layout.counts().values():
		total += count
	return total

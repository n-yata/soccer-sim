## アルゴリズム4: 守備の手による移動（DefenseMover）のテスト。
## 期待値は functional-overview.md アルゴリズム4の規則から手で書いた。target は攻撃側から見た座標、
## 守備側の配置と動きは守備側から見た座標（component-design.md §1.2）。テストの説明の T_d は守備側から見た座標。
extends GdUnitTestSuite

const PRESS := GameEnums.DefenseAction.PRESS
const COVER := GameEnums.DefenseAction.COVER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## spec は [選手 ID, 基本エリア, 固定先（無ければ ""）] の配列。現在エリアは固定先、無ければ基本エリア。
func _team(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		var fixed: PitchArea = null if fixed_key == "" else _area(fixed_key)
		var player := PlayerState.new(row[0] as String, _area(row[1] as String), fixed)
		players.append(player)
		current[player.player_id] = fixed if fixed != null else player.base_area
	return TeamLayout.new(players, current)


## 攻撃側は1エリア1人（攻撃側から見た座標）
func _attackers(keys: Array) -> TeamLayout:
	var spec: Array = []
	for index: int in range(keys.size()):
		spec.append(["a%d" % index, keys[index], ""])
	return _team(spec)


func _pair(attacker_keys: Array, defender_spec: Array) -> LayoutPair:
	return LayoutPair.new(_attackers(attacker_keys), _team(defender_spec), HOME)


func _areas_of(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


## "選手 ID:移動元>移動先:理由"
func _moves(step: LayoutStep) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in step.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## 守備側の選手 ID の動き（"from>to"）だけ
func _press_from(attacker_keys: Array, defender_spec: Array, target_key: String) -> Array[String]:
	var step: LayoutStep = DefenseMover.apply(_pair(attacker_keys, defender_spec), PRESS, _area(target_key))
	return _moves(step)


# --- PRESS ---

func test_press_moves_one_player_from_the_neighbor_with_the_largest_surplus() -> void:
	# T_d = M-C（攻撃側の視点でも M-C）。背後の D-C は余り +2、横の M-L1 は +1
	var step: LayoutStep = DefenseMover.apply(
			_pair([], [["d1", "D-C", ""], ["d2", "D-C", ""], ["d3", "M-L1", ""]]), PRESS, _area("M-C"))
	assert_array(_moves(step)).is_equal(["d1:D-C>M-C:PRESS"])
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "M-C", "d2": "D-C", "d3": "M-L1"})
	assert_str(step.pair.defender.players[0].fixed_area.to_key()).is_equal("M-C")
	assert_int(step.movements[0].side).is_equal(AWAY)
	assert_int(step.pair.attacker_side).is_equal(HOME)


func test_press_counts_attackers_in_the_defender_view() -> void:
	# 守備側の M-L1 に1人・攻撃側が2人（攻撃側の視点で M-R1）で余り -1。M-R1 は1人で余り +1
	var step: LayoutStep = DefenseMover.apply(
			_pair(["M-R1", "M-R1"], [["d1", "M-L1", ""], ["d2", "M-R1", ""]]), PRESS, _area("M-C"))
	assert_array(_moves(step)).is_equal(["d2:M-R1>M-C:PRESS"])


func test_press_still_moves_when_every_surplus_is_negative() -> void:
	var moves: Array[String] = _press_from(["M-R1", "M-R1"], [["d1", "M-L1", ""]], "M-C")
	assert_array(moves).is_equal(["d1:M-L1>M-C:PRESS"])


func test_press_tie_prefers_the_player_in_front() -> void:
	# 前方 A-C・横 M-L1/M-R1・背後 D-C に1人ずつ。すべて余り +1
	var moves: Array[String] = _press_from([], [
		["back", "D-C", ""], ["left", "M-L1", ""], ["right", "M-R1", ""], ["front", "A-C", ""],
	], "M-C")
	assert_array(moves).is_equal(["front:A-C>M-C:PRESS"])


func test_press_tie_between_sides_takes_the_defender_left() -> void:
	var moves: Array[String] = _press_from([], [
		["back", "D-C", ""], ["right", "M-R1", ""], ["left", "M-L1", ""],
	], "M-C")
	assert_array(moves).is_equal(["left:M-L1>M-C:PRESS"])


func test_press_tie_between_sides_takes_the_more_central_lane_first() -> void:
	# T_d = M-L1（攻撃側の視点で M-R1）。横は M-L2（大外）と M-C（中央）。左が先でも中央寄りを優先する
	var moves: Array[String] = _press_from([], [["wide", "M-L2", ""], ["center", "M-C", ""]], "M-R1")
	assert_array(moves).is_equal(["center:M-C>M-L1:PRESS"])


func test_press_tie_takes_the_side_before_the_back_line() -> void:
	var moves: Array[String] = _press_from([], [["back", "D-C", ""], ["right", "M-R1", ""]], "M-C")
	assert_array(moves).is_equal(["right:M-R1>M-C:PRESS"])


func test_press_moves_an_unfixed_player_before_a_fixed_one() -> void:
	# D-C に固定された d1（基本は M-L2）と、固定されていない d2
	var step: LayoutStep = DefenseMover.apply(
			_pair([], [["d1", "M-L2", "D-C"], ["d2", "D-C", ""]]), PRESS, _area("M-C"))
	assert_array(_moves(step)).is_equal(["d2:D-C>M-C:PRESS"])
	assert_str(step.pair.defender.players[0].fixed_area.to_key()).is_equal("D-C")


func test_press_moves_a_fixed_player_when_no_one_else_is_there_and_updates_the_fix() -> void:
	var step: LayoutStep = DefenseMover.apply(_pair([], [["d1", "M-L2", "D-C"]]), PRESS, _area("M-C"))
	assert_array(_moves(step)).is_equal(["d1:D-C>M-C:PRESS"])
	assert_str(step.pair.defender.players[0].fixed_area.to_key()).is_equal("M-C")
	assert_str(step.pair.defender.players[0].base_area.to_key()).is_equal("M-L2")


func test_press_without_a_neighbor_defender_returns_null() -> void:
	var step: LayoutStep = DefenseMover.apply(_pair([], [["d1", "A-L2", ""]]), PRESS, _area("M-C"))
	assert_object(step).is_null()


# --- COVER ---

func test_cover_drops_the_player_in_the_area_one_zone_back() -> void:
	# T_d = M-C にいる d1 が、背後の D-C へ下がる
	var step: LayoutStep = DefenseMover.apply(
			_pair([], [["d1", "M-C", ""], ["d2", "A-C", ""]]), COVER, _area("M-C"))
	assert_array(_moves(step)).is_equal(["d1:M-C>D-C:COVER"])
	assert_str(step.pair.defender.players[0].fixed_area.to_key()).is_equal("D-C")
	assert_int(step.movements[0].side).is_equal(AWAY)


func test_cover_without_a_player_in_the_area_takes_a_side_neighbor_not_the_front() -> void:
	# T_d = M-C に誰もいない。前方 A-C から背後の D-C へは2ゾーン下がることになるので選ばない（1ターン1マス）。
	# 横の M-R1 から、斜めに D-C へ
	var step: LayoutStep = DefenseMover.apply(
			_pair([], [["side", "M-R1", ""], ["front", "A-C", ""]]), COVER, _area("M-C"))
	assert_array(_moves(step)).is_equal(["side:M-R1>D-C:COVER"])


func test_cover_with_only_a_player_in_front_returns_null() -> void:
	# T_d = M-C の前方 A-C にしか守備側がいない。背後の D-C まで1マスで届く選手がいないので、カバーは選べない
	var step: LayoutStep = DefenseMover.apply(_pair([], [["front", "A-C", ""]]), COVER, _area("M-C"))
	assert_object(step).is_null()


func test_cover_by_a_player_already_behind_fixes_in_place_without_a_movement() -> void:
	# T_d = M-C は空で、守備側は背後の D-C にだけいる。D-C から D-C へは動かず、その場で固定する
	var step: LayoutStep = DefenseMover.apply(_pair([], [["d1", "D-C", ""]]), COVER, _area("M-C"))
	assert_array(_moves(step)).is_empty()
	assert_str(step.pair.defender.current_area_of("d1").to_key()).is_equal("D-C")
	assert_str(step.pair.defender.players[0].fixed_area.to_key()).is_equal("D-C")


func test_apply_succeeds_exactly_for_the_defense_options() -> void:
	# MoveRules.defense_options と DefenseMover.apply は同じ条件を別々に書いている。片方だけ直す事故を防ぐため、
	# 代表的な配置の全エリアで「選べる ⇔ null でない」を確かめる
	var layouts: Array = [
		[["d1", "D-C", ""]],
		[["d1", "M-L2", ""]],
		[["d1", "A-R2", ""], ["d2", "D-L2", "M-C"]],
		[["d1", "D-L2", ""], ["d2", "D-L1", ""], ["d3", "D-C", ""], ["d4", "M-R1", ""], ["d5", "A-C", ""]],
	]
	var checked: int = 0
	for spec: Array in layouts:
		var pair: LayoutPair = _pair(["M-C", "A-L1"], spec)
		var options: MoveOptions = MoveRules.defense_options(pair)
		for action: GameEnums.DefenseAction in [PRESS, COVER]:
			var allowed: Array[String] = []
			for target: PitchArea in options.targets(GameEnums.ChoiceFamily.DEFENSE, action):
				allowed.append(target.to_key())
			for target: PitchArea in PitchArea.all():
				var label: String = "%s %d %s" % [str(spec), action, target.to_key()]
				var step: LayoutStep = DefenseMover.apply(pair, action, target)
				assert_bool(step != null).override_failure_message(label).is_equal(target.to_key() in allowed)
				checked += 1
	assert_int(checked).is_equal(4 * 2 * 15)


func test_cover_in_the_defender_d_zone_returns_null() -> void:
	# 攻撃側の視点の A-C は、守備側の D-C。背後が無い
	var step: LayoutStep = DefenseMover.apply(_pair([], [["d1", "D-C", ""]]), COVER, _area("A-C"))
	assert_object(step).is_null()


# --- 不変の性質・組み合わせ ---

func test_apply_does_not_modify_its_inputs() -> void:
	var pair: LayoutPair = _pair(["M-C"], [["d1", "D-C", ""], ["d2", "M-L2", "D-C"]])
	DefenseMover.apply(pair, PRESS, _area("M-C"))
	assert_dict(_areas_of(pair.defender)).is_equal({"d1": "D-C", "d2": "D-C"})
	assert_bool(pair.defender.players[0].is_fixed()).is_false()
	assert_str(pair.defender.players[1].fixed_area.to_key()).is_equal("D-C")


func test_man_marker_pressing_is_fixed_and_the_spare_cover_takes_the_mark() -> void:
	# 攻撃側は守備側から見て D-C と M-C に1人ずつ。マーカーは d1（D-C）・d2（M-C）、d3 は余りで D-C
	var attacker: TeamLayout = _attackers(["A-C", "M-C"])
	var defender: TeamLayout = _team([["d1", "D-C", ""], ["d2", "M-C", ""], ["d3", "D-L1", ""]])
	var man := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	var counter := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, counter, defender, man, _area("M-C"), HOME)
	assert_dict(_areas_of(start.pair.defender)).is_equal({"d1": "D-C", "d2": "M-C", "d3": "D-C"})
	# T_d = M-L1（攻撃側の視点で M-R1）。隣接に守備側がいるのは M-C だけで、マーカーの d2 がプレスに出る
	var pressed: LayoutStep = DefenseMover.apply(start.pair, PRESS, _area("M-R1"))
	assert_array(_moves(pressed)).is_equal(["d2:M-C>M-L1:PRESS"])
	var marked: LayoutStep = StyleLayoutCalculator.remark(pressed.pair, man)
	# d2 は固定されたまま。余りの d3 が、空いた M-C の相手につく
	assert_dict(_areas_of(marked.pair.defender)).is_equal({"d1": "D-C", "d2": "M-L1", "d3": "M-C"})
	assert_array(_moves(marked)).is_equal(["d3:D-C>M-C:MARK"])


func test_man_marker_pressing_without_a_spare_leaves_the_opponent_free() -> void:
	var attacker: TeamLayout = _attackers(["A-C", "M-C"])
	var defender: TeamLayout = _team([["d1", "D-C", ""], ["d2", "M-C", ""]])
	var man := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	var counter := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, counter, defender, man, _area("M-C"), HOME)
	var pressed: LayoutStep = DefenseMover.apply(start.pair, PRESS, _area("M-R1"))
	var marked: LayoutStep = StyleLayoutCalculator.remark(pressed.pair, man)
	# マーカーは d1 だけで、優先の D-C の相手につく。M-C の相手はフリー
	assert_int(marked.pair.defender.count_at(_area("M-C"))).is_equal(0)
	assert_str(marked.pair.defender.current_area_of("d1").to_key()).is_equal("D-C")

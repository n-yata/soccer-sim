## PitchArea（component-design.md §2.2）のテスト。
## 期待値は functional-overview.md「ドメイン上の制約」の鏡像の対応と、盤面（6列 × 5レーン。2026-10-25）から直接書く。
extends GdUnitTestSuite

const ALL_KEYS_IN_ORDER: Array[String] = [
	"D1-L2", "D1-L1", "D1-C", "D1-R1", "D1-R2",
	"D2-L2", "D2-L1", "D2-C", "D2-R1", "D2-R2",
	"M1-L2", "M1-L1", "M1-C", "M1-R1", "M1-R2",
	"M2-L2", "M2-L1", "M2-C", "M2-R1", "M2-R2",
	"A1-L2", "A1-L1", "A1-C", "A1-R1", "A1-R2",
	"A2-L2", "A2-L1", "A2-C", "A2-R1", "A2-R2",
]


func _area(key: String) -> PitchArea:
	var area: PitchArea = PitchArea.from_key(key)
	assert_object(area).override_failure_message("キーを解釈できない: %s" % key).is_not_null()
	return area


func _keys(areas: Array[PitchArea]) -> Array[String]:
	var keys: Array[String] = []
	for area: PitchArea in areas:
		keys.append(area.to_key())
	return keys


func test_all_returns_30_areas_from_the_own_goal_to_the_opponents_goal_and_left_to_right() -> void:
	assert_array(_keys(PitchArea.all())).is_equal(ALL_KEYS_IN_ORDER)


func test_constructor_keeps_lane_and_zone() -> void:
	var area := PitchArea.new(GameEnums.Lane.R1, GameEnums.Zone.A2)
	assert_int(area.lane).is_equal(GameEnums.Lane.R1)
	assert_int(area.zone).is_equal(GameEnums.Zone.A2)
	assert_str(area.to_key()).is_equal("A2-R1")


func test_mirrored_follows_the_mirror_table() -> void:
	# 相手から見ると列が逆（D1↔A2、D2↔A1、M1↔M2）、レーンも左右が逆
	var expected: Dictionary = {
		"D1-L2": "A2-R2", "D1-C": "A2-C", "D2-L1": "A1-R1", "D2-R2": "A1-L2",
		"M1-C": "M2-C", "M1-L2": "M2-R2", "M2-R1": "M1-L1",
		"A1-R2": "D2-L2", "A1-C": "D2-C", "A2-C": "D1-C", "A2-L1": "D1-R1",
	}
	for key: String in expected:
		assert_str(_area(key).mirrored().to_key()).override_failure_message("鏡像: %s" % key).is_equal(expected[key])


func test_mirrored_twice_returns_the_same_area_for_all_30() -> void:
	for area: PitchArea in PitchArea.all():
		assert_bool(area.mirrored().mirrored().equals(area)).override_failure_message(area.to_key()).is_true()


func test_mirrored_does_not_change_the_original() -> void:
	var area: PitchArea = _area("D1-L2")
	area.mirrored()
	assert_str(area.to_key()).is_equal("D1-L2")


func test_forward_and_backward_move_one_row() -> void:
	assert_str(_area("D1-L1").forward().to_key()).is_equal("D2-L1")
	# ハーフウェーライン（M1 と M2 の境）をまたぐ
	assert_str(_area("M1-L1").forward().to_key()).is_equal("M2-L1")
	assert_str(_area("A1-R2").forward().to_key()).is_equal("A2-R2")
	assert_str(_area("A2-R2").backward().to_key()).is_equal("A1-R2")
	assert_str(_area("M2-C").backward().to_key()).is_equal("M1-C")


func test_forward_and_backward_return_null_off_the_pitch() -> void:
	for lane_key: String in ["L2", "L1", "C", "R1", "R2"]:
		assert_object(_area("A2-" + lane_key).forward()).is_null()
		assert_object(_area("D1-" + lane_key).backward()).is_null()


func test_own_half_is_the_first_three_rows() -> void:
	for key: String in ["D1-L2", "D2-C", "M1-R2"]:
		assert_bool(_area(key).is_own_half()).override_failure_message(key).is_true()
	for key: String in ["M2-L2", "A1-C", "A2-R2"]:
		assert_bool(_area(key).is_own_half()).override_failure_message(key).is_false()


func test_neighbors4_at_corner_edge_and_center() -> void:
	assert_array(_keys(_area("D1-L2").neighbors4())).is_equal(["D1-L1", "D2-L2"] as Array[String])
	assert_array(_keys(_area("A2-R2").neighbors4())).is_equal(["A1-R2", "A2-R1"] as Array[String])
	assert_array(_keys(_area("D1-C").neighbors4())).is_equal(["D1-L1", "D1-R1", "D2-C"] as Array[String])
	assert_array(_keys(_area("M1-L2").neighbors4())).is_equal(["D2-L2", "M1-L1", "M2-L2"] as Array[String])
	assert_array(_keys(_area("M1-C").neighbors4())).is_equal(["D2-C", "M1-L1", "M1-R1", "M2-C"] as Array[String])


func test_neighbors8_at_corner_edge_and_center() -> void:
	assert_array(_keys(_area("D1-L2").neighbors8())).is_equal(["D1-L1", "D2-L2", "D2-L1"] as Array[String])
	assert_array(_keys(_area("D1-C").neighbors8())).is_equal(
			["D1-L1", "D1-R1", "D2-L1", "D2-C", "D2-R1"] as Array[String])
	assert_array(_keys(_area("M1-L2").neighbors8())).is_equal(
			["D2-L2", "D2-L1", "M1-L1", "M2-L2", "M2-L1"] as Array[String])
	assert_array(_keys(_area("M2-C").neighbors8())).is_equal(
			["M1-L1", "M1-C", "M1-R1", "M2-L1", "M2-R1", "A1-L1", "A1-C", "A1-R1"] as Array[String])


func test_neighbor_counts_for_every_area() -> void:
	# 角は 2/3、角以外の辺は 3/5、内側は 4/8
	for area: PitchArea in PitchArea.all():
		var is_on_lane_edge: bool = area.lane == GameEnums.Lane.L2 or area.lane == GameEnums.Lane.R2
		var is_on_zone_edge: bool = area.zone == GameEnums.Zone.D1 or area.zone == GameEnums.Zone.A2
		var expected4: int = 4
		var expected8: int = 8
		if is_on_lane_edge and is_on_zone_edge:
			expected4 = 2
			expected8 = 3
		elif is_on_lane_edge or is_on_zone_edge:
			expected4 = 3
			expected8 = 5
		assert_int(area.neighbors4().size()).override_failure_message(area.to_key()).is_equal(expected4)
		assert_int(area.neighbors8().size()).override_failure_message(area.to_key()).is_equal(expected8)


func test_equals_compares_lane_and_zone() -> void:
	assert_bool(_area("M1-L1").equals(PitchArea.new(GameEnums.Lane.L1, GameEnums.Zone.M1))).is_true()
	assert_bool(_area("M1-L1").equals(_area("M1-R1"))).is_false()
	assert_bool(_area("M1-L1").equals(_area("M2-L1"))).is_false()
	assert_bool(_area("M1-L1").equals(null)).is_false()


func test_key_round_trip_for_all_30() -> void:
	for key: String in ALL_KEYS_IN_ORDER:
		assert_str(_area(key).to_key()).is_equal(key)


func test_from_key_returns_null_for_invalid_strings() -> void:
	# 3列のころのキー（M-L1 など）も、もう読めない
	for key: String in ["", "M1", "M1-", "-L1", "M1L1", "M1_L1", "X1-L1", "M3-L1", "D0-C", "M1-L3", "m1-l1",
			"M1-L1-C", " M1-L1", "1-0", "M-L1", "D-C", "A-R2"]:
		assert_object(PitchArea.from_key(key)).override_failure_message("不正なキー: '%s'" % key).is_null()


func test_distance_is_the_row_gap_plus_the_lane_gap() -> void:
	var center: PitchArea = PitchArea.from_key("M1-C")
	assert_int(center.distance_to(PitchArea.from_key("M1-C"))).is_equal(0)
	assert_int(center.distance_to(PitchArea.from_key("M2-C"))).is_equal(1)
	assert_int(center.distance_to(PitchArea.from_key("M1-L2"))).is_equal(2)
	# 斜めは2（列差1＋レーン差1）。向きによらない
	assert_int(center.distance_to(PitchArea.from_key("D2-R1"))).is_equal(2)
	assert_int(PitchArea.from_key("D2-R1").distance_to(center)).is_equal(2)
	assert_int(PitchArea.from_key("D1-L2").distance_to(PitchArea.from_key("A2-R2"))).is_equal(9)


func test_step_toward_moves_one_area_closing_both_gaps() -> void:
	# [起点, 目標, 1マス近づいた先]。列差・レーン差をそれぞれ1ずつ詰める（斜めを優先）
	var cases: Array = [
		["M1-C", "M1-C", "M1-C"],
		["M1-C", "A2-C", "M2-C"],
		["D1-L2", "D1-R2", "D1-L1"],
		["D1-C", "A2-R2", "D2-R1"],
		["A2-R2", "D1-L2", "A1-R1"],
		["M1-L1", "M1-R2", "M1-C"],
	]
	for case: Array in cases:
		assert_str(_area(case[0] as String).step_toward(_area(case[1] as String)).to_key()) \
				.override_failure_message(str(case)).is_equal(case[2] as String)


func test_step_toward_never_moves_more_than_one_area() -> void:
	for start: PitchArea in PitchArea.all():
		for target: PitchArea in PitchArea.all():
			var stepped: PitchArea = start.step_toward(target)
			assert_bool(start.is_within_one(stepped)).override_failure_message("%s>%s" % [start.to_key(), target.to_key()]).is_true()
			# 目標から離れない（チェビシェフ距離で1つ詰まるか、すでに目標）
			assert_int(stepped.steps_to(target)).is_equal(maxi(start.steps_to(target) - 1, 0))


func test_within_one_counts_diagonals_as_one() -> void:
	var center: PitchArea = _area("M1-C")
	assert_bool(center.is_within_one(_area("M1-C"))).is_true()
	assert_bool(center.is_within_one(_area("M2-R1"))).is_true()
	assert_bool(center.is_within_one(_area("D2-L1"))).is_true()
	assert_bool(center.is_within_one(_area("M1-L2"))).is_false()
	assert_bool(center.is_within_one(_area("A1-C"))).is_false()
	assert_int(_area("D1-L2").steps_to(_area("A2-R2"))).is_equal(5)

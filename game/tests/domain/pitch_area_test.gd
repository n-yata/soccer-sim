## PitchArea（component-design.md §2.2）のテスト。
## 期待値は functional-overview.md「ドメイン上の制約」の鏡像の対応と、盤面（3ゾーン × 5レーン）から直接書く。
extends GdUnitTestSuite

const ALL_KEYS_IN_ORDER: Array[String] = [
	"D-L2", "D-L1", "D-C", "D-R1", "D-R2",
	"M-L2", "M-L1", "M-C", "M-R1", "M-R2",
	"A-L2", "A-L1", "A-C", "A-R1", "A-R2",
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


func test_all_returns_15_areas_from_defense_to_attack_and_left_to_right() -> void:
	assert_array(_keys(PitchArea.all())).is_equal(ALL_KEYS_IN_ORDER)


func test_constructor_keeps_lane_and_zone() -> void:
	var area := PitchArea.new(GameEnums.Lane.R1, GameEnums.Zone.A)
	assert_int(area.lane).is_equal(GameEnums.Lane.R1)
	assert_int(area.zone).is_equal(GameEnums.Zone.A)
	assert_str(area.to_key()).is_equal("A-R1")


func test_mirrored_follows_the_mirror_table() -> void:
	var expected: Dictionary = {
		"D-L2": "A-R2", "D-L1": "A-R1", "D-C": "A-C", "D-R1": "A-L1", "D-R2": "A-L2",
		"M-L2": "M-R2", "M-L1": "M-R1", "M-C": "M-C", "M-R1": "M-L1", "M-R2": "M-L2",
		"A-L2": "D-R2", "A-L1": "D-R1", "A-C": "D-C", "A-R1": "D-L1", "A-R2": "D-L2",
	}
	for key: String in ALL_KEYS_IN_ORDER:
		assert_str(_area(key).mirrored().to_key()).override_failure_message("鏡像: %s" % key).is_equal(expected[key])


func test_mirrored_twice_returns_the_same_area_for_all_15() -> void:
	for area: PitchArea in PitchArea.all():
		assert_bool(area.mirrored().mirrored().equals(area)).override_failure_message(area.to_key()).is_true()


func test_mirrored_does_not_change_the_original() -> void:
	var area: PitchArea = _area("D-L2")
	area.mirrored()
	assert_str(area.to_key()).is_equal("D-L2")


func test_forward_and_backward_move_one_zone() -> void:
	assert_str(_area("D-L1").forward().to_key()).is_equal("M-L1")
	assert_str(_area("M-L1").forward().to_key()).is_equal("A-L1")
	assert_str(_area("A-R2").backward().to_key()).is_equal("M-R2")
	assert_str(_area("M-C").backward().to_key()).is_equal("D-C")


func test_forward_and_backward_return_null_off_the_pitch() -> void:
	for lane_key: String in ["L2", "L1", "C", "R1", "R2"]:
		assert_object(_area("A-" + lane_key).forward()).is_null()
		assert_object(_area("D-" + lane_key).backward()).is_null()


func test_neighbors4_at_corner_edge_and_center() -> void:
	assert_array(_keys(_area("D-L2").neighbors4())).is_equal(["D-L1", "M-L2"] as Array[String])
	assert_array(_keys(_area("A-R2").neighbors4())).is_equal(["M-R2", "A-R1"] as Array[String])
	assert_array(_keys(_area("D-C").neighbors4())).is_equal(["D-L1", "D-R1", "M-C"] as Array[String])
	assert_array(_keys(_area("M-L2").neighbors4())).is_equal(["D-L2", "M-L1", "A-L2"] as Array[String])
	assert_array(_keys(_area("M-C").neighbors4())).is_equal(["D-C", "M-L1", "M-R1", "A-C"] as Array[String])


func test_neighbors8_at_corner_edge_and_center() -> void:
	assert_array(_keys(_area("D-L2").neighbors8())).is_equal(["D-L1", "M-L2", "M-L1"] as Array[String])
	assert_array(_keys(_area("D-C").neighbors8())).is_equal(
			["D-L1", "D-R1", "M-L1", "M-C", "M-R1"] as Array[String])
	assert_array(_keys(_area("M-L2").neighbors8())).is_equal(
			["D-L2", "D-L1", "M-L1", "A-L2", "A-L1"] as Array[String])
	assert_array(_keys(_area("M-C").neighbors8())).is_equal(
			["D-L1", "D-C", "D-R1", "M-L1", "M-R1", "A-L1", "A-C", "A-R1"] as Array[String])


func test_neighbor_counts_for_every_area() -> void:
	# 角は 2/3、角以外の辺は 3/5、内側は 4/8
	for area: PitchArea in PitchArea.all():
		var is_on_lane_edge: bool = area.lane == GameEnums.Lane.L2 or area.lane == GameEnums.Lane.R2
		var is_on_zone_edge: bool = area.zone == GameEnums.Zone.D or area.zone == GameEnums.Zone.A
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
	assert_bool(_area("M-L1").equals(PitchArea.new(GameEnums.Lane.L1, GameEnums.Zone.M))).is_true()
	assert_bool(_area("M-L1").equals(_area("M-R1"))).is_false()
	assert_bool(_area("M-L1").equals(_area("D-L1"))).is_false()
	assert_bool(_area("M-L1").equals(null)).is_false()


func test_key_round_trip_for_all_15() -> void:
	for key: String in ALL_KEYS_IN_ORDER:
		assert_str(_area(key).to_key()).is_equal(key)


func test_from_key_returns_null_for_invalid_strings() -> void:
	for key: String in ["", "M", "M-", "-L1", "ML1", "M_L1", "X-L1", "M-L3", "m-l1", "M-L1-C", " M-L1", "1-0"]:
		assert_object(PitchArea.from_key(key)).override_failure_message("不正なキー: '%s'" % key).is_null()


func test_distance_is_the_zone_gap_plus_the_lane_gap() -> void:
	var center: PitchArea = PitchArea.from_key("M-C")
	assert_int(center.distance_to(PitchArea.from_key("M-C"))).is_equal(0)
	assert_int(center.distance_to(PitchArea.from_key("A-C"))).is_equal(1)
	assert_int(center.distance_to(PitchArea.from_key("M-L2"))).is_equal(2)
	# 斜めは2（ゾーン差1＋レーン差1）。向きによらない
	assert_int(center.distance_to(PitchArea.from_key("D-R1"))).is_equal(2)
	assert_int(PitchArea.from_key("D-R1").distance_to(center)).is_equal(2)
	assert_int(PitchArea.from_key("D-L2").distance_to(PitchArea.from_key("A-R2"))).is_equal(6)


func test_step_toward_moves_one_area_closing_both_gaps() -> void:
	# [起点, 目標, 1マス近づいた先]。ゾーン差・レーン差をそれぞれ1ずつ詰める（斜めを優先）
	var cases: Array = [
		["M-C", "M-C", "M-C"],
		["M-C", "A-C", "A-C"],
		["D-L2", "D-R2", "D-L1"],
		["D-C", "A-R2", "M-R1"],
		["A-R2", "D-L2", "M-R1"],
		["M-L1", "M-R2", "M-C"],
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
	var center: PitchArea = _area("M-C")
	assert_bool(center.is_within_one(_area("M-C"))).is_true()
	assert_bool(center.is_within_one(_area("A-R1"))).is_true()
	assert_bool(center.is_within_one(_area("D-L1"))).is_true()
	assert_bool(center.is_within_one(_area("M-L2"))).is_false()
	assert_bool(center.is_within_one(_area("A-R2"))).is_false()
	assert_int(_area("D-L2").steps_to(_area("A-R2"))).is_equal(4)

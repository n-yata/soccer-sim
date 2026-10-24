## BaseLayoutDeriver（functional-overview.md アルゴリズム1）のテスト。
## アルゴリズム1の「エッジケース（テスト対象）」をすべて扱う。4陣形の表との一致は
## tests/data/formations_base_layout_test.gd（本物の formations.json を使う）。
extends GdUnitTestSuite


func _key_of(x: float, y: float) -> String:
	return BaseLayoutDeriver.area_of(x, y).to_key()


func test_lane_center_up_to_distance_15_inclusive() -> void:
	# d = |x - 50|。d = 15 ちょうど（x = 35 / 65）は C
	assert_str(_key_of(35.0, 50.0)).is_equal("M-C")
	assert_str(_key_of(65.0, 50.0)).is_equal("M-C")
	assert_str(_key_of(50.0, 50.0)).is_equal("M-C")


func test_lane_x_50_is_center_without_left_right() -> void:
	assert_str(_key_of(50.0, 5.0)).is_equal("D-C")
	assert_str(_key_of(50.0, 95.0)).is_equal("A-C")


func test_lane_half_space_between_15_and_30_exclusive() -> void:
	assert_str(_key_of(34.9, 50.0)).is_equal("M-L1")
	assert_str(_key_of(65.1, 50.0)).is_equal("M-R1")
	assert_str(_key_of(20.1, 50.0)).is_equal("M-L1")
	assert_str(_key_of(79.9, 50.0)).is_equal("M-R1")


func test_lane_wide_from_distance_30_inclusive() -> void:
	# d = 30 ちょうど（x = 20 / 80）は大外
	assert_str(_key_of(20.0, 50.0)).is_equal("M-L2")
	assert_str(_key_of(80.0, 50.0)).is_equal("M-R2")
	assert_str(_key_of(0.0, 50.0)).is_equal("M-L2")
	assert_str(_key_of(100.0, 50.0)).is_equal("M-R2")


func test_zone_boundaries_at_one_third_and_two_thirds() -> void:
	# y < 100/3 は D、y < 200/3 は M、それ以外は A。境界ちょうどは前のゾーン
	assert_str(_key_of(50.0, 0.0)).is_equal("D-C")
	assert_str(_key_of(50.0, 33.3)).is_equal("D-C")
	assert_str(_key_of(50.0, 100.0 / 3.0)).is_equal("M-C")
	assert_str(_key_of(50.0, 66.6)).is_equal("M-C")
	assert_str(_key_of(50.0, 200.0 / 3.0)).is_equal("A-C")
	assert_str(_key_of(50.0, 100.0)).is_equal("A-C")


func _slot(slot_id: String, position_type: String, x: float, y: float) -> PlayerSlotDef:
	return PlayerSlotDef.new(slot_id, position_type, position_type, 1, x, y)


## 4-4-2 と同じ形の、手で組んだ陣形（数値は本物から独立させ、境界の値を混ぜてある）
func _sample_formation() -> FormationDef:
	var slots: Array[PlayerSlotDef] = [
		_slot("gk", "GK", 50.0, 5.0),
		_slot("lb", "DF", 15.0, 20.0),
		_slot("cb1", "DF", 35.0, 18.0),
		_slot("cb2", "DF", 65.0, 18.0),
		_slot("rb", "DF", 85.0, 20.0),
		_slot("lm", "MF", 20.0, 100.0 / 3.0),
		_slot("cm1", "MF", 34.0, 50.0),
		_slot("cm2", "MF", 66.0, 50.0),
		_slot("rm", "MF", 80.0, 60.0),
		_slot("st1", "FW", 50.0, 200.0 / 3.0),
		_slot("st2", "FW", 60.0, 85.0),
	]
	return FormationDef.new("sample", "sample", "テスト用", [] as Array[String], slots)


func test_derive_excludes_goalkeeper_and_keeps_ten_players() -> void:
	var layout: TeamLayout = BaseLayoutDeriver.derive(_sample_formation())
	assert_int(layout.players.size()).is_equal(10)
	assert_object(layout.current_area_of("gk")).is_null()
	var total: int = 0
	var counts: Dictionary = layout.counts()
	for key: String in counts:
		total += counts[key] as int
	assert_int(total).is_equal(10)


func test_derive_places_each_player_on_area_of_its_coordinates() -> void:
	# 座標のエリアは cb1・cb2 が D-C、st1・st2 が A-C で重なる。重なるゾーン（D・A）だけ、並び順のままレーンへ散らす
	# （レーンの中心 10・30・50・70・90 との差の合計が最小）。重ならない M はそのまま
	var layout: TeamLayout = BaseLayoutDeriver.derive(_sample_formation())
	var expected: Dictionary = {
		"lb": "D-L2", "cb1": "D-L1", "cb2": "D-R1", "rb": "D-R2",
		"lm": "M-L2", "cm1": "M-L1", "cm2": "M-R1", "rm": "M-R2",
		"st1": "A-C", "st2": "A-R1",
	}
	for player: PlayerState in layout.players:
		assert_str(player.base_area.to_key()).override_failure_message(player.player_id) \
				.is_equal(expected[player.player_id])
		assert_str(layout.current_area_of(player.player_id).to_key()).is_equal(expected[player.player_id])
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()


## GK と、指定したゾーンの y に並べた選手（id, x）だけの陣形。足りない人数は D-L2〜 に1人ずつ置く（重ならない）
func _formation_with(zone_y: float, spec: Array) -> FormationDef:
	var slots: Array[PlayerSlotDef] = [_slot("gk", "GK", 50.0, 5.0)]
	for entry: Array in spec:
		slots.append(_slot(entry[0] as String, "MF", entry[1] as float, zone_y))
	return FormationDef.new("spread", "spread", "テスト用", [] as Array[String], slots)


func _areas(layout: TeamLayout, ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for player_id: String in ids:
		result.append(layout.current_area_of(player_id).to_key())
	return result


func test_two_central_players_are_spread_symmetrically() -> void:
	# x=40・60 はどちらも C。散らし方は (L1,C)・(C,R1)・(L1,R1) のどれも差の合計 20 で同じ。
	# 同じなら、置いたレーンの中心の平均が座標の平均（50）に近い、左右の釣り合いが取れた (L1,R1) を選ぶ
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(85.0, [["a", 40.0], ["b", 60.0]]))
	assert_array(_areas(layout, ["a", "b"])).is_equal(["A-L1", "A-R1"])


func test_a_symmetric_pair_close_to_the_center_leans_left() -> void:
	# x=45・55 は (L1,C)・(C,R1) が差の合計 20・釣り合い 10 で同じ（(L1,R1) は差 30）。左右対称にはならず、左を先に詰める
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0, [["a", 45.0], ["b", 55.0]]))
	assert_array(_areas(layout, ["a", "b"])).is_equal(["M-L1", "M-C"])


func test_players_on_the_same_coordinate_keep_the_formation_order() -> void:
	# 同じ x=50 の2人。(L1,C) と (C,R1) は差の合計も釣り合いも同じ。陣形データの順で先の選手を左に置く
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0, [["first", 50.0], ["second", 50.0]]))
	assert_array(_areas(layout, ["first", "second"])).is_equal(["M-L1", "M-C"])


func test_spreading_keeps_the_left_to_right_order_of_the_coordinates() -> void:
	# 中央に3人（x=45・50・55）と大外に1人。左右の並び順は変えない
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0,
			[["right", 55.0], ["left", 45.0], ["wide", 90.0], ["middle", 50.0]]))
	assert_array(_areas(layout, ["left", "middle", "right", "wide"])).is_equal(["M-L1", "M-C", "M-R1", "M-R2"])


func test_a_zone_without_overlap_keeps_the_areas_of_the_coordinates() -> void:
	# x=36 は d=14 で C。置き直すとレーンの中心 30（L1）のほうが近いが、重なりが無いので座標のエリアのまま
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0, [["near_center", 36.0], ["wide", 90.0]]))
	assert_array(_areas(layout, ["near_center", "wide"])).is_equal(["M-C", "M-R2"])


func test_coordinates_that_are_not_numbers_are_left_as_they_are() -> void:
	# 読み込み（ContentRepository）は座標が有限で 0〜100 かを確かめるので、通常は起きない。
	# 起きても、置き方を比べられない（差が NaN）ので置き直さず、座標のエリアのまま返す（範囲外を参照しない）
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0, [["a", NAN], ["b", NAN]]))
	var expected: String = BaseLayoutDeriver.area_of(NAN, 50.0).to_key()
	assert_array(_areas(layout, ["a", "b"])).is_equal([expected, expected])


func test_a_zone_with_more_players_than_lanes_is_not_spread() -> void:
	# 6人は1マス1人にできないので、座標のエリアのまま（重なりを残す）
	var spec: Array = [["p1", 10.0], ["p2", 30.0], ["p3", 50.0], ["p4", 50.0], ["p5", 70.0], ["p6", 90.0]]
	var layout: TeamLayout = BaseLayoutDeriver.derive(_formation_with(50.0, spec))
	assert_array(_areas(layout, ["p1", "p2", "p3", "p4", "p5", "p6"])) \
			.is_equal(["M-L2", "M-L1", "M-C", "M-C", "M-R1", "M-R2"])


func test_derive_does_not_change_the_formation() -> void:
	var formation: FormationDef = _sample_formation()
	BaseLayoutDeriver.derive(formation)
	assert_int(formation.players.size()).is_equal(11)
	assert_float(formation.players[5].y).is_equal(100.0 / 3.0)

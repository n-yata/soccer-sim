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
	var layout: TeamLayout = BaseLayoutDeriver.derive(_sample_formation())
	var expected: Dictionary = {
		"lb": "D-L2", "cb1": "D-C", "cb2": "D-C", "rb": "D-R2",
		"lm": "M-L2", "cm1": "M-L1", "cm2": "M-R1", "rm": "M-R2",
		"st1": "A-C", "st2": "A-C",
	}
	for player: PlayerState in layout.players:
		assert_str(player.base_area.to_key()).override_failure_message(player.player_id) \
				.is_equal(expected[player.player_id])
		assert_str(layout.current_area_of(player.player_id).to_key()).is_equal(expected[player.player_id])
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()


func test_derive_does_not_change_the_formation() -> void:
	var formation: FormationDef = _sample_formation()
	BaseLayoutDeriver.derive(formation)
	assert_int(formation.players.size()).is_equal(11)
	assert_float(formation.players[5].y).is_equal(100.0 / 3.0)

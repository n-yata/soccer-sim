## 陣形と配置の値オブジェクト（PlayerSlotDef・FormationDef・PlayerState・TeamLayout・ContentCatalog）のテスト。
extends GdUnitTestSuite


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _players() -> Array[PlayerState]:
	var players: Array[PlayerState] = [
		PlayerState.new("p1", _area("D1-C")),
		PlayerState.new("p2", _area("D1-C")),
		PlayerState.new("p3", _area("M1-L2")),
		PlayerState.new("p4", _area("A1-R1"), _area("A1-C")),
	]
	return players


func test_player_state_is_fixed_only_when_fixed_area_is_set() -> void:
	assert_bool(PlayerState.new("p1", _area("D1-C")).is_fixed()).is_false()
	assert_bool(PlayerState.new("p1", _area("D1-C"), _area("M1-C")).is_fixed()).is_true()


func test_player_state_current_area_defaults_to_the_fixed_or_base_area() -> void:
	# 位置を持ち越す（2026-10-24。1ターン1マス）。省略したら、固定先があれば固定先、なければ基本エリア
	assert_str(PlayerState.new("p1", _area("D1-C")).current_area.to_key()).is_equal("D1-C")
	assert_str(PlayerState.new("p1", _area("D1-C"), _area("M1-C")).current_area.to_key()).is_equal("M1-C")
	var moved := PlayerState.new("p1", _area("D1-C"), null, _area("D1-L1"))
	assert_str(moved.current_area.to_key()).is_equal("D1-L1")
	assert_bool(moved.moved_in_turn).is_false()


func test_player_state_duplicate_deep_copies_the_position_and_the_moved_flag() -> void:
	var player := PlayerState.new("p1", _area("D1-C"), null, _area("D1-L1"))
	player.moved_in_turn = true
	var copy: PlayerState = player.duplicate_deep()
	assert_str(copy.current_area.to_key()).is_equal("D1-L1")
	assert_bool(copy.moved_in_turn).is_true()
	assert_object(copy.current_area).is_not_same(player.current_area)


func test_from_players_puts_every_player_on_the_current_area() -> void:
	var players: Array[PlayerState] = _players()
	players[2].current_area = _area("M1-L1")
	var layout: TeamLayout = TeamLayout.from_players(players)
	assert_str(layout.current_area_of("p1").to_key()).is_equal("D1-C")
	assert_str(layout.current_area_of("p3").to_key()).is_equal("M1-L1")
	# p4 は固定先 A1-C にいる
	assert_str(layout.current_area_of("p4").to_key()).is_equal("A1-C")


func test_at_base_puts_every_player_on_the_base_area() -> void:
	var layout: TeamLayout = TeamLayout.at_base(_players())
	assert_str(layout.current_area_of("p1").to_key()).is_equal("D1-C")
	assert_str(layout.current_area_of("p3").to_key()).is_equal("M1-L2")
	# at_base は固定の有無を見ない（固定先へ動かすのはアルゴリズム2）
	assert_str(layout.current_area_of("p4").to_key()).is_equal("A1-R1")


func test_current_area_of_unknown_player_is_null() -> void:
	assert_object(TeamLayout.at_base(_players()).current_area_of("nobody")).is_null()


func test_counts_has_all_30_keys_and_sums_to_the_number_of_players() -> void:
	var counts: Dictionary = TeamLayout.at_base(_players()).counts()
	assert_int(counts.size()).is_equal(30)
	var total: int = 0
	for area: PitchArea in PitchArea.all():
		assert_bool(counts.has(area.to_key())).override_failure_message(area.to_key()).is_true()
		total += counts[area.to_key()] as int
	assert_int(total).is_equal(4)
	assert_int(counts["D1-C"] as int).is_equal(2)
	assert_int(counts["M1-L2"] as int).is_equal(1)
	assert_int(counts["A1-R1"] as int).is_equal(1)
	assert_int(counts["M1-C"] as int).is_equal(0)


func test_counts_follow_the_current_area_not_the_base_area() -> void:
	var current: Dictionary = {
		"p1": _area("D1-C"), "p2": _area("M1-C"), "p3": _area("M1-L1"), "p4": _area("A1-C"),
	}
	var layout := TeamLayout.new(_players(), current)
	assert_int(layout.count_at(_area("D1-C"))).is_equal(1)
	assert_int(layout.count_at(_area("M1-C"))).is_equal(1)
	assert_int(layout.count_at(_area("M1-L2"))).is_equal(0)
	assert_int(layout.count_at(_area("M1-L1"))).is_equal(1)
	assert_int(layout.count_at(_area("A1-R1"))).is_equal(0)
	assert_int(layout.count_at(_area("A1-C"))).is_equal(1)


func test_duplicate_deep_does_not_share_players_or_areas() -> void:
	var original: TeamLayout = TeamLayout.at_base(_players())
	var copy: TeamLayout = original.duplicate_deep()
	copy.players[0].fixed_area = _area("A1-C")
	copy.players.append(PlayerState.new("p5", _area("D1-L2")))
	assert_bool(original.players[0].is_fixed()).is_false()
	assert_int(original.players.size()).is_equal(4)
	assert_int(copy.count_at(_area("D1-C"))).is_equal(2)
	assert_str(copy.current_area_of("p1").to_key()).is_equal("D1-C")


func test_player_slot_def_detects_goalkeeper_by_position_type() -> void:
	assert_bool(PlayerSlotDef.new("x-gk", "GK", "GK", 1, 50.0, 5.0).is_goalkeeper()).is_true()
	assert_bool(PlayerSlotDef.new("x-cb", "DF", "CB", 4, 35.0, 18.0).is_goalkeeper()).is_false()


func test_content_catalog_finds_formation_by_id() -> void:
	var slots: Array[PlayerSlotDef] = [PlayerSlotDef.new("a-gk", "GK", "GK", 1, 50.0, 5.0)]
	var tags: Array[String] = ["タグ"]
	var formations: Array[FormationDef] = [
		FormationDef.new("a", "A", "説明A", tags, slots),
		FormationDef.new("b", "B", "説明B", [] as Array[String], [] as Array[PlayerSlotDef]),
	]
	var catalog := ContentCatalog.new(formations)
	assert_str(catalog.formation("b").name).is_equal("B")
	assert_str(catalog.formation("a").players[0].id).is_equal("a-gk")
	assert_array(catalog.formation("a").extra_tags).is_equal(["タグ"] as Array[String])
	assert_object(catalog.formation("zzz")).is_null()


func test_formation_def_duplicate_deep_does_not_share_players() -> void:
	var slots: Array[PlayerSlotDef] = [PlayerSlotDef.new("a-gk", "GK", "GK", 1, 50.0, 5.0)]
	var original := FormationDef.new("a", "A", "説明", [] as Array[String], slots)
	var copy: FormationDef = original.duplicate_deep()
	copy.players[0].number = 99
	copy.extra_tags.append("追加")
	assert_int(original.players[0].number).is_equal(1)
	assert_int(original.extra_tags.size()).is_equal(0)


func test_team_layout_does_not_share_input_collections() -> void:
	var players: Array[PlayerState] = _players()
	var current: Dictionary = {"p1": _area("D1-C"), "p2": _area("D1-C"), "p3": _area("M1-L2"), "p4": _area("A1-R1")}
	var layout := TeamLayout.new(players, current)
	players.append(PlayerState.new("p5", _area("D1-C")))
	current["p1"] = _area("A1-C")
	assert_int(layout.players.size()).is_equal(4)
	assert_str(layout.current_area_of("p1").to_key()).is_equal("D1-C")
	assert_int(layout.count_at(_area("D1-C"))).is_equal(2)


func test_count_at_null_is_zero() -> void:
	assert_int(TeamLayout.at_base(_players()).count_at(null)).is_equal(0)


func test_content_catalog_does_not_share_input_and_duplicates_deep() -> void:
	var formations: Array[FormationDef] = [
		FormationDef.new("a", "A", "説明A", [] as Array[String], [] as Array[PlayerSlotDef]),
	]
	var catalog := ContentCatalog.new(formations)
	formations.clear()
	assert_int(catalog.formations.size()).is_equal(1)
	var copy: ContentCatalog = catalog.duplicate_deep()
	copy.formations[0].name = "変更"
	copy.formations.append(FormationDef.new("b", "B", "説明B", [] as Array[String], [] as Array[PlayerSlotDef]))
	assert_str(catalog.formation("a").name).is_equal("A")
	assert_object(catalog.formation("b")).is_null()

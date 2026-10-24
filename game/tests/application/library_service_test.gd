## LibraryService（component-design.md §3.4）のテスト。今は陣形の一覧と基本配置の人数だけ。
extends GdUnitTestSuite


func _library() -> LibraryService:
	return LibraryService.new(ContentRepository.new().load_catalog())


func test_formations_are_the_four_mvp_formations_in_data_order() -> void:
	var ids: Array[String] = []
	for formation: FormationDef in _library().formations():
		ids.append(formation.id)
	assert_array(ids).is_equal(["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"] as Array[String])


func test_formations_returns_a_copy_of_the_list() -> void:
	var library: LibraryService = _library()
	library.formations().clear()
	assert_int(library.formations().size()).is_equal(4)


func test_base_counts_of_4_4_2_match_the_algorithm_1_table() -> void:
	# functional-overview.md アルゴリズム1の表の 4-4-2（列は L2 / L1 / C / R1 / R2）
	# 2026-10-24 から、重なりを1マス1人に散らした値
	var expected: Dictionary = {
		"A": [0, 1, 0, 1, 0],
		"M": [1, 1, 0, 1, 1],
		"D": [1, 1, 0, 1, 1],
	}
	var lanes: Array[String] = ["L2", "L1", "C", "R1", "R2"]
	var counts: Dictionary = _library().base_counts("4-4-2")
	assert_int(counts.size()).is_equal(15)
	for zone: String in expected:
		var row: Array = expected[zone]
		for i: int in lanes.size():
			var key: String = "%s-%s" % [zone, lanes[i]]
			assert_int(counts[key] as int).override_failure_message(key).is_equal(row[i] as int)


func test_base_counts_of_unknown_formation_is_empty() -> void:
	assert_dict(_library().base_counts("5-3-2")).is_empty()


func test_base_counts_of_unknown_formation_reports_an_error() -> void:
	var library: LibraryService = _library()
	await assert_error(func() -> void: library.base_counts("5-3-2")) \
			.is_push_error("LibraryService: 陣形が無い: 5-3-2")


func test_app_library_is_created_on_start_with_four_formations() -> void:
	assert_object(App.library).is_not_null()
	assert_int(App.library.formations().size()).is_equal(4)

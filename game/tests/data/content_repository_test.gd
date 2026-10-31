## ContentRepository（component-design.md §4.1。検証の項目は data-definition.md §3・§3.1）のテスト。
##
## 壊れたデータは、本物の formations.json を1か所だけ変えてテストの中で作る。
## 本物のデータを写した fixture を置くと、本物を直したときに fixture だけが古いまま残るため。
## 1か所だけ変えているので、「その誤りだけが1件出る」ことまで確かめる。
extends GdUnitTestSuite

const REAL_CONTENT_DIR: String = "res://content"
const FORMATIONS_FILE: String = "formations.json"


func _real_data() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(REAL_CONTENT_DIR.path_join(FORMATIONS_FILE))
	return JSON.parse_string(text) as Dictionary


## 陣形以外の静的データ（単純化・チュートリアル・原則・場面問題）は本物を写す（陣形の誤りだけを確かめるため）。
func _copy_other_real_files(dir: String) -> void:
	for file_name: String in [ContentRepository.SIMPLIFICATIONS_FILE, ContentRepository.TUTORIAL_FILE,
			ContentRepository.PRINCIPLES_FILE, ContentRepository.QUIZ_FILE]:
		var copied := FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
		copied.store_string(FileAccess.get_file_as_string(REAL_CONTENT_DIR.path_join(file_name)))
		copied.close()


## data の内容で formations.json を一時ディレクトリに書き、その場所を読む ContentRepository を返す。
func _repository_with(data: Variant, case_name: String) -> ContentRepository:
	var dir: String = create_temp_dir("content_repository/" + case_name)
	_copy_other_real_files(dir)
	var file := FileAccess.open(dir.path_join(FORMATIONS_FILE), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return ContentRepository.new(dir)


func _formation(data: Dictionary, index: int) -> Dictionary:
	return (data["formations"] as Array)[index] as Dictionary


func _player(data: Dictionary, formation_index: int, player_index: int) -> Dictionary:
	return (_formation(data, formation_index)["players"] as Array)[player_index] as Dictionary


## 誤りがちょうど1件で、location を含むこと。さらに load_catalog() が陣形を返さないこと。
func _assert_single_error_at(repository: ContentRepository, location: String) -> void:
	var catalog: ContentCatalog = repository.load_catalog()
	var errors: Array[String] = repository.validation_errors()
	assert_int(errors.size()).override_failure_message("誤り: %s" % [errors]).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0]).contains("formations.json: " + location + ":")
	assert_int(catalog.formations.size()).is_equal(0)


func test_real_formations_have_no_validation_errors() -> void:
	var repository := ContentRepository.new()
	repository.load_catalog()
	assert_array(repository.validation_errors()).is_empty()


func test_real_formations_are_converted_to_four_formations_of_eleven() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var ids: Array[String] = []
	for formation: FormationDef in catalog.formations:
		ids.append(formation.id)
		assert_int(formation.players.size()).override_failure_message(formation.id).is_equal(11)
	assert_array(ids).is_equal(["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"] as Array[String])


func test_real_formation_values_are_converted_with_types() -> void:
	var formation: FormationDef = ContentRepository.new().load_catalog().formation("4-4-2")
	assert_str(formation.name).is_equal("4-4-2")
	assert_str(formation.description).is_not_empty()
	assert_array(formation.extra_tags).is_equal(["ライン間が空く"] as Array[String])
	var left_back: PlayerSlotDef = formation.players[1]
	assert_str(left_back.id).is_equal("4-4-2-lb")
	assert_str(left_back.position_type).is_equal("DF")
	assert_str(left_back.label).is_equal("LB")
	assert_int(left_back.number).is_equal(3)
	assert_float(left_back.x).is_equal(15.0)
	assert_float(left_back.y).is_equal(20.0)
	assert_bool(formation.players[0].is_goalkeeper()).is_true()


func test_validation_errors_loads_when_not_loaded_yet() -> void:
	var data: Dictionary = _real_data()
	data.erase("format_version")
	var repository: ContentRepository = _repository_with(data, "lazy")
	assert_int(repository.validation_errors().size()).is_equal(1)


func test_missing_file_is_an_error() -> void:
	var missing_dir: String = create_temp_dir("content_repository/missing")
	_copy_other_real_files(missing_dir)
	var repository := ContentRepository.new(missing_dir)
	assert_int(repository.load_catalog().formations.size()).is_equal(0)
	assert_int(repository.validation_errors().size()).is_equal(1)


func test_broken_json_is_an_error() -> void:
	var dir: String = create_temp_dir("content_repository/broken_json")
	_copy_other_real_files(dir)
	var file := FileAccess.open(dir.path_join(FORMATIONS_FILE), FileAccess.WRITE)
	file.store_string("{\"format_version\": 1, \"formations\": [")
	file.close()
	var repository := ContentRepository.new(dir)
	assert_int(repository.load_catalog().formations.size()).is_equal(0)
	assert_int(repository.validation_errors().size()).is_equal(1)


func test_top_level_must_be_an_object() -> void:
	_assert_single_error_at(_repository_with([1, 2], "not_object"), "(最上位)")


func test_missing_format_version_is_an_error() -> void:
	var data: Dictionary = _real_data()
	data.erase("format_version")
	_assert_single_error_at(_repository_with(data, "no_version"), "format_version")


func test_unknown_format_version_is_an_error() -> void:
	var data: Dictionary = _real_data()
	data["format_version"] = 2
	_assert_single_error_at(_repository_with(data, "version_2"), "format_version")


func test_formation_count_must_be_four() -> void:
	var data: Dictionary = _real_data()
	(data["formations"] as Array).pop_back()
	_assert_single_error_at(_repository_with(data, "three_formations"), "formations")


func test_duplicate_formation_id_is_an_error() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 1)["id"] = "4-4-2"
	# 選手 ID は変えていないので、陣形 ID の重複だけが出る
	_assert_single_error_at(_repository_with(data, "duplicate_formation_id"), "formations[1].id")


func test_formation_id_format_is_checked() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 0)["id"] = "4 4 2"
	_assert_single_error_at(_repository_with(data, "formation_id_format"), "formations[0].id")


func test_name_length_is_checked() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 2)["name"] = ""
	_assert_single_error_at(_repository_with(data, "empty_name"), "formations[2].name")
	data = _real_data()
	_formation(data, 2)["name"] = "x".repeat(21)
	_assert_single_error_at(_repository_with(data, "long_name"), "formations[2].name")


func test_description_length_is_checked() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 3)["description"] = "あ".repeat(201)
	_assert_single_error_at(_repository_with(data, "long_description"), "formations[3].description")


func test_extra_tags_must_be_strings() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 0)["extra_tags"] = ["ライン間が空く", 3]
	_assert_single_error_at(_repository_with(data, "tag_not_string"), "formations[0].extra_tags[1]")


func test_player_count_must_be_eleven() -> void:
	var data: Dictionary = _real_data()
	(_formation(data, 1)["players"] as Array).pop_back()
	_assert_single_error_at(_repository_with(data, "ten_players"), "formations[1].players")


func test_exactly_one_goalkeeper_is_required() -> void:
	var data: Dictionary = _real_data()
	_player(data, 0, 2)["type"] = "GK"
	_assert_single_error_at(_repository_with(data, "two_goalkeepers"), "formations[0].players")
	data = _real_data()
	_player(data, 0, 0)["type"] = "DF"
	_assert_single_error_at(_repository_with(data, "no_goalkeeper"), "formations[0].players")


func test_player_id_must_be_unique_across_formations() -> void:
	var data: Dictionary = _real_data()
	_player(data, 1, 0)["id"] = "4-4-2-gk"
	_assert_single_error_at(_repository_with(data, "duplicate_player_id"), "formations[1].players[0].id")


func test_player_id_format_is_checked() -> void:
	var data: Dictionary = _real_data()
	_player(data, 0, 4)["id"] = "4-4-2/rb"
	_assert_single_error_at(_repository_with(data, "player_id_format"), "formations[0].players[4].id")


func test_player_type_must_be_known() -> void:
	var data: Dictionary = _real_data()
	_player(data, 2, 5)["type"] = "WG"
	_assert_single_error_at(_repository_with(data, "unknown_type"), "formations[2].players[5].type")


func test_label_length_is_checked() -> void:
	var data: Dictionary = _real_data()
	_player(data, 3, 1)["label"] = "LCBX1"
	_assert_single_error_at(_repository_with(data, "long_label"), "formations[3].players[1].label")


func test_number_must_be_unique_in_formation() -> void:
	var data: Dictionary = _real_data()
	_player(data, 0, 2)["number"] = 3
	_assert_single_error_at(_repository_with(data, "duplicate_number"), "formations[0].players[2].number")


func test_number_must_be_integer_from_1_to_99() -> void:
	for invalid: Variant in [0, 100, 7.5, "7"]:
		var data: Dictionary = _real_data()
		_player(data, 1, 3)["number"] = invalid
		_assert_single_error_at(_repository_with(data, "number_%s" % str(invalid).replace(".", "_")),
				"formations[1].players[3].number")


func test_coordinates_must_be_numbers_from_0_to_100() -> void:
	for invalid: Variant in [-0.5, 100.5, "50"]:
		var data: Dictionary = _real_data()
		_player(data, 2, 7)["x"] = invalid
		_assert_single_error_at(_repository_with(data, "x_%s" % str(invalid).replace(".", "_")),
				"formations[2].players[7].x")
	var data_y: Dictionary = _real_data()
	_player(data_y, 2, 7)["y"] = 101
	_assert_single_error_at(_repository_with(data_y, "y_101"), "formations[2].players[7].y")


func test_boundary_values_are_accepted() -> void:
	var data: Dictionary = _real_data()
	_player(data, 0, 1)["x"] = 0
	_player(data, 0, 1)["y"] = 100
	_player(data, 0, 2)["number"] = 99
	_formation(data, 0)["name"] = "x".repeat(20)
	_player(data, 0, 3)["label"] = "ABCD"
	var repository: ContentRepository = _repository_with(data, "boundaries")
	repository.load_catalog()
	assert_array(repository.validation_errors()).is_empty()


func test_formation_id_must_be_one_of_the_mvp_formations() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 3)["id"] = "5-3-2"
	_assert_single_error_at(_repository_with(data, "unknown_formation_id"), "formations[3].id")


func test_format_version_must_be_a_number() -> void:
	var data: Dictionary = _real_data()
	data["format_version"] = "1"
	_assert_single_error_at(_repository_with(data, "version_string"), "format_version")


func test_formations_must_be_an_array() -> void:
	var data: Dictionary = _real_data()
	data["formations"] = {"4-4-2": {}}
	_assert_single_error_at(_repository_with(data, "formations_object"), "formations")


func test_each_formation_must_be_an_object() -> void:
	var data: Dictionary = _real_data()
	(data["formations"] as Array)[2] = "4-2-3-1"
	_assert_single_error_at(_repository_with(data, "formation_string"), "formations[2]")


func test_players_must_be_an_array() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 1)["players"] = "11人"
	_assert_single_error_at(_repository_with(data, "players_string"), "formations[1].players")


func test_each_player_must_be_an_object() -> void:
	var data: Dictionary = _real_data()
	(_formation(data, 0)["players"] as Array)[10] = 9
	_assert_single_error_at(_repository_with(data, "player_number_only"), "formations[0].players[10]")


func test_extra_tags_must_be_an_array() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 0)["extra_tags"] = "ライン間が空く"
	_assert_single_error_at(_repository_with(data, "tags_string"), "formations[0].extra_tags")


func test_empty_description_and_label_are_errors() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 1)["description"] = ""
	_assert_single_error_at(_repository_with(data, "empty_description"), "formations[1].description")
	data = _real_data()
	_player(data, 1, 2)["label"] = ""
	_assert_single_error_at(_repository_with(data, "empty_label"), "formations[1].players[2].label")


func test_coordinate_beyond_json_range_is_an_error() -> void:
	var dir: String = create_temp_dir("content_repository/infinite_x")
	var text: String = FileAccess.get_file_as_string(REAL_CONTENT_DIR.path_join(FORMATIONS_FILE))
	# 4-4-2 の GK の x を、JSON で表せる範囲を超える数にする（Godot の JSON は inf として読む）。
	# inf は範囲の比較でも弾かれるため、このテストは実装の is_finite の確認が無くても通る
	# （変異で確かめた）。is_finite が守るのは NaN だが、Godot の JSON は NaN を作れないので、ここでは試せない
	# 「範囲外の数が入らないこと」を確かめるテストとして置く
	var broken: String = text.replace("\"id\": \"4-4-2-gk\", \"type\": \"GK\", \"label\": \"GK\", \"number\": 1, \"x\": 50,",
			"\"id\": \"4-4-2-gk\", \"type\": \"GK\", \"label\": \"GK\", \"number\": 1, \"x\": 1e999,")
	assert_str(broken).is_not_equal(text)
	_copy_other_real_files(dir)
	var file := FileAccess.open(dir.path_join(FORMATIONS_FILE), FileAccess.WRITE)
	file.store_string(broken)
	file.close()
	_assert_single_error_at(ContentRepository.new(dir), "formations[0].players[0].x")


func test_upper_boundary_lengths_are_accepted() -> void:
	var data: Dictionary = _real_data()
	_formation(data, 2)["description"] = "あ".repeat(200)
	var repository: ContentRepository = _repository_with(data, "description_200")
	repository.load_catalog()
	assert_array(repository.validation_errors()).is_empty()

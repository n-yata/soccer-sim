## SuspendedMatchStore（component-design.md §4.3）のテスト。一時ディレクトリに保存し、ファイルを直接置いて壊れた場合を作る。
extends GdUnitTestSuite

var _catalog: ContentCatalog
var _rules: MatchRuleConfig


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	_rules = ConfigRepository.new().match_rules()


func _store(case_name: String) -> SuspendedMatchStore:
	return SuspendedMatchStore.new(_catalog, _rules, create_temp_dir("suspended_store/" + case_name))


func _path(case_name: String) -> String:
	return create_temp_dir("suspended_store/" + case_name).path_join(SuspendedMatchStore.FILE_NAME)


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## 何ターンか進めた試合の状態
func _state(turns: int) -> MatchState:
	var controller: MatchController = ScreenTestHelper.new_controller(0, func(_s: AppScreens.Id, _p: Dictionary) -> void: pass)
	controller.start_match(ScreenTestHelper.user_setup())
	for step: int in range(turns):
		if controller.state().stage != GameEnums.MatchStage.TURN:
			break
		controller.submit_turn(ScreenTestHelper.forward_choice(controller.user_options()))
		controller.continue_after_reveal()
	return controller.state()


func test_nothing_saved_is_none() -> void:
	var load: SuspendedLoad = _store("none").load()
	assert_int(load.status).is_equal(SuspendedLoad.Status.NONE)
	assert_object(load.state).is_null()


func test_saved_state_is_read_back() -> void:
	var store: SuspendedMatchStore = _store("saved")
	var state: MatchState = _state(3)
	assert_bool(store.save(state)).is_true()
	var load: SuspendedLoad = store.load()
	assert_int(load.status).is_equal(SuspendedLoad.Status.OK)
	assert_str(SuspendedMatchEncoder.to_json(load.state)).is_equal(SuspendedMatchEncoder.to_json(state))


func test_a_later_save_overwrites_the_earlier_one() -> void:
	var store: SuspendedMatchStore = _store("overwrite")
	store.save(_state(1))
	var later: MatchState = _state(4)
	store.save(later)
	assert_int(store.load().state.turn_records.size()).is_equal(later.turn_records.size())


func test_not_json_newer_version_and_out_of_range_are_corrupted() -> void:
	var valid: Dictionary = SuspendedMatchEncoder.encode(_state(2))
	var newer: Dictionary = valid.duplicate(true)
	newer["format_version"] = 2
	var bad_area: Dictionary = valid.duplicate(true)
	bad_area["match"]["ball_area"] = "Z9-C"
	var cases: Dictionary = {"not_json": "{broken", "newer": JSON.stringify(newer), "bad_area": JSON.stringify(bad_area),
			"empty": ""}
	for case_name: String in cases:
		var path: String = _path(case_name)
		_put(path, cases[case_name] as String)
		var store := SuspendedMatchStore.new(_catalog, _rules, path.get_base_dir())
		var load: SuspendedLoad = store.load()
		assert_int(load.status).override_failure_message(case_name).is_equal(SuspendedLoad.Status.CORRUPTED)
		assert_object(load.state).override_failure_message(case_name).is_null()


func test_a_broken_main_file_falls_back_to_the_bak_left_by_an_interrupted_write() -> void:
	var path: String = _path("bak")
	var state: MatchState = _state(2)
	_put(path, "{broken")
	_put(path + SaveFileIO.BAK_SUFFIX, SuspendedMatchEncoder.to_json(state))
	var load: SuspendedLoad = SuspendedMatchStore.new(_catalog, _rules, path.get_base_dir()).load()
	assert_int(load.status).is_equal(SuspendedLoad.Status.OK)
	assert_int(load.state.turn_records.size()).is_equal(state.turn_records.size())


func test_only_a_tmp_left_is_none_and_the_tmp_is_removed() -> void:
	var path: String = _path("tmp")
	_put(path + SaveFileIO.TMP_SUFFIX, SuspendedMatchEncoder.to_json(_state(1)))
	var load: SuspendedLoad = SuspendedMatchStore.new(_catalog, _rules, path.get_base_dir()).load()
	assert_int(load.status).is_equal(SuspendedLoad.Status.NONE)
	assert_bool(FileAccess.file_exists(path + SaveFileIO.TMP_SUFFIX)).is_false()


func test_delete_leaves_nothing_to_load() -> void:
	var store: SuspendedMatchStore = _store("delete")
	store.save(_state(1))
	assert_bool(store.delete()).is_true()
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)


func test_saving_into_a_missing_directory_fails() -> void:
	var store := SuspendedMatchStore.new(_catalog, _rules, "user://no_such_dir_for_store/x")
	assert_bool(store.save(_state(1))).is_false()

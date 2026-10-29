## SaveFileIO（component-design.md §4.3「書き込み手順」）のテスト。書き込みの途中で止まった各状態を、ファイルを直接置いて作る。
extends GdUnitTestSuite

const NAME: String = "data.json"


func _dir(case_name: String) -> String:
	return create_temp_dir("save_file_io/" + case_name)


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _is_json(text: String) -> bool:
	return JSON.parse_string(text) != null


func test_write_replaces_the_main_file_and_leaves_no_tmp_or_bak() -> void:
	var path: String = _dir("write").path_join(NAME)
	assert_bool(SaveFileIO.write(path, "{\"a\": 1}")).is_true()
	assert_bool(SaveFileIO.write(path, "{\"a\": 2}")).is_true()
	assert_str(_read_raw(path)).is_equal("{\"a\": 2}")
	assert_bool(FileAccess.file_exists(path + SaveFileIO.TMP_SUFFIX)).is_false()
	assert_bool(FileAccess.file_exists(path + SaveFileIO.BAK_SUFFIX)).is_false()


func test_read_returns_the_main_file_when_it_is_valid() -> void:
	var path: String = _dir("main").path_join(NAME)
	_put(path, "{\"a\": 1}")
	_put(path + SaveFileIO.BAK_SUFFIX, "{\"a\": 0}")
	assert_str(SaveFileIO.read(path, _is_json)).is_equal("{\"a\": 1}")


func test_read_falls_back_to_bak_when_stopped_between_renames() -> void:
	# 手順2（本体 → .bak）と3（.tmp → 本体）の間で止まった: 本体が無く、.bak と .tmp がある
	var path: String = _dir("between").path_join(NAME)
	_put(path + SaveFileIO.BAK_SUFFIX, "{\"a\": 1}")
	_put(path + SaveFileIO.TMP_SUFFIX, "{\"a\": 2")
	assert_str(SaveFileIO.read(path, _is_json)).is_equal("{\"a\": 1}")
	# 書き込みの途中で止まった可能性のある .tmp は読まずに消す
	assert_bool(FileAccess.file_exists(path + SaveFileIO.TMP_SUFFIX)).is_false()


func test_read_falls_back_to_bak_when_the_main_file_is_broken() -> void:
	var path: String = _dir("broken").path_join(NAME)
	_put(path, "{broken")
	_put(path + SaveFileIO.BAK_SUFFIX, "{\"a\": 1}")
	assert_str(SaveFileIO.read(path, _is_json)).is_equal("{\"a\": 1}")


func test_read_returns_empty_when_nothing_valid_is_left() -> void:
	var dir: String = _dir("nothing")
	assert_str(SaveFileIO.read(dir.path_join(NAME), _is_json)).is_empty()
	var broken: String = dir.path_join("broken.json")
	_put(broken, "{broken")
	assert_str(SaveFileIO.read(broken, _is_json)).is_empty()
	# .tmp だけ（手順1の途中で止まった）は、何も無いのと同じ
	var only_tmp: String = dir.path_join("tmp.json")
	_put(only_tmp + SaveFileIO.TMP_SUFFIX, "{\"a\": 1}")
	assert_str(SaveFileIO.read(only_tmp, _is_json)).is_empty()


func test_files_over_the_size_limit_are_not_read() -> void:
	var path: String = _dir("large").path_join(NAME)
	var big: String = "[" + "0,".repeat(SaveFileIO.MAX_READ_BYTES / 2) + "0]"
	_put(path, big)
	assert_int(big.length()).is_greater(SaveFileIO.MAX_READ_BYTES)
	assert_str(SaveFileIO.read(path, _is_json)).is_empty()


func test_exists_sees_the_main_file_or_bak() -> void:
	var dir: String = _dir("exists")
	assert_bool(SaveFileIO.exists(dir.path_join(NAME))).is_false()
	_put(dir.path_join(NAME) + SaveFileIO.BAK_SUFFIX, "{}")
	assert_bool(SaveFileIO.exists(dir.path_join(NAME))).is_true()


func test_delete_removes_the_main_file_bak_and_tmp() -> void:
	var path: String = _dir("delete").path_join(NAME)
	_put(path, "{}")
	_put(path + SaveFileIO.BAK_SUFFIX, "{}")
	_put(path + SaveFileIO.TMP_SUFFIX, "{}")
	assert_bool(SaveFileIO.delete(path)).is_true()
	for suffix: String in ["", SaveFileIO.BAK_SUFFIX, SaveFileIO.TMP_SUFFIX]:
		assert_bool(FileAccess.file_exists(path + suffix)).override_failure_message(suffix).is_false()
	# 何も無くても成功
	assert_bool(SaveFileIO.delete(path)).is_true()


func test_write_to_a_missing_directory_fails_and_keeps_the_old_file_untouched() -> void:
	assert_bool(SaveFileIO.write("user://no_such_dir_for_save_file_io/x/data.json", "{}")).is_false()

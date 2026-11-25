## QuizAnswerStore（component-design.md §4.3・data-definition.md §2.3）のテスト。一時ディレクトリに保存し、ファイルを直接置いて
## 壊れた場合・新しい版・上限を作る。退避の細かい手順（.bak・同じ秒の退避・退避できない場合）は、同じ VersionedJsonFile を使う
## RecordStore のテストで確かめる。
## gdUnit の一時ディレクトリはスイートの中でテストごとに消えないので、テストごとに別の名前を使う。
extends GdUnitTestSuite


func _dir(case_name: String) -> String:
	return create_temp_dir("quiz_answer_store/" + case_name)


func _path(case_name: String) -> String:
	return _dir(case_name).path_join(QuizAnswerStore.FILE_NAME)


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _moved_aside(case_name: String) -> Array[String]:
	var moved: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_dir(case_name)):
		if file_name.begins_with(QuizAnswerStore.FILE_NAME + SaveFileIO.CORRUPT_INFIX):
			moved.append(file_name)
	return moved


func _item(question_id: String = "lg1-switch", correct: Variant = true,
		answered_at: Variant = "2026-10-31T10:00:00") -> Dictionary:
	return {"question_id": question_id, "correct": correct, "answered_at": answered_at}


func _root(items: Array) -> String:
	return JSON.stringify({"format_version": QuizAnswerStore.FORMAT_VERSION, "answers": items})


func test_nothing_saved_is_empty() -> void:
	var store := QuizAnswerStore.new(_dir("empty"))
	assert_array(store.load_all()).is_empty()
	assert_int(store.load_state()).is_equal(VersionedJsonFile.LoadState.EMPTY)


func test_appended_answers_are_read_back_in_the_order_answered() -> void:
	var case_name: String = "append"
	var store := QuizAnswerStore.new(_dir(case_name))
	assert_bool(store.append(QuizAnswer.new("lg1-switch", false, "2026-10-31T10:00:00"))).is_true()
	assert_bool(store.append(QuizAnswer.new("lg1-switch", true, "2026-10-31T10:01:00"))).is_true()
	# 別のストアで読み直しても同じ（ファイルに書けている）
	var answers: Array[QuizAnswer] = QuizAnswerStore.new(_dir(case_name)).load_all()
	assert_int(answers.size()).is_equal(2)
	assert_str(answers[0].question_id).is_equal("lg1-switch")
	assert_bool(answers[0].correct).is_false()
	assert_str(answers[0].answered_at).is_equal("2026-10-31T10:00:00")
	assert_bool(answers[1].correct).is_true()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path(case_name))) as Dictionary
	assert_int(int(saved["format_version"])).is_equal(QuizAnswerStore.FORMAT_VERSION)


## 読んだ配列を書き換えても、ストアが覚えている値は変わらない
func test_the_loaded_array_is_a_copy() -> void:
	var store := QuizAnswerStore.new(_dir("copy"))
	store.append(QuizAnswer.new("lg1-switch", true, "2026-10-31T10:00:00"))
	store.load_all().clear()
	assert_int(store.load_all().size()).is_equal(1)


func test_over_the_count_limit_drops_the_oldest() -> void:
	var case_name: String = "limit"
	var items: Array = []
	for index: int in range(QuizAnswerStore.MAX_ANSWERS):
		items.append(_item("q-%d" % index))
	_put(_path(case_name), _root(items))
	var store := QuizAnswerStore.new(_dir(case_name))
	assert_bool(store.append(QuizAnswer.new("newest", true, "2026-10-31T11:00:00"))).is_true()
	var answers: Array[QuizAnswer] = store.load_all()
	assert_int(answers.size()).is_equal(QuizAnswerStore.MAX_ANSWERS)
	assert_str(answers[0].question_id).is_equal("q-1")
	assert_str(answers.back().question_id).is_equal("newest")


## 型・範囲から外れた項目が1つでもあれば、ファイル全体を破損として退避し、空として扱う
func test_a_bad_field_makes_the_file_corrupted() -> void:
	var cases: Dictionary = {
		"bad_id": _item("bad id!"),
		"bad_correct": _item("lg1-switch", "yes"),
		"bad_time": _item("lg1-switch", true, "2026/10/31 10:00"),
		"missing_time": {"question_id": "lg1-switch", "correct": true},
	}
	for case_name: String in cases:
		_put(_path(case_name), _root([_item(), cases[case_name]]))
		var store := QuizAnswerStore.new(_dir(case_name))
		assert_array(store.load_all()).override_failure_message(case_name).is_empty()
		assert_int(store.load_state()).override_failure_message(case_name).is_equal(VersionedJsonFile.LoadState.CORRUPTED)
		assert_array(_moved_aside(case_name)).override_failure_message(case_name).has_size(1)
		assert_array(store.errors()).override_failure_message(case_name).is_not_empty()


func test_after_a_corrupted_file_the_next_answer_starts_a_new_file() -> void:
	var case_name: String = "corrupted_append"
	_put(_path(case_name), "{ not json")
	var store := QuizAnswerStore.new(_dir(case_name))
	assert_bool(store.append(QuizAnswer.new("lg2-cover", true, "2026-10-31T10:00:00"))).is_true()
	assert_int(store.load_all().size()).is_equal(1)
	assert_int(store.load_state()).is_equal(VersionedJsonFile.LoadState.OK)
	assert_array(_moved_aside(case_name)).has_size(1)


func test_a_newer_version_is_read_as_empty_and_never_overwritten() -> void:
	var case_name: String = "newer"
	var newer: String = JSON.stringify({"format_version": QuizAnswerStore.FORMAT_VERSION + 1, "answers": "future"})
	_put(_path(case_name), newer)
	var store := QuizAnswerStore.new(_dir(case_name))
	assert_array(store.load_all()).is_empty()
	assert_int(store.load_state()).is_equal(VersionedJsonFile.LoadState.NEWER_VERSION)
	assert_bool(store.append(QuizAnswer.new("lg1-switch", true, "2026-10-31T10:00:00"))).is_false()
	assert_str(FileAccess.get_file_as_string(_path(case_name))).is_equal(newer)
	assert_array(_moved_aside(case_name)).is_empty()


## 件数の上限まで、いちばん長い回答（問題 ID 40文字）を書いても、読み込みの上限（SaveFileIO.MAX_READ_BYTES）に収まる
## （収まらないと、書けるのに次の起動で読めないファイルになる。項目や ID の長さを変えたら、ここで気づく）
func test_a_full_file_of_the_longest_answers_still_fits_the_read_limit() -> void:
	var longest: String = JSON.stringify(_item("a".repeat(40), false, "2026-10-31T10:00:00"))
	var header: String = _root([])
	var full_size: int = header.length() + (longest.length() + 1) * QuizAnswerStore.MAX_ANSWERS
	assert_int(full_size).is_less(SaveFileIO.MAX_READ_BYTES)

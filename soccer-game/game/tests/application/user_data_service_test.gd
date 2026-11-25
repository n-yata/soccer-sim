## UserDataService（component-design.md §3.4）の戦績のテスト。本物の RecordStore に一時ディレクトリで保存する。
## 一時ディレクトリはスイートの中でテストごとに消えないので、テストごとに別の名前を使う。
extends GdUnitTestSuite

var _rules: MatchRuleConfig
var _failures: Array[int] = []


func before() -> void:
	_rules = ConfigRepository.new().match_rules()


func before_test() -> void:
	_failures.clear()


func _dir(case_name: String) -> String:
	return create_temp_dir("user_data/" + case_name)


func _on_failed(kind: AppScreens.StorageErrorKind) -> void:
	_failures.append(kind)


func _service(case_name: String) -> UserDataService:
	var service := UserDataService.new(RecordStore.new(_rules, _dir(case_name)), SettingsStore.new(_dir(case_name)),
			QuizAnswerStore.new(_dir(case_name)), [])
	service.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: _failures.append(kind))
	return service


func _put(case_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_dir(case_name).path_join(RecordStore.FILE_NAME), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _record(id_number: int, finished_at: String, score_user: int, score_cpu: int) -> MatchRecord:
	var record := MatchRecord.new()
	record.match_id = "20261029-100000-%04d" % id_number
	record.record_id = record.match_id
	record.finished_at = finished_at
	record.score_user = score_user
	record.score_cpu = score_cpu
	record.result = MatchRecord.result_of(score_user, score_cpu)
	var setup := TeamSetup.new("4-3-3", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION))
	record.timeline.append(RecordPeriod.new(1, 1, setup, setup.duplicate_deep()))
	return record


func _ids(records: Array[MatchRecord]) -> Array[String]:
	var ids: Array[String] = []
	for record: MatchRecord in records:
		ids.append(record.match_id.right(4))
	return ids


func test_records_are_newest_first_and_ties_put_the_later_recorded_first() -> void:
	var service: UserDataService = _service("order")
	service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))
	service.append_record(_record(2, "2026-10-29T12:00:00", 1, 0))
	# やり直しで遅れて記録された試合（日時は古い）
	service.append_record(_record(3, "2026-10-29T11:00:00", 1, 0))
	service.append_record(_record(4, "2026-10-29T12:00:00", 1, 0))
	assert_array(_ids(service.records())).is_equal(["0004", "0002", "0003", "0001"])


func test_records_are_read_back_by_a_new_service() -> void:
	_service("persist").append_record(_record(7, "2026-10-29T10:00:00", 2, 2))
	var records: Array[MatchRecord] = _service("persist").records()
	assert_array(_ids(records)).is_equal(["0007"])
	assert_int(records[0].result).is_equal(GameEnums.MatchResult.DRAW)


func test_totals_count_wins_draws_and_losses() -> void:
	var service: UserDataService = _service("totals")
	assert_dict(service.totals()).is_equal({"win": 0, "draw": 0, "lose": 0})
	service.append_record(_record(1, "2026-10-29T10:00:00", 2, 1))
	service.append_record(_record(2, "2026-10-29T10:10:00", 3, 0))
	service.append_record(_record(3, "2026-10-29T10:20:00", 1, 1))
	service.append_record(_record(4, "2026-10-29T10:30:00", 0, 1))
	assert_dict(service.totals()).is_equal({"win": 2, "draw": 1, "lose": 1})


func test_appending_the_same_match_twice_keeps_one() -> void:
	var service: UserDataService = _service("twice")
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 2, 1))).is_true()
	assert_bool(service.append_record(_record(1, "2026-10-29T10:05:00", 2, 1))).is_true()
	assert_int(service.records().size()).is_equal(1)
	assert_dict(service.totals()).is_equal({"win": 1, "draw": 0, "lose": 0})


func test_the_returned_list_is_a_copy() -> void:
	var service: UserDataService = _service("copy")
	service.append_record(_record(1, "2026-10-29T10:00:00", 2, 1))
	service.records().clear()
	assert_int(service.records().size()).is_equal(1)


func test_a_corrupted_file_is_reported_once_and_reads_as_empty() -> void:
	_put("corrupted", "{ broken")
	var service: UserDataService = _service("corrupted")
	assert_array(service.records()).is_empty()
	assert_dict(service.totals()).is_equal({"win": 0, "draw": 0, "lose": 0})
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_LOAD])


## 新しい版は読んだときに1回だけ知らせる（保存を断るたびに重ねない）
func test_a_newer_version_is_reported_once_and_appending_is_refused() -> void:
	_put("newer", JSON.stringify({"format_version": MatchRecordCodec.FORMAT_VERSION + 1, "records": []}))
	var service: UserDataService = _service("newer")
	assert_array(service.records()).is_empty()
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))).is_false()
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))).is_false()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_NEWER])
	assert_array(service.records()).is_empty()


## 保存の失敗が続く間は最初の1回だけ知らせ、成功したら戻す（次の失敗はまた知らせる）
func test_repeated_save_failures_are_reported_once_until_a_save_works() -> void:
	var blocked: String = _dir("repeat").path_join("records")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var service := UserDataService.new(RecordStore.new(_rules, blocked), SettingsStore.new(blocked),
			QuizAnswerStore.new(blocked), [])
	service.storage_failed.connect(_on_failed)
	service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))
	service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])
	DirAccess.remove_absolute(blocked)
	DirAccess.make_dir_recursive_absolute(blocked)
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))).is_true()
	DirAccess.remove_absolute(blocked.path_join(RecordStore.FILE_NAME))
	DirAccess.remove_absolute(blocked)
	file = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	service.append_record(_record(2, "2026-10-29T10:10:00", 1, 0))
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE,
			AppScreens.StorageErrorKind.USER_DATA_SAVE])


## 上限で古い戦績が捨てられたら、持っている一覧と通算も同じだけ減る（再起動後と食い違わない）
func test_records_dropped_at_the_limit_are_dropped_from_the_totals_too() -> void:
	var existing: Array[MatchRecord] = []
	for index: int in range(MatchRecordCodec.MAX_RECORDS):
		existing.append(_record(index, "2026-10-28T10:00:00", 1, 0))
	_put("limit", MatchRecordCodec.to_json(existing))
	var service: UserDataService = _service("limit")
	assert_dict(service.totals()).is_equal({"win": MatchRecordCodec.MAX_RECORDS, "draw": 0, "lose": 0})
	service.append_record(_record(MatchRecordCodec.MAX_RECORDS, "2026-10-29T10:00:00", 0, 1))
	assert_int(service.records().size()).is_equal(MatchRecordCodec.MAX_RECORDS)
	assert_dict(service.totals()).is_equal({"win": MatchRecordCodec.MAX_RECORDS - 1, "draw": 0, "lose": 1})


## 保存先にファイルを置いて、その下にディレクトリを作れなくする（書き込みが失敗する）
func test_a_failed_save_is_reported_and_not_kept() -> void:
	var blocked: String = _dir("blocked").path_join("not_a_dir")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var service := UserDataService.new(RecordStore.new(_rules, blocked), SettingsStore.new(blocked),
			QuizAnswerStore.new(blocked), [])
	service.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: _failures.append(kind))
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))).is_false()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])
	assert_array(service.records()).is_empty()


# --- 設定 ---

func _put_settings(case_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_dir(case_name).path_join(SettingsStore.FILE_NAME), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_settings_start_at_the_defaults_and_are_kept_after_saving() -> void:
	var service: UserDataService = _service("settings")
	var settings: UserSettings = service.settings()
	assert_array([settings.bgm_volume, settings.se_volume, settings.show_hints]).is_equal([0.7, 0.7, true])
	settings.bgm_volume = 0.3
	settings.show_hints = false
	assert_bool(service.save_settings(settings)).is_true()
	var reread: UserSettings = _service("settings").settings()
	assert_array([reread.bgm_volume, reread.show_hints]).is_equal([0.3, false])
	assert_array(_failures).is_empty()


## 受け取った写しを書き換えても、保存するまで持っている値は変わらない
func test_settings_returns_a_copy() -> void:
	var service: UserDataService = _service("settings_copy")
	service.settings().show_hints = false
	assert_bool(service.settings().show_hints).is_true()


func test_a_failed_settings_save_keeps_the_new_values_and_reports_once() -> void:
	var blocked: String = _dir("settings_blocked").path_join("records")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var service := UserDataService.new(RecordStore.new(_rules, blocked), SettingsStore.new(blocked),
			QuizAnswerStore.new(blocked), [])
	service.storage_failed.connect(_on_failed)
	var settings: UserSettings = service.settings()
	settings.se_volume = 0.0
	assert_bool(service.save_settings(settings)).is_false()
	assert_bool(service.save_settings(settings)).is_false()
	assert_float(service.settings().se_volume).is_equal(0.0)
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])


func test_broken_settings_are_reported_once_and_read_as_the_defaults() -> void:
	_put_settings("settings_broken", "[audio]\nbgm_volume=0.1\n")
	var service: UserDataService = _service("settings_broken")
	assert_float(service.settings().bgm_volume).is_equal(UserSettings.DEFAULT_VOLUME)
	service.settings()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_LOAD])


func test_newer_settings_are_reported_once_and_never_saved() -> void:
	_put_settings("settings_newer", "[meta]\nformat_version=2\n")
	var service: UserDataService = _service("settings_newer")
	assert_bool(service.save_settings(service.settings())).is_false()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_NEWER])


func test_mark_tutorial_completed_saves_only_that_flag() -> void:
	var service: UserDataService = _service("tutorial")
	var settings: UserSettings = service.settings()
	settings.bgm_volume = 0.4
	service.save_settings(settings)
	assert_bool(service.mark_tutorial_completed()).is_true()
	var reread: UserSettings = _service("tutorial").settings()
	assert_array([reread.tutorial_completed, reread.bgm_volume]).is_equal([true, 0.4])



# --- 理解度チェックの回答結果 ---

## 本物の場面問題（LG-1〜4 に2問ずつ）で正答状況を数えるサービス
func _quiz_service(case_name: String) -> UserDataService:
	var dir: String = _dir(case_name)
	var service := UserDataService.new(RecordStore.new(_rules, dir), SettingsStore.new(dir), QuizAnswerStore.new(dir),
			ContentRepository.new().load_catalog().quiz_questions)
	service.storage_failed.connect(_on_failed)
	return service


func _answer(question_id: String, correct: bool, minute: int = 0) -> QuizAnswer:
	return QuizAnswer.new(question_id, correct, "2026-10-31T10:%02d:00" % minute)


func test_with_no_answers_every_goal_is_unanswered_with_its_question_count() -> void:
	var progress: Dictionary = _quiz_service("quiz_empty").quiz_progress()
	assert_array(progress.keys()).is_equal(["LG-1", "LG-2", "LG-3", "LG-4"])
	for goal_id: String in progress:
		assert_dict(progress[goal_id] as Dictionary).is_equal({"answered": 0, "correct": 0, "total": 2})
	assert_array(_failures).is_empty()


## 同じ問題に何度も答えたら、最後の回答だけで数える（screen-09-quiz.md「正答状況の数え方」）
func test_progress_counts_the_latest_answer_of_each_question() -> void:
	var service: UserDataService = _quiz_service("quiz_latest")
	assert_bool(service.save_quiz_answer(_answer("lg1-half-space", false, 0))).is_true()
	service.save_quiz_answer(_answer("lg1-half-space", true, 1))
	# 2問とも不正解の後に正解（最初の回答で数えると正解0になる）
	service.save_quiz_answer(_answer("lg1-switch", false, 2))
	service.save_quiz_answer(_answer("lg1-switch", true, 3))
	service.save_quiz_answer(_answer("lg3-counter", true, 4))
	service.save_quiz_answer(_answer("lg3-counter", false, 5))
	var progress: Dictionary = service.quiz_progress()
	assert_dict(progress["LG-1"] as Dictionary).is_equal({"answered": 2, "correct": 2, "total": 2})
	assert_dict(progress["LG-2"] as Dictionary).is_equal({"answered": 0, "correct": 0, "total": 2})
	# 正解の後に不正解なら、最新の不正解で数える
	assert_dict(progress["LG-3"] as Dictionary).is_equal({"answered": 1, "correct": 0, "total": 2})
	# 再起動後（別のサービスで読み直し）も同じ
	assert_dict(_quiz_service("quiz_latest").quiz_progress()).is_equal(progress)


## quiz.json に無い問題（削除した問題）の回答は数えない
func test_answers_to_questions_that_no_longer_exist_are_not_counted() -> void:
	var service: UserDataService = _quiz_service("quiz_removed")
	service.save_quiz_answer(_answer("removed-question", true))
	service.save_quiz_answer(_answer("lg2-cover", true))
	var progress: Dictionary = service.quiz_progress()
	assert_dict(progress["LG-2"] as Dictionary).is_equal({"answered": 1, "correct": 1, "total": 2})
	var answered: int = 0
	for goal_id: String in progress:
		answered += (progress[goal_id] as Dictionary)["answered"] as int
	assert_int(answered).is_equal(1)


func test_broken_answers_are_reported_once_and_read_as_unanswered() -> void:
	var file: FileAccess = FileAccess.open(_dir("quiz_broken").path_join(QuizAnswerStore.FILE_NAME), FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var service: UserDataService = _quiz_service("quiz_broken")
	assert_int((service.quiz_progress()["LG-1"] as Dictionary)["answered"] as int).is_equal(0)
	service.quiz_progress()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_LOAD])
	# 次の回答は新しいファイルとして書ける
	assert_bool(service.save_quiz_answer(_answer("lg1-switch", true))).is_true()


## 新しい版の回答結果は、未回答として出し、上書きしない（保存は false。通知は読み込みの1回だけ）
func test_newer_answers_are_shown_as_unanswered_and_never_overwritten() -> void:
	var path: String = _dir("quiz_newer").path_join(QuizAnswerStore.FILE_NAME)
	var newer: String = JSON.stringify({"format_version": QuizAnswerStore.FORMAT_VERSION + 1, "answers": []})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(newer)
	file.close()
	var service: UserDataService = _quiz_service("quiz_newer")
	assert_int((service.quiz_progress()["LG-1"] as Dictionary)["answered"] as int).is_equal(0)
	assert_bool(service.save_quiz_answer(_answer("lg1-switch", true))).is_false()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_NEWER])
	assert_str(FileAccess.get_file_as_string(path)).is_equal(newer)


## 保存に失敗しても、画面の正答状況は今回の回答を含める。失敗の通知は続く間は1回だけ
func test_a_failed_answer_save_is_reported_once_and_still_counted() -> void:
	var blocked: String = _dir("quiz_blocked").path_join("not_a_dir")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var service := UserDataService.new(RecordStore.new(_rules, blocked), SettingsStore.new(blocked),
			QuizAnswerStore.new(blocked), ContentRepository.new().load_catalog().quiz_questions)
	service.storage_failed.connect(_on_failed)
	assert_bool(service.save_quiz_answer(_answer("lg4-fix", true))).is_false()
	assert_bool(service.save_quiz_answer(_answer("lg4-anchor", false))).is_false()
	assert_dict(service.quiz_progress()["LG-4"] as Dictionary).is_equal({"answered": 2, "correct": 1, "total": 2})
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])


## 保存に失敗した回答は、保存できるようになった次の回答のときに一緒に書く（失敗から戻っても集計から消えない）
func test_an_answer_that_failed_to_save_is_written_with_the_next_one() -> void:
	var blocked: String = _dir("quiz_recover").path_join("not_a_dir")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var service := UserDataService.new(RecordStore.new(_rules, blocked), SettingsStore.new(blocked),
			QuizAnswerStore.new(blocked), ContentRepository.new().load_catalog().quiz_questions)
	service.storage_failed.connect(_on_failed)
	assert_bool(service.save_quiz_answer(_answer("lg4-anchor", true, 0))).is_false()
	DirAccess.remove_absolute(blocked)
	DirAccess.make_dir_recursive_absolute(blocked)
	assert_bool(service.save_quiz_answer(_answer("lg4-fix", false, 1))).is_true()
	assert_dict(service.quiz_progress()["LG-4"] as Dictionary).is_equal({"answered": 2, "correct": 1, "total": 2})
	var saved: Array[QuizAnswer] = QuizAnswerStore.new(blocked).load_all()
	assert_array(saved.map(func(item: QuizAnswer) -> String: return item.question_id)).is_equal(["lg4-anchor", "lg4-fix"])
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])

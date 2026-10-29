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
	var service := UserDataService.new(RecordStore.new(_rules, _dir(case_name)))
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
	var service := UserDataService.new(RecordStore.new(_rules, blocked))
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
	var service := UserDataService.new(RecordStore.new(_rules, blocked))
	service.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: _failures.append(kind))
	assert_bool(service.append_record(_record(1, "2026-10-29T10:00:00", 1, 0))).is_false()
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE])
	assert_array(service.records()).is_empty()

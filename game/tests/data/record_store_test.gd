## RecordStore・MatchRecordCodec（component-design.md §4.3・data-definition.md §2.2）のテスト。
## 一時ディレクトリに保存し、ファイルを直接置いて壊れた場合・新しい版・上限を作る。
## gdUnit の一時ディレクトリはスイートの中でテストごとに消えないので、テストごとに別の名前を使う。
extends GdUnitTestSuite

var _rules: MatchRuleConfig


func before() -> void:
	_rules = ConfigRepository.new().match_rules()


func _dir(case_name: String) -> String:
	return create_temp_dir("record_store/" + case_name)


func _store(case_name: String) -> RecordStore:
	return RecordStore.new(_rules, _dir(case_name))


func _path(case_name: String) -> String:
	return _dir(case_name).path_join(RecordStore.FILE_NAME)


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## 退避したファイルの名前（<名前>.corrupt-<日時>）
func _moved_aside(case_name: String) -> Array[String]:
	var moved: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_dir(case_name)):
		if file_name.begins_with(RecordStore.FILE_NAME + SaveFileIO.CORRUPT_INFIX):
			moved.append(file_name)
	return moved


func _setup(formation_id: String = "4-3-3") -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION))


## 試合 ID は 20261029-1000SS-NNNN（index で変える）
func _record(index: int, score_user: int = 1, score_cpu: int = 0, periods: int = 1) -> MatchRecord:
	var record := MatchRecord.new()
	record.match_id = "20261029-%06d-%04d" % [100000 + floori(index / 10000.0), index % 10000]
	record.record_id = record.match_id
	record.finished_at = "2026-10-29T10:%02d:%02d" % [floori(index / 60.0) % 60, index % 60]
	record.score_user = score_user
	record.score_cpu = score_cpu
	record.result = MatchRecord.result_of(score_user, score_cpu)
	for period: int in range(periods):
		record.timeline.append(RecordPeriod.new(1 + period % 2, 1 + period % 10, _setup(), _setup("4-4-2")))
	return record


## 正しい1件の戦績のファイルの中身（Dictionary）。範囲外のテストは、これを1か所ずつ壊す。
func _valid_root() -> Dictionary:
	var records: Array[MatchRecord] = [_record(1, 2, 1)]
	return JSON.parse_string(MatchRecordCodec.to_json(records)) as Dictionary


func _decodes(root: Variant) -> bool:
	return MatchRecordCodec.new(_rules).decode(root) != null


# --- 読み込み・追記 ---

func test_nothing_saved_is_empty() -> void:
	var store: RecordStore = _store("empty")
	assert_array(store.load_all()).is_empty()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.EMPTY)


func test_appended_records_are_read_back_in_the_order_recorded() -> void:
	var store: RecordStore = _store("append")
	assert_bool(store.append(_record(1, 2, 1, 3))).is_true()
	assert_bool(store.append(_record(2, 0, 0))).is_true()
	var records: Array[MatchRecord] = store.load_all()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.OK)
	assert_array(records.map(func(r: MatchRecord) -> String: return r.match_id)) \
			.is_equal([_record(1).match_id, _record(2).match_id])
	assert_str(JSON.stringify(MatchRecordCodec.encode(records[0]))).is_equal(JSON.stringify(MatchRecordCodec.encode(_record(1, 2, 1, 3))))


func test_the_same_match_is_not_recorded_twice() -> void:
	var store: RecordStore = _store("idempotent")
	store.append(_record(1, 2, 1))
	var again: MatchRecord = _record(1, 0, 3)
	assert_bool(store.append(again)).is_true()
	var records: Array[MatchRecord] = store.load_all()
	assert_int(records.size()).is_equal(1)
	assert_int(records[0].score_user).is_equal(2)


func test_over_the_count_limit_drops_the_oldest() -> void:
	var case_name: String = "count_limit"
	var records: Array[MatchRecord] = []
	for index: int in range(MatchRecordCodec.MAX_RECORDS):
		records.append(_record(index))
	_put(_path(case_name), MatchRecordCodec.to_json(records))
	var store: RecordStore = _store(case_name)
	assert_bool(store.append(_record(MatchRecordCodec.MAX_RECORDS))).is_true()
	var saved: Array[MatchRecord] = store.load_all()
	assert_int(saved.size()).is_equal(MatchRecordCodec.MAX_RECORDS)
	assert_str(saved[0].match_id).is_equal(_record(1).match_id)
	assert_str(saved.back().match_id).is_equal(_record(MatchRecordCodec.MAX_RECORDS).match_id)


func test_over_the_size_limit_drops_the_oldest_until_it_fits() -> void:
	var case_name: String = "size_limit"
	var max_periods: int = (_rules.turns_per_half + _rules.max_additional_turns) * 2 + 2
	var records: Array[MatchRecord] = []
	# 1件ぶんの大きさ（区切りの「,」を含む）
	var one_size: int = JSON.stringify(MatchRecordCodec.encode(_record(0, 1, 0, max_periods))).length() + 1
	# 書き込みの上限をわずかに超えるまで、推移の多い戦績を並べる（読み込みの上限 5MB は超えない）
	while records.size() * one_size <= RecordStore.MAX_WRITE_BYTES:
		records.append(_record(records.size(), 1, 0, max_periods))
	_put(_path(case_name), MatchRecordCodec.to_json(records))
	var store: RecordStore = _store(case_name)
	var newest: MatchRecord = _record(records.size(), 1, 0, max_periods)
	assert_bool(store.append(newest)).is_true()
	var size: int = FileAccess.open(_path(case_name), FileAccess.READ).get_length()
	assert_int(size).is_less_equal(RecordStore.MAX_WRITE_BYTES)
	var saved: Array[MatchRecord] = store.load_all()
	assert_int(saved.size()).is_less(records.size() + 1)
	assert_str(saved.back().match_id).is_equal(newest.match_id)
	assert_str(saved[0].match_id).is_not_equal(records[0].match_id)


# --- 破損・新しい版 ---

func test_a_corrupted_file_is_moved_aside_and_read_as_empty() -> void:
	var case_name: String = "corrupted"
	_put(_path(case_name), "{ not json")
	var store: RecordStore = _store(case_name)
	assert_array(store.load_all()).is_empty()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.CORRUPTED)
	assert_bool(FileAccess.file_exists(_path(case_name))).is_false()
	var moved: Array[String] = _moved_aside(case_name)
	assert_int(moved.size()).is_equal(1)
	assert_str(_read(_dir(case_name).path_join(moved[0] as String))).is_equal("{ not json")


## 同じ秒に2回退避しても、前に退避したファイルを上書きせず、別の名前で退避する
func test_corrupted_files_found_twice_are_both_kept() -> void:
	var case_name: String = "corrupted_twice"
	_put(_path(case_name), "{ first")
	_store(case_name).load_all()
	_put(_path(case_name), "{ second")
	var store: RecordStore = _store(case_name)
	store.load_all()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.CORRUPTED)
	var contents: Array[String] = []
	for file_name: String in _moved_aside(case_name):
		contents.append(_read(_dir(case_name).path_join(file_name)))
	contents.sort()
	assert_array(contents).is_equal(["{ first", "{ second"] as Array[String])


func test_after_moving_a_corrupted_file_aside_the_next_append_starts_a_new_file() -> void:
	var case_name: String = "corrupted_append"
	_put(_path(case_name), "[]")
	var store: RecordStore = _store(case_name)
	assert_bool(store.append(_record(5))).is_true()
	var records: Array[MatchRecord] = store.load_all()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.OK)
	assert_int(records.size()).is_equal(1)


## 本体が壊れていても .bak が正しければ、そちらを使う（書き込みの途中で止まった場合。SaveFileIO）
func test_a_valid_backup_is_used_when_the_main_file_is_broken() -> void:
	var case_name: String = "backup"
	_put(_path(case_name), "{ broken")
	_put(_path(case_name) + SaveFileIO.BAK_SUFFIX, JSON.stringify(_valid_root()))
	var store: RecordStore = _store(case_name)
	assert_int(store.load_all().size()).is_equal(1)
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.OK)
	# 壊れた本体は退避されている（次の書き込みで .bak へ回されて消えない）
	assert_array(_moved_aside(case_name)).has_size(1)
	assert_str(_read(_dir(case_name).path_join(_moved_aside(case_name)[0]))).is_equal("{ broken")
	assert_bool(store.append(_record(2))).is_true()
	assert_int(store.load_all().size()).is_equal(2)
	assert_array(_moved_aside(case_name)).has_size(1)


func test_a_newer_version_is_read_as_empty_and_never_overwritten() -> void:
	var case_name: String = "newer"
	var newer: String = JSON.stringify({"format_version": MatchRecordCodec.FORMAT_VERSION + 1, "records": "future"})
	_put(_path(case_name), newer)
	var store: RecordStore = _store(case_name)
	assert_array(store.load_all()).is_empty()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.NEWER_VERSION)
	assert_bool(store.append(_record(1))).is_false()
	assert_str(_read(_path(case_name))).is_equal(newer)


func test_a_corrupted_file_that_cannot_be_moved_aside_is_not_overwritten() -> void:
	var case_name: String = "unmovable"
	_put(_path(case_name), "{ broken")
	# 退避先の名前（日時を秒まで含む）に、中身のあるディレクトリを先に置いて、名前を変えられなくする。
	# テストの実行中に秒が進んでもよいよう、この先の数秒ぶんを置く
	var start: int = int(Time.get_unix_time_from_system())
	for offset: int in range(10):
		var stamp: Dictionary = Time.get_datetime_dict_from_unix_time(start + offset + _local_offset_sec())
		var blocker: String = _path(case_name) + SaveFileIO.CORRUPT_INFIX + "%04d%02d%02d-%02d%02d%02d" % [stamp["year"],
				stamp["month"], stamp["day"], stamp["hour"], stamp["minute"], stamp["second"]]
		# 名前が既にあれば連番を付けて探すので、連番の名前もすべて塞ぐ
		for suffix: int in range(SaveFileIO.MAX_MOVE_ASIDE_SUFFIX + 1):
			var name_taken: String = blocker if suffix == 0 else "%s-%d" % [blocker, suffix]
			DirAccess.make_dir_recursive_absolute(name_taken)
			_put(name_taken.path_join("keep"), "x")
	var store: RecordStore = _store(case_name)
	assert_bool(store.append(_record(1))).is_false()
	assert_int(store.load_state()).is_equal(RecordStore.LoadState.CORRUPTED)
	assert_str(_read(_path(case_name))).is_equal("{ broken")


## 端末のローカル時刻と UTC の差（秒）。退避の名前はローカル時刻で付く
func _local_offset_sec() -> int:
	return int(Time.get_time_zone_from_system()["bias"]) * 60


# --- 範囲外（1か所ずつ壊して、全体を使わない） ---

func test_the_valid_root_decodes() -> void:
	assert_bool(_decodes(_valid_root())).is_true()


func test_out_of_range_fields_are_rejected() -> void:
	var cases: Dictionary = {
		"format_version": func(root: Dictionary) -> void: root["format_version"] = 0,
		"records not array": func(root: Dictionary) -> void: root["records"] = {},
		"match_id shape": func(root: Dictionary) -> void: root["records"][0]["match_id"] = "x",
		"record_id differs": func(root: Dictionary) -> void: root["records"][0]["record_id"] = "20261029-000000-0000",
		"finished_at shape": func(root: Dictionary) -> void: root["records"][0]["finished_at"] = "10/29",
		"score over": func(root: Dictionary) -> void: root["records"][0]["score_user"] = MatchRecordCodec.MAX_SCORE + 1,
		"score negative": func(root: Dictionary) -> void: root["records"][0]["score_cpu"] = -1,
		"score fraction": func(root: Dictionary) -> void: root["records"][0]["score_cpu"] = 0.5,
		"result unknown": func(root: Dictionary) -> void: root["records"][0]["result"] = "WON",
		"result mismatch": func(root: Dictionary) -> void: root["records"][0]["result"] = "LOSE",
		"timeline empty": func(root: Dictionary) -> void: root["records"][0]["timeline"] = [],
		"half over": func(root: Dictionary) -> void: root["records"][0]["timeline"][0]["half"] = 3,
		"from_turn zero": func(root: Dictionary) -> void: root["records"][0]["timeline"][0]["from_turn"] = 0,
		"formation empty": func(root: Dictionary) -> void: root["records"][0]["timeline"][0]["user"]["formation_id"] = "",
		"formation shape": func(root: Dictionary) -> void: root["records"][0]["timeline"][0]["cpu"]["formation_id"] = "<4-3-3>",
		"score huge": func(root: Dictionary) -> void: root["records"][0]["score_user"] = 1e300,
		"defense unknown": func(root: Dictionary) -> void: root["records"][0]["timeline"][0]["cpu"]["defense"] = "PRESS",
		"cpu missing": func(root: Dictionary) -> void: (root["records"][0]["timeline"][0] as Dictionary).erase("cpu"),
		"record not object": func(root: Dictionary) -> void: root["records"][0] = 1,
		"duplicate match": func(root: Dictionary) -> void: (root["records"] as Array).append((root["records"][0] as Dictionary).duplicate(true)),
	}
	for case_name: String in cases:
		var root: Dictionary = _valid_root()
		(cases[case_name] as Callable).call(root)
		assert_bool(_decodes(root)).override_failure_message("壊したのに読めた: " + case_name).is_false()


func test_timeline_count_limit() -> void:
	var max_periods: int = (_rules.turns_per_half + _rules.max_additional_turns) * 2 + 2
	var at_limit: Array[MatchRecord] = [_record(1, 1, 0, max_periods)]
	assert_bool(_decodes(JSON.parse_string(MatchRecordCodec.to_json(at_limit)))).is_true()
	var over: Array[MatchRecord] = [_record(1, 1, 0, max_periods + 1)]
	assert_bool(_decodes(JSON.parse_string(MatchRecordCodec.to_json(over)))).is_false()


## 陣形 ID はカタログに無くても読める（陣形を減らした後も過去の戦績を残す）
func test_an_unknown_formation_is_still_read() -> void:
	var root: Dictionary = _valid_root()
	root["records"][0]["timeline"][0]["user"]["formation_id"] = "2-3-5"
	assert_bool(_decodes(root)).is_true()

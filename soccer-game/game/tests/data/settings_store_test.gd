## SettingsStore（component-design.md §4.3・data-definition.md §2.4）のテスト。一時ディレクトリに保存し、ファイルを直接置いて
## キーの外れ・破損・新しい版を作る。一時ディレクトリはスイートの中でテストごとに消えないので、テストごとに別の名前を使う。
extends GdUnitTestSuite


func _dir(case_name: String) -> String:
	return create_temp_dir("settings_store/" + case_name)


func _path(case_name: String) -> String:
	return _dir(case_name).path_join(SettingsStore.FILE_NAME)


func _put(case_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_path(case_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _moved_aside(case_name: String) -> Array[String]:
	var moved: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_dir(case_name)):
		if file_name.begins_with(SettingsStore.FILE_NAME + SaveFileIO.CORRUPT_INFIX):
			moved.append(file_name)
	return moved


func _changed() -> UserSettings:
	var settings := UserSettings.new()
	settings.bgm_volume = 0.25
	settings.se_volume = 1.0
	settings.show_hints = false
	settings.tutorial_completed = true
	return settings


func _values(settings: UserSettings) -> Array:
	return [settings.bgm_volume, settings.se_volume, settings.show_hints, settings.tutorial_completed]


func test_nothing_saved_reads_the_defaults() -> void:
	var store := SettingsStore.new(_dir("empty"))
	assert_array(_values(store.load())).is_equal([0.7, 0.7, true, false])
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.EMPTY)


func test_saved_settings_are_read_back_by_a_new_store() -> void:
	assert_bool(SettingsStore.new(_dir("saved")).save(_changed())).is_true()
	var store := SettingsStore.new(_dir("saved"))
	assert_array(_values(store.load())).is_equal([0.25, 1.0, false, true])
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.OK)


## 外れたキーだけ初期値にし、ほかのキーは読む（ファイル全体を破損にしない）
func test_a_bad_key_falls_back_alone() -> void:
	var cases: Dictionary = {
		"over": "[meta]\nformat_version=1\n[audio]\nbgm_volume=1.5\nse_volume=0.2\n[ui]\nshow_hints=false\n",
		"negative": "[meta]\nformat_version=1\n[audio]\nbgm_volume=-0.1\nse_volume=0.2\n[ui]\nshow_hints=false\n",
		"text": "[meta]\nformat_version=1\n[audio]\nbgm_volume=\"loud\"\nse_volume=0.2\n[ui]\nshow_hints=false\n",
		"nan": "[meta]\nformat_version=1\n[audio]\nbgm_volume=nan\nse_volume=0.2\n[ui]\nshow_hints=false\n",
		"missing": "[meta]\nformat_version=1\n[audio]\nse_volume=0.2\n[ui]\nshow_hints=false\n",
	}
	for case_name: String in cases:
		_put(case_name, cases[case_name] as String)
		var store := SettingsStore.new(_dir(case_name))
		assert_array(_values(store.load())).override_failure_message("キー単位で直していない: " + case_name) \
				.is_equal([0.7, 0.2, false, false])
		assert_int(store.load_state()).is_equal(SettingsStore.LoadState.OK)
		assert_array(_moved_aside(case_name)).is_empty()


func test_volume_bounds_and_whole_numbers_are_accepted() -> void:
	_put("bounds", "[meta]\nformat_version=1\n[audio]\nbgm_volume=0\nse_volume=1\n[ui]\nshow_hints=0\n")
	var settings: UserSettings = SettingsStore.new(_dir("bounds")).load()
	assert_array([settings.bgm_volume, settings.se_volume]).is_equal([0.0, 1.0])
	# 真偽値は bool だけ（数の 0 は外れなので、OFF ではなく初期値の ON）
	assert_bool(settings.show_hints).is_true()


func test_a_file_without_a_readable_version_is_moved_aside_and_reads_the_defaults() -> void:
	var cases: Dictionary = {
		"no_version": "[audio]\nbgm_volume=0.1\n",
		"text_version": "[meta]\nformat_version=\"1\"\n[audio]\nbgm_volume=0.1\n",
		"zero_version": "[meta]\nformat_version=0\n[audio]\nbgm_volume=0.1\n",
		"not_config": "{ this is not a config file",
	}
	for case_name: String in cases:
		_put(case_name, cases[case_name] as String)
		var store := SettingsStore.new(_dir(case_name))
		assert_array(_values(store.load())).is_equal([0.7, 0.7, true, false])
		assert_int(store.load_state()).override_failure_message("破損にしていない: " + case_name) \
				.is_equal(SettingsStore.LoadState.CORRUPTED)
		assert_array(_moved_aside(case_name)).has_size(1)
		assert_bool(FileAccess.file_exists(_path(case_name))).is_false()
		# 退避した後は、新しいファイルとして保存できる
		assert_bool(store.save(_changed())).is_true()
		assert_array(_values(SettingsStore.new(_dir(case_name)).load())).is_equal([0.25, 1.0, false, true])


func test_a_newer_version_reads_the_defaults_and_is_never_overwritten() -> void:
	var newer: String = "[meta]\nformat_version=2\n[audio]\nbgm_volume=0.1\n"
	_put("newer", newer)
	var store := SettingsStore.new(_dir("newer"))
	assert_array(_values(store.load())).is_equal([0.7, 0.7, true, false])
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.NEWER_VERSION)
	assert_bool(store.save(_changed())).is_false()
	assert_str(FileAccess.get_file_as_string(_path("newer"))).is_equal(newer)


## 値に Object(...)・Resource(...) などを書いたファイルは、解析する前に破損として退避する
## （ConfigFile.parse に渡すとオブジェクトを作り、リソースを読み込むため。コミット前レビュー H-1）
func test_values_that_would_build_objects_or_load_resources_are_rejected_as_broken() -> void:
	var cases: Dictionary = {
		"object": "[meta]\nformat_version=1\n[x]\ny=Object(RefCounted)\n",
		"resource": "[meta]\nformat_version=1\n[audio]\nbgm_volume=Resource(\"res://default_bus_layout.tres\")\n",
		"vector": "[meta]\nformat_version=1\n[audio]\nbgm_volume=Vector2(0, 0)\n",
		"quoted_key": "[meta]\nformat_version=1\n[audio]\n\"bgm_volume\"=0.5\n",
	}
	for case_name: String in cases:
		_put(case_name, cases[case_name] as String)
		var store := SettingsStore.new(_dir(case_name))
		assert_array(_values(store.load())).is_equal([0.7, 0.7, true, false])
		assert_int(store.load_state()).override_failure_message("破損にしていない: " + case_name) \
				.is_equal(SettingsStore.LoadState.CORRUPTED)
		assert_array(_moved_aside(case_name)).has_size(1)


## 本体が壊れていて .bak が読めるときは .bak を使い、壊れた本体は退避する（次の保存で本体が .bak へ回されて消えない）
func test_a_broken_main_file_is_moved_aside_when_the_backup_is_used() -> void:
	_put("backup", "{ broken")
	var bak: FileAccess = FileAccess.open(_path("backup") + SaveFileIO.BAK_SUFFIX, FileAccess.WRITE)
	bak.store_string("[meta]\nformat_version=1\n[audio]\nbgm_volume=0.2\n")
	bak.close()
	var store := SettingsStore.new(_dir("backup"))
	assert_float(store.load().bgm_volume).is_equal(0.2)
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.OK)
	assert_array(_moved_aside("backup")).has_size(1)
	assert_bool(store.save(_changed())).is_true()
	assert_array(_moved_aside("backup")).has_size(1)
	assert_str(FileAccess.get_file_as_string(_dir("backup").path_join(_moved_aside("backup")[0]))).is_equal("{ broken")


## 退避先の名前（日時と連番）をすべて塞ぎ、退避できない壊れたファイルは上書きしない
func test_a_broken_file_that_cannot_be_moved_aside_is_not_overwritten() -> void:
	_put("unmovable", "{ broken")
	_block_move_aside("unmovable")
	var store := SettingsStore.new(_dir("unmovable"))
	assert_bool(store.save(_changed())).is_false()
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.CORRUPTED)
	assert_str(FileAccess.get_file_as_string(_path("unmovable"))).is_equal("{ broken")


## 新しい版は、この版の読み方で読めない値（配列・Color(...) など）を含んでも、破損にせず新しい版として扱う（退避も上書きもしない）
func test_a_newer_version_with_values_this_version_cannot_read_is_kept_as_newer() -> void:
	var newer: String = "[meta]\nformat_version=3\n[ui]\ntheme_color=Color(1, 0, 0, 1)\nrecent=[1, 2]\n"
	_put("newer_values", newer)
	var store := SettingsStore.new(_dir("newer_values"))
	assert_array(_values(store.load())).is_equal([0.7, 0.7, true, false])
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.NEWER_VERSION)
	assert_bool(store.save(_changed())).is_false()
	assert_str(FileAccess.get_file_as_string(_path("newer_values"))).is_equal(newer)
	assert_array(_moved_aside("newer_values")).is_empty()


## 本体が壊れていて .bak があっても、本体を退避できなければ、壊れた本体を上書きしない
func test_a_broken_main_file_that_cannot_be_moved_aside_is_kept_even_with_a_backup() -> void:
	_put("unmovable_bak", "{ broken")
	var bak: FileAccess = FileAccess.open(_path("unmovable_bak") + SaveFileIO.BAK_SUFFIX, FileAccess.WRITE)
	bak.store_string("[meta]\nformat_version=1\n")
	bak.close()
	_block_move_aside("unmovable_bak")
	var store := SettingsStore.new(_dir("unmovable_bak"))
	assert_bool(store.save(_changed())).is_false()
	assert_int(store.load_state()).is_equal(SettingsStore.LoadState.CORRUPTED)
	assert_str(FileAccess.get_file_as_string(_path("unmovable_bak"))).is_equal("{ broken")


## 退避先の名前（この先の数秒ぶんの日時と、その連番）に中身のあるディレクトリを置き、退避できなくする
func _block_move_aside(case_name: String) -> void:
	var start: int = int(Time.get_unix_time_from_system())
	var bias_sec: int = int(Time.get_time_zone_from_system()["bias"]) * 60
	for offset: int in range(10):
		var stamp: Dictionary = Time.get_datetime_dict_from_unix_time(start + offset + bias_sec)
		var base: String = _path(case_name) + SaveFileIO.CORRUPT_INFIX + "%04d%02d%02d-%02d%02d%02d" % [stamp["year"],
				stamp["month"], stamp["day"], stamp["hour"], stamp["minute"], stamp["second"]]
		for suffix: int in range(SaveFileIO.MAX_MOVE_ASIDE_SUFFIX + 1):
			var taken: String = base if suffix == 0 else "%s-%d" % [base, suffix]
			DirAccess.make_dir_recursive_absolute(taken)
			var keep: FileAccess = FileAccess.open(taken.path_join("keep"), FileAccess.WRITE)
			keep.store_string("x")
			keep.close()


## 保存先の場所にファイルを置き、その下にファイルを作れなくする
func test_a_failed_save_returns_false() -> void:
	var blocked: String = _dir("blocked").path_join("not_a_dir")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	assert_bool(SettingsStore.new(blocked).save(_changed())).is_false()

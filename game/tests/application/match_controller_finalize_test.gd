## MatchController の試合の終了処理（戦績の記録）とそのやり直しのテスト（component-design.md §3.2「試合の終了処理」。
## functional-overview.md 確定事項「試合終了から破棄までの順序」「削除方針」「起動時の扱い」）。
## 中断データ・戦績とも、本物の保存先を一時ディレクトリに置く。戦績の保存の失敗は、保存先の場所にファイルを置いて作る
## （その下にファイルを作れない）。ファイルを消してディレクトリを作れば、次の保存は成功する。
extends GdUnitTestSuite

var _catalog: ContentCatalog
var _rules: MatchRuleConfig
var _requests: Array[int] = []
var _failures: Array[int] = []
var _test_count: int = 0


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	_rules = ConfigRepository.new().match_rules()


func before_test() -> void:
	_requests.clear()
	_failures.clear()
	_test_count += 1


func _record_request(screen: AppScreens.Id, _params: Dictionary = {}) -> void:
	_requests.append(screen)


func _on_failed(kind: AppScreens.StorageErrorKind) -> void:
	_failures.append(kind)


## テストごとの一時ディレクトリ（スイートの中では消えないので、テストごとに名前を変える）
func _dir() -> String:
	return create_temp_dir("controller_finalize/case%d" % _test_count)


func _suspend_dir() -> String:
	return create_temp_dir("controller_finalize/case%d/suspend" % _test_count)


func _store() -> SuspendedMatchStore:
	return SuspendedMatchStore.new(_catalog, _rules, _suspend_dir())


## 戦績の保存先。blocked なら、その場所にファイルを置いて保存を失敗させる
func _records_dir(blocked: bool) -> String:
	var path: String = _dir().path_join("records")
	if blocked:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string("x")
		file.close()
	else:
		DirAccess.make_dir_recursive_absolute(path)
	return path


func _unblock(records_dir: String) -> void:
	DirAccess.remove_absolute(records_dir)
	DirAccess.make_dir_recursive_absolute(records_dir)


## 戦績の記録先（records_dir）と、その中を読み直す別のサービス
func _user_data(records_dir: String) -> UserDataService:
	var service := UserDataService.new(RecordStore.new(_rules, records_dir), SettingsStore.new(records_dir),
			QuizAnswerStore.new(records_dir), [])
	service.storage_failed.connect(_on_failed)
	return service


func _saved_records(records_dir: String) -> Array[MatchRecord]:
	return RecordStore.new(_rules, records_dir).load_all()


func _controller(store: SuspendedMatchStore, user_data: UserDataService, seed_value: int = 0) -> MatchController:
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value, _record_request, store, user_data)
	controller.storage_failed.connect(_on_failed)
	return controller


## stop に届くシードで試合を始め、stop まで進めた MatchController
func _controller_at(store: SuspendedMatchStore, user_data: UserDataService,
		stop: ScreenTestHelper.Stop) -> MatchController:
	var seed_value: int = ScreenTestHelper.seed_reaching(stop)
	assert_int(seed_value).is_not_equal(-1)
	var controller: MatchController = _controller(store, user_data, seed_value)
	controller.start_match(ScreenTestHelper.user_setup())
	assert_bool(ScreenTestHelper.advance_until(controller, stop)).is_true()
	_requests.clear()
	return controller


# --- 最終ターンの確定時 ---

func test_the_last_turn_records_the_match_and_saves_it_as_finished() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(false)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	var records: Array[MatchRecord] = _saved_records(records_dir)
	assert_int(records.size()).is_equal(1)
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(records[0].match_id).is_equal(controller.state().match_id)
	assert_array([records[0].score_user, records[0].score_cpu]).is_equal([snapshot.score_user, snapshot.score_opponent])
	assert_int(records[0].result).is_equal(MatchRecord.result_of(snapshot.score_user, snapshot.score_opponent))
	# 前半と後半で少なくとも2つの区切り（ハーフの境で必ず区切る）
	assert_int(records[0].timeline.size()).is_greater_equal(2)
	assert_int(store.load().state.status).is_equal(GameEnums.MatchStatus.FINISHED)
	assert_array(_failures).is_empty()
	# 記録した戦績（final_record）の区切りは前半から後半まで、最初の区切りは利用者の陣形
	# （試合を最後まで回すのに時間がかかるので、同じ試合で確かめる。2026-11-03 に別のテストから寄せた）
	var record: MatchRecord = controller.final_record()
	assert_array([record.score_user, record.score_cpu]).is_equal([snapshot.score_user, snapshot.score_opponent])
	assert_int(record.timeline[0].half).is_equal(1)
	assert_int(record.timeline.back().half).is_equal(2)
	assert_str(record.timeline[0].user_setup.formation_id).is_equal(ScreenTestHelper.user_setup().formation_id)
	assert_str(record.finished_at).is_not_empty()
	# 最終ターンの判定理由からは中断しない（同じく別のテストから寄せた）
	assert_bool(controller.suspend_to_title()).is_false()
	assert_array(_requests).is_empty()
	assert_bool(controller.is_match_over()).is_true()


func test_final_record_before_the_end_is_null() -> void:
	var controller: MatchController = _controller(null, null)
	controller.start_match(ScreenTestHelper.user_setup())
	await assert_error(func() -> void: controller.final_record()) \
			.is_push_error("MatchController: 試合が終わる前に final_record は呼べない")


## 戦績の記録に失敗したら FINISHED にしない（中断データは IN_PROGRESS のまま）
func test_a_failed_record_keeps_the_match_in_progress() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	_controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	assert_int(store.load().state.status).is_equal(GameEnums.MatchStatus.IN_PROGRESS)
	assert_array(_failures).contains([AppScreens.StorageErrorKind.USER_DATA_SAVE])


## 戦績は記録できたが FINISHED の保存に失敗したら、中断データは最後に保存できた状態のまま（やり直しで二重に記録しない）。
## .tmp の名前にディレクトリを置き、試合の初めから中断データの保存を失敗させる
func test_a_failed_finished_save_is_retried_without_recording_twice() -> void:
	var dir: String = _suspend_dir()
	DirAccess.make_dir_recursive_absolute(dir.path_join(SuspendedMatchStore.FILE_NAME + SaveFileIO.TMP_SUFFIX))
	var store := SuspendedMatchStore.new(_catalog, _rules, dir)
	var records_dir: String = _records_dir(false)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	assert_int(_saved_records(records_dir).size()).is_equal(1)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.SUSPEND_SAVE] as Array[int])
	DirAccess.remove_absolute(dir.path_join(SuspendedMatchStore.FILE_NAME + SaveFileIO.TMP_SUFFIX))
	controller.leave_result()
	assert_int(_saved_records(records_dir).size()).is_equal(1)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


# --- 結果画面から出るとき ---

func test_leaving_the_result_retries_a_failed_record_and_deletes_after_success() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	_unblock(records_dir)
	assert_bool(controller.leave_result()).is_true()
	assert_int(_saved_records(records_dir).size()).is_equal(1)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)
	assert_array(_requests).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_leaving_the_result_keeps_the_match_when_the_retry_fails_too() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	assert_bool(controller.leave_result()).is_true()
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.OK)
	assert_int(store.load().state.status).is_equal(GameEnums.MatchStatus.IN_PROGRESS)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.FINALIZE_PENDING)
	assert_array(_requests).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	# 終了処理待ちの試合は再開の対象にしない
	assert_object(controller.suspended_snapshot()).is_null()


func test_retry_pending_finalize_records_and_deletes_once_it_can_save() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	controller.leave_result()
	assert_bool(controller.retry_pending_finalize()).is_false()
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.FINALIZE_PENDING)
	_unblock(records_dir)
	assert_bool(controller.retry_pending_finalize()).is_true()
	assert_int(_saved_records(records_dir).size()).is_equal(1)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


func test_retry_without_a_pending_match_is_false() -> void:
	assert_bool(_controller(_store(), _user_data(_records_dir(false))).retry_pending_finalize()).is_false()


## 新しい試合を始めたら、終了処理待ちの試合は上書きされる（利用者の確認の後。削除の時点①）
func test_starting_a_new_match_overwrites_the_pending_match() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	controller.leave_result()
	controller.start_match(ScreenTestHelper.user_setup())
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)
	assert_array(store.load().state.turn_records).is_empty()


# --- 起動時 ---

func test_startup_finalizes_a_match_played_to_the_end() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	_controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	_unblock(records_dir)
	var next_launch: MatchController = _controller(store, _user_data(records_dir), 5)
	assert_int(next_launch.inspect_suspended()).is_equal(AppScreens.StartupResult.FINALIZED)
	assert_int(_saved_records(records_dir).size()).is_equal(1)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(next_launch.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


func test_startup_keeps_the_match_pending_when_recording_still_fails() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(true)
	_controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	var next_launch: MatchController = _controller(store, _user_data(records_dir), 5)
	assert_int(next_launch.inspect_suspended()).is_equal(AppScreens.StartupResult.FINALIZE_FAILED)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.OK)
	assert_int(next_launch.suspended_status()).is_equal(AppScreens.SuspendedStatus.FINALIZE_PENDING)


## 前の起動で戦績は記録できていた（FINISHED の保存だけ失敗した）試合を、やり直しても二重に記録しない
func test_startup_retry_does_not_record_the_same_match_twice() -> void:
	var store: SuspendedMatchStore = _store()
	var records_dir: String = _records_dir(false)
	var controller: MatchController = _controller_at(store, _user_data(records_dir), ScreenTestHelper.Stop.OVER)
	var unfinished: MatchState = controller.state()
	unfinished.status = GameEnums.MatchStatus.IN_PROGRESS
	store.save(unfinished)
	assert_int(_controller(store, _user_data(records_dir), 5).inspect_suspended()) \
			.is_equal(AppScreens.StartupResult.FINALIZED)
	assert_int(_saved_records(records_dir).size()).is_equal(1)


# --- 再開した試合の振り返り（中断・再開の作業からの申し送り） ---

## 振り返りは得点後のスコアをターン記録から数え直す。中断データからターン記録を全件戻していれば、盤面のスコアと一致する
func test_a_resumed_match_reviews_the_same_score_as_the_board() -> void:
	var store: SuspendedMatchStore = _store()
	var before_suspend: MatchController = _controller_at(store, null, ScreenTestHelper.Stop.STYLE_CHANGE)
	var resumed: MatchController = _controller(store, null, 9)
	resumed.inspect_suspended()
	assert_bool(resumed.resume()).is_true()
	var goals: Array[Dictionary] = resumed.review().goals
	assert_int(goals.size()).is_greater(0)
	var snapshot: BoardSnapshot = resumed.snapshot()
	assert_array([goals.back()["score_user"], goals.back()["score_opponent"]]) \
			.is_equal([snapshot.score_user, snapshot.score_opponent])
	assert_int(resumed.state().turn_records.size()).is_equal(before_suspend.state().turn_records.size())

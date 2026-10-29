## MatchController の中断データの保存・起動時の後始末・再開・中断のテスト（component-design.md §3.2「保存の時点」・UC-05。
## functional-overview.md 確定事項「保存の時点」「削除方針」「起動時の扱い」「再開先」）。
## 保存先は一時ディレクトリ。保存の失敗は、存在しないディレクトリか、.tmp の名前にディレクトリを置いて作る。
extends GdUnitTestSuite

var _catalog: ContentCatalog
var _rules: MatchRuleConfig
var _requests: Array[int] = []
var _failures: Array[int] = []


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	_rules = ConfigRepository.new().match_rules()


func before_test() -> void:
	_requests.clear()
	_failures.clear()


func _record_request(screen: AppScreens.Id, _params: Dictionary = {}) -> void:
	_requests.append(screen)


func _store_in(dir: String) -> SuspendedMatchStore:
	return SuspendedMatchStore.new(_catalog, _rules, dir)


func _store(case_name: String) -> SuspendedMatchStore:
	return _store_in(create_temp_dir("controller_suspend/" + case_name))


func _controller(store: SuspendedMatchStore, seed_value: int = 0) -> MatchController:
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value, _record_request, store)
	controller.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: _failures.append(kind))
	return controller


func _play_turn(controller: MatchController) -> void:
	controller.submit_turn(ScreenTestHelper.forward_choice(controller.user_options()))
	controller.continue_after_reveal()


## stop に届くシードで試合を始め、stop まで進めた MatchController（保存先は store）
func _controller_at(store: SuspendedMatchStore, stop: ScreenTestHelper.Stop) -> MatchController:
	var seed_value: int = ScreenTestHelper.seed_reaching(stop)
	assert_int(seed_value).is_not_equal(-1)
	var controller: MatchController = _controller(store, seed_value)
	controller.start_match(ScreenTestHelper.user_setup())
	assert_bool(ScreenTestHelper.advance_until(controller, stop)).is_true()
	_requests.clear()
	return controller


func _json(state: MatchState) -> String:
	return SuspendedMatchEncoder.to_json(state)


# --- 保存の時点 ---


func test_starting_a_match_saves_it_before_any_turn() -> void:
	var store: SuspendedMatchStore = _store("start")
	var controller: MatchController = _controller(store)
	controller.start_match(ScreenTestHelper.user_setup())
	var saved: SuspendedLoad = store.load()
	assert_int(saved.status).is_equal(SuspendedLoad.Status.OK)
	assert_str(_json(saved.state)).is_equal(_json(controller.state()))
	assert_array(saved.state.turn_records).is_empty()


func test_a_confirmed_turn_is_saved_before_the_reveal_is_confirmed() -> void:
	var store: SuspendedMatchStore = _store("turn")
	var controller: MatchController = _controller(store)
	controller.start_match(ScreenTestHelper.user_setup())
	controller.submit_turn(ScreenTestHelper.forward_choice(controller.user_options()))
	# 開示を確かめる前（continue_after_reveal の前）に強制終了しても、確定したターンは残る
	assert_str(_json(store.load().state)).is_equal(_json(controller.state()))
	assert_int(store.load().state.turn_records.size()).is_equal(1)


func test_entering_and_leaving_the_style_change_are_saved() -> void:
	var store: SuspendedMatchStore = _store("style")
	var controller: MatchController = _controller_at(store, ScreenTestHelper.Stop.STYLE_CHANGE)
	assert_int(store.load().state.stage).is_equal(GameEnums.MatchStage.STYLE_CHANGE)
	var styles := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION)
	controller.submit_style_change(styles)
	var saved: MatchState = store.load().state
	assert_int(saved.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(saved.home_setup.styles.defense).is_equal(GameEnums.DefenseStyle.ZONE)
	assert_int(saved.home_setup.styles.attack).is_equal(GameEnums.AttackStyle.POSSESSION)


func test_entering_and_leaving_the_halftime_are_saved() -> void:
	var store: SuspendedMatchStore = _store("halftime")
	var controller: MatchController = _controller_at(store, ScreenTestHelper.Stop.HALFTIME)
	assert_int(store.load().state.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	controller.submit_halftime(TeamSetup.new("3-5-2",
			TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)))
	var saved: MatchState = store.load().state
	assert_int(saved.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(saved.half).is_equal(2)
	assert_str(saved.home_setup.formation_id).is_equal("3-5-2")


func test_a_failed_save_keeps_the_match_going_reports_once_and_clears_after_a_later_success() -> void:
	var dir: String = create_temp_dir("controller_suspend/fail").path_join("later")
	var controller: MatchController = _controller(_store_in(dir))
	assert_bool(controller.start_match(ScreenTestHelper.user_setup())).is_true()
	assert_bool(controller.has_unsaved_progress()).is_true()
	_play_turn(controller)
	_play_turn(controller)
	# 失敗が続く間は、最初の1回だけ知らせる
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.SUSPEND_SAVE] as Array[int])
	assert_int(controller.state().turn_records.size()).is_equal(2)
	DirAccess.make_dir_recursive_absolute(dir)
	_play_turn(controller)
	assert_bool(controller.has_unsaved_progress()).is_false()
	assert_int(_store_in(dir).load().state.turn_records.size()).is_equal(3)


func test_a_new_match_that_cannot_be_saved_drops_the_previous_suspended_match() -> void:
	var dir: String = create_temp_dir("controller_suspend/stale")
	var store: SuspendedMatchStore = _store_in(dir)
	var earlier: MatchController = _controller(store)
	earlier.start_match(ScreenTestHelper.user_setup())
	_play_turn(earlier)
	# .tmp の名前にディレクトリを置くと、本体を残したまま書き込みだけが失敗する
	DirAccess.make_dir_absolute(dir.path_join(SuspendedMatchStore.FILE_NAME + SaveFileIO.TMP_SUFFIX))
	var later: MatchController = _controller(store, 1)
	later.start_match(ScreenTestHelper.user_setup())
	assert_bool(later.has_unsaved_progress()).is_true()
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)


func test_without_a_store_nothing_is_saved_and_nothing_is_unsaved() -> void:
	var controller: MatchController = _controller(null)
	controller.start_match(ScreenTestHelper.user_setup())
	_play_turn(controller)
	assert_bool(controller.has_unsaved_progress()).is_false()
	assert_array(_failures).is_empty()
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.NONE)


# --- 起動時の後始末 ---


func test_inspect_without_suspended_data_is_none() -> void:
	var controller: MatchController = _controller(_store("inspect_none"))
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)
	assert_object(controller.suspended_snapshot()).is_null()


func test_inspect_finds_a_resumable_match_and_shows_its_board() -> void:
	var store: SuspendedMatchStore = _store("inspect_ok")
	var earlier: MatchController = _controller(store)
	earlier.start_match(ScreenTestHelper.user_setup())
	_play_turn(earlier)
	_play_turn(earlier)
	var expected: BoardSnapshot = earlier.snapshot()
	var controller: MatchController = _controller(store, 5)
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.RESUMABLE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.RESUMABLE)
	assert_bool(controller.is_match_started()).is_false()
	var shown: BoardSnapshot = controller.suspended_snapshot()
	assert_array([shown.half, shown.turn_number, shown.score_user, shown.score_opponent, shown.ball_area,
			shown.user_setup.formation_id, shown.opponent_setup.formation_id]).is_equal([expected.half,
			expected.turn_number, expected.score_user, expected.score_opponent, expected.ball_area,
			expected.user_setup.formation_id, expected.opponent_setup.formation_id])


func test_inspect_deletes_corrupted_data_and_reports_it() -> void:
	var dir: String = create_temp_dir("controller_suspend/corrupt")
	var file: FileAccess = FileAccess.open(dir.path_join(SuspendedMatchStore.FILE_NAME), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var controller: MatchController = _controller(_store_in(dir))
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.CORRUPTED)
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.SUSPEND_LOAD] as Array[int])
	assert_bool(FileAccess.file_exists(dir.path_join(SuspendedMatchStore.FILE_NAME))).is_false()
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


## 戦績の記録先を持たないコントローラーでは、記録は成功した扱い（戦績の記録の失敗は match_controller_finalize_test）
func test_inspect_deletes_finished_matches_and_finalizes_matches_played_to_the_end() -> void:
	var store: SuspendedMatchStore = _store("inspect_finished")
	var over: MatchController = _controller_at(store, ScreenTestHelper.Stop.OVER)
	# 最終ターンで終了処理が済み、FINISHED で保存されている
	assert_int(store.load().state.status).is_equal(GameEnums.MatchStatus.FINISHED)
	var controller: MatchController = _controller(store, 3)
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.FINALIZED)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)
	# 最終ターンまで終えた IN_PROGRESS（終了処理の保存に失敗した試合）は、やり直して消す
	var unfinished: MatchState = over.state()
	unfinished.status = GameEnums.MatchStatus.IN_PROGRESS
	store.save(unfinished)
	assert_int(_controller(store, 3).inspect_suspended()).is_equal(AppScreens.StartupResult.FINALIZED)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_array(_failures).is_empty()


# --- 再開 ---


func _assert_resumes_on(stop: ScreenTestHelper.Stop, screen: AppScreens.Id) -> void:
	var store: SuspendedMatchStore = _store("resume_%d" % stop)
	var earlier: MatchController = _controller_at(store, stop)
	var before: MatchState = earlier.state()
	var before_snapshot: BoardSnapshot = earlier.snapshot()
	# アプリを閉じて、新しく起動した
	var controller: MatchController = _controller(store, 7)
	assert_int(controller.inspect_suspended()).is_equal(AppScreens.StartupResult.RESUMABLE)
	_requests.clear()
	assert_bool(controller.resume()).is_true()
	assert_array(_requests).is_equal([screen] as Array[int])
	assert_str(_json(controller.state())).is_equal(_json(before))
	assert_int(controller.snapshot().last_goal_by).is_equal(before_snapshot.last_goal_by)
	assert_int(controller.stage()).is_equal(before.stage)
	# 試合中は再開カードを出さない
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


func test_resume_opens_the_match_screen_for_a_turn() -> void:
	_assert_resumes_on(ScreenTestHelper.Stop.TRANSITION, AppScreens.Id.S03_MATCH)


func test_resume_opens_the_style_change_after_a_goal_and_names_the_scorer() -> void:
	_assert_resumes_on(ScreenTestHelper.Stop.STYLE_CHANGE, AppScreens.Id.S04_STYLE_CHANGE)


func test_resume_opens_the_halftime() -> void:
	_assert_resumes_on(ScreenTestHelper.Stop.HALFTIME, AppScreens.Id.S05_HALFTIME)


func test_a_resumed_match_can_be_played_on_and_keeps_saving() -> void:
	var store: SuspendedMatchStore = _store("resume_play")
	var earlier: MatchController = _controller(store)
	earlier.start_match(ScreenTestHelper.user_setup())
	_play_turn(earlier)
	var controller: MatchController = _controller(store, 9)
	controller.inspect_suspended()
	controller.resume()
	_play_turn(controller)
	assert_int(controller.state().turn_records.size()).is_equal(2)
	assert_int(store.load().state.turn_records.size()).is_equal(2)


func test_resume_after_the_data_disappeared_reports_and_goes_back_to_the_title() -> void:
	var store: SuspendedMatchStore = _store("resume_gone")
	var earlier: MatchController = _controller(store)
	earlier.start_match(ScreenTestHelper.user_setup())
	var controller: MatchController = _controller(store, 2)
	controller.inspect_suspended()
	store.delete()
	_requests.clear()
	assert_bool(controller.resume()).is_false()
	assert_array(_requests).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.SUSPEND_LOAD] as Array[int])
	assert_bool(controller.is_match_started()).is_false()
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


# --- 中断してタイトルへ・結果からタイトルへ ---


func test_suspend_to_title_closes_the_match_and_offers_it_on_the_title() -> void:
	var store: SuspendedMatchStore = _store("suspend")
	var controller: MatchController = _controller(store)
	controller.start_match(ScreenTestHelper.user_setup())
	_play_turn(controller)
	var turn_number: int = controller.snapshot().turn_number
	_requests.clear()
	assert_bool(controller.suspend_to_title()).is_true()
	assert_array(_requests).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_bool(controller.is_match_started()).is_false()
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.RESUMABLE)
	assert_int(controller.suspended_snapshot().turn_number).is_equal(turn_number)
	# 中断していない試合が無ければ何もしない
	assert_bool(controller.suspend_to_title()).is_false()


func test_suspend_to_title_retries_a_failed_save() -> void:
	var dir: String = create_temp_dir("controller_suspend/retry").path_join("later")
	var controller: MatchController = _controller(_store_in(dir))
	controller.start_match(ScreenTestHelper.user_setup())
	_play_turn(controller)
	assert_bool(controller.has_unsaved_progress()).is_true()
	DirAccess.make_dir_recursive_absolute(dir)
	assert_bool(controller.suspend_to_title()).is_true()
	assert_int(_store_in(dir).load().state.turn_records.size()).is_equal(1)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.RESUMABLE)


func test_resuming_clears_the_unsaved_mark_so_the_next_failure_is_reported_again() -> void:
	var dir: String = create_temp_dir("controller_suspend/resume_unsaved")
	var store: SuspendedMatchStore = _store_in(dir)
	var controller: MatchController = _controller(store)
	controller.start_match(ScreenTestHelper.user_setup())
	# .tmp の名前にディレクトリを置くと、本体（試合の作成時の保存）を残したまま書き込みだけが失敗する
	var blocker: String = dir.path_join(SuspendedMatchStore.FILE_NAME + SaveFileIO.TMP_SUFFIX)
	DirAccess.make_dir_absolute(blocker)
	_play_turn(controller)
	assert_bool(controller.suspend_to_title()).is_false()
	DirAccess.remove_absolute(blocker)
	assert_bool(controller.resume()).is_true()
	# 読み直した状態は保存データそのもの。根拠のない警告を出さない
	assert_bool(controller.has_unsaved_progress()).is_false()
	# 再開後の最初の失敗も、もう一度知らせる
	DirAccess.make_dir_absolute(blocker)
	_play_turn(controller)
	assert_array(_failures).is_equal([AppScreens.StorageErrorKind.SUSPEND_SAVE,
			AppScreens.StorageErrorKind.SUSPEND_SAVE] as Array[int])
	DirAccess.remove_absolute(blocker)


func test_suspend_to_title_that_still_cannot_save_returns_false_and_offers_nothing() -> void:
	var dir: String = create_temp_dir("controller_suspend/never").path_join("missing")
	var controller: MatchController = _controller(_store_in(dir))
	controller.start_match(ScreenTestHelper.user_setup())
	assert_bool(controller.suspend_to_title()).is_false()
	assert_array(_requests.slice(-1)).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)


func test_starting_a_new_match_hides_the_resume_card() -> void:
	var store: SuspendedMatchStore = _store("new_after_suspend")
	var controller: MatchController = _controller(store)
	controller.start_match(ScreenTestHelper.user_setup())
	controller.suspend_to_title()
	controller.start_match(ScreenTestHelper.user_setup())
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)
	assert_array(store.load().state.turn_records).is_empty()


func test_leaving_the_result_deletes_the_suspended_data() -> void:
	var store: SuspendedMatchStore = _store("leave")
	var controller: MatchController = _controller_at(store, ScreenTestHelper.Stop.OVER)
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.OK)
	assert_bool(controller.leave_result()).is_true()
	assert_int(store.load().status).is_equal(SuspendedLoad.Status.NONE)
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.NONE)

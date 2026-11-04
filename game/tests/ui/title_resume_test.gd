## S-01 タイトルの再開カードと「CPU 対戦」の確認（screen-01-title.md「画面を開く」「再開カードを押す」「CPU 対戦を押す」・UC-05）。
## App.match_controller を、一時ディレクトリへ保存するコントローラに差し替える。中断した試合は、試合を進めてから
## suspend_to_title で作る（本番と同じ経路）。
extends GdUnitTestSuite

const TITLE_SCENE: String = "res://ui/screens/s01_title/title_screen.tscn"

var _original_controller: MatchController
var _requested: Array[int] = []
var _store: SuspendedMatchStore
## 一時ディレクトリはスイートの中ではテストごとに消えないので、テストごとに別の名前にする
var _test_count: int = 0
## App.user_data の元のサービス（テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0


func before_test() -> void:
	_user_data_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("title_resume/records_%d" % _user_data_count))
	_original_controller = App.match_controller
	_requested.clear()
	_test_count += 1
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	_store = SuspendedMatchStore.new(catalog, ConfigRepository.new().match_rules(),
			create_temp_dir("title_resume/save_%d" % _test_count))
	App.match_controller = ScreenTestHelper.new_controller(0, App.request_screen, _store)
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	App.match_controller = _original_controller
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> TitleScreen:
	var title: TitleScreen = auto_free((load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen) as TitleScreen
	add_child(title)
	title.enter({})
	_requested.clear()
	return title


## 2ターン進めて中断した試合を作る（スコアと時計は、そのときの盤面）
func _suspend_a_match() -> BoardSnapshot:
	var controller: MatchController = App.match_controller
	controller.start_match(ScreenTestHelper.user_setup())
	for step: int in range(2):
		controller.submit_turn(ScreenTestHelper.forward_choice(controller.user_options()))
		controller.continue_after_reveal()
	var snapshot: BoardSnapshot = controller.snapshot()
	controller.suspend_to_title()
	return snapshot


func test_no_suspended_match_hides_the_resume_card() -> void:
	var title: TitleScreen = _open()
	assert_bool(title.resume_card().visible).is_false()


func test_a_suspended_match_shows_the_clock_formations_and_score() -> void:
	var before: BoardSnapshot = _suspend_a_match()
	var title: TitleScreen = _open()
	assert_bool(title.resume_card().visible).is_true()
	assert_str(title.resume_summary_text()).is_equal("%s・%s 対 %s" % [MatchTexts.clock_text(before),
			before.user_setup.formation_id, before.opponent_setup.formation_id])
	assert_str(title.resume_summary_text()).starts_with("前半 ")
	assert_str(title.resume_score_text()).is_equal("%d – %d" % [before.score_user, before.score_opponent])


func test_pressing_the_resume_card_resumes_once() -> void:
	_suspend_a_match()
	var title: TitleScreen = _open()
	title.resume_card().pressed.emit()
	title.resume_card().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S03_MATCH] as Array[int])
	assert_int(title.state()).is_equal(TitleScreen.State.BUSY)
	assert_bool(App.match_controller.is_match_started()).is_true()


func test_resuming_after_the_data_disappeared_returns_to_idle_on_the_title() -> void:
	_suspend_a_match()
	var title: TitleScreen = _open()
	_store.delete()
	title.resume_card().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(title.state()).is_equal(TitleScreen.State.IDLE)


func test_kick_off_without_a_suspended_match_goes_straight_to_the_setup() -> void:
	var title: TitleScreen = _open()
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S02_MATCH_SETUP] as Array[int])
	assert_bool(title.confirm_dialog().is_open()).is_false()


func test_kick_off_with_a_suspended_match_asks_and_cancel_keeps_it() -> void:
	_suspend_a_match()
	var title: TitleScreen = _open()
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	var dialog: ConfirmDialog = title.confirm_dialog()
	assert_bool(dialog.is_open()).is_true()
	assert_str(dialog.message()).is_equal(NewMatchGate.DISCARD_MESSAGE)
	assert_int(title.state()).is_equal(TitleScreen.State.CONFIRMING)
	# 確認中はほかのカードも再開カードも押せない
	title.resume_card().pressed.emit()
	assert_array(_requested).is_empty()
	dialog.cancel_button().pressed.emit()
	assert_array(_requested).is_empty()
	assert_int(title.state()).is_equal(TitleScreen.State.IDLE)
	# 中断データはここでは消さない
	assert_int(_store.load().status).is_equal(SuspendedLoad.Status.OK)


func test_kick_off_with_a_suspended_match_continues_to_the_setup_when_accepted() -> void:
	_suspend_a_match()
	var title: TitleScreen = _open()
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	title.confirm_dialog().ok_button().pressed.emit()
	title.confirm_dialog().ok_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S02_MATCH_SETUP] as Array[int])
	assert_int(_store.load().status).is_equal(SuspendedLoad.Status.OK)


func test_back_while_confirming_closes_the_dialog_like_cancel() -> void:
	_suspend_a_match()
	var title: TitleScreen = _open()
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	assert_bool(title.handle_back()).is_true()
	assert_bool(title.confirm_dialog().is_open()).is_false()
	assert_int(title.state()).is_equal(TitleScreen.State.IDLE)
	assert_array(_requested).is_empty()
	# IDLE に戻ったら、戻る操作でアプリを閉じる
	assert_bool(title.handle_back()).is_false()


# --- 戦績のカードの一言と、戦績を記録できていない試合（FINALIZE_PENDING） ---

func _record(id_number: int, score_user: int, score_cpu: int) -> MatchRecord:
	var record := MatchRecord.new()
	record.match_id = "20261029-100000-%04d" % id_number
	record.record_id = record.match_id
	record.finished_at = "2026-10-29T10:00:00"
	record.score_user = score_user
	record.score_cpu = score_cpu
	record.result = MatchRecord.result_of(score_user, score_cpu)
	record.timeline.append(RecordPeriod.new(1, 1, ScreenTestHelper.user_setup(), ScreenTestHelper.user_setup()))
	return record


func test_the_records_card_shows_the_totals() -> void:
	assert_str(_open().records_summary_text()).is_equal("まだ記録がありません")
	App.user_data.append_record(_record(1, 2, 0))
	App.user_data.append_record(_record(2, 1, 1))
	App.user_data.append_record(_record(3, 0, 1))
	assert_str(_open().records_summary_text()).is_equal("1勝\n1分\n1敗")


## 戦績の保存先にファイルを置いて記録を失敗させたまま試合を終え、結果画面から出る（終了処理待ちが残る）。
## 戻り値は戦績の保存先（_unblock で記録できるようにする）
func _leave_an_unrecorded_match() -> String:
	var records_dir: String = create_temp_dir("title_resume/pending_%d" % _test_count).path_join("records")
	var file: FileAccess = FileAccess.open(records_dir, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var user_data := UserDataService.new(RecordStore.new(ConfigRepository.new().match_rules(), records_dir),
			SettingsStore.new(records_dir), QuizAnswerStore.new(records_dir), [])
	# 試合を回さず、最終ターンの直前から再開して終える（ScreenTestHelper.controller_at）
	var controller: MatchController = ScreenTestHelper.controller_at(ScreenTestHelper.Stop.OVER, App.request_screen,
			_store, user_data)
	assert_object(controller).override_failure_message("試合の終わりから始められない").is_not_null()
	App.match_controller = controller
	assert_bool(controller.is_match_over()).is_true()
	controller.leave_result()
	assert_int(controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.FINALIZE_PENDING)
	return records_dir


func test_kick_off_with_an_unrecorded_match_records_it_and_goes_to_the_setup_when_the_retry_works() -> void:
	var records_dir: String = _leave_an_unrecorded_match()
	var title: TitleScreen = _open()
	# 終了処理待ちの試合は再開カードに出さない
	assert_bool(title.resume_card().visible).is_false()
	DirAccess.remove_absolute(records_dir)
	DirAccess.make_dir_recursive_absolute(records_dir)
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	assert_bool(title.confirm_dialog().is_open()).is_false()
	assert_array(_requested).is_equal([AppScreens.Id.S02_MATCH_SETUP] as Array[int])
	assert_int(RecordStore.new(ConfigRepository.new().match_rules(), records_dir).load_all().size()).is_equal(1)
	assert_int(_store.load().status).is_equal(SuspendedLoad.Status.NONE)


func test_kick_off_with_an_unrecorded_match_asks_when_the_retry_fails() -> void:
	_leave_an_unrecorded_match()
	var title: TitleScreen = _open()
	(title.find_child("KickOffCard", true, false) as Button).pressed.emit()
	var dialog: ConfirmDialog = title.confirm_dialog()
	assert_bool(dialog.is_open()).is_true()
	assert_str(dialog.message()).is_equal(NewMatchGate.UNRECORDED_MESSAGE)
	assert_int(title.state()).is_equal(TitleScreen.State.CONFIRMING)
	dialog.ok_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S02_MATCH_SETUP] as Array[int])
	# 中断データはここでは消さない（試合の作成時に上書きされる）
	assert_int(_store.load().status).is_equal(SuspendedLoad.Status.OK)

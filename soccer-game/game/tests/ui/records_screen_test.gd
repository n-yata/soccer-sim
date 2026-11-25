## S-11 戦績（screen-11-records.md）のテスト。App.user_data を一時ディレクトリへ保存するサービスに差し替え、
## 戦績はそのサービスの append_record で入れる（本番と同じ経路）。
extends GdUnitTestSuite

const RECORDS_SCENE: String = "res://ui/screens/s11_records/records_screen.tscn"

var _original_user_data: UserDataService
var _original_controller: MatchController
var _requested: Array[int] = []
var _store: SuspendedMatchStore
## 一時ディレクトリはスイートの中ではテストごとに消えないので、テストごとに別の名前にする
var _test_count: int = 0


func before_test() -> void:
	_test_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("records_screen/records_%d" % _test_count))
	_original_controller = App.match_controller
	_store = SuspendedMatchStore.new(ContentRepository.new().load_catalog(), ConfigRepository.new().match_rules(),
			create_temp_dir("records_screen/save_%d" % _test_count))
	App.match_controller = ScreenTestHelper.new_controller(0, App.request_screen, _store)
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	App.match_controller = _original_controller
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> RecordsScreen:
	var screen: RecordsScreen = auto_free((load(RECORDS_SCENE) as PackedScene).instantiate() as RecordsScreen) \
			as RecordsScreen
	add_child(screen)
	screen.enter({})
	_requested.clear()
	return screen


## 試合 ID の末尾は id_number、終了日時は 10/<day> 19:<minute>
func _add(id_number: int, score_user: int, score_cpu: int, day: int = 17, minute: int = 0) -> void:
	var record := MatchRecord.new()
	record.match_id = "20261029-100000-%04d" % id_number
	record.record_id = record.match_id
	record.finished_at = "2026-10-%02dT19:%02d:00" % [day, minute]
	record.score_user = score_user
	record.score_cpu = score_cpu
	record.result = MatchRecord.result_of(score_user, score_cpu)
	record.timeline.append(RecordPeriod.new(1, 1,
			TeamSetup.new("4-3-3", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION)),
			TeamSetup.new("4-4-2", TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER))))
	assert_bool(App.user_data.append_record(record)).is_true()


func test_totals_and_rows_newest_first() -> void:
	_add(1, 2, 1, 17, 42)
	_add(2, 1, 1, 18, 5)
	_add(3, 0, 2, 16, 30)
	var screen: RecordsScreen = _open()
	assert_bool(screen.is_empty_shown()).is_false()
	assert_array([screen.total_text("win"), screen.total_text("draw"), screen.total_text("lose")]).is_equal(["1", "1", "1"])
	assert_int(screen.row_count()).is_equal(3)
	assert_array(screen.row_texts(0)).is_equal(["引き分け", "1 – 1　10/18 19:05",
			"● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型"])
	assert_array(screen.row_texts(1).slice(0, 2)).is_equal(["勝ち", "2 – 1　10/17 19:42"])
	assert_array(screen.row_texts(2).slice(0, 2)).is_equal(["負け", "0 – 2　10/16 19:30"])


func test_no_records_shows_the_empty_state_and_kick_off_goes_to_the_setup() -> void:
	var screen: RecordsScreen = _open()
	assert_bool(screen.is_empty_shown()).is_true()
	assert_int(screen.row_count()).is_equal(0)
	assert_array([screen.total_text("win"), screen.total_text("draw"), screen.total_text("lose")]).is_equal(["0", "0", "0"])
	screen.kick_off_button().pressed.emit()
	screen.kick_off_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S02_MATCH_SETUP] as Array[int])
	assert_int(screen.state()).is_equal(RecordsScreen.State.BUSY)


func test_kick_off_with_a_suspended_match_asks_and_back_closes_the_dialog() -> void:
	App.match_controller.start_match(ScreenTestHelper.user_setup())
	App.match_controller.suspend_to_title()
	var screen: RecordsScreen = _open()
	screen.kick_off_button().pressed.emit()
	assert_bool(screen.confirm_dialog().is_open()).is_true()
	assert_str(screen.confirm_dialog().message()).is_equal(NewMatchGate.DISCARD_MESSAGE)
	assert_int(screen.state()).is_equal(RecordsScreen.State.CONFIRMING)
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.confirm_dialog().is_open()).is_false()
	assert_int(screen.state()).is_equal(RecordsScreen.State.IDLE)
	assert_array(_requested).is_empty()


func test_back_goes_to_the_title() -> void:
	var screen: RecordsScreen = _open()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_rows_are_added_page_by_page() -> void:
	var total: int = RecordsScreen.PAGE_SIZE * 2 + 5
	for index: int in range(total):
		_add(index, 1, 0, 1 + floori(index / 60.0), index % 60)
	var screen: RecordsScreen = _open()
	assert_int(screen.row_count()).is_equal(RecordsScreen.PAGE_SIZE)
	screen.show_more()
	assert_int(screen.row_count()).is_equal(RecordsScreen.PAGE_SIZE * 2)
	screen.show_more()
	screen.show_more()
	assert_int(screen.row_count()).is_equal(total)
	# 最後の行は最も古い試合
	assert_str(screen.row_texts(total - 1)[1]).ends_with("10/1 19:00")


func test_scrolling_to_the_bottom_adds_the_next_page() -> void:
	for index: int in range(RecordsScreen.PAGE_SIZE + 3):
		_add(index, 1, 0, 1, index)
	var screen: RecordsScreen = _open()
	screen.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: VScrollBar = screen.record_list().get_v_scroll_bar()
	assert_float(bar.max_value).is_greater(bar.page)
	bar.value = bar.max_value
	assert_int(screen.row_count()).is_equal(RecordsScreen.PAGE_SIZE + 3)

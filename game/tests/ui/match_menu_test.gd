## 試合中のメニュー（MatchMenu・MatchMenuHost）と ConfirmDialog のテスト（screen-03-match.md「メニュー」「Android の戻る操作」、
## S-04・S-05 は同じ）。画面のテストは App.match_controller を一時ディレクトリへ保存するコントローラに差し替える。
extends GdUnitTestSuite

var _original_controller: MatchController
var _requested: Array[int] = []
var _test_count: int = 0


func before_test() -> void:
	_original_controller = App.match_controller
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.match_controller = _original_controller
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


## stop まで進めた試合を App に置く（保存先はテストごとの一時ディレクトリ）
func _match_at(stop: ScreenTestHelper.Stop) -> MatchController:
	_test_count += 1
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var store := SuspendedMatchStore.new(catalog, ConfigRepository.new().match_rules(),
			create_temp_dir("match_menu/save_%d" % _test_count))
	var controller: MatchController = ScreenTestHelper.new_controller(ScreenTestHelper.seed_reaching(stop),
			App.request_screen, store)
	controller.start_match(ScreenTestHelper.user_setup())
	ScreenTestHelper.advance_until(controller, stop)
	App.match_controller = controller
	_requested.clear()
	return controller


func _open(path: String) -> AppScreen:
	var screen: AppScreen = auto_free((load(path) as PackedScene).instantiate() as AppScreen) as AppScreen
	add_child(screen)
	screen.size = Vector2(1280, 720)
	screen.enter({})
	return screen


func _menu() -> MatchMenu:
	var menu: MatchMenu = auto_free(MatchMenu.new()) as MatchMenu
	add_child(menu)
	return menu


# --- ConfirmDialog ---


func test_confirm_dialog_answers_once_and_closes() -> void:
	var dialog: ConfirmDialog = auto_free(ConfirmDialog.new()) as ConfirmDialog
	add_child(dialog)
	var answers: Array[bool] = []
	dialog.answered.connect(func(ok: bool) -> void: answers.append(ok))
	dialog.ask("よろしいですか", "はい", "いいえ")
	assert_bool(dialog.is_open()).is_true()
	assert_str(dialog.message()).is_equal("よろしいですか")
	assert_array([dialog.ok_button().text, dialog.cancel_button().text]).is_equal(["はい", "いいえ"])
	dialog.ok_button().pressed.emit()
	dialog.ok_button().pressed.emit()
	assert_array(answers).is_equal([true] as Array[bool])
	assert_bool(dialog.is_open()).is_false()
	dialog.ask("もう一度", "はい", "いいえ")
	dialog.cancel()
	dialog.cancel()
	assert_array(answers).is_equal([true, false] as Array[bool])


func test_confirm_dialog_covers_the_screen_and_stops_input_below() -> void:
	var dialog: ConfirmDialog = auto_free(ConfirmDialog.new()) as ConfirmDialog
	add_child(dialog)
	assert_int(dialog.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(dialog.ok_button().custom_minimum_size.y >= 96.0).is_true()


func test_an_open_dialog_keeps_the_keyboard_focus_inside() -> void:
	var outside := Button.new()
	add_child(auto_free(outside) as Button)
	var dialog: ConfirmDialog = auto_free(ConfirmDialog.new()) as ConfirmDialog
	add_child(dialog)
	dialog.ask("よろしいですか", "はい", "いいえ")
	assert_bool(dialog.is_ancestor_of(get_viewport().gui_get_focus_owner())).is_true()
	# 下の画面のボタンへフォーカスが移ろうとしても、ダイアログの中へ戻す（矢印・Tab で下のボタンを押せない）
	outside.grab_focus()
	assert_bool(dialog.is_ancestor_of(get_viewport().gui_get_focus_owner())).is_true()
	# 閉じたら、外のボタンへ移れる
	dialog.cancel()
	outside.grab_focus()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(outside)


# --- MatchMenu ---


func test_suspend_without_unsaved_progress_is_requested_at_once() -> void:
	var menu: MatchMenu = _menu()
	var requested: Array[bool] = []
	menu.suspend_requested.connect(func() -> void: requested.append(true))
	menu.open(false)
	menu.suspend_button().pressed.emit()
	assert_array(requested).is_equal([true] as Array[bool])
	assert_bool(menu.is_open()).is_false()
	assert_bool(menu.confirm_dialog().is_open()).is_false()


func test_suspend_with_unsaved_progress_warns_first() -> void:
	var menu: MatchMenu = _menu()
	var requested: Array[bool] = []
	menu.suspend_requested.connect(func() -> void: requested.append(true))
	menu.open(true)
	menu.suspend_button().pressed.emit()
	assert_bool(menu.confirm_dialog().is_open()).is_true()
	assert_str(menu.confirm_dialog().message()).is_equal(MatchMenu.UNSAVED_WARNING)
	# やめたらメニューに戻る
	menu.confirm_dialog().cancel_button().pressed.emit()
	assert_array(requested).is_empty()
	assert_bool(menu.is_open()).is_true()
	menu.suspend_button().pressed.emit()
	menu.confirm_dialog().ok_button().pressed.emit()
	assert_array(requested).is_equal([true] as Array[bool])
	assert_bool(menu.is_open()).is_false()


func test_back_closes_the_topmost_layer_and_settings_is_not_ready_yet() -> void:
	var menu: MatchMenu = _menu()
	var closed: Array[bool] = []
	menu.closed.connect(func() -> void: closed.append(true))
	assert_bool(menu.settings_button().disabled).is_true()
	menu.open(true)
	menu.suspend_button().pressed.emit()
	assert_bool(menu.handle_back()).is_true()
	assert_bool(menu.confirm_dialog().is_open()).is_false()
	assert_bool(menu.is_open()).is_true()
	assert_bool(menu.handle_back()).is_true()
	assert_bool(menu.is_open()).is_false()
	assert_array(closed).is_equal([true] as Array[bool])
	assert_bool(menu.handle_back()).is_false()


# --- 画面 ---


func test_match_screen_menu_opens_from_the_button_and_back_and_suspends_to_the_title() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var host: MatchMenuHost = screen.menu_host()
	host.menu_button().pressed.emit()
	assert_bool(host.is_open()).is_true()
	# メニューが開いている間の戻る操作は、メニューを閉じる
	assert_bool(screen.handle_back()).is_true()
	assert_bool(host.is_open()).is_false()
	# 閉じているときの戻る操作は、メニューを開く
	assert_bool(screen.handle_back()).is_true()
	assert_bool(host.is_open()).is_true()
	host.menu().suspend_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(App.match_controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.RESUMABLE)


func test_match_screen_menu_does_not_open_while_the_move_is_being_submitted() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	var choice: TurnChoice = ScreenTestHelper.forward_choice(App.match_controller.user_options())
	panel.choice_panel().button_for(choice.action).pressed.emit()
	if choice.target != null:
		panel.board().area_pressed.emit(panel.board().selectable_areas().back())
	# 判定理由を出している間は開ける
	panel.primary_button().pressed.emit()
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.SHOW_RESULT)
	screen.menu_host().menu_button().pressed.emit()
	assert_bool(screen.menu_host().is_open()).is_true()
	screen.menu_host().menu().close()
	# 「次へ」の後（画面の切り替えか次のターンを待つ LEAVING）は開かない
	panel.primary_button().pressed.emit()
	if panel.state() == MatchBoardPanel.State.LEAVING:
		screen.menu_host().menu_button().pressed.emit()
		assert_bool(screen.menu_host().is_open()).is_false()


func test_style_change_menu_suspends_and_is_closed_while_kicking_off() -> void:
	_match_at(ScreenTestHelper.Stop.STYLE_CHANGE)
	var screen: StyleChangeScreen = _open("res://ui/screens/s04_style_change/style_change_screen.tscn") \
			as StyleChangeScreen
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.menu_host().is_open()).is_true()
	screen.menu_host().menu().suspend_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	# 中断した段階（方式の選び直し）から再開できる
	_requested.clear()
	assert_bool(App.match_controller.resume()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S04_STYLE_CHANGE] as Array[int])


func test_style_change_menu_does_not_open_after_kick_off_was_pressed() -> void:
	_match_at(ScreenTestHelper.Stop.STYLE_CHANGE)
	var screen: StyleChangeScreen = _open("res://ui/screens/s04_style_change/style_change_screen.tscn") \
			as StyleChangeScreen
	screen.kick_off_button().pressed.emit()
	assert_int(screen.state()).is_equal(StyleChangeScreen.State.SUBMITTING)
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.menu_host().is_open()).is_false()


func test_halftime_menu_suspends_to_the_title() -> void:
	_match_at(ScreenTestHelper.Stop.HALFTIME)
	var screen: HalftimeScreen = _open("res://ui/screens/s05_halftime/halftime_screen.tscn") as HalftimeScreen
	screen.menu_host().menu_button().pressed.emit()
	assert_bool(screen.menu_host().is_open()).is_true()
	screen.menu_host().menu().suspend_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(App.match_controller.suspended_status()).is_equal(AppScreens.SuspendedStatus.RESUMABLE)


func test_the_menu_warns_when_the_last_save_failed() -> void:
	_test_count += 1
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var store := SuspendedMatchStore.new(catalog, ConfigRepository.new().match_rules(),
			create_temp_dir("match_menu/unsaved_%d" % _test_count).path_join("missing"))
	var controller: MatchController = ScreenTestHelper.new_controller(0, App.request_screen, store)
	controller.start_match(ScreenTestHelper.user_setup())
	App.match_controller = controller
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	screen.menu_host().menu_button().pressed.emit()
	screen.menu_host().menu().suspend_button().pressed.emit()
	assert_bool(screen.menu_host().menu().confirm_dialog().is_open()).is_true()

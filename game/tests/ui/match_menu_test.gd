## 試合中のメニュー（MatchMenu・MatchMenuHost）と ConfirmDialog のテスト（screen-03-match.md「メニュー」「Android の戻る操作」、
## S-04・S-05 は同じ）。画面のテストは App.match_controller を一時ディレクトリへ保存するコントローラに差し替える。
extends GdUnitTestSuite

var _original_controller: MatchController
var _requested: Array[int] = []
var _test_count: int = 0
## App.user_data の元のサービス（試合画面は設定を読むので、テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0
## 設定のテストはバスの音量を変えるので、前に控えて後で戻す
var _saved_buses: Array = []


func before_test() -> void:
	_user_data_count += 1
	_saved_buses = ScreenTestHelper.save_buses()
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("match_menu/user_%d" % _user_data_count))
	_original_controller = App.match_controller
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	ScreenTestHelper.restore_buses(_saved_buses)
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


func test_back_closes_the_topmost_layer() -> void:
	var menu: MatchMenu = _menu()
	var closed: Array[bool] = []
	menu.closed.connect(func() -> void: closed.append(true))
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


## メニューの「設定」で設定を重ね、戻る操作はライセンス → 設定 → メニューの順に閉じる。値は App.user_data に保存される
func test_settings_from_the_menu_stack_on_top_and_back_closes_them_in_order() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var host: MatchMenuHost = screen.menu_host()
	host.menu_button().pressed.emit()
	assert_bool(host.menu().settings_button().disabled).is_false()
	host.menu().settings_button().pressed.emit()
	var overlay: SettingsOverlay = host.settings_overlay()
	assert_bool(overlay.is_open()).is_true()
	assert_bool(host.menu().is_open()).is_true()
	# 設定はメニューより上に描く（後の子）
	assert_int(overlay.get_index()).is_greater(host.menu().get_index())
	overlay.panel().se_slider().value = 40.0
	assert_float(App.user_data.settings().se_volume).is_equal_approx(0.4, 0.0001)
	overlay.panel().license_button().pressed.emit()
	assert_bool(overlay.license_view().is_open()).is_true()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(overlay.license_view().is_open()).is_false()
	assert_bool(overlay.is_open()).is_true()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(overlay.is_open()).is_false()
	assert_bool(host.menu().is_open()).is_true()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(host.menu().is_open()).is_false()
	assert_array(_requested).is_empty()


## ヒントの札が出ているエリアの数（行き先のうち、手の番号のほかにヒントの文を添えた札。番号だけの札は「①」「①③」で空白を含まない。
## 2026-11-03）
func _hint_tag_count(panel: MatchBoardPanel) -> int:
	var count: int = 0
	for area_key: String in panel.board().selectable_areas():
		if panel.board().hint_of(area_key).contains(" "):
			count += 1
	return count


## ヒント表示を切り替えると、選んだ手のまま札が消える／出る（screen-03-match.md「メニュー」の 2.）
## 手の詳細のポップアップを開いているときの戻る操作は、メニューを開かずにポップアップを閉じる（2026-11-05）
func test_back_closes_the_move_detail_before_opening_the_menu() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	panel.choice_panel().button_for(panel.choice_panel().actions()[0]).pressed.emit()
	panel.detail_button().pressed.emit()
	assert_bool(panel.detail_view().is_open()).is_true()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(panel.detail_view().is_open()).is_false()
	assert_bool(screen.menu_host().is_open()).is_false()
	# 閉じた後の戻る操作は、ふだんどおりメニューを開く
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.menu_host().is_open()).is_true()


func test_turning_hints_off_in_the_match_redraws_without_hint_tags() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	# 手を選ぶ前から、自分の手の行き先に札が出ている（2026-11-03）
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
	assert_int(_hint_tag_count(panel)).is_greater(0)
	var host: MatchMenuHost = screen.menu_host()
	host.menu_button().pressed.emit()
	host.menu().settings_button().pressed.emit()
	host.settings_overlay().panel().hint_toggle().button_pressed = false
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
	assert_int(_hint_tag_count(panel)).is_equal(0)
	assert_bool(App.user_data.settings().show_hints).is_false()
	host.settings_overlay().panel().hint_toggle().button_pressed = true
	assert_int(_hint_tag_count(panel)).is_greater(0)


## 運ぶ先まで選んだ後（READY）に切り替えても、選んだ手と運ぶ先はそのまま（screen-03-match.md「メニュー」の 2.「選択は保つ」）。
## 閉じると、メニューにキー操作のフォーカスが戻る
func test_turning_hints_off_after_choosing_a_target_keeps_the_choice() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	var choice: TurnChoice = _choice_with_target(App.match_controller.user_options())
	panel.choice_panel().button_for(choice.action).pressed.emit()
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.READY)
	var summary: String = panel.primary_summary()
	var host: MatchMenuHost = screen.menu_host()
	host.menu_button().pressed.emit()
	host.menu().settings_button().pressed.emit()
	host.settings_overlay().panel().hint_toggle().button_pressed = false
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.READY)
	assert_str(panel.primary_summary()).is_equal(summary)
	assert_int(_hint_tag_count(panel)).is_equal(0)
	host.settings_overlay().close_button().pressed.emit()
	assert_bool(host.menu().is_ancestor_of(get_viewport().gui_get_focus_owner())).is_true()


## 設定でヒント表示が OFF なら、試合画面は最初からヒントの札を出さない
func test_with_hints_off_the_match_screen_shows_no_hint_tags() -> void:
	var settings: UserSettings = App.user_data.settings()
	settings.show_hints = false
	App.user_data.save_settings(settings)
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	panel.choice_panel().button_for(_choice_with_target(App.match_controller.user_options()).action).pressed.emit()
	assert_int(panel.board().selectable_areas().size()).is_greater(0)
	assert_int(_hint_tag_count(panel)).is_equal(0)


## 運ぶ先を持つ手のうち、選べる最初の手
func _choice_with_target(options: MoveOptions) -> TurnChoice:
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for family: int in range(action_counts.size()):
		for action: int in range(action_counts[family]):
			var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
			if options.is_available(family_value, action) and MoveOptions.needs_target(family_value, action):
				return TurnChoice.new(family_value, action, options.targets(family_value, action)[0])
	return null


func test_match_screen_menu_does_not_open_while_the_move_is_being_submitted() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	var choice: TurnChoice = ScreenTestHelper.forward_choice(App.match_controller.user_options())
	panel.choice_panel().button_for(choice.action).pressed.emit()
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


## 試合を終えた後（最終ターンの判定理由）は、メニューを開かない（中断せず、結果画面と終了処理を通す）
func test_match_screen_menu_does_not_open_after_the_last_turn() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.OVER)
	assert_bool(controller.is_match_over()).is_true()
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	screen.menu_host().menu_button().pressed.emit()
	assert_bool(screen.menu_host().is_open()).is_false()
	screen.handle_back()
	assert_bool(screen.menu_host().is_open()).is_false()
	assert_array(_requested).is_empty()


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

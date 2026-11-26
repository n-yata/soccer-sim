## MainShell のテスト。セーフエリアの余白の計算（screen-common.md §1.1）と、画面の対応の有無。
## 画面の入れ替えそのものは ScreenSwitcher のテスト、戻る操作でアプリを閉じることはエミュレーターと PC で確かめる。
## MainShell は起動時に App.match_controller.inspect_suspended() を呼ぶので、テストごとに一時ディレクトリへ保存する
## コントローラに差し替える（開発用の PC の中断データを読み書きしないため）。
extends GdUnitTestSuite

var _original_controller: MatchController
var _save_dir: String
## 一時ディレクトリはスイートの中ではテストごとに消えないので、テストごとに別の名前にする（前のテストの中断データを読まないため）
var _test_count: int = 0
## App.user_data の元のサービス（テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0
## MainShell は起動時に設定の音量をバスへ反映するので、前に控えて後で戻す
var _saved_buses: Array = []


func before_test() -> void:
	_user_data_count += 1
	_saved_buses = ScreenTestHelper.save_buses()
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("main_shell/records_%d" % _user_data_count))
	_original_controller = App.match_controller
	_test_count += 1
	_save_dir = create_temp_dir("main_shell/save_%d" % _test_count)
	_use_store_in(_save_dir)


func after_test() -> void:
	App.user_data = _original_user_data
	ScreenTestHelper.restore_buses(_saved_buses)
	App.match_controller = _original_controller


func _use_store_in(dir: String) -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var store := SuspendedMatchStore.new(catalog, ConfigRepository.new().match_rules(), dir)
	var controller: MatchController = ScreenTestHelper.new_controller(0, App.request_screen, store)
	controller.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: App.storage_error.emit(kind))
	App.match_controller = controller


func _assert_margins(actual: Vector2, left: float, right: float) -> void:
	assert_float(actual.x).is_equal_approx(left, 0.001)
	assert_float(actual.y).is_equal_approx(right, 0.001)


func test_side_margins_are_zero_without_cutout() -> void:
	_assert_margins(MainShell.side_margins(Vector2i(2400, 1080), Rect2i(0, 0, 2400, 1080), 720.0), 0.0, 0.0)


func test_side_margins_scale_left_cutout_to_base_resolution() -> void:
	# keep_height なので、倍率は 720 / 1080。切り欠き 120px は基準解像度で 80px
	_assert_margins(MainShell.side_margins(Vector2i(2400, 1080), Rect2i(120, 0, 2280, 1080), 720.0), 80.0, 0.0)


func test_side_margins_handle_both_sides() -> void:
	_assert_margins(MainShell.side_margins(Vector2i(2400, 1080), Rect2i(90, 0, 2160, 1080), 720.0), 60.0, 100.0)


func test_side_margins_without_scaling() -> void:
	_assert_margins(MainShell.side_margins(Vector2i(1600, 720), Rect2i(40, 0, 1500, 720), 720.0), 40.0, 60.0)


func test_side_margins_never_negative() -> void:
	# 安全な範囲がウィンドウからはみ出していても、余白は負にしない
	_assert_margins(MainShell.side_margins(Vector2i(2400, 1080), Rect2i(-30, 0, 2500, 1080), 720.0), 0.0, 0.0)


func test_side_margins_with_zero_window_height_are_zero() -> void:
	_assert_margins(MainShell.side_margins(Vector2i(0, 0), Rect2i(0, 0, 0, 0), 720.0), 0.0, 0.0)


func test_side_margins_with_empty_safe_area_are_zero() -> void:
	# 端末や状態によって get_display_safe_area() が大きさ 0 の範囲を返すことがある。右の余白が画面幅にならないこと
	_assert_margins(MainShell.side_margins(Vector2i(2400, 1080), Rect2i(), 720.0), 0.0, 0.0)


## 縦・横（2026-11-27）: ウィンドウが縦長（高さ ＞ 幅）なら縦。正方形は横として扱う（今までの配置のまま）
func test_a_window_taller_than_wide_is_portrait() -> void:
	assert_bool(MainShell.is_portrait_window(Vector2i(390, 844))).is_true()
	assert_bool(MainShell.is_portrait_window(Vector2i(844, 390))).is_false()
	assert_bool(MainShell.is_portrait_window(Vector2i(800, 800))).is_false()
	assert_bool(MainShell.is_portrait_window(Vector2i(0, 0))).is_false()


## 基準の解像度と合わせ方: 横は 1280×720 を高さに合わせ（余った幅を画面に渡す）、縦は 720×1280 を幅に合わせる（余った高さを渡す）
func test_the_base_size_and_aspect_follow_the_orientation() -> void:
	assert_object(MainShell.base_size(false)).is_equal(Vector2i(1280, 720))
	assert_int(MainShell.scale_aspect(false)).is_equal(Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT)
	assert_object(MainShell.base_size(true)).is_equal(Vector2i(720, 1280))
	assert_int(MainShell.scale_aspect(true)).is_equal(Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH)


## 縦の切り欠き（上）・ジェスチャーの帯（下）の余白。keep_width なので倍率は viewport_width / window_size.x
func test_top_bottom_margins_scale_the_cutout_to_the_base_resolution() -> void:
	# 1080×2400 の窓で、上に 120px の切り欠き、下に 60px の帯。基準の幅 720 なので 2/3 倍
	_assert_margins(MainShell.top_bottom_margins(Vector2i(1080, 2400), Rect2i(0, 120, 1080, 2220), 720.0), 80.0, 40.0)
	_assert_margins(MainShell.top_bottom_margins(Vector2i(1080, 2400), Rect2i(0, 0, 1080, 2400), 720.0), 0.0, 0.0)


func test_top_bottom_margins_are_zero_for_an_empty_window_or_safe_area_and_never_negative() -> void:
	_assert_margins(MainShell.top_bottom_margins(Vector2i(0, 0), Rect2i(0, 0, 0, 0), 720.0), 0.0, 0.0)
	_assert_margins(MainShell.top_bottom_margins(Vector2i(1080, 2400), Rect2i(), 720.0), 0.0, 0.0)
	_assert_margins(MainShell.top_bottom_margins(Vector2i(1080, 2400), Rect2i(0, -30, 1080, 2500), 720.0), 0.0, 0.0)


func test_has_screen_follows_screen_scenes() -> void:
	assert_bool(MainShell.has_screen(AppScreens.Id.S01_TITLE)).is_true()
	for screen: int in AppScreens.Id.values():
		assert_bool(MainShell.has_screen(screen as AppScreens.Id)) \
				.override_failure_message(AppScreens.Id.find_key(screen) as String) \
				.is_equal(MainShell.SCREEN_SCENES.has(screen))


func test_every_registered_scene_exists_and_is_an_app_screen() -> void:
	for screen: int in MainShell.SCREEN_SCENES:
		var path: String = MainShell.SCREEN_SCENES[screen]
		var scene: PackedScene = load(path) as PackedScene
		assert_object(scene).override_failure_message(path).is_not_null()
		if scene != null:
			var instance: Node = scene.instantiate()
			assert_bool(instance is AppScreen).override_failure_message(path).is_true()
			instance.free()


const MAIN_SHELL_SCENE: String = "res://ui/main_shell.tscn"


## 組み立てる側のテスト。実際のメインシーンを作り、App のシグナルからタイトルが開くまでを通す。
## 画面の入れ替えは遅らせて呼ぶ（call_deferred）ため、フレームを進めてから確かめる。
func _open_main_shell() -> MainShell:
	var shell: MainShell = (load(MAIN_SHELL_SCENE) as PackedScene).instantiate() as MainShell
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	return shell


func test_main_shell_opens_title_on_start() -> void:
	var shell: MainShell = await _open_main_shell()
	var screen_root: Node = shell.get_node("ScreenRoot")
	assert_int(screen_root.get_child_count()).is_equal(1)
	assert_bool(screen_root.get_child(0) is TitleScreen).is_true()
	assert_int(shell.current_screen_id()).is_equal(AppScreens.Id.S01_TITLE)
	shell.free()


## 画面一覧（S-01〜S-12）のすべてを作った（理解度チェックで最後。2026-10-31）。登録の無い画面を頼んだときに今の画面のまま
## にすることは、ScreenSwitcher のテスト（test_unknown_screen_keeps_current_screen）で確かめる
func test_every_screen_is_registered() -> void:
	for screen: int in AppScreens.Id.values():
		assert_bool(MainShell.has_screen(screen as AppScreens.Id)) \
				.override_failure_message(str(AppScreens.Id.find_key(screen))).is_true()
		assert_bool(ResourceLoader.exists(MainShell.SCREEN_SCENES[screen] as String)) \
				.override_failure_message(str(AppScreens.Id.find_key(screen))).is_true()


func test_a_corrupted_suspended_match_at_startup_is_reported_after_the_title_opens() -> void:
	var file: FileAccess = FileAccess.open(_save_dir.path_join(SuspendedMatchStore.FILE_NAME), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var shell: MainShell = await _open_main_shell()
	assert_int(shell.current_screen_id()).is_equal(AppScreens.Id.S01_TITLE)
	assert_str(shell.toast_message()).is_equal(ToastView.message_of(AppScreens.StorageErrorKind.SUSPEND_LOAD))
	assert_bool(FileAccess.file_exists(_save_dir.path_join(SuspendedMatchStore.FILE_NAME))).is_false()
	shell.free()


func test_a_resumable_match_at_startup_shows_the_resume_card_without_a_notice() -> void:
	var earlier: MatchController = App.match_controller
	earlier.start_match(ScreenTestHelper.user_setup())
	_use_store_in(_save_dir)
	var shell: MainShell = await _open_main_shell()
	assert_str(shell.toast_message()).is_empty()
	var title: TitleScreen = shell.current_screen() as TitleScreen
	assert_bool(title.resume_card().visible).is_true()
	shell.free()


func test_storage_errors_after_the_title_opened_are_shown_at_once() -> void:
	var shell: MainShell = await _open_main_shell()
	assert_str(shell.toast_message()).is_empty()
	App.storage_error.emit(AppScreens.StorageErrorKind.SUSPEND_SAVE)
	assert_str(shell.toast_message()).is_equal(ToastView.message_of(AppScreens.StorageErrorKind.SUSPEND_SAVE))
	shell.free()


func test_every_storage_error_kind_has_a_message() -> void:
	for kind: int in AppScreens.StorageErrorKind.values():
		assert_str(ToastView.message_of(kind as AppScreens.StorageErrorKind)).override_failure_message(str(kind)) \
				.is_not_empty()


func test_back_at_title_means_the_app_should_quit() -> void:
	var shell: MainShell = await _open_main_shell()
	assert_bool(shell.should_quit_after_back("test")).is_true()
	shell.free()


func test_main_shell_disconnects_from_app_when_removed() -> void:
	var before: int = App.screen_requested.get_connections().size()
	var shell: MainShell = await _open_main_shell()
	assert_int(App.screen_requested.get_connections().size()).is_equal(before + 1)
	shell.free()
	assert_int(App.screen_requested.get_connections().size()).is_equal(before)


func test_pressing_kick_off_on_title_opens_match_setup_without_errors() -> void:
	var shell: MainShell = await _open_main_shell()
	var title: TitleScreen = shell.get_node("ScreenRoot").get_child(0) as TitleScreen
	var kick_off: Button = title.find_child("KickOffCard", true, false) as Button
	# 押したボタンの pressed の中で画面の入れ替えが要求される。入れ替えは遅らせて行うので、その間にエラーが出ないこと
	await assert_error(func() -> void:
		kick_off.pressed.emit()
		await get_tree().process_frame
	).is_success()
	assert_int(shell.current_screen_id()).is_equal(AppScreens.Id.S02_MATCH_SETUP)
	assert_bool(shell.get_node("ScreenRoot").get_child(0) is MatchSetupScreen).is_true()
	# 試合準備で戻る操作をすると、タイトルへ戻り、アプリは閉じない
	assert_bool(shell.should_quit_after_back("test")).is_false()
	await get_tree().process_frame
	assert_int(shell.current_screen_id()).is_equal(AppScreens.Id.S01_TITLE)
	shell.free()

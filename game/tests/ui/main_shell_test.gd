## MainShell のテスト。セーフエリアの余白の計算（screen-common.md §1.1）と、画面の対応の有無。
## 画面の入れ替えそのものは ScreenSwitcher のテスト、戻る操作でアプリを閉じることはエミュレーターと PC で確かめる。
extends GdUnitTestSuite


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


func test_main_shell_keeps_screen_when_requested_screen_is_missing() -> void:
	var shell: MainShell = await _open_main_shell()
	var title: Node = shell.get_node("ScreenRoot").get_child(0)
	# チュートリアル（S-08）はまだ作っていない画面（S-07 は 2026-10-29 に作った）
	App.request_screen(AppScreens.Id.S08_TUTORIAL)
	await get_tree().process_frame
	assert_int(shell.current_screen_id()).is_equal(AppScreens.Id.S01_TITLE)
	assert_object(shell.get_node("ScreenRoot").get_child(0)).is_same(title)
	shell.free()


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

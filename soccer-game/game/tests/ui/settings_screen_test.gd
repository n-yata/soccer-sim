## S-12 設定（screen-12-settings.md）と SettingsPanel・LicenseView・AudioBuses のテスト。App.user_data を一時ディレクトリへ
## 保存するサービスに差し替え、保存した値はそのサービスから読み直して確かめる。バスの音量とミュートはテストの前に控えて、後で戻す。
extends GdUnitTestSuite

const SETTINGS_SCENE: String = "res://ui/screens/s12_settings/settings_screen.tscn"

var _original_user_data: UserDataService
var _requested: Array[int] = []
var _test_count: int = 0
var _saved_buses: Array = []


func before_test() -> void:
	_test_count += 1
	_saved_buses = ScreenTestHelper.save_buses()
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("settings_screen/user_%d" % _test_count))
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	ScreenTestHelper.restore_buses(_saved_buses)
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> SettingsScreen:
	var screen: SettingsScreen = auto_free((load(SETTINGS_SCENE) as PackedScene).instantiate() as SettingsScreen) \
			as SettingsScreen
	add_child(screen)
	screen.enter({})
	return screen


func _bus_index(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


func test_the_screen_shows_the_saved_settings() -> void:
	var settings: UserSettings = App.user_data.settings()
	settings.bgm_volume = 0.35
	settings.se_volume = 0.0
	settings.show_hints = false
	App.user_data.save_settings(settings)
	var panel: SettingsPanel = _open().panel()
	assert_array([panel.bgm_slider().value, panel.se_slider().value]).is_equal([35.0, 0.0])
	assert_array(panel.value_texts()).is_equal(["35", "0"] as Array[String])
	assert_bool(panel.hint_toggle().button_pressed).is_false()


func test_the_defaults_are_70_70_and_hints_on() -> void:
	var panel: SettingsPanel = _open().panel()
	assert_array([panel.bgm_slider().value, panel.se_slider().value]).is_equal([70.0, 70.0])
	assert_bool(panel.hint_toggle().button_pressed).is_true()


## スライダーは刻み 5、押せる高さ 96px 以上（NFR-19）
func test_sliders_step_by_5_and_are_tall_enough() -> void:
	var panel: SettingsPanel = _open().panel()
	panel.bgm_slider().value = 33.0
	assert_float(panel.bgm_slider().value).is_equal(35.0)
	assert_float(panel.bgm_slider().custom_minimum_size.y).is_greater_equal(96.0)
	assert_float(panel.hint_toggle().custom_minimum_size.y).is_greater_equal(96.0)


## ドラッグしている間は保存せず、離したときに保存する（バスにはその場で反映する）
func test_dragging_applies_at_once_but_saves_only_when_released() -> void:
	var panel: SettingsPanel = _open().panel()
	var slider: HSlider = panel.bgm_slider()
	slider.drag_started.emit()
	slider.value = 20.0
	assert_float(AudioServer.get_bus_volume_db(_bus_index(AudioBuses.BGM_BUS))).is_equal_approx(linear_to_db(0.2), 0.001)
	assert_float(SettingsStore.new(_user_dir()).load().bgm_volume).is_equal(UserSettings.DEFAULT_VOLUME)
	slider.value = 25.0
	slider.drag_ended.emit(true)
	assert_float(SettingsStore.new(_user_dir()).load().bgm_volume).is_equal_approx(0.25, 0.0001)


## ドラッグでない変更（キー操作・押した位置へ飛ぶ）と、トグルの切り替えは、その場で保存する
func test_changes_without_dragging_and_the_toggle_are_saved_at_once() -> void:
	var panel: SettingsPanel = _open().panel()
	panel.se_slider().value = 10.0
	panel.hint_toggle().button_pressed = false
	var saved: UserSettings = SettingsStore.new(_user_dir()).load()
	assert_array([saved.se_volume, saved.show_hints]).is_equal([0.1, false])


func test_volume_zero_mutes_the_bus() -> void:
	var panel: SettingsPanel = _open().panel()
	panel.se_slider().value = 0.0
	assert_bool(AudioServer.is_bus_mute(_bus_index(AudioBuses.SE_BUS))).is_true()
	panel.se_slider().value = 50.0
	assert_bool(AudioServer.is_bus_mute(_bus_index(AudioBuses.SE_BUS))).is_false()
	assert_float(AudioServer.get_bus_volume_db(_bus_index(AudioBuses.SE_BUS))).is_equal_approx(linear_to_db(0.5), 0.001)


## 値を入れるとき（画面を開いたとき）は保存しない
func test_showing_the_settings_does_not_save() -> void:
	_open()
	assert_bool(FileAccess.file_exists(_user_dir().path_join(SettingsStore.FILE_NAME))).is_false()


func test_back_goes_to_the_title_and_closes_the_license_first() -> void:
	var screen: SettingsScreen = _open()
	screen.panel().license_button().pressed.emit()
	assert_bool(screen.license_view().is_open()).is_true()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.license_view().is_open()).is_false()
	assert_array(_requested).is_empty()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_the_license_shows_the_bundled_font_license_with_its_copyright() -> void:
	var screen: SettingsScreen = _open()
	screen.panel().license_button().pressed.emit()
	var text: String = screen.license_view().text()
	assert_str(text).starts_with("Barlow Condensed")
	assert_str(text).contains("Copyright 2017 The Barlow Project Authors")
	assert_str(text).contains("SIL OPEN FONT LICENSE Version 1.1")
	# 日本語の書体（Noto Sans JP）も、配布元の本文に無い著作権表示を先頭に足した OFL で出す（LICENSES.md の台帳）
	assert_str(text).contains("Noto Sans JP\n\nCopyright 2014-2021 Adobe (http://www.adobe.com/).")
	assert_str(text).not_contains(LicenseView.UNREADABLE_TEXT)
	screen.license_view().close_button().pressed.emit()
	assert_bool(screen.license_view().is_open()).is_false()


## 設定の画面は MainShell に登録され、タイトルの「設定」が押せる
func test_the_settings_screen_is_registered() -> void:
	assert_bool(MainShell.has_screen(AppScreens.Id.S12_SETTINGS)).is_true()


func _user_dir() -> String:
	return create_temp_dir("settings_screen/user_%d" % _test_count)

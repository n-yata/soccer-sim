## ScreenSwitcher（画面の入れ替えと戻る操作の振り分け。screen-common.md §4）のテスト。
## 画面はテスト用の対応（tests/fixtures/screens/）を渡して作る。
extends GdUnitTestSuite

const RECORDING_SCREEN: String = "res://tests/fixtures/screens/recording_screen.tscn"
const NOT_A_SCREEN: String = "res://tests/fixtures/screens/not_a_screen.tscn"

var _container: Control
var _switcher: ScreenSwitcher
var _log: Array


func before_test() -> void:
	_container = auto_free(Control.new()) as Control
	add_child(_container)
	_switcher = ScreenSwitcher.new(_container, {
		AppScreens.Id.S01_TITLE: RECORDING_SCREEN,
		AppScreens.Id.S11_RECORDS: RECORDING_SCREEN,
		AppScreens.Id.S12_SETTINGS: NOT_A_SCREEN,
	})
	_log = []


func _params(screen_name: String, back_result: bool = false) -> Dictionary:
	return {"name": screen_name, "back_result": back_result, "call_log": _log}


func test_open_adds_the_screen_and_calls_enter_with_params() -> void:
	var params: Dictionary = _params("title")
	assert_bool(_switcher.open(AppScreens.Id.S01_TITLE, params)).is_true()
	assert_int(_container.get_child_count()).is_equal(1)
	assert_object(_switcher.current()).is_same(_container.get_child(0))
	assert_int(_switcher.current_id()).is_equal(AppScreens.Id.S01_TITLE)
	assert_dict(_switcher.current().get("received_params") as Dictionary).is_equal(params)
	assert_array(_log).is_equal(["title:enter"])


func test_switching_calls_exit_on_old_screen_before_enter_on_new_one() -> void:
	_switcher.open(AppScreens.Id.S01_TITLE, _params("title"))
	var old_screen: AppScreen = _switcher.current()
	assert_bool(_switcher.open(AppScreens.Id.S11_RECORDS, _params("records"))).is_true()
	assert_array(_log).is_equal(["title:enter", "title:exit", "records:enter"])
	assert_int(_container.get_child_count()).is_equal(1)
	assert_object(old_screen.get_parent()).is_null()
	assert_bool(old_screen.is_queued_for_deletion()).is_true()
	assert_int(_switcher.current_id()).is_equal(AppScreens.Id.S11_RECORDS)


func test_unknown_screen_keeps_current_screen() -> void:
	_switcher.open(AppScreens.Id.S01_TITLE, _params("title"))
	var before: AppScreen = _switcher.current()
	assert_bool(_switcher.open(AppScreens.Id.S02_MATCH_SETUP, _params("setup"))).is_false()
	assert_object(_switcher.current()).is_same(before)
	assert_int(_switcher.current_id()).is_equal(AppScreens.Id.S01_TITLE)
	assert_array(_log).is_equal(["title:enter"])
	assert_int(_container.get_child_count()).is_equal(1)


func test_scene_whose_root_is_not_app_screen_is_rejected() -> void:
	_switcher.open(AppScreens.Id.S01_TITLE, _params("title"))
	assert_bool(_switcher.open(AppScreens.Id.S12_SETTINGS, _params("settings"))).is_false()
	assert_int(_switcher.current_id()).is_equal(AppScreens.Id.S01_TITLE)
	assert_array(_log).is_equal(["title:enter"])
	assert_int(_container.get_child_count()).is_equal(1)


func test_route_back_calls_handle_back_once_and_returns_its_value() -> void:
	_switcher.open(AppScreens.Id.S01_TITLE, _params("title", true))
	assert_bool(_switcher.route_back()).is_true()
	assert_array(_log).is_equal(["title:enter", "title:back"])
	_switcher.open(AppScreens.Id.S11_RECORDS, _params("records", false))
	assert_bool(_switcher.route_back()).is_false()
	assert_int(_log.count("records:back")).is_equal(1)


func test_route_back_without_screen_returns_false() -> void:
	assert_object(_switcher.current()).is_null()
	assert_int(_switcher.current_id()).is_equal(-1)
	assert_bool(_switcher.route_back()).is_false()


func test_unknown_screen_reports_an_error() -> void:
	await assert_error(func() -> void: _switcher.open(AppScreens.Id.S02_MATCH_SETUP, _params("setup"))) \
			.is_push_error("ScreenSwitcher: 画面のシーンが登録されていない: S02_MATCH_SETUP")


func test_scene_whose_root_is_not_app_screen_reports_an_error() -> void:
	await assert_error(func() -> void: _switcher.open(AppScreens.Id.S12_SETTINGS, _params("settings"))) \
			.is_push_error("ScreenSwitcher: 画面のルートが AppScreen でない: " + NOT_A_SCREEN)


## 縦・横（2026-11-27）: 向きは、表示中の画面と、その後に開く画面へ伝える。開く画面へは enter の前に伝える（配置を組んでから中身を出す）。
## 同じ向きを伝え直しても、画面は組み替えない
func test_the_orientation_reaches_the_current_and_later_screens_once_per_change() -> void:
	_switcher.set_portrait(true)
	_switcher.open(AppScreens.Id.S01_TITLE, _params("title"))
	var title: AppScreen = _switcher.current()
	assert_bool(title.is_portrait()).is_true()
	assert_array(title.get("orientation_calls") as Array).is_equal([true])
	_switcher.set_portrait(true)
	assert_array(title.get("orientation_calls") as Array).is_equal([true])
	_switcher.set_portrait(false)
	assert_bool(title.is_portrait()).is_false()
	assert_array(title.get("orientation_calls") as Array).is_equal([true, false])
	# 横で開く画面は、初めから横（組み替えは呼ばない）
	_switcher.open(AppScreens.Id.S11_RECORDS, _params("records"))
	assert_bool(_switcher.current().is_portrait()).is_false()
	assert_array(_switcher.current().get("orientation_calls") as Array).is_empty()


func test_setting_the_orientation_without_a_screen_does_nothing_but_remembers_it() -> void:
	_switcher.set_portrait(true)
	assert_object(_switcher.current()).is_null()
	assert_bool(_switcher.is_portrait()).is_true()

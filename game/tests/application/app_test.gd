## App（オートロード。component-design.md §3.1）と AppScreens のテスト。
## オートロードの実体ではなく、スクリプトから新しく作ったものを使う（ほかのテストと状態を共有しないため）。
extends GdUnitTestSuite

const APP_SCRIPT: String = "res://application/app.gd"

var _received: Array[Array] = []


func _on_screen_requested(screen: AppScreens.Id, params: Dictionary) -> void:
	_received.append([screen, params])


func test_request_screen_emits_screen_requested_once_with_same_values() -> void:
	var app: Node = auto_free((load(APP_SCRIPT) as GDScript).new() as Node) as Node
	_received.clear()
	app.connect("screen_requested", _on_screen_requested)
	app.call("request_screen", AppScreens.Id.S11_RECORDS, {"from": "title"})
	assert_int(_received.size()).is_equal(1)
	assert_int(_received[0][0] as int).is_equal(AppScreens.Id.S11_RECORDS)
	assert_dict(_received[0][1] as Dictionary).is_equal({"from": "title"})


func test_request_screen_without_params_sends_empty_dictionary() -> void:
	var app: Node = auto_free((load(APP_SCRIPT) as GDScript).new() as Node) as Node
	_received.clear()
	app.connect("screen_requested", _on_screen_requested)
	app.call("request_screen", AppScreens.Id.S01_TITLE)
	assert_int(_received.size()).is_equal(1)
	assert_dict(_received[0][1] as Dictionary).is_empty()


func test_screen_ids_cover_the_12_screens_in_order() -> void:
	# 画面一覧（functional-overview.md「画面設計」）の S-01〜S-12 と1対1
	var expected: Array[String] = [
		"S01_TITLE", "S02_MATCH_SETUP", "S03_MATCH", "S04_STYLE_CHANGE", "S05_HALFTIME", "S06_RESULT",
		"S07_REVIEW", "S08_TUTORIAL", "S09_QUIZ", "S10_SCOPE", "S11_RECORDS", "S12_SETTINGS",
	]
	var actual: Array[String] = []
	for key: String in AppScreens.Id.keys():
		actual.append(key)
	assert_array(actual).is_equal(expected)


func test_storage_error_kinds_match_component_design() -> void:
	var actual: Array[String] = []
	for key: String in AppScreens.StorageErrorKind.keys():
		actual.append(key)
	assert_array(actual).is_equal(
			["SUSPEND_SAVE", "USER_DATA_SAVE", "SUSPEND_LOAD", "USER_DATA_LOAD", "USER_DATA_NEWER"] as Array[String])

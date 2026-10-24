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


func test_ready_creates_a_match_controller_that_requests_screens_through_the_app() -> void:
	var app: Node = auto_free((load(APP_SCRIPT) as GDScript).new() as Node) as Node
	add_child(app)
	_received.clear()
	app.connect("screen_requested", _on_screen_requested)
	var controller: MatchController = app.get("match_controller") as MatchController
	assert_object(controller).is_not_null()
	# 同梱の陣形で試合を作れる（library と同じカタログ）
	var setup := TeamSetup.new("4-4-2", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER))
	assert_bool(controller.start_match(setup)).is_true()
	assert_int(controller.snapshot().turns_per_half).is_equal(15)
	# 試合を終えるまで進めると、結果の画面を App 経由で頼む（画面が無い前半・後半の切り替えは選び直しで進める）
	var steps: int = 0
	while not controller.is_match_over() and steps < 100:
		steps += 1
		match controller.state().stage:
			GameEnums.MatchStage.STYLE_CHANGE:
				controller.submit_style_change(setup.styles)
			GameEnums.MatchStage.HALFTIME:
				controller.submit_halftime(setup)
			_:
				controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
				controller.continue_after_reveal()
	assert_bool(controller.is_match_over()).is_true()
	assert_int(_received.back()[0] as int).is_equal(AppScreens.Id.S06_RESULT)


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

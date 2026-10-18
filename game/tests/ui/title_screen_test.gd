## TitleScreen（S-01 の骨格。screen-01-title.md）のテスト。
## カードを押せるかは、行き先の画面が MainShell にあるかで決まる（画面を作れば自動で押せるようになる）。
extends GdUnitTestSuite

const TITLE_SCENE: String = "res://ui/screens/s01_title/title_screen.tscn"

## カードのノード名 → 行き先（screen-01-title.md「画面遷移」）
const CARD_DESTINATIONS: Dictionary = {
	"TutorialCard": AppScreens.Id.S08_TUTORIAL,
	"KickOffCard": AppScreens.Id.S02_MATCH_SETUP,
	"QuizCard": AppScreens.Id.S09_QUIZ,
	"RecordsCard": AppScreens.Id.S11_RECORDS,
	"ScopeCard": AppScreens.Id.S10_SCOPE,
	"SettingsCard": AppScreens.Id.S12_SETTINGS,
}

var _title: TitleScreen
var _requested: Array[int] = []


func before_test() -> void:
	_title = auto_free((load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen) as TitleScreen
	add_child(_title)
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _card(card_name: String) -> Button:
	var card: Button = _title.find_child(card_name, true, false) as Button
	assert_object(card).override_failure_message("カードが無い: %s" % card_name).is_not_null()
	return card


func _pending_label(card_name: String) -> Label:
	return _card(card_name).find_child("PendingLabel", true, false) as Label


## 前提: 2026-10-18 時点で MainShell.SCREEN_SCENES にはカードの行き先が1つも無いため、このテストは
## 「enter が MainShell の対応を使っていること」を区別できない（{} を渡す実装でも通る）。S-02 などの画面を足して
## SCREEN_SCENES に登録した時点で、意味のあるテストになる（画面を足す作業で、押せるカードがあることも確かめる）。
func test_cards_follow_main_shell_screens_on_enter() -> void:
	_title.enter({})
	for card_name: String in CARD_DESTINATIONS:
		var is_available: bool = MainShell.has_screen(CARD_DESTINATIONS[card_name] as AppScreens.Id)
		assert_bool(_card(card_name).disabled).override_failure_message(card_name).is_equal(not is_available)
		assert_bool(_pending_label(card_name).visible).override_failure_message(card_name).is_equal(not is_available)


func test_card_with_destination_is_enabled_and_without_is_disabled() -> void:
	_title.enter({})
	_title.apply_availability({AppScreens.Id.S09_QUIZ: "res://any.tscn", AppScreens.Id.S02_MATCH_SETUP: "res://any.tscn"})
	assert_bool(_card("QuizCard").disabled).is_false()
	assert_bool(_pending_label("QuizCard").visible).is_false()
	assert_bool(_card("KickOffCard").disabled).is_false()
	assert_bool(_card("RecordsCard").disabled).is_true()
	assert_bool(_pending_label("RecordsCard").visible).is_true()
	assert_str(_pending_label("RecordsCard").text).is_equal("準備中")


func test_pressing_a_card_requests_its_destination() -> void:
	_title.enter({})
	_title.apply_availability({AppScreens.Id.S11_RECORDS: "res://any.tscn"})
	_card("RecordsCard").pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S11_RECORDS] as Array[int])


func test_every_card_requests_its_own_destination() -> void:
	_title.enter({})
	var all_screens: Dictionary = {}
	for screen: int in AppScreens.Id.values():
		all_screens[screen] = "res://any.tscn"
	_title.apply_availability(all_screens)
	for card_name: String in CARD_DESTINATIONS:
		_requested.clear()
		_card(card_name).pressed.emit()
		assert_array(_requested).override_failure_message(card_name) \
				.is_equal([CARD_DESTINATIONS[card_name] as int] as Array[int])


func test_resume_card_is_hidden_until_match_controller_exists() -> void:
	_title.enter({})
	assert_bool(_card("ResumeCard").visible).is_false()


func test_handle_back_in_idle_returns_false_so_the_app_closes() -> void:
	_title.enter({})
	assert_bool(_title.handle_back()).is_false()


func test_text_in_disabled_card_uses_the_theme_disabled_color() -> void:
	_title.enter({})
	_title.apply_availability({AppScreens.Id.S09_QUIZ: "res://any.tscn"})
	var disabled_color: Color = _title.get_theme_color("font_disabled_color", "Button")
	var kick_off_label: Label = _card("KickOffCard").find_child("KickOffLabel", true, false) as Label
	assert_bool(kick_off_label.has_theme_color_override("font_color")).is_true()
	assert_object(kick_off_label.get_theme_color("font_color")).is_equal(disabled_color)
	# 押せるカードの文字は、テーマの色のまま（上書きしない）
	var quiz_title: Label = _card("QuizCard").find_child("Title", true, false) as Label
	assert_bool(quiz_title.has_theme_color_override("font_color")).is_false()
	# 押せるようになったら、上書きを外す
	_title.apply_availability({AppScreens.Id.S02_MATCH_SETUP: "res://any.tscn"})
	assert_bool(kick_off_label.has_theme_color_override("font_color")).is_false()
	# 「準備中」とタグは上書きしない
	var badge: Label = _card("TutorialCard").find_child("FirstTimeBadge", true, false) as Label
	assert_bool(badge.has_theme_color_override("font_color")).is_false()
	assert_bool(_pending_label("TutorialCard").has_theme_color_override("font_color")).is_false()

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
## App.user_data の元のサービス（テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0


func before_test() -> void:
	_user_data_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("title_screen/records_%d" % _user_data_count))
	_title = auto_free((load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen) as TitleScreen
	add_child(_title)
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
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


## チュートリアルが未完了なら、KICK OFF の直前の大きなカードで「はじめての方へ」を出す（screen-01-title.md「画面を開く」の 3.）
func test_an_unfinished_tutorial_is_the_large_card_before_kick_off() -> void:
	_title.enter({})
	var tutorial: Button = _title.tutorial_card()
	var kick_off: Button = _card("KickOffCard")
	assert_object(tutorial.get_parent()).is_same(kick_off.get_parent())
	assert_int(tutorial.get_index()).is_equal(kick_off.get_index() - 1)
	assert_bool((tutorial.find_child("FirstTimeBadge", true, false) as Control).visible).is_true()
	assert_int(_title.small_cards().columns).is_equal(4)
	assert_bool(tutorial.disabled).is_false()


## 完了後は小さなカードの最後（5列）。「はじめての方へ」を隠し、KICK OFF を高くする（再開カードも無いとき）
func test_a_finished_tutorial_moves_to_the_end_of_the_small_cards() -> void:
	App.user_data.mark_tutorial_completed()
	_title.enter({})
	var tutorial: Button = _title.tutorial_card()
	assert_object(tutorial.get_parent()).is_same(_title.small_cards())
	assert_int(tutorial.get_index()).is_equal(_title.small_cards().get_child_count() - 1)
	assert_int(_title.small_cards().columns).is_equal(5)
	assert_bool((tutorial.find_child("FirstTimeBadge", true, false) as Control).visible).is_false()
	assert_float(_card("KickOffCard").custom_minimum_size.y).is_equal(200.0)
	tutorial.pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S08_TUTORIAL] as Array[int])


## もう一度開いたときに未完了へ戻っていれば（設定を消したなど）、大きなカードへ戻す
func test_the_tutorial_card_moves_back_when_unfinished_again() -> void:
	_title.place_tutorial_card(true)
	_title.place_tutorial_card(false)
	var kick_off: Button = _card("KickOffCard")
	assert_object(_title.tutorial_card().get_parent()).is_same(kick_off.get_parent())
	assert_int(_title.tutorial_card().get_index()).is_equal(kick_off.get_index() - 1)
	assert_int(_title.small_cards().columns).is_equal(4)
	assert_float(kick_off.custom_minimum_size.y).is_equal(136.0)


## 小さなカードの一言（screen-01-title.md「ノード構成」）。押せない間は隠して「準備中」だけを出す
func test_small_cards_show_their_one_liners_only_while_available() -> void:
	_title.enter({})
	assert_str(_title.card_sub_text("ScopeCard")).is_equal("実戦との違い")
	assert_str(_title.card_sub_text("SettingsCard")).is_equal("音量・ヒント")
	assert_str(_title.card_sub_text("RecordsCard")).is_equal("まだ記録がありません")
	assert_str(_title.card_sub_text("QuizCard")).is_equal("未回答")
	_title.apply_availability({AppScreens.Id.S02_MATCH_SETUP: "res://any.tscn"})
	for card_name: String in ["ScopeCard", "SettingsCard", "RecordsCard", "QuizCard"]:
		assert_str(_title.card_sub_text(card_name)).override_failure_message(card_name).is_empty()
		assert_bool(_pending_label(card_name).visible).is_true()


## 理解度チェックの一言は、全学習目標の正答数／問題数（同じ問題は最新の回答で数える。screen-01-title.md「画面を開く」の 4.）
func test_the_quiz_card_shows_the_correct_answers_out_of_all_questions() -> void:
	var total: int = App.library.quiz_questions().size()
	App.user_data.save_quiz_answer(QuizAnswer.new("lg1-switch", false, "2026-10-31T10:00:00"))
	_title.enter({})
	assert_str(_title.card_sub_text("QuizCard")).is_equal("0／%d 正解" % total)
	App.user_data.save_quiz_answer(QuizAnswer.new("lg1-switch", true, "2026-10-31T10:01:00"))
	App.user_data.save_quiz_answer(QuizAnswer.new("lg2-cover", true, "2026-10-31T10:02:00"))
	_title.enter({})
	assert_str(_title.card_sub_text("QuizCard")).is_equal("2／%d 正解" % total)


## MainShell.SCREEN_SCENES に登録した画面（S-02 試合準備など）のカードだけが押せる。
## 押せるカードがあることを、下の test_kick_off_card_is_enabled_because_match_setup_exists で確かめる
## （押せるカードが1つも無いと、enter が MainShell の対応を使っているかを区別できないため）。
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
	var all_screens: Dictionary = {}
	for screen: int in AppScreens.Id.values():
		all_screens[screen] = "res://any.tscn"
	for card_name: String in CARD_DESTINATIONS:
		# 遷移を頼んだ後は画面が替わる前提で押せなくなる（BUSY）ので、カードごとに開き直す
		_title.enter({})
		_title.apply_availability(all_screens)
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


func test_kick_off_card_is_enabled_because_match_setup_exists() -> void:
	# 試合準備（S-02）を MainShell に登録したので、enter で「CPU 対戦」が押せるようになる
	_title.enter({})
	assert_bool(_card("KickOffCard").disabled).is_false()
	assert_bool(_pending_label("KickOffCard").visible).is_false()

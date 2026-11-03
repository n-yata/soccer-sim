## MatchSetupScreen（S-02。screen-02-match-setup.md）のテスト。
extends GdUnitTestSuite

const SCENE: String = "res://ui/screens/s02_match_setup/match_setup_screen.tscn"
const GUIDE_TEXT: String = "陣形と方式を選ぶと、ここに解説が出ます"

var _screen: MatchSetupScreen
var _requested: Array[int] = []
## 空のカタログのテストが App.library を差し替えるので、テストごとに元に戻す（途中で止まっても後のテストに残さない）
var _original_library: LibraryService
## 試合開始のテストが App.match_controller を差し替えるので、テストごとに元に戻す
var _original_controller: MatchController


func before_test() -> void:
	_original_library = App.library
	_original_controller = App.match_controller
	_screen = auto_free((load(SCENE) as PackedScene).instantiate() as MatchSetupScreen) as MatchSetupScreen
	add_child(_screen)
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)
	_screen.enter({})


func after_test() -> void:
	App.library = _original_library
	App.match_controller = _original_controller
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _cards() -> Array[FormationCard]:
	var cards: Array[FormationCard] = []
	for child: Node in _screen.find_child("FormationGrid", true, false).get_children():
		cards.append(child as FormationCard)
	return cards


func _card_by_name(formation_id: String) -> FormationCard:
	for card: FormationCard in _cards():
		if (card.find_child("NameLabel", true, false) as Label).text == formation_id:
			return card
	return null


func _is_marked(card: FormationCard) -> bool:
	return (card.find_child("CheckLabel", true, false) as Label).visible


func _button(node_name: String) -> Button:
	return _screen.find_child(node_name, true, false) as Button


func _start_button() -> Button:
	return _button("StartButton")


func _notes() -> NotesView:
	return _screen.find_child("NotesView", true, false) as NotesView


func _select_all() -> void:
	(_card_by_name("4-3-3").find_child("CardButton", true, false) as Button).pressed.emit()
	_button("ManButton").pressed.emit()
	_button("CounterButton").pressed.emit()


func test_enter_shows_four_formation_cards_in_data_order_with_base_counts() -> void:
	var cards: Array[FormationCard] = _cards()
	assert_int(cards.size()).is_equal(4)
	var expected_ids: Array[String] = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"]
	for i: int in cards.size():
		var name_label: Label = cards[i].find_child("NameLabel", true, false) as Label
		assert_str(name_label.text).is_equal(expected_ids[i])
		var pitch: MiniPitch = cards[i].find_child("MiniPitch", true, false) as MiniPitch
		assert_dict(pitch.counts()).is_equal(App.library.base_counts(expected_ids[i]))


func test_starts_with_nothing_selected_and_start_disabled() -> void:
	assert_bool(_screen.is_ready()).is_false()
	for card: FormationCard in _cards():
		assert_bool(_is_marked(card)).is_false()
	for node_name: String in ["ZoneButton", "ManButton", "PossessionButton", "CounterButton"]:
		assert_bool(_button(node_name).button_pressed).override_failure_message(node_name).is_false()
	assert_bool(_start_button().disabled).is_true()
	assert_array(_notes().texts()).is_equal([GUIDE_TEXT])
	assert_array(_notes().headings()).is_empty()


func test_selecting_a_formation_marks_only_that_card() -> void:
	(_card_by_name("4-3-3").find_child("CardButton", true, false) as Button).pressed.emit()
	assert_bool(_is_marked(_card_by_name("4-3-3"))).is_true()
	(_card_by_name("3-5-2").find_child("CardButton", true, false) as Button).pressed.emit()
	assert_bool(_is_marked(_card_by_name("3-5-2"))).is_true()
	assert_bool(_is_marked(_card_by_name("4-3-3"))).is_false()
	assert_array(_notes().headings()).is_equal(["陣形 3-5-2"])


## 解説欄は、選んだ項目の単独の解説だけを「陣形・守備方式・攻撃方式」の順に出す（screen-02-match-setup.md）
func test_notes_show_only_the_selected_items_in_order() -> void:
	_button("CounterButton").pressed.emit()
	assert_array(_notes().headings()).is_equal(["攻撃方式 カウンター型"])
	_button("ManButton").pressed.emit()
	assert_array(_notes().headings()).is_equal(["守備方式 マンツーマン", "攻撃方式 カウンター型"])
	(_card_by_name("4-3-3").find_child("CardButton", true, false) as Button).pressed.emit()
	assert_array(_notes().headings()).is_equal(["陣形 4-3-3", "守備方式 マンツーマン", "攻撃方式 カウンター型"])
	var expected: Array[String] = []
	for note: MatchupNote in App.library.formation_notes("4-3-3", ""):
		expected.append(NotesView.BULLET + note.text)
	for note: MatchupNote in App.library.style_notes(
			TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER), null):
		expected.append(NotesView.BULLET + note.text)
	assert_array(_notes().texts()).is_equal(expected)
	assert_int(expected.size()).is_equal(9)


func test_style_toggles_select_one_of_two() -> void:
	_button("ZoneButton").pressed.emit()
	assert_bool(_button("ZoneButton").button_pressed).is_true()
	_button("ManButton").pressed.emit()
	assert_bool(_button("ManButton").button_pressed).is_true()
	assert_bool(_button("ZoneButton").button_pressed).is_false()
	_button("PossessionButton").pressed.emit()
	assert_bool(_button("PossessionButton").button_pressed).is_true()
	assert_bool(_button("CounterButton").button_pressed).is_false()


func test_ready_only_after_all_three_are_selected() -> void:
	(_card_by_name("4-3-3").find_child("CardButton", true, false) as Button).pressed.emit()
	_button("ManButton").pressed.emit()
	assert_bool(_screen.is_ready()).is_false()
	_button("CounterButton").pressed.emit()
	assert_bool(_screen.is_ready()).is_true()


func test_start_needs_ready_and_the_match_screen() -> void:
	# 試合画面（S-03）が登録されていれば、READY のときだけ押せる
	_select_all()
	assert_bool(_start_button().disabled).is_false()
	assert_bool((_screen.find_child("StartPendingLabel", true, false) as Label).visible).is_false()
	# S-03 が無ければ、READY でも押せず「準備中」が出る
	_screen.apply_start_availability({})
	assert_bool(_start_button().disabled).is_true()
	assert_bool((_screen.find_child("StartPendingLabel", true, false) as Label).visible).is_true()


func test_start_creates_the_match_with_the_chosen_setup_once() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var config := ConfigRepository.new()
	App.match_controller = MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
			App.request_screen, true)
	_select_all()
	_start_button().pressed.emit()
	# 二度押し・STARTING 中の操作では、試合を作り直さない
	_start_button().pressed.emit()
	assert_bool(_screen.handle_back()).is_true()
	var setup: TeamSetup = App.match_controller.snapshot().user_setup
	assert_str(setup.formation_id).is_equal("4-3-3")
	assert_int(setup.styles.defense).is_equal(GameEnums.DefenseStyle.MAN)
	assert_int(setup.styles.attack).is_equal(GameEnums.AttackStyle.COUNTER)
	assert_array(_requested).is_equal([AppScreens.Id.S03_MATCH] as Array[int])
	assert_int(_screen.state()).is_equal(MatchSetupScreen.State.STARTING)
	assert_bool(_start_button().disabled).is_true()


func test_start_stays_disabled_while_editing_even_with_match_screen() -> void:
	_screen.apply_start_availability({AppScreens.Id.S03_MATCH: "res://any.tscn"})
	assert_bool(_start_button().disabled).is_true()


func test_back_button_requests_title() -> void:
	(_screen.find_child("Header", true, false).find_child("BackButton", true, false) as Button).pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_handle_back_requests_title_and_keeps_the_app_open() -> void:
	assert_bool(_screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_enter_again_clears_previous_selections() -> void:
	_select_all()
	_screen.enter({})
	assert_bool(_screen.is_ready()).is_false()
	for card: FormationCard in _cards():
		assert_bool(_is_marked(card)).is_false()
	assert_bool(_button("ManButton").button_pressed).is_false()
	assert_int(_cards().size()).is_equal(4)


## 実際の押下を再現する: toggle_mode のボタンは、自分で押した状態を反転してから pressed を出す。
func _click_toggle(button: Button) -> void:
	button.set_pressed_no_signal(not button.button_pressed)
	button.pressed.emit()


func test_clicking_the_selected_style_again_keeps_it_selected() -> void:
	_click_toggle(_button("ZoneButton"))
	assert_bool(_button("ZoneButton").button_pressed).is_true()
	_click_toggle(_button("ZoneButton"))
	assert_bool(_button("ZoneButton").button_pressed).is_true()
	assert_bool(_button("ManButton").button_pressed).is_false()


func test_clicking_the_other_style_moves_the_selection() -> void:
	_click_toggle(_button("PossessionButton"))
	_click_toggle(_button("CounterButton"))
	assert_bool(_button("CounterButton").button_pressed).is_true()
	assert_bool(_button("PossessionButton").button_pressed).is_false()


func test_clicking_cards_marks_only_the_clicked_card() -> void:
	var card_433: Button = _card_by_name("4-3-3").find_child("CardButton", true, false) as Button
	var card_352: Button = _card_by_name("3-5-2").find_child("CardButton", true, false) as Button
	_click_toggle(card_433)
	_click_toggle(card_352)
	assert_bool(card_352.button_pressed).is_true()
	assert_bool(card_433.button_pressed).is_false()
	# 選択中のカードをもう一度押しても選択中のまま
	_click_toggle(card_352)
	assert_bool(card_352.button_pressed).is_true()
	assert_bool(_is_marked(_card_by_name("3-5-2"))).is_true()


func test_screen_opens_without_formations_when_catalog_is_empty() -> void:
	# 静的データに誤りがあると、カタログは空になる（ContentRepository）。そのときも画面は開け、開始ボタンは押せない
	App.library = LibraryService.new(ContentCatalog.new())
	_screen.enter({})
	assert_int(_cards().size()).is_equal(0)
	assert_bool(_screen.is_ready()).is_false()
	assert_bool(_start_button().disabled).is_true()

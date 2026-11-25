## S-10 ゲームの表現範囲（screen-10-scope.md）のテスト。一覧は同梱の simplifications.json（App.library）を使う。
extends GdUnitTestSuite

const SCOPE_SCENE: String = "res://ui/screens/s10_scope/scope_screen.tscn"

var _requested: Array[int] = []


func before_test() -> void:
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> ScopeScreen:
	var screen: ScopeScreen = auto_free((load(SCOPE_SCENE) as PackedScene).instantiate() as ScopeScreen) as ScopeScreen
	add_child(screen)
	screen.enter({})
	return screen


## 単純化カタログの全項目を ID 順に、「SIM-NN 名前」「ゲームでは: …」「実戦では: …」のカードで出す（FR-23）
func test_every_simplification_is_shown_in_id_order() -> void:
	var cards: Array[Array] = _open().simplification_list().card_texts()
	var simplifications: Array[SimplificationDef] = App.library.simplifications()
	assert_int(cards.size()).is_equal(simplifications.size())
	assert_int(cards.size()).is_greater(0)
	for index: int in range(cards.size()):
		var expected: SimplificationDef = simplifications[index]
		assert_array(cards[index]).is_equal(["%s %s" % [expected.id, expected.name],
				SimplificationList.IN_GAME_PREFIX + expected.in_game, SimplificationList.IN_REAL_PREFIX + expected.in_real])
	assert_str(cards[0][0] as String).starts_with("SIM-01 ")


func test_the_lead_says_what_the_list_is() -> void:
	var lead: Array[String] = _open().lead_texts()
	assert_str(lead[0]).is_equal("このゲームが表現していないこと")
	assert_str(lead[1]).is_equal("読み合いに集中できるよう、実際のサッカーの次の要素を単純化しています。")


## ヘッダーの「← 戻る」も、戻る操作と同じくタイトルへ
func test_the_header_back_button_goes_to_the_title() -> void:
	var screen: ScopeScreen = _open()
	(screen.find_child("BackButton", true, false) as Button).pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


## 「実戦では」は caution の色（screen-common.md の色の表 #FBBF77）
func test_in_real_lines_use_the_caution_color() -> void:
	var screen: ScopeScreen = _open()
	var in_real: Label = screen.simplification_list().find_child("InReal", true, false) as Label
	assert_str(String(in_real.theme_type_variation)).is_equal("CautionLabel")
	assert_str(in_real.get_theme_color("font_color", "CautionLabel").to_html(false)).is_equal("fbbf77")


func test_opening_again_does_not_duplicate_cards() -> void:
	var screen: ScopeScreen = _open()
	screen.enter({})
	assert_int(screen.simplification_list().card_texts().size()).is_equal(App.library.simplifications().size())


func test_back_goes_to_the_title() -> void:
	var screen: ScopeScreen = _open()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_the_scope_screen_is_registered() -> void:
	assert_bool(MainShell.has_screen(AppScreens.Id.S10_SCOPE)).is_true()

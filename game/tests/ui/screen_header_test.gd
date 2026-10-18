## ScreenHeader（screen-common.md §5）のテスト。
extends GdUnitTestSuite

const SCENE: String = "res://ui/common/screen_header.tscn"

var _header: ScreenHeader
var _back_count: int = 0


func before_test() -> void:
	_header = auto_free((load(SCENE) as PackedScene).instantiate() as ScreenHeader) as ScreenHeader
	add_child(_header)
	_back_count = 0
	_header.back_pressed.connect(func() -> void: _back_count += 1)


func test_back_button_emits_back_pressed_once() -> void:
	(_header.find_child("BackButton", true, false) as Button).pressed.emit()
	assert_int(_back_count).is_equal(1)


func test_set_title_and_back_label_change_the_texts() -> void:
	_header.set_title("試合準備")
	_header.set_back_label("← やめる")
	assert_str((_header.find_child("TitleLabel", true, false) as Label).text).is_equal("試合準備")
	assert_str((_header.find_child("BackButton", true, false) as Button).text).is_equal("← やめる")


func test_header_is_96px_high_and_back_button_is_large_enough_to_tap() -> void:
	# screen-common.md §1.1（ヘッダーの高さ 96px）と、押せるものの最小 96×96px（NFR-19）
	assert_float(_header.custom_minimum_size.y).is_equal(96.0)
	var back: Button = _header.find_child("BackButton", true, false) as Button
	assert_bool(back.custom_minimum_size.x >= 96.0 and back.custom_minimum_size.y >= 96.0).is_true()

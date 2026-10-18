## FormationCard（screen-common.md §5）のテスト。選択の状態は画面が持ち、カードは show() で受け取った値を出すだけ。
extends GdUnitTestSuite

const SCENE: String = "res://ui/common/formation_card.tscn"

var _card: FormationCard
var _pressed_ids: Array[String] = []


func before_test() -> void:
	_card = auto_free((load(SCENE) as PackedScene).instantiate() as FormationCard) as FormationCard
	add_child(_card)
	_pressed_ids.clear()
	_card.pressed.connect(func(formation_id: String) -> void: _pressed_ids.append(formation_id))


func _formation() -> FormationDef:
	return App.library.formations()[0]


func _button() -> Button:
	return _card.find_child("CardButton", true, false) as Button


func test_show_displays_name_and_counts() -> void:
	var formation: FormationDef = _formation()
	var counts: Dictionary = App.library.base_counts(formation.id)
	_card.show_formation(formation, counts, false, false)
	assert_str((_card.find_child("NameLabel", true, false) as Label).text).is_equal(formation.name)
	assert_dict((_card.find_child("MiniPitch", true, false) as MiniPitch).counts()).is_equal(counts)


func test_selected_shows_the_mark() -> void:
	_card.show_formation(_formation(), {}, true, false)
	assert_bool(_button().button_pressed).is_true()
	assert_bool((_card.find_child("CheckLabel", true, false) as Label).visible).is_true()
	_card.show_formation(_formation(), {}, false, false)
	assert_bool(_button().button_pressed).is_false()
	assert_bool((_card.find_child("CheckLabel", true, false) as Label).visible).is_false()


func test_pressing_emits_formation_id_without_changing_the_mark() -> void:
	_card.show_formation(_formation(), {}, false, false)
	_button().pressed.emit()
	assert_array(_pressed_ids).is_equal([_formation().id] as Array[String])
	# 印を変えるのは画面（show を呼び直す）。押しただけでは変えない
	assert_bool((_card.find_child("CheckLabel", true, false) as Label).visible).is_false()


func test_real_click_on_unselected_card_does_not_leave_it_looking_selected() -> void:
	# 実際の押下では、toggle_mode のボタンが自分で押した状態を反転してから pressed が出る。それを再現する
	_card.show_formation(_formation(), {}, false, false)
	_button().set_pressed_no_signal(true)
	_button().pressed.emit()
	assert_array(_pressed_ids).is_equal([_formation().id] as Array[String])
	# 印（黄色の縁＝押した状態と ✓）を決めるのは画面。カードは show_formation で受け取った値（未選択）に戻す
	assert_bool(_button().button_pressed).is_false()
	assert_bool((_card.find_child("CheckLabel", true, false) as Label).visible).is_false()


func test_real_click_on_selected_card_keeps_it_looking_selected() -> void:
	_card.show_formation(_formation(), {}, true, false)
	_button().set_pressed_no_signal(false)
	_button().pressed.emit()
	assert_bool(_button().button_pressed).is_true()

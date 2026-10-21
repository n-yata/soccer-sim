## 手のボタン（screen-common.md §5 の ChoicePanel）。局面の手を enum の順に2列で並べる。
## 運ぶ先が1つもない手は選択不可にし、色だけでなく「（選択不可）」の文字でも示す（screen-design.md S-03）。
## 選んだ印（押した状態）は画面が select_action で付ける。押しただけでは付けない（選択の状態は画面が持つ）。
class_name ChoicePanel
extends GridContainer

signal action_selected(family: GameEnums.ChoiceFamily, action: int)

## ボタンの高さ（screen-common.md §1.1 の押せるものの最小 96px）
const BUTTON_HEIGHT: float = 96.0
## 選べない手は、手の名前の下の行に添える
const UNAVAILABLE_SUFFIX: String = "\n選択不可"

var _family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
var _buttons: Array[Button] = []
var _available: Array[bool] = []
## 画面が select_action で決めた手（-1 は未選択）
var _selected_action: int = -1


func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)


## 局面（攻守ターンかトランジションか、ボールを持っているか）の手を並べ直す。
func show_options(options: MoveOptions, turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> void:
	_family = family_of(turn_kind, user_has_ball)
	for button: Button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_available.clear()
	_selected_action = -1
	var names: Array = MatchTexts.ACTION_NAMES[_family] as Array
	for action: int in range(names.size()):
		var is_available: bool = options.is_available(_family, action)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.text = names[action] as String if is_available else (names[action] as String) + UNAVAILABLE_SUFFIX
		button.disabled = not is_available
		# 長い手の名前（背後へのロングボール）は、ボタンの中で折り返す（左右の余白を詰めた ChoiceButton）
		button.theme_type_variation = &"ChoiceButton"
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		button.pressed.connect(_on_button_pressed.bind(action))
		add_child(button)
		_buttons.append(button)
		_available.append(is_available)


## 局面の手の種類。トランジションでボールを持っているのは奪取側。
static func family_of(turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> GameEnums.ChoiceFamily:
	if turn_kind == GameEnums.TurnKind.TRANSITION:
		return GameEnums.ChoiceFamily.POS_TRANS if user_has_ball else GameEnums.ChoiceFamily.NEG_TRANS
	return GameEnums.ChoiceFamily.ATTACK if user_has_ball else GameEnums.ChoiceFamily.DEFENSE


## 選んだ手に印を付け、ほかの手の印を外す。-1 ならすべて外す。
func select_action(action: int) -> void:
	_selected_action = action
	for index: int in range(_buttons.size()):
		_buttons[index].set_pressed_no_signal(index == action)


## 偽なら全部押せなくする。真に戻すと、選べる手だけを押せるようにする。
func set_enabled(enabled: bool) -> void:
	for index: int in range(_buttons.size()):
		_buttons[index].disabled = not (enabled and _available[index])


## 選べる手が1つ以上あるか。
func has_available() -> bool:
	return _available.has(true)


func family() -> GameEnums.ChoiceFamily:
	return _family


func button_count() -> int:
	return _buttons.size()


## 手のボタン（テストと画面の操作用）。範囲外なら null。
func button_for(action: int) -> Button:
	if action < 0 or action >= _buttons.size():
		return null
	return _buttons[action]


func _on_button_pressed(action: int) -> void:
	# toggle_mode の押した状態は、画面が select_action で決め直すまで、記録した選択のとおりに戻しておく
	select_action(_selected_action)
	action_selected.emit(_family, action)

## 手のボタン（screen-common.md §5 の ChoicePanel）。画面に出す手（MoveMenu）のうち選べる手だけを、枠の並びで2列に並べる
## （2026-11-03。行き先はゲームが決めるので、選べない手は出さない。手は4つまでで、スクロールせずに選べる）。
## ボタンは番号と行動の名前だけ（「① ショートパス」。2026-11-05）。行き先・ヒント・説明は「詳細」のポップアップで見せる。
## 番号は盤面の行き先の札と同じ（MatchBoardPanel が number_of で引く）。
## 選んだ印（押した状態）は画面が select_action で付ける。押しただけでは付けない（選択の状態は画面が持つ）。
class_name ChoicePanel
extends GridContainer

signal action_selected(family: GameEnums.ChoiceFamily, action: int)

## ボタンの高さ（screen-common.md §1.1 の押せるものの最小 96px）
const BUTTON_HEIGHT: float = 96.0
## ボタンと盤面の札の番号（4つ目まで）
const NUMBERS: Array[String] = ["①", "②", "③", "④"]

var _family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
var _buttons: Array[Button] = []
## ボタンの並びごとの手
var _actions: Array[int] = []
## 画面が select_action で決めた手（-1 は未選択）
var _selected_action: int = -1
var _enabled: bool = true


func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)


## 局面（攻守ターンかトランジションか、ボールを持っているか）の手を並べ直す。options は利用者の視点の画面に出す手。
func show_options(options: MoveOptions, turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> void:
	_family = family_of(turn_kind, user_has_ball)
	for button: Button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_actions.clear()
	_selected_action = -1
	for slot: Array in MoveMenu.SLOTS[_family] as Array:
		for action: int in slot:
			if options.is_available(_family, action):
				_add_button(action)


## 局面の手の種類（正本は TurnChoice.family_for。チュートリアルの静的データの検証もそれを使う）。
static func family_of(turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> GameEnums.ChoiceFamily:
	return TurnChoice.family_for(turn_kind, user_has_ball)


## 選んだ手に印を付け、ほかの手の印を外す。-1 ならすべて外す。
func select_action(action: int) -> void:
	_selected_action = action
	for index: int in range(_buttons.size()):
		_buttons[index].set_pressed_no_signal(_actions[index] == action)


## 偽なら全部押せなくする。
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for button: Button in _buttons:
		button.disabled = not enabled


## 選べる手が1つ以上あるか。
func has_available() -> bool:
	return not _buttons.is_empty()


func family() -> GameEnums.ChoiceFamily:
	return _family


func button_count() -> int:
	return _buttons.size()


## 並べた手（ボタンの並び）。
func actions() -> Array[int]:
	return _actions.duplicate()


## 手のボタン（テストと画面の操作用）。並べていない手なら null。
func button_for(action: int) -> Button:
	var index: int = _actions.find(action)
	return null if index < 0 else _buttons[index]


## 手の番号（「①」など。盤面の札と同じ）。並べていない手なら空。
func number_of(action: int) -> String:
	var index: int = _actions.find(action)
	return "" if index < 0 or index >= NUMBERS.size() else NUMBERS[index]


func _add_button(action: int) -> void:
	_actions.append(action)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.text = "%s %s" % [number_of(action), MatchTexts.slot_button_text(_family, action)]
	button.disabled = not _enabled
	# 長い手の名前（シュートコースを塞ぐ）は、slot_button_text が語の切れ目で改行する（左右の余白を詰めた ChoiceButton）。
	# 折り返しの指定は、それでも入らない幅（狭い端末など）のときの保険
	button.theme_type_variation = &"ChoiceButton"
	button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	button.pressed.connect(_on_button_pressed.bind(action))
	add_child(button)
	_buttons.append(button)


func _on_button_pressed(action: int) -> void:
	# toggle_mode の押した状態は、画面が select_action で決め直すまで、記録した選択のとおりに戻しておく
	select_action(_selected_action)
	action_selected.emit(_family, action)

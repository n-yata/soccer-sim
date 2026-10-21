## 守備方式・攻撃方式の2択を2組並べる部品（S-04・S-05）。選んだ状態は押した状態（黄色の縁）で示す。
## 選択の状態はこの部品が持ち、変わったら changed を出す。初期値は画面が set_styles で渡す（現在の方式）。
class_name StylePicker
extends VBoxContainer

signal changed(styles: TeamStyles)

const BUTTON_HEIGHT: float = 96.0

var _defense: GameEnums.DefenseStyle = GameEnums.DefenseStyle.ZONE
var _attack: GameEnums.AttackStyle = GameEnums.AttackStyle.POSSESSION
var _defense_buttons: Array[Button] = []
var _attack_buttons: Array[Button] = []


func _init() -> void:
	add_theme_constant_override("separation", 12)
	_defense_buttons = _add_row("DefenseTitle", "守備方式", "DefenseToggle",
			[["ZoneButton", MatchTexts.defense_style_name(GameEnums.DefenseStyle.ZONE)],
			["ManButton", MatchTexts.defense_style_name(GameEnums.DefenseStyle.MAN)]], _on_defense_pressed)
	_attack_buttons = _add_row("AttackTitle", "攻撃方式", "AttackToggle",
			[["PossessionButton", MatchTexts.attack_style_name(GameEnums.AttackStyle.POSSESSION)],
			["CounterButton", MatchTexts.attack_style_name(GameEnums.AttackStyle.COUNTER)]], _on_attack_pressed)
	_refresh()


func set_styles(styles: TeamStyles) -> void:
	_defense = styles.defense
	_attack = styles.attack
	_refresh()


func styles() -> TeamStyles:
	return TeamStyles.new(_defense, _attack)


func set_enabled(enabled: bool) -> void:
	for button: Button in _defense_buttons + _attack_buttons:
		button.disabled = not enabled


func _on_defense_pressed(index: int) -> void:
	_defense = index as GameEnums.DefenseStyle
	_refresh()
	changed.emit(styles())


func _on_attack_pressed(index: int) -> void:
	_attack = index as GameEnums.AttackStyle
	_refresh()
	changed.emit(styles())


## 押した状態は、ボタンが自分で切り替えた状態ではなく、記録した値から決め直す。
func _refresh() -> void:
	for index: int in range(_defense_buttons.size()):
		_defense_buttons[index].set_pressed_no_signal(index == _defense)
	for index: int in range(_attack_buttons.size()):
		_attack_buttons[index].set_pressed_no_signal(index == _attack)


func _add_row(title_name: String, title: String, row_name: String, buttons: Array, handler: Callable) -> Array[Button]:
	var label := Label.new()
	label.name = title_name
	label.text = title
	label.theme_type_variation = &"SectionTitleLabel"
	add_child(label)
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var created: Array[Button] = []
	for index: int in range(buttons.size()):
		var button := Button.new()
		button.name = buttons[index][0] as String
		button.text = buttons[index][1] as String
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(handler.bind(index))
		row.add_child(button)
		created.append(button)
	return created

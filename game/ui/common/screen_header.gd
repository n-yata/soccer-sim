## 画面の上端のヘッダー（screen-common.md §5。高さ 96px は §1.1）。左に戻る（またはやめる）、その右に画面名。
class_name ScreenHeader
extends Control

## 戻る（またはやめる）のボタンが押された
signal back_pressed

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## 今の画面名。
func title_text() -> String:
	return _title_label.text


## 画面名を変える。
func set_title(text: String) -> void:
	_title_label.text = text


## ヘッダーの右端に部品を置く（振り返りのタブなど）。画面名との間は空ける。
## 木に入る前（画面の組み立て中）にも呼べるよう、@onready の変数ではなくノードの道筋で行を引く。
func add_to_right(control: Control) -> void:
	var row: HBoxContainer = get_node("Row") as HBoxContainer
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(control)


## 戻るボタンの文字を変える（「← やめる」など）。
func set_back_label(text: String) -> void:
	_back_button.text = text

## 画面の上端のヘッダー（screen-common.md §5。高さ 96px は §1.1）。左に戻る（またはやめる）、その右に画面名。
class_name ScreenHeader
extends Control

## 戻る（またはやめる）のボタンが押された
signal back_pressed

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## 画面名を変える。
func set_title(text: String) -> void:
	_title_label.text = text


## 戻るボタンの文字を変える（「← やめる」など）。
func set_back_label(text: String) -> void:
	_back_button.text = text

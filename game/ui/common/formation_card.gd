## 陣形のカード（screen-common.md §5）。陣形名・ミニピッチ・選択中の印（黄色の縁と ✓）を出す。
## ルートを Button にしないのは、シグナル pressed(formation_id) が Button.pressed とぶつかるため。
## 中の全面のボタンを押せる範囲とし、選択の状態は画面が持つ（押しただけでは印を変えず、画面が show_formation を呼び直す）。
## show() は CanvasItem.show() とぶつかるため show_formation() とする。
class_name FormationCard
extends Control

## カードが押された（選択の状態を変えるのは画面）
signal pressed(formation_id: String)

@onready var _button: Button = %CardButton
@onready var _name_label: Label = %NameLabel
@onready var _mini_pitch: MiniPitch = %MiniPitch
@onready var _check_label: Label = %CheckLabel
var _formation_id: String = ""


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)


## compact（S-05 の小さい版）は S-05 の作業で足す。今は無視する。
func show_formation(formation: FormationDef, counts: Dictionary, selected: bool, _compact: bool) -> void:
	_formation_id = formation.id
	_name_label.text = formation.name
	_mini_pitch.show_counts(counts, false)
	_button.set_pressed_no_signal(selected)
	_check_label.visible = selected


func _on_button_pressed() -> void:
	# toggle_mode の押した状態は、画面が show_formation で決め直すまで元に戻しておく
	_button.set_pressed_no_signal(_check_label.visible)
	pressed.emit(_formation_id)

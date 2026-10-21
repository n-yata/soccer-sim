## 陣形のカード（screen-common.md §5）。陣形名・ミニピッチ・選択中の印（黄色の縁と ✓）を出す。
## ルートを Button にしないのは、シグナル pressed(formation_id) が Button.pressed とぶつかるため。
## 中の全面のボタンを押せる範囲とし、選択の状態は画面が持つ（押しただけでは印を変えず、画面が show_formation を呼び直す）。
## show() は CanvasItem.show() とぶつかるため show_formation() とする。
class_name FormationCard
extends Control

## カードが押された（選択の状態を変えるのは画面）
signal pressed(formation_id: String)

## 通常の大きさ（formation_card.tscn のルートの custom_minimum_size の写し。変えたら両方を直す）と、
## 小さい版の大きさ（押せる高さ 96px を保つ）
const FULL_SIZE: Vector2 = Vector2(300, 260)
const COMPACT_SIZE: Vector2 = Vector2(200, 96)

@onready var _button: Button = %CardButton
@onready var _name_label: Label = %NameLabel
@onready var _mini_pitch: MiniPitch = %MiniPitch
@onready var _check_label: Label = %CheckLabel
var _formation_id: String = ""


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)


## compact が真なら、陣形名と ✓ だけの小さい版（S-05。screen-common.md §5）。ミニピッチを隠す。
func show_formation(formation: FormationDef, counts: Dictionary, selected: bool, compact: bool) -> void:
	_formation_id = formation.id
	_name_label.text = formation.name
	_mini_pitch.show_counts(counts, false)
	_mini_pitch.visible = not compact
	custom_minimum_size = COMPACT_SIZE if compact else FULL_SIZE
	_button.set_pressed_no_signal(selected)
	_check_label.visible = selected


func _on_button_pressed() -> void:
	# toggle_mode の押した状態は、画面が show_formation で決め直すまで元に戻しておく
	_button.set_pressed_no_signal(_check_label.visible)
	pressed.emit(_formation_id)

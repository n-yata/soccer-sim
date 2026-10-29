## 画面の上に重ねる部品（確認ダイアログ・試合中のメニュー）の土台。画面全体を暗い幕で覆って下の画面の入力を止め、
## 中央の枠（テーマの型 DialogPanel）に中身を並べる。幕の外側を押しても閉じない（screen-03-match.md「画面の状態」）。
## 画面の最後の子として置く（ほかの部品より上に描かれる）。
class_name ModalOverlay
extends Control

const PANEL_WIDTH: float = 720.0
## ボタンの高さ（screen-common.md §1.1 の押せる大きさ 96px 以上）
const BUTTON_HEIGHT: float = 96.0

## 中身を並べる場所（継承したクラスが組み立てる）
var body: VBoxContainer
var _dim: ColorRect


func _init() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 24)
	panel.add_child(body)


func _ready() -> void:
	_dim.color = get_theme_color(&"dim", &"DialogPanel")
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func is_open() -> bool:
	return visible


## 幕と枠を出す（いちばん上に描かれるよう、親の最後の子へ移す）。
## 幕はマウスとタッチしか止めないので、キー操作（矢印・Tab・決定）でも下の画面を押せないよう、フォーカスを中の最初の
## ボタンへ移し、外へ出たら戻す（screen-03-match.md「下の画面の入力を止める」。2026-10-29）。
func _show_overlay() -> void:
	if get_parent() != null:
		get_parent().move_child(self, -1)
	visible = true
	focus_first()


## 中の押せる最初のボタンにフォーカスを移す（無ければ何もしない）。
func focus_first() -> void:
	if not is_inside_tree():
		return
	for node: Node in find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return


func _on_focus_changed(control: Control) -> void:
	if visible and control != null and not is_ancestor_of(control):
		focus_first()


func _hide_overlay() -> void:
	visible = false


static func make_button(node_name: String, label: String, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = variation
	return button

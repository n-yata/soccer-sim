## 確認ダイアログ（screen-common.md §5 の ConfirmDialog）。ask で文と2つのボタンを出し、押された方を answered で返す。
## 1つの画面で同時に1つだけ。Android の戻る操作は、画面が cancel() を呼んで「やめる」と同じにする。
class_name ConfirmDialog
extends ModalOverlay

signal answered(ok: bool)

var _message: Label
var _ok_button: Button
var _cancel_button: Button


func _init() -> void:
	super()
	name = "ConfirmDialog"
	_message = MatchScreenLayout.text(body, "Message", &"")
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 16)
	body.add_child(buttons)
	_cancel_button = ModalOverlay.make_button("CancelButton", "")
	_ok_button = ModalOverlay.make_button("OkButton", "", &"AccentCard")
	buttons.add_child(_cancel_button)
	buttons.add_child(_ok_button)
	_ok_button.pressed.connect(_answer.bind(true))
	_cancel_button.pressed.connect(_answer.bind(false))


func ask(message: String, ok_label: String, cancel_label: String) -> void:
	_message.text = message
	_ok_button.text = ok_label
	_cancel_button.text = cancel_label
	_show_overlay()


## 「やめる」と同じ（開いていなければ何もしない）。
func cancel() -> void:
	if is_open():
		_answer(false)


func message() -> String:
	return _message.text


func ok_button() -> Button:
	return _ok_button


func cancel_button() -> Button:
	return _cancel_button


## 閉じてから知らせる（受け取った側が、続けて別の確認を出せるように）。二度押しでは2回知らせない。
func _answer(ok: bool) -> void:
	if not is_open():
		return
	_hide_overlay()
	answered.emit(ok)

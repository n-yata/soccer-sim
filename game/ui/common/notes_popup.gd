## 解説のポップアップ（2026-11-06。S-02 の「解説を見る」ボタン）。解説の欄（NotesView）を、スクロールできる枠に出す。
## 画面に欄を並べると、長い解説が画面からはみ出して読めなかったため。「閉じる」で閉じ、画面の選択はそのまま。
## 中身は置く側が notes_view() に入れる（閉じている間も入れてよい）。
class_name NotesPopup
extends ModalOverlay

## 解説の枠の高さ。題・「閉じる」・余白と合わせて画面（高さ 720）に収まる
const TEXT_HEIGHT: float = 400.0

var _notes_view: NotesView
var _close_button: Button


func _init() -> void:
	super()
	name = "NotesPopup"
	MatchScreenLayout.text(body, "Title", &"SectionTitleLabel").text = "解説"
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, TEXT_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_notes_view = NotesView.new()
	_notes_view.name = "NotesView"
	scroll.add_child(_notes_view)
	_close_button = ModalOverlay.make_button("CloseButton", "閉じる", &"AccentCard")
	_close_button.pressed.connect(close)
	body.add_child(_close_button)


func open() -> void:
	_show_overlay()


func close() -> void:
	_hide_overlay()


func notes_view() -> NotesView:
	return _notes_view


func close_button() -> Button:
	return _close_button

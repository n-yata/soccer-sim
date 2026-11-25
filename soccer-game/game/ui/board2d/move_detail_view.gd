## 選んだ手の詳細のポップアップ（2026-11-05。screen-03-match.md「詳細を押す」）。手のボタンは行動の名前だけにしたので、
## 行き先・判断材料（ヒント）・手の説明はここで見せる。「閉じる」で閉じ、選んだ手はそのまま。
class_name MoveDetailView
extends ModalOverlay

var _title: Label
var _text: Label
var _close_button: Button


func _init() -> void:
	super()
	name = "MoveDetailView"
	_title = MatchScreenLayout.text(body, "Title", &"SectionTitleLabel")
	_text = MatchScreenLayout.text(body, "Text", &"PanelLabel")
	_close_button = ModalOverlay.make_button("CloseButton", "閉じる", &"AccentCard")
	_close_button.pressed.connect(close)
	body.add_child(_close_button)


## title は手の名前、lines は1行ずつの説明（空の行は出さない）。
func open(title: String, lines: Array[String]) -> void:
	_title.text = title
	var shown: Array[String] = []
	for line: String in lines:
		if not line.is_empty():
			shown.append(line)
	_text.text = "\n".join(shown)
	_show_overlay()


func close() -> void:
	_hide_overlay()


func title() -> String:
	return _title.text


func text() -> String:
	return _text.text


func close_button() -> Button:
	return _close_button

## アプリ内のライセンスの表示（screen-12-settings.md「ライセンス」。architecture-overview.md のフォントの注記）。
## 同梱した素材の OFL の本文と著作権表示を、スクロールできる枠に出す。閉じると設定に戻る。
## 素材の一覧は assets/LICENSES.md（ライセンス台帳）の書き写し。素材を足したら、台帳とここの両方を直す
## （本文のファイルは書き出しの include_filter にも入れる。export_presets.cfg.example）。
class_name LicenseView
extends ModalOverlay

## [名前, 本文のファイル]。本文の先頭に著作権表示がある
const LICENSES: Array[Array] = [
	["Barlow Condensed", "res://assets/fonts/barlow-condensed/OFL.txt"],
]
const TEXT_HEIGHT: float = 440.0
const UNREADABLE_TEXT: String = "（ライセンスの本文を読み込めませんでした）"

var _text: Label
var _close_button: Button


func _init() -> void:
	super()
	name = "LicenseView"
	MatchScreenLayout.text(body, "Title", &"SectionTitleLabel").text = "ライセンス"
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, TEXT_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_text = MatchScreenLayout.text(scroll, "Text", &"MutedLabel")
	_close_button = ModalOverlay.make_button("CloseButton", "閉じる", &"AccentCard")
	_close_button.pressed.connect(close)
	body.add_child(_close_button)


func open() -> void:
	_text.text = license_text()
	_show_overlay()


func close() -> void:
	_hide_overlay()


## 素材ごとに「名前」と本文を並べた文。本文が読めない素材は、読めなかったことを出す（同梱漏れは開発時の誤り）。
static func license_text() -> String:
	var parts: Array[String] = []
	for entry: Array in LICENSES:
		var content: String = FileAccess.get_file_as_string(entry[1] as String)
		if content.is_empty():
			push_error("LicenseView: ライセンスの本文が無い: %s" % entry[1])
			content = UNREADABLE_TEXT
		parts.append("%s\n\n%s" % [entry[0], content.strip_edges()])
	return "\n\n".join(parts)


func text() -> String:
	return _text.text


func close_button() -> Button:
	return _close_button

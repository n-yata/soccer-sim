## 解説の欄（screen-common.md §5。S-02・S-04・S-05）。解説（MatchupNote）を、見出し（label）ごとにまとめて並べる。
## 続く同じ見出しは1つにまとめ、本文は「・」を頭に折り返して出す。表示専用で、スクロールは置く側（ScrollContainer）が持つ。
## 単純化の「実戦では」（FR-23）を添えるのは、その作業で足す。
class_name NotesView
extends VBoxContainer

const BULLET: String = "・"

var _headings: Array[String] = []
var _texts: Array[String] = []


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_notes(notes: Array[MatchupNote]) -> void:
	_clear()
	var previous_label: String = ""
	for index: int in range(notes.size()):
		var note: MatchupNote = notes[index]
		if not note.label.is_empty() and (index == 0 or note.label != previous_label):
			_add_label(note.label, &"SectionTitleLabel", true)
			_headings.append(note.label)
		previous_label = note.label
		_add_label(BULLET + note.text, &"PanelLabel", false)


## 解説の代わりの案内文（例「陣形と方式を選ぶと、ここに解説が出ます」）を1行。
func show_message(text: String) -> void:
	_clear()
	_add_label(text, &"MutedLabel", false)


## 出している見出し（テストと画面の確認用）。
func headings() -> Array[String]:
	return _headings.duplicate()


## 出している本文（案内文を含む）。
func texts() -> Array[String]:
	return _texts.duplicate()


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_headings.clear()
	_texts.clear()


func _add_label(text: String, variation: StringName, is_heading: bool) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(label)
	if not is_heading:
		_texts.append(text)

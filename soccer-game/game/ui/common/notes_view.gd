## 解説の欄（screen-common.md §5。S-02・S-04・S-05）。解説（MatchupNote）を、見出し（label）ごとにまとめて並べる。
## 続く同じ見出しは1つにまとめ、本文は「・」を頭に折り返して出す。表示専用で、スクロールは置く側（ScrollContainer）が持つ。
## 項目が単純化 ID を持つときは、そのすぐ下に単純化カタログの「実戦では」を caution の色で添える（FR-23）。
## 同じ単純化は欄の中で最初に出てくる項目の下にだけ出す（方式の単独の解説は3件とも同じ ID を持つため）。
class_name NotesView
extends VBoxContainer

const BULLET: String = "・"

var _headings: Array[String] = []
var _texts: Array[String] = []
var _in_real_texts: Array[String] = []


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## simplifications は単純化カタログ（`LibraryService.simplifications()`）。渡さなければ「実戦では」を出さない。
## カタログに無い ID は出さない（読み込み時の検査で弾かれるので、通常は起きない）。
func show_notes(notes: Array[MatchupNote], simplifications: Array[SimplificationDef] = []) -> void:
	_clear()
	var in_real_by_id: Dictionary[String, String] = {}
	for simplification: SimplificationDef in simplifications:
		in_real_by_id[simplification.id] = simplification.in_real
	var shown_ids: Dictionary[String, bool] = {}
	var previous_label: String = ""
	for index: int in range(notes.size()):
		var note: MatchupNote = notes[index]
		if not note.label.is_empty() and (index == 0 or note.label != previous_label):
			_add_label(note.label, &"SectionTitleLabel", true)
			_headings.append(note.label)
		previous_label = note.label
		_add_label(BULLET + note.text, &"PanelLabel", false)
		for simplification_id: String in note.simplification_ids:
			if shown_ids.has(simplification_id) or not in_real_by_id.has(simplification_id):
				continue
			shown_ids[simplification_id] = true
			var in_real: String = SimplificationList.IN_REAL_PREFIX + in_real_by_id[simplification_id]
			_add_label(in_real, &"CautionLabel", true)
			_in_real_texts.append(in_real)


## 解説の代わりの案内文（例「陣形と方式を選ぶと、ここに解説が出ます」）を1行。
func show_message(text: String) -> void:
	_clear()
	_add_label(text, &"MutedLabel", false)


## 出している見出し（テストと画面の確認用）。
func headings() -> Array[String]:
	return _headings.duplicate()


## 出している本文（案内文を含む。「実戦では」は含めない）。
func texts() -> Array[String]:
	return _texts.duplicate()


## 出している「実戦では」（「実戦では: 」付き。テストと画面の確認用）。
func in_real_texts() -> Array[String]:
	return _in_real_texts.duplicate()


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_headings.clear()
	_texts.clear()
	_in_real_texts.clear()


## is_extra が真なら、本文の一覧（texts）に入れない（見出しと「実戦では」）。
func _add_label(text: String, variation: StringName, is_extra: bool) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(label)
	if not is_extra:
		_texts.append(text)

## 解説の1項目（component-design.md §2.2。アルゴリズム9）。text の根拠の原則と、「実戦では」を添える単純化を持つ。
## label は画面で並べるときの見出し（ドメインは空のまま返し、LibraryService が付ける）。
class_name MatchupNote
extends RefCounted

var label: String
var text: String
var principle_ids: Array[String]
var simplification_ids: Array[String]


func _init(p_text: String, p_principle_ids: Array[String], p_simplification_ids: Array[String] = [],
		p_label: String = "") -> void:
	text = p_text
	principle_ids = p_principle_ids.duplicate()
	simplification_ids = p_simplification_ids.duplicate()
	label = p_label


## 見出しと文を差し替えた写し（原則・単純化はそのまま）。
func relabeled(p_label: String, p_text: String = text) -> MatchupNote:
	return MatchupNote.new(p_text, principle_ids, simplification_ids, p_label)

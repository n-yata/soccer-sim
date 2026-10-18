## 静的データ全体（component-design.md §2.2）。今は陣形だけを持つ。
## ほかの静的データ（方式・噛み合わせルールなど）は、それを使う機能の作業で足す。
class_name ContentCatalog
extends RefCounted

var formations: Array[FormationDef]


func _init(p_formations: Array[FormationDef] = []) -> void:
	formations = p_formations.duplicate()


## 無ければ null。
func formation(formation_id: String) -> FormationDef:
	for candidate: FormationDef in formations:
		if candidate.id == formation_id:
			return candidate
	return null


func duplicate_deep() -> ContentCatalog:
	var copied: Array[FormationDef] = []
	for formation_def: FormationDef in formations:
		copied.append(formation_def.duplicate_deep())
	return ContentCatalog.new(copied)

## 静的データ全体（component-design.md §2.2）。陣形・単純化カタログ・チュートリアルの段階を持つ。
## ほかの静的データ（方式・噛み合わせルールなど）は、それを使う機能の作業で足す。
class_name ContentCatalog
extends RefCounted

var formations: Array[FormationDef]
var simplifications: Array[SimplificationDef]
var tutorial_steps: Array[TutorialStepDef]


func _init(p_formations: Array[FormationDef] = [], p_simplifications: Array[SimplificationDef] = [],
		p_tutorial_steps: Array[TutorialStepDef] = []) -> void:
	formations = p_formations.duplicate()
	simplifications = p_simplifications.duplicate()
	tutorial_steps = p_tutorial_steps.duplicate()


## 無ければ null。
func formation(formation_id: String) -> FormationDef:
	for candidate: FormationDef in formations:
		if candidate.id == formation_id:
			return candidate
	return null


## 陣形は写す。単純化とチュートリアルの段階は読むだけの値なので共有する（作成後に値を変えない約束）。
func duplicate_deep() -> ContentCatalog:
	var copied: Array[FormationDef] = []
	for formation_def: FormationDef in formations:
		copied.append(formation_def.duplicate_deep())
	return ContentCatalog.new(copied, simplifications, tutorial_steps)

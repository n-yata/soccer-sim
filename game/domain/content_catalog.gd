## 静的データ全体（component-design.md §2.2）。陣形・単純化カタログ・チュートリアルの段階・戦術原則カタログ・場面問題を持つ。
## ほかの静的データ（方式・噛み合わせルールなど）は、それを使う機能の作業で足す。
class_name ContentCatalog
extends RefCounted

var formations: Array[FormationDef]
var simplifications: Array[SimplificationDef]
var tutorial_steps: Array[TutorialStepDef]
var principles: Array[PrincipleDef]
var quiz_questions: Array[QuizQuestionDef]


func _init(p_formations: Array[FormationDef] = [], p_simplifications: Array[SimplificationDef] = [],
		p_tutorial_steps: Array[TutorialStepDef] = [], p_principles: Array[PrincipleDef] = [],
		p_quiz_questions: Array[QuizQuestionDef] = []) -> void:
	formations = p_formations.duplicate()
	simplifications = p_simplifications.duplicate()
	tutorial_steps = p_tutorial_steps.duplicate()
	principles = p_principles.duplicate()
	quiz_questions = p_quiz_questions.duplicate()


## 無ければ null。
func formation(formation_id: String) -> FormationDef:
	for candidate: FormationDef in formations:
		if candidate.id == formation_id:
			return candidate
	return null


## 無ければ null。
func principle(principle_id: String) -> PrincipleDef:
	for candidate: PrincipleDef in principles:
		if candidate.id == principle_id:
			return candidate
	return null


## 陣形は写す。単純化・チュートリアルの段階・原則・場面問題は読むだけの値なので共有する（作成後に値を変えない約束）。
func duplicate_deep() -> ContentCatalog:
	var copied: Array[FormationDef] = []
	for formation_def: FormationDef in formations:
		copied.append(formation_def.duplicate_deep())
	return ContentCatalog.new(copied, simplifications, tutorial_steps, principles, quiz_questions)

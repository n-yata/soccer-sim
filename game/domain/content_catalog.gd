## 静的データ全体（component-design.md §2.2）。陣形・方式・噛み合わせルール・単純化カタログ・チュートリアルの段階・
## 戦術原則カタログ・場面問題を持つ。
class_name ContentCatalog
extends RefCounted

var formations: Array[FormationDef]
var simplifications: Array[SimplificationDef]
var tutorial_steps: Array[TutorialStepDef]
var principles: Array[PrincipleDef]
var quiz_questions: Array[QuizQuestionDef]
## 方式（静的データの順。守備方式・攻撃方式の4件）
var styles: Array[StyleDef]
## 噛み合わせルール（配列の順が採用の順。アルゴリズム9）
var matchup_rules: Array[MatchupRuleDef]
## 陣形どうしでルールが1件も当たらない側に出す文。無ければ null
var matchup_fallback: MatchupNote


func _init(p_formations: Array[FormationDef] = [], p_simplifications: Array[SimplificationDef] = [],
		p_tutorial_steps: Array[TutorialStepDef] = [], p_principles: Array[PrincipleDef] = [],
		p_quiz_questions: Array[QuizQuestionDef] = [], p_styles: Array[StyleDef] = [],
		p_matchup_rules: Array[MatchupRuleDef] = [], p_matchup_fallback: MatchupNote = null) -> void:
	formations = p_formations.duplicate()
	simplifications = p_simplifications.duplicate()
	tutorial_steps = p_tutorial_steps.duplicate()
	principles = p_principles.duplicate()
	quiz_questions = p_quiz_questions.duplicate()
	styles = p_styles.duplicate()
	matchup_rules = p_matchup_rules.duplicate()
	matchup_fallback = p_matchup_fallback


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


## 無ければ null。style_id は区分値の名前（StyleDef.id）。
func style(style_id: String) -> StyleDef:
	for candidate: StyleDef in styles:
		if candidate.id == style_id:
			return candidate
	return null


## 陣形は写す。ほか（単純化・チュートリアルの段階・原則・場面問題・方式・ルール）は読むだけの値なので共有する
## （作成後に値を変えない約束）。
func duplicate_deep() -> ContentCatalog:
	var copied: Array[FormationDef] = []
	for formation_def: FormationDef in formations:
		copied.append(formation_def.duplicate_deep())
	return ContentCatalog.new(copied, simplifications, tutorial_steps, principles, quiz_questions, styles, matchup_rules,
			matchup_fallback)

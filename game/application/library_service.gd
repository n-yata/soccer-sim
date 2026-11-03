## 画面向けの参照（component-design.md §3.4）。静的データ（ContentCatalog）から、画面が出す値を作る。
## 陣形の一覧と基本配置の人数・噛み合わせの人数、解説（アルゴリズム9。導出は CommentaryGenerator）、単純化カタログ、
## チュートリアルの段階、戦術原則、場面問題。解説には画面で並べるときの見出し（MatchupNote.label）を付ける。
class_name LibraryService
extends RefCounted

const OWN_SIDE_LABEL: String = "こちらの狙いどころ"
const OPPONENT_SIDE_LABEL: String = "相手の狙いどころ"
const STYLE_MATCHUP_LABEL: String = "方式の噛み合わせ"
## ルールの文は解説を見る側から書き、相手チームを「相手」と書く（data-definition.md §3.3）。相手の狙いどころは相手から見た文
## なので、相手から見た「相手」（= 利用者）を「こちら」に言い換える
const OPPONENT_WORD: String = "相手"
const OWN_WORD: String = "こちら"

var _catalog: ContentCatalog


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


## 陣形の一覧（静的データの順）。呼び出し側が並べ替えても影響しないよう、配列はコピーして返す。
func formations() -> Array[FormationDef]:
	return _catalog.formations.duplicate()


## 単純化カタログ（静的データの順。FR-23）。配列は写し（中の値は読むだけ）。
func simplifications() -> Array[SimplificationDef]:
	return _catalog.simplifications.duplicate()


## チュートリアルの段階（並びが段階の順。FR-12）。配列は写し（中の値は読むだけ）。
func tutorial_steps() -> Array[TutorialStepDef]:
	return _catalog.tutorial_steps.duplicate()


## 戦術原則（理解度チェックの根拠の原則の名前）。無ければ null。
func principle(principle_id: String) -> PrincipleDef:
	return _catalog.principle(principle_id)


## 場面問題（並びが出題の順。FR-22）。配列は写し（中の値は読むだけ）。
func quiz_questions() -> Array[QuizQuestionDef]:
	return _catalog.quiz_questions.duplicate()


## 基本配置の人数（PitchArea のキー → 人数。そのチーム自身の視点。アルゴリズム1）。存在しない陣形なら空。
func base_counts(formation_id: String) -> Dictionary:
	var formation: FormationDef = _catalog.formation(formation_id)
	if formation == null:
		push_error("LibraryService: 陣形が無い: %s" % formation_id)
		return {}
	return BaseLayoutDeriver.derive(formation).counts()


## 両チームの基本配置の人数（PitchArea のキー → [利用者, 相手]。30エリアすべて）。相手の基本配置は相手の視点なので、
## 利用者の視点へ鏡像にする（S-05 の噛み合わせのミニピッチ。方式による動きは含めない）。存在しない陣形なら空。
func matchup_counts(user_formation_id: String, opponent_formation_id: String) -> Dictionary:
	var user_counts: Dictionary = base_counts(user_formation_id)
	var opponent_counts: Dictionary = base_counts(opponent_formation_id)
	if user_counts.is_empty() or opponent_counts.is_empty():
		return {}
	var result: Dictionary = {}
	for area: PitchArea in PitchArea.all():
		result[area.to_key()] = [user_counts.get(area.to_key(), 0) as int,
				opponent_counts.get(area.mirrored().to_key(), 0) as int]
	return result


## 陣形の解説。opponent_id が空なら viewer の単独の解説（見出し「陣形 4-4-2」）。相手があれば、viewer の狙いどころと
## 相手の狙いどころ（同じ陣形どうしは両側が同じになるので viewer 側だけ）。存在しない陣形なら空。
func formation_notes(viewer_id: String, opponent_id: String) -> Array[MatchupNote]:
	var result: Array[MatchupNote] = []
	var viewer: FormationDef = _formation_or_error(viewer_id)
	if viewer == null:
		return result
	if opponent_id.is_empty():
		return _labeled(CommentaryGenerator.formation_profile(viewer), "陣形 %s" % viewer.name)
	var opponent: FormationDef = _formation_or_error(opponent_id)
	if opponent == null:
		return result
	result.append_array(_labeled(CommentaryGenerator.formation_matchup(viewer, opponent, _catalog), OWN_SIDE_LABEL))
	if viewer_id == opponent_id:
		return result
	for note: MatchupNote in CommentaryGenerator.formation_matchup(opponent, viewer, _catalog):
		result.append(note.relabeled(OPPONENT_SIDE_LABEL, note.text.replace(OPPONENT_WORD, OWN_WORD)))
	return result


## 方式の解説。opponent が null なら viewer の守備方式・攻撃方式の単独の解説。相手があれば方式どうしの噛み合わせ。
func style_notes(viewer: TeamStyles, opponent: TeamStyles) -> Array[MatchupNote]:
	if opponent == null:
		var result: Array[MatchupNote] = defense_style_notes(viewer.defense)
		result.append_array(attack_style_notes(viewer.attack))
		return result
	return _labeled(CommentaryGenerator.style_matchup(viewer, opponent, _catalog), STYLE_MATCHUP_LABEL)


## 守備方式だけの単独の解説（見出し「守備方式 ゾーン」）。
func defense_style_notes(style: GameEnums.DefenseStyle) -> Array[MatchupNote]:
	return _style_profile(StyleDef.defense_id(style), "守備方式 %s")


## 攻撃方式だけの単独の解説（見出し「攻撃方式 保持型」）。
func attack_style_notes(style: GameEnums.AttackStyle) -> Array[MatchupNote]:
	return _style_profile(StyleDef.attack_id(style), "攻撃方式 %s")


func _style_profile(style_id: String, label_format: String) -> Array[MatchupNote]:
	var style: StyleDef = _catalog.style(style_id)
	var label: String = label_format % (style.name if style != null else style_id)
	return _labeled(CommentaryGenerator.style_profile(style_id, _catalog), label)


func _formation_or_error(formation_id: String) -> FormationDef:
	var formation: FormationDef = _catalog.formation(formation_id)
	if formation == null:
		push_error("LibraryService: 陣形が無い: %s" % formation_id)
	return formation


static func _labeled(notes: Array[MatchupNote], label: String) -> Array[MatchupNote]:
	var result: Array[MatchupNote] = []
	for note: MatchupNote in notes:
		result.append(note.relabeled(label))
	return result

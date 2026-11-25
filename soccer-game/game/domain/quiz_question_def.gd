## 場面問題の1件（data-definition.md §3.5 の quiz.json。FR-22）。場面の人数とボールは利用者の視点。
## 正誤の判定は選んだ選択肢が正解と一致するかだけで、ルールの計算は伴わない（usecase.md UC-07）。
class_name QuizQuestionDef
extends RefCounted

## 学習目標 ID（requirements-definition.md §1.4）。並びが一覧のカードの順
const GOAL_IDS: Array[String] = ["LG-1", "LG-2", "LG-3", "LG-4"]

var id: String
var goal_id: String
## 公開前プレイテストの測定に使う8問の1つか（requirements-definition.md §1.5）
var is_playtest_set: bool
## 場面: PitchArea のキー → 人数（利用者・相手）。人数が0のエリアは持たない
var user_counts: Dictionary = {}
var opponent_counts: Dictionary = {}
var ball_area: PitchArea
var user_styles: TeamStyles
var opponent_styles: TeamStyles
var text: String
## 選択肢の ID・文（並びが表示の順）
var choice_ids: Array[String] = []
var choice_texts: Array[String] = []
## 正解の選択肢の ID
var answer: String
var explanation: String
var principle_ids: Array[String] = []


## 選んだ選択肢が正解か（正誤の判定はこれだけ。ルールの計算は伴わない）。
func is_correct(choice_id: String) -> bool:
	return choice_id == answer


## 選択肢の文。無い ID なら空文字。
func choice_text(choice_id: String) -> String:
	var index: int = choice_ids.find(choice_id)
	return choice_texts[index] if index >= 0 else ""

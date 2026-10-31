## 回答結果の1件（data-definition.md §2.3 の quiz_answers.json）。作成後に値を変えない。
class_name QuizAnswer
extends RefCounted

var question_id: String
var correct: bool
## 端末のローカル時刻の ISO 8601（タイムゾーンなし）
var answered_at: String


func _init(p_question_id: String, p_correct: bool, p_answered_at: String) -> void:
	question_id = p_question_id
	correct = p_correct
	answered_at = p_answered_at

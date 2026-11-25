## 理解度チェック（S-09）とタイトルのカードの文言を1か所に集める。
## 場面問題の文（問題文・選択肢・解説）の中の {M2-L1} は、試合の画面と同じエリアの呼び名（MatchTexts.area_name）にして出す。
class_name QuizTexts
extends RefCounted

## 学習目標の名前。要件定義書 §1.4 の表の書き写し（並びは QuizQuestionDef.GOAL_IDS）。表を変えたらここも直す
## （ID と名前が表と同じかは tests/content/quiz_content_test.gd が確かめる）
const GOAL_NAMES: Dictionary = {
	"LG-1": "位置的・数的優位を見つける",
	"LG-2": "チャレンジ＆カバーとスライド",
	"LG-3": "トランジションの判断",
	"LG-4": "噛み合わせ",
}
const UNANSWERED: String = "未回答"
const CORRECT_MARK: String = "○ 正解"
const WRONG_MARK: String = "× 不正解"

static var _placeholder: RegEx = RegEx.create_from_string("\\{([A-Z0-9-]+)\\}")


## 文の中の {エリアのキー} をエリアの呼び名にする（「{M2-L1}」→「中盤（敵陣）・左HS」）。
static func fill(text: String) -> String:
	var result: String = text
	for found: RegExMatch in _placeholder.search_all(text):
		result = result.replace(found.get_string(), MatchTexts.area_name(found.get_string(1)))
	return result


## 文の中の {エリアのキー}（現れた順。テストが場面の人数と照らし合わせる）。
static func placeholder_keys(text: String) -> Array[String]:
	var keys: Array[String] = []
	for found: RegExMatch in _placeholder.search_all(text):
		keys.append(found.get_string(1))
	return keys


## 一覧のカードの見出し「LG-1 位置的・数的優位を見つける」。
static func goal_title(goal_id: String) -> String:
	return "%s %s" % [goal_id, GOAL_NAMES.get(goal_id, "") as String]


## 一覧のカードの正答状況「2問中 1問正解」。1問も答えていなければ「未回答」（screen-09-quiz.md「正答状況の数え方」）。
static func goal_summary(counts: Dictionary) -> String:
	if counts.get("answered", 0) as int == 0:
		return UNANSWERED
	return "%d問中 %d問正解" % [counts.get("total", 0) as int, counts.get("correct", 0) as int]


## タイトルのカードの一言「3／8 正解」（全学習目標の正答数／問題数）。1問も答えていなければ「未回答」。
static func total_summary(progress: Dictionary) -> String:
	var answered: int = 0
	var correct: int = 0
	var total: int = 0
	for counts: Dictionary in progress.values():
		answered += counts.get("answered", 0) as int
		correct += counts.get("correct", 0) as int
		total += counts.get("total", 0) as int
	if answered == 0:
		return UNANSWERED
	return "%d／%d 正解" % [correct, total]


## 正誤の下の文。正解なら「あなたの答え: …」、不正解なら正解も添える（「あなたの答え: …／正解: …」）。
## picked・answer は表示用に置き換え済みの選択肢の文。
static func answer_line(picked: String, answer: String, is_correct: bool) -> String:
	if is_correct:
		return "あなたの答え: %s" % picked
	return "あなたの答え: %s／正解: %s" % [picked, answer]


## 問題の表示中のヘッダー「LG-2　1／2」。
static func question_header(goal_id: String, index: int, count: int) -> String:
	return "%s　%d／%d" % [goal_id, index + 1, count]


## 場面の図の下の文「自分: ゾーン・保持型　相手: ゾーン・カウンター型　ボール: 中盤（敵陣）・左HS」。
static func scene_info(question: QuizQuestionDef) -> String:
	return "自分: %s・%s　相手: %s・%s　ボール: %s" % [
			MatchTexts.defense_style_name(question.user_styles.defense),
			MatchTexts.attack_style_name(question.user_styles.attack),
			MatchTexts.defense_style_name(question.opponent_styles.defense),
			MatchTexts.attack_style_name(question.opponent_styles.attack),
			MatchTexts.area_name(question.ball_area.to_key())]


## 根拠の原則「根拠: TP-03 チャレンジ＆カバー」（複数は「／」でつなぐ）。
static func principles_line(principles: Array[PrincipleDef]) -> String:
	var names: Array[String] = []
	for principle: PrincipleDef in principles:
		names.append("%s %s" % [principle.id, principle.name])
	return "根拠: " + "／".join(names)

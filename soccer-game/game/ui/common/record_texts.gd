## 戦績の表示の文（S-01 の一言・S-06 の陣形と方式の推移・S-11 の行）。値は MatchRecord（利用者 = 自分、CPU = 相手）。
## 勝敗は色だけでなく文字で示す。
class_name RecordTexts
extends RefCounted

const RESULT_WORDS: Dictionary = {
	GameEnums.MatchResult.WIN: "勝ち",
	GameEnums.MatchResult.DRAW: "引き分け",
	GameEnums.MatchResult.LOSE: "負け",
}
const NO_RECORDS_TEXT: String = "まだ記録がありません"
const EMPTY_TEXT: String = "まだ試合の記録がありません"
const HALF_NAMES: Array[String] = ["", "前半", "後半"]
## 変えた側の主語（英字の後には空白を入れる）
const SIDE_SUBJECTS: Array[String] = ["自分が", "CPU が"]


static func result_word(result: GameEnums.MatchResult) -> String:
	return RESULT_WORDS[result]


## タイトルの戦績のカードの一言「5勝 2分 3敗」。1件も無ければ「まだ記録がありません」。
static func totals_summary(totals: Dictionary) -> String:
	var win: int = totals["win"] as int
	var draw: int = totals["draw"] as int
	var lose: int = totals["lose"] as int
	if win + draw + lose == 0:
		return NO_RECORDS_TEXT
	return "%d勝 %d分 %d敗" % [win, draw, lose]


## 一覧の日時「10/17 19:42」（端末のローカル時刻。月日の頭の 0 は付けない）。形が違えばそのまま返す。
static func date_text(finished_at: String) -> String:
	var parts: PackedStringArray = finished_at.split("T")
	if parts.size() != 2 or parts[0].length() != 10 or parts[1].length() < 5:
		return finished_at
	return "%d/%d %s" % [parts[0].substr(5, 2).to_int(), parts[0].substr(8, 2).to_int(), parts[1].substr(0, 5)]


## スコア「2 – 1」（自分の数字・相手の数字の順）。
static func score_text(record: MatchRecord) -> String:
	return "%d – %d" % [record.score_user, record.score_cpu]


## 両者の陣形と方式「● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型」。
static func matchup_text(period: RecordPeriod) -> String:
	return "● %s 対 ◆ %s" % [MatchTexts.setup_text(period.user_setup), MatchTexts.setup_text(period.cpu_setup)]


## 結果画面の陣形と方式の推移（screen-06-result.md「画面を開く」）。各ハーフの最初は「前半: ● … 対 ◆ …」、
## ハーフの途中の変化は「後半 4ターン目: CPU が守備方式をゾーンに変更」を、変えた側・変えた方式ごとに1行。
static func history_lines(record: MatchRecord, turns_per_half: int) -> Array[String]:
	var lines: Array[String] = []
	var previous: RecordPeriod = null
	for period: RecordPeriod in record.timeline:
		if previous == null or previous.half != period.half:
			lines.append("%s: %s" % [HALF_NAMES[period.half], matchup_text(period)])
		else:
			var when: String = "%sターン目" % ReviewTexts.turn_text(period.half, period.from_turn, turns_per_half)
			lines.append_array(_change_lines(when, 0, previous.user_setup, period.user_setup))
			lines.append_array(_change_lines(when, 1, previous.cpu_setup, period.cpu_setup))
		previous = period
	return lines


static func _change_lines(when: String, side: int, before: TeamSetup, after: TeamSetup) -> Array[String]:
	var lines: Array[String] = []
	if before.formation_id != after.formation_id:
		lines.append("%s: %s陣形を %s に変更" % [when, SIDE_SUBJECTS[side], after.formation_id])
	if before.styles.defense != after.styles.defense:
		lines.append("%s: %s守備方式を%sに変更" % [when, SIDE_SUBJECTS[side],
				MatchTexts.defense_style_name(after.styles.defense)])
	if before.styles.attack != after.styles.attack:
		lines.append("%s: %s攻撃方式を%sに変更" % [when, SIDE_SUBJECTS[side],
				MatchTexts.attack_style_name(after.styles.attack)])
	return lines

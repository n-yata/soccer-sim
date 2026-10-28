## 振り返り（S-07）の文言を1か所に集める。数の配列は [勝ち, 負け, 膠着]（ReviewView の集計の形）。
## 局面の名前の正本は glossary.md、得点の見出しと時間帯の文の形は screen-07-review.md・screen-design.md「S-07」。
class_name ReviewTexts
extends RefCounted

const PHASE_NAMES: Array[String] = ["攻撃", "ネガティブトランジション", "守備", "ポジティブトランジション"]
const NOT_OCCURRED_TEXT: String = "この試合では起きなかった"
const NO_GOALS_TEXT: String = "この試合は 0 %s 0 でした。エリア別・局面別で、どこで判断が通ったかを確かめよう"
const NO_DATA_TEXT: String = "振り返りのデータがありません"
## 勝ち負けの数え方の説明（アルゴリズム10）。エリア別のページの操作の列に出す
const AREA_LEGEND_TEXT: String = "勝＝こちらの判断が通った回数、負＝相手の判断が通った回数、膠＝膠着の回数。\n" \
		+ "攻撃では前進・得点が勝ち、守備ではロスト・シュート阻止・オフサイドを奪えたら勝ち。\n" \
		+ "エリアは比べたエリア（奪い返しは奪ったエリア）で、リトリートと保持が重なった（争わなかった）場面は数えない"


## 「勝3 負1 膠1」。0 の項目は省く。3つとも 0 なら空（札を出さない）。
static func tally_text(counts: Array) -> String:
	var parts: Array[String] = []
	var heads: Array[String] = ["勝", "負", "膠"]
	for index: int in range(heads.size()):
		var count: int = counts[index] as int
		if count > 0:
			parts.append("%s%d" % [heads[index], count])
	return " ".join(parts)


## 局面別の行の数「勝 3　負 1　膠着 0」。判定が1回も無ければ「この試合では起きなかった」。
static func phase_counts_text(counts: Array) -> String:
	if is_empty(counts):
		return NOT_OCCURRED_TEXT
	return "勝 %d　負 %d　膠着 %d" % [counts[0], counts[1], counts[2]]


static func is_empty(counts: Array) -> bool:
	return (counts[0] as int) + (counts[1] as int) + (counts[2] as int) == 0


static func phase_name(phase: GameEnums.Phase) -> String:
	return PHASE_NAMES[phase]


## 「前半 6」。アディショナルタイムは「前半 15＋2」（MatchTexts.clock_text と同じ形）。
static func turn_text(half: int, turn_number: int, turns_per_half: int) -> String:
	var half_name: String = "前半" if half == 1 else "後半"
	if turns_per_half > 0 and turn_number > turns_per_half:
		return "%s %d＋%d" % [half_name, turns_per_half, turn_number - turns_per_half]
	return "%s %d" % [half_name, turn_number]


## 得点のカードの見出し「▲ 得点 前半 6ターン目（1 − 0）」。利用者の失点は「▼ 失点」（記号と文字で区別し、色は補助）。
static func goal_title(goal: Dictionary, turns_per_half: int) -> String:
	var is_user: bool = goal["is_user"] as bool
	var mark: String = "▲ 得点" if is_user else "▼ 失点"
	return "%s %sターン目（%d %s %d）" % [mark, turn_text(goal["half"] as int, goal["turn_number"] as int, turns_per_half),
			goal["score_user"], MatchTexts.MINUS_SIGN, goal["score_opponent"]]


## 時間帯の一行「前半 1〜6ターン: ● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型」。
## 1ターンだけの時間帯は「前半 7ターン: …」。
static func segment_text(segment: Dictionary, turns_per_half: int) -> String:
	var half: int = segment["half"] as int
	var from_text: String = turn_text(half, segment["from_turn"] as int, turns_per_half)
	var span: String = from_text
	if (segment["to_turn"] as int) != (segment["from_turn"] as int):
		# ハーフの名前は最初だけに付ける
		span = "%s〜%s" % [from_text, turn_text(half, segment["to_turn"] as int, turns_per_half).split(" ")[1]]
	return "%sターン: ● %s 対 ◆ %s" % [span, MatchTexts.setup_text(segment["user_setup"] as TeamSetup),
			MatchTexts.setup_text(segment["opponent_setup"] as TeamSetup)]


## 得失点の流れの1ターンの見出し「前半 5ターン目　攻撃」。
static func turn_heading(reveal: RevealView, turns_per_half: int) -> String:
	return "%sターン目　%s" % [turn_text(reveal.half, reveal.turn_number, turns_per_half), phase_name(reveal.user_role)]


## 両者の手「● 自分: ショートパス → 中盤（敵陣）・中央　◆ 相手: プレス → …」。
static func choices_text(reveal: RevealView) -> String:
	return "● 自分: %s\n◆ 相手: %s" % [MatchTexts.choice_summary(reveal.user_choice),
			MatchTexts.choice_summary(reveal.opponent_choice)]


static func no_goals_text() -> String:
	return NO_GOALS_TEXT % MatchTexts.MINUS_SIGN

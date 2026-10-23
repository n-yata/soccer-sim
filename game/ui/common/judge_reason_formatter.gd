## 判定理由の文（component-design.md §5。形式の正本は functional-overview.md「表示仕様」の判定理由）。
## 「中盤・中央で 1対0。こちらが数的優位で前進」の形で、比較エリア・人数（自分 対 相手）・カバーの有無を必ず含める。
## 原因の句は人数の大小・カバーの有無・守備の読みから作る基本の文。解説（アルゴリズム9）の作業で言い回しを差し替える。
class_name JudgeReasonFormatter
extends RefCounted


static func format(reveal: RevealView) -> String:
	if not reveal.has_detail:
		return _no_contest(reveal)
	return "%sで %d対%d。%s%s" % [MatchTexts.area_name(reveal.compare_area), reveal.user_count,
			reveal.opponent_count, _cause(reveal), MatchTexts.outcome_word(reveal.outcome)]


## 判定の内訳「比較エリア 中盤・中央／● 自分 1 対 0 相手 ◆／カバー なし」。判定が無ければ空。
static func detail(reveal: RevealView) -> String:
	if not reveal.has_detail:
		return ""
	var cover: String = "あり" if reveal.cover == GameEnums.CoverKind.DEFENDER else "なし"
	return "比較エリア %s／● 自分 %d 対 %d 相手 ◆／カバー %s" % [MatchTexts.area_name(reveal.compare_area),
			reveal.user_count, reveal.opponent_count, cover]


## 利用者から見た人数の大小。同数なら、カバーの内訳で句を変える（カバー判定はアルゴリズム5）。
## 守備が読んで止めた（ロスト・シュート阻止）なら、人数ではなく読みを原因にする（読まれると1人多いだけでは前進できない）。
static func _cause(reveal: RevealView) -> String:
	var is_stopped: bool = reveal.outcome == GameEnums.TurnOutcome.LOSS or reveal.outcome == GameEnums.TurnOutcome.SAVE
	if reveal.is_read and is_stopped:
		return "読まれて" if reveal.user_role == GameEnums.Phase.ATTACK else "読み切って"
	if reveal.user_count > reveal.opponent_count:
		return "こちらが数的優位で"
	if reveal.user_count < reveal.opponent_count:
		return "相手が数的優位で"
	# シュートはカバー判定をしない。同数の得点は、読まれなかったことが理由
	if reveal.outcome == GameEnums.TurnOutcome.GOAL:
		return "同数で読まれず" if reveal.user_role == GameEnums.Phase.ATTACK else "同数で読めず"
	if reveal.cover == GameEnums.CoverKind.DEFENDER:
		return "同数で背後にカバーがいて"
	# カバーが無いことも文に入れる（表示仕様「カバーの有無を必ず含める」）
	return "同数でカバーがいなくて"


## 判定なし（リトリート×保持）。奪取側（ポジティブトランジション）から見るか、喪失側から見るかで主語が変わる。
static func _no_contest(reveal: RevealView) -> String:
	if reveal.user_role == GameEnums.Phase.POS_TRANSITION:
		return "判定なし（相手は撤退、こちらは保持）"
	return "判定なし（こちらは撤退、相手は保持）"

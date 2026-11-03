## 判定理由の文（component-design.md §5。形式の正本は functional-overview.md「表示仕様」の判定理由）。
## 「中盤（敵陣）・中央で 1対0。こちらが数的優位で前進」の形で、比較エリア・人数（自分 対 相手）・カバーの有無を必ず含める。
## 原因の句は人数の大小・カバーの有無・守備の読みから作る。陣形・方式の解説（アルゴリズム9。CommentaryGenerator）とは別で、
## 判定理由の言い回しはここだけが持つ。
class_name JudgeReasonFormatter
extends RefCounted


static func format(reveal: RevealView) -> String:
	if not reveal.has_detail:
		return _no_contest(reveal)
	# オフサイド（2026-10-25）は人数・読みに関係なく決まるので、人数を出さず、受け手のいたエリアと理由だけを言う
	if reveal.outcome == GameEnums.TurnOutcome.OFFSIDE:
		return "%sでオフサイド。受け手がラインより前にいた" % MatchTexts.area_name(reveal.compare_area)
	return "%sで %d対%d。%s%s" % [MatchTexts.area_name(reveal.compare_area), reveal.user_count,
			reveal.opponent_count, _cause(reveal), MatchTexts.outcome_word(reveal.outcome)]


## 判定の内訳「比較エリア 中盤（敵陣）・中央／● 自分 1 対 0 相手 ◆／カバー なし」。判定が無ければ空。
static func detail(reveal: RevealView) -> String:
	if not reveal.has_detail:
		return ""
	var cover: String = "あり" if reveal.cover == GameEnums.CoverKind.DEFENDER else "なし"
	return "比較エリア %s／● 自分 %d 対 %d 相手 ◆／カバー %s" % [MatchTexts.area_name(reveal.compare_area),
			reveal.user_count, reveal.opponent_count, cover]


## 利用者から見た人数の大小。同数なら、カバーの内訳で句を変える（カバー判定はアルゴリズム5）。
## 守備が読んで止めた（ロスト・シュート阻止）なら、人数ではなく読みを原因にする（読まれると、ぴったりなら1人多いだけ、
## 隣なら同数では前進できない）。攻撃側が少なければ、読まれていなくても止まるので、原因は人数のまま。
static func _cause(reveal: RevealView) -> String:
	var is_attacker: bool = reveal.user_role == GameEnums.Phase.ATTACK
	if _is_through_pass(reveal, is_attacker):
		return _through_pass_cause(reveal, is_attacker)
	# ボールに寄せてドリブルを読んだ（2026-11-03）は、人数に関係なく運ぶ前に奪うので、原因は読みだけで言う
	if _is_closed_down_dribble(reveal, is_attacker):
		return "読まれて" if is_attacker else "読み切って"
	var attackers: int = reveal.user_count if is_attacker else reveal.opponent_count
	var defenders: int = reveal.opponent_count if is_attacker else reveal.user_count
	var is_stopped: bool = reveal.outcome == GameEnums.TurnOutcome.LOSS or reveal.outcome == GameEnums.TurnOutcome.SAVE
	if is_stopped and attackers >= defenders:
		if reveal.read == GameEnums.ReadKind.EXACT:
			return "読まれて" if is_attacker else "読み切って"
		if reveal.read == GameEnums.ReadKind.NEAR:
			return "隣を読まれて" if is_attacker else "隣を読んで"
	if reveal.user_count > reveal.opponent_count:
		return "こちらが数的優位で"
	if reveal.user_count < reveal.opponent_count:
		return "相手が数的優位で"
	# シュートはカバー判定をしない。同数の得点は、読まれなかったことが理由
	if reveal.outcome == GameEnums.TurnOutcome.GOAL:
		# 隣の読みはシュートに効かない。守備は隣を読んでいたので「読まれず」とは言わない
		if reveal.read == GameEnums.ReadKind.NEAR:
			return "隣を読まれたが同数で" if is_attacker else "隣を読んだが同数で"
		return "同数で読まれず" if is_attacker else "同数で読めず"
	if reveal.cover == GameEnums.CoverKind.DEFENDER:
		return "同数で背後にカバーがいて"
	# カバーが無いことも文に入れる（表示仕様「カバーの有無を必ず含める」）
	return "同数でカバーがいなくて"


## 攻撃側の手がスルーパスか（攻守ターンの攻撃側の選択で見る。トランジションには無い）。
static func _is_through_pass(reveal: RevealView, is_attacker: bool) -> bool:
	if reveal.turn_kind != GameEnums.TurnKind.OPEN_PLAY:
		return false
	var attack: TurnChoice = reveal.user_choice if is_attacker else reveal.opponent_choice
	return attack != null and attack.family == GameEnums.ChoiceFamily.ATTACK \
			and attack.action == GameEnums.PlayType.THROUGH_PASS


## 攻守ターンで、攻撃側のドリブルを守備側がボールに寄せて読んだか（判定は人数に関係なくロスト。2026-11-03）。
static func _is_closed_down_dribble(reveal: RevealView, is_attacker: bool) -> bool:
	if reveal.turn_kind != GameEnums.TurnKind.OPEN_PLAY:
		return false
	var attack: TurnChoice = reveal.user_choice if is_attacker else reveal.opponent_choice
	var defense: TurnChoice = reveal.opponent_choice if is_attacker else reveal.user_choice
	return attack != null and defense != null and attack.family == GameEnums.ChoiceFamily.ATTACK \
			and attack.action == GameEnums.PlayType.DRIBBLE and defense.family == GameEnums.ChoiceFamily.DEFENSE \
			and defense.action == GameEnums.DefenseAction.CLOSE_DOWN


## スルーパスは人数に関係なく読みで決まる（アルゴリズム5。2026-10-25）ので、原因は読みだけで言う。
## ぴったり読まれたらロスト、守備が運ぶ先へ入ってきたらロスト（2026-10-28）、それ以外（隣の読み・外れ）は前進。
static func _through_pass_cause(reveal: RevealView, is_attacker: bool) -> String:
	if reveal.read == GameEnums.ReadKind.EXACT:
		return "読まれて" if is_attacker else "読み切って"
	# ぴったり読まれずにロストしたのは、守備が運ぶ先へ入ってきたから（2026-10-28）
	if reveal.outcome == GameEnums.TurnOutcome.LOSS:
		return "相手に入られて" if is_attacker else "運ぶ先に入って"
	if reveal.read == GameEnums.ReadKind.NEAR:
		return "隣を読まれたが" if is_attacker else "隣を読んだが"
	return "読まれず" if is_attacker else "読めず"


## 判定なし（リトリート×保持、攻守ターンのバックパス）。ボールを持つ側から見るか、相手側から見るかで主語が変わる。
static func _no_contest(reveal: RevealView) -> String:
	if reveal.user_role in [GameEnums.Phase.ATTACK, GameEnums.Phase.DEFENSE]:
		# 攻守ターンの判定なしはバックパス（2026-11-03）。読めない手なので、守備側の手の当たり外れは言わない
		if reveal.user_role == GameEnums.Phase.ATTACK:
			return "判定なし（バックパスで作り直し）"
		return "判定なし（相手がバックパスで作り直し）"
	if reveal.user_role == GameEnums.Phase.POS_TRANSITION:
		return "判定なし（相手は撤退、こちらは保持）"
	return "判定なし（こちらは撤退、相手は保持）"

## 試合の画面（S-03〜S-06）の文言を1か所に集める。エリアは利用者の視点のキー（BoardSnapshot・RevealView の値）。
## 用語の正本は glossary.md（ゾーン: 自陣・中盤・敵陣、レーン: 左大外・左ハーフスペース・中央…、HS = ハーフスペース）と
## functional-overview.md の区分値（ターン結果の日本語名）。
class_name MatchTexts
extends RefCounted

const ZONE_NAMES: Array[String] = ["自陣", "中盤", "敵陣"]
const LANE_NAMES: Array[String] = ["左大外", "左HS", "中央", "右HS", "右大外"]
const ACTION_NAMES: Dictionary = {
	GameEnums.ChoiceFamily.ATTACK: ["ショートパス", "ドリブル", "背後へのロングボール", "サイドチェンジ", "シュート"],
	GameEnums.ChoiceFamily.DEFENSE: ["プレス", "カバー"],
	GameEnums.ChoiceFamily.NEG_TRANS: ["即時奪回", "リトリート"],
	GameEnums.ChoiceFamily.POS_TRANS: ["カウンター", "保持"],
}
## 判定で手が成功した側（利用者から見た値）。NONE は奪い合いの無い結果（NO_CONTEST）
enum TurnWinner { USER, OPPONENT, NONE }

const OUTCOME_WORDS: Array[String] = ["前進", "膠着", "ロスト", "得点", "シュート阻止", "奪回成功", "奪回失敗", "判定なし"]
const DEFENSE_STYLE_NAMES: Array[String] = ["ゾーン", "マンツーマン"]
const ATTACK_STYLE_NAMES: Array[String] = ["保持型", "カウンター型"]
## 人数差の符号。マイナスは数学の記号（U+2212）で、ハイフンより読みやすい
const MINUS_SIGN: String = "−"


## "M-L1" → 「中盤・左HS」。読めないキーはそのまま返す。
static func area_name(key: String) -> String:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return key
	return "%s・%s" % [ZONE_NAMES[area.zone], LANE_NAMES[area.lane]]


static func lane_name(lane: GameEnums.Lane) -> String:
	return LANE_NAMES[lane]


static func action_name(family: GameEnums.ChoiceFamily, action: int) -> String:
	return (ACTION_NAMES[family] as Array)[action] as String


## 運ぶ先を選ぶ間に添える一言（誰が動くか・どのエリアを選べるか）。条件は MoveRules.defense_options と同じ。
## プレス・カバーだけ（違いが盤面から読みにくく、選べないエリアがある理由が分かりにくいため）。ほかの手は空。
static func target_rule(family: GameEnums.ChoiceFamily, action: int) -> String:
	if family != GameEnums.ChoiceFamily.DEFENSE:
		return ""
	if action == GameEnums.DefenseAction.PRESS:
		return "プレス: 隣のエリアの味方1人が、選んだエリアへ寄せる。隣に味方がいるエリアだけ選べる"
	if action != GameEnums.DefenseAction.COVER:
		return ""
	return "カバー: 味方1人が、選んだエリアの背後へ下がる。自陣の列と、その場にも横にも背後にも味方がいないエリアは選べない（前にいる味方は届かない）"


## 「ショートパス → 中盤・中央」。運ぶ先を持たない手は手の名前だけ。
static func choice_summary(choice: TurnChoice) -> String:
	var name: String = action_name(choice.family, choice.action)
	if choice.target == null:
		return name
	return "%s → %s" % [name, area_name(choice.target.to_key())]


## 上部バーに常に出す、どちらのボールか（2026-10-24）。駒と同じ記号を添える。
static func possession_text(user_has_ball: bool) -> String:
	return "● 自分のボール" if user_has_ball else "◆ CPU のボール"


## 局面のタグ。トランジションでボールを持っているのは奪取側（ポジティブ）。
static func phase_tag(turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> String:
	if turn_kind == GameEnums.TurnKind.TRANSITION:
		return "POS.TRANSITION ポジティブトランジション" if user_has_ball else "NEG.TRANSITION ネガティブトランジション"
	return "ATTACK 攻撃" if user_has_ball else "DEFENSE 守備"


## 「ADVANCE 前進」の形。
static func outcome_label(outcome: GameEnums.TurnOutcome) -> String:
	return "%s %s" % [GameEnums.TurnOutcome.find_key(outcome), outcome_word(outcome)]


## 判定でどちらの手が成功したか（結果の札の色分けに使う。2026-10-24）。
## 保持側（攻守ターンの攻撃側・トランジションの奪った側）の成功は前進・得点・奪い返しの失敗、相手側の成功は膠着・
## ロスト・シュート阻止・奪回成功。奪い合いの無い判定なし（保持 × リトリート）はどちらでもない。
static func turn_winner(reveal: RevealView) -> TurnWinner:
	if reveal.outcome == GameEnums.TurnOutcome.NO_CONTEST:
		return TurnWinner.NONE
	var is_user_holder: bool = reveal.user_role in [GameEnums.Phase.ATTACK, GameEnums.Phase.POS_TRANSITION]
	var holder_won: bool = reveal.outcome in [GameEnums.TurnOutcome.ADVANCE, GameEnums.TurnOutcome.GOAL,
			GameEnums.TurnOutcome.REGAIN_FAILED]
	return TurnWinner.USER if holder_won == is_user_holder else TurnWinner.OPPONENT


## 結果の札「● ADVANCE 前進」。成功した側を、色だけでなく駒と同じ記号（自分 ●・相手 ◆）でも示す。
## どちらでもない結果は記号を付けない。
static func outcome_tag(reveal: RevealView) -> String:
	match turn_winner(reveal):
		TurnWinner.USER:
			return "● " + outcome_label(reveal.outcome)
		TurnWinner.OPPONENT:
			return "◆ " + outcome_label(reveal.outcome)
	return outcome_label(reveal.outcome)


## 「前進」など、結果の日本語名だけ。
static func outcome_word(outcome: GameEnums.TurnOutcome) -> String:
	return OUTCOME_WORDS[outcome]


## 「4-3-3 ゾーン・カウンター型」。
static func setup_text(setup: TeamSetup) -> String:
	return "%s %s・%s" % [setup.formation_id, DEFENSE_STYLE_NAMES[setup.styles.defense],
			ATTACK_STYLE_NAMES[setup.styles.attack]]


static func defense_style_name(style: GameEnums.DefenseStyle) -> String:
	return DEFENSE_STYLE_NAMES[style]


static func attack_style_name(style: GameEnums.AttackStyle) -> String:
	return ATTACK_STYLE_NAMES[style]


## ヒントの札（表示仕様「`+1`、`±0 カバーあり`」）。カバーは同数のときだけ添える（同数のときだけ判定に効くため）。
## 人数を比べない手（リトリート・保持）は空。
static func hint_tag(hint: ChoiceHint) -> String:
	if not hint.is_compared:
		return ""
	var diff: int = hint.diff()
	if diff > 0:
		return "+%d" % diff
	if diff < 0:
		return "%s%d" % [MINUS_SIGN, -diff]
	var cover: String = cover_short(hint.cover)
	return "±0" if cover.is_empty() else "±0 %s" % cover


## 「1対0」（自分 対 相手）。人数を比べない手は空。
static func hint_counts(hint: ChoiceHint) -> String:
	if not hint.is_compared:
		return ""
	return "%d対%d" % [hint.own_count, hint.opponent_count]


## カバーの短い表記（ヒントの札・判定の内訳）。カバーが無ければ空。
static func cover_short(cover: GameEnums.CoverKind) -> String:
	return "カバーあり" if cover == GameEnums.CoverKind.DEFENDER else ""


## 「前半 5／15」。アディショナルタイムは「前半 15＋2」（規定のターン数＋何ターン目か）。
## ハーフを終えた後の盤面（turn_number が1つ先に進む）は、最後に行ったターンを出す。
static func clock_text(snapshot: BoardSnapshot) -> String:
	var half_name: String = "前半" if snapshot.half == 1 else "後半"
	var turn: int = snapshot.turn_number - 1 if snapshot.is_half_over else snapshot.turn_number
	if turn > snapshot.turns_per_half:
		return "%s %d＋%d" % [half_name, snapshot.turns_per_half, turn - snapshot.turns_per_half]
	return "%s %d／%d" % [half_name, turn, snapshot.turns_per_half]

## 試合の画面（S-03〜S-06）の文言を1か所に集める。エリアは利用者の視点のキー（BoardSnapshot・RevealView の値）。
## 用語の正本は glossary.md（列: 自陣ゴール前・自陣・中盤（自陣）・中盤（敵陣）・敵陣・敵陣ゴール前、レーン: 左大外・左ハーフスペース・中央…、HS = ハーフスペース）と
## functional-overview.md の区分値（ターン結果の日本語名）。
class_name MatchTexts
extends RefCounted

const ZONE_NAMES: Array[String] = ["自陣ゴール前", "自陣", "中盤（自陣）", "中盤（敵陣）", "敵陣", "敵陣ゴール前"]
const LANE_NAMES: Array[String] = ["左大外", "左HS", "中央", "右HS", "右大外"]
const ACTION_NAMES: Dictionary = {
	GameEnums.ChoiceFamily.ATTACK: ["ショートパス", "ドリブル", "スルーパス", "背後へのロングボール", "サイドチェンジ", "シュート", "バックパス"],
	# 守備の手は、何を読んで守るかが分かる名前にする（2026-11-03。行き先はゲームが決め、手のボタンだけで選ぶため）
	GameEnums.ChoiceFamily.DEFENSE: ["パスコースを切る", "背後を埋める", "ドリブルのコースを切る", "シュートコースを塞ぐ"],
	GameEnums.ChoiceFamily.NEG_TRANS: ["即時奪回", "リトリート"],
	GameEnums.ChoiceFamily.POS_TRANS: ["カウンター", "保持"],
}
## 手のボタンの枠の名前（MoveMenu.SLOTS の並び。2026-11-03）。攻撃は距離で分けた枠の名前で、中身の手（スルーパス・
## サイドチェンジなど）はボタンの2行目に添える。4つ目の枠と、守備・トランジションの手は手の名前のまま
const SLOT_NAMES: Dictionary = {
	GameEnums.ChoiceFamily.ATTACK: ["ショートパス", "ロングパス", "ドリブル", ""],
}
## 手のボタンで1行に入らない名前 → 1行目の文字数（2026-11-05）。Godot の折り返しは、かなの間ならどこでも切る
## （「パスコースを切／る」）ので、語の切れ目で改行する。ボタンの内側（16:9 で 218px）に 24px の字は約9文字で、
## 番号「① 」を足すと8文字以上の名前は入らない
const BUTTON_LINE_BREAKS: Dictionary = {
	"パスコースを切る": 6,
	"ドリブルのコースを切る": 5,
	"シュートコースを塞ぐ": 4,
}
## 判定で手が成功した側（利用者から見た値）。NONE は奪い合いの無い結果（NO_CONTEST）
enum TurnWinner { USER, OPPONENT, NONE }

const OUTCOME_WORDS: Array[String] = ["前進", "膠着", "ロスト", "得点", "シュート阻止", "奪回成功", "奪回失敗", "判定なし", "オフサイド"]
const DEFENSE_STYLE_NAMES: Array[String] = ["ゾーン", "マンツーマン"]
const ATTACK_STYLE_NAMES: Array[String] = ["保持型", "カウンター型"]
## 人数差の符号。マイナスは数学の記号（U+2212）で、ハイフンより読みやすい
const MINUS_SIGN: String = "−"


## "M2-L1" → 「中盤（敵陣）・左HS」。読めないキーはそのまま返す。
static func area_name(key: String) -> String:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return key
	return "%s・%s" % [ZONE_NAMES[area.zone], LANE_NAMES[area.lane]]


static func lane_name(lane: GameEnums.Lane) -> String:
	return LANE_NAMES[lane]


static func action_name(family: GameEnums.ChoiceFamily, action: int) -> String:
	return (ACTION_NAMES[family] as Array)[action] as String


## 手のボタンの1行目の名前（枠の名前。枠の名前が無ければ手の名前）。
static func slot_name(family: GameEnums.ChoiceFamily, action: int) -> String:
	var index: int = MoveMenu.slot_index(family, action)
	if SLOT_NAMES.has(family) and index >= 0:
		var name: String = (SLOT_NAMES[family] as Array)[index] as String
		if not name.is_empty():
			return name
	return action_name(family, action)


## 手のボタンの名前。1行に入らない名前は、BUTTON_LINE_BREAKS の位置で改行する。
static func slot_button_text(family: GameEnums.ChoiceFamily, action: int) -> String:
	var name: String = slot_name(family, action)
	if not BUTTON_LINE_BREAKS.has(name):
		return name
	var first_line: int = BUTTON_LINE_BREAKS[name] as int
	return "%s\n%s" % [name.left(first_line), name.substr(first_line)]


## 手を選んだときに添える一言（誰が動くか・何を読む手か。2026-11-03 に、行き先を選ばない操作に合わせて書き直した）。
## スルーパス（人数に関係なく読みで決まる、ほかの手と違う規則）・バックパス（判定しない）と、守備の手（違いが盤面から読みにくいため）。
## ほかの手は空。
static func target_rule(family: GameEnums.ChoiceFamily, action: int) -> String:
	if family == GameEnums.ChoiceFamily.ATTACK:
		match action:
			GameEnums.PlayType.THROUGH_PASS:
				return "スルーパス: 味方が相手の背後へ走り込む。人数に関係なく、読まれるか相手が入ってくれば奪われ、そうでなければ通る"
			GameEnums.PlayType.BACK_PASS:
				return "バックパス: 後ろの味方へ戻して作り直す。相手は読めず必ず通るが、前には進めない"
		return ""
	if family != GameEnums.ChoiceFamily.DEFENSE:
		return ""
	match action:
		GameEnums.DefenseAction.PRESS:
			return "パスコースを切る: 相手のショートパスの行き先を読み、隣の味方1人がそのエリアへ寄せる"
		GameEnums.DefenseAction.COVER:
			return "背後を埋める: 相手のロングパスの行き先を読み、味方1人がそのエリアの背後へ下がる"
		GameEnums.DefenseAction.CLOSE_DOWN:
			return "ドリブルのコースを切る: 相手のドリブルの行き先を読み、隣の味方1人がそのエリアへ寄せる。読みが当たれば、人数に関係なく奪う"
		GameEnums.DefenseAction.BLOCK_SHOT:
			return "シュートコースを塞ぐ: 隣の味方1人がボールを持つ選手へ寄せ、シュートを止めに行く。相手のシュートを読む手"
	return ""


## 「ショートパス → 中盤（敵陣）・中央」。運ぶ先を持たない手は手の名前だけ。
static func choice_summary(choice: TurnChoice) -> String:
	var name: String = action_name(choice.family, choice.action)
	if choice.target == null:
		return name
	return "%s → %s" % [name, area_name(choice.target.to_key())]


## 上部バーに常に出す、どちらのボールか（2026-10-24）。駒と同じ記号を添える。
static func possession_text(user_has_ball: bool) -> String:
	return "● 自分のボール" if user_has_ball else "◆ CPU のボール"


## 局面のタグ。トランジションでボールを持っているのは奪取側（ポジティブ）。
## 英字と日本語を2行に分ける（1行の「NEG.TRANSITION ネガティブトランジション」は約 480px あり、上部バーが画面の幅を超えた。2026-10-29）。
static func phase_tag(turn_kind: GameEnums.TurnKind, user_has_ball: bool) -> String:
	if turn_kind == GameEnums.TurnKind.TRANSITION:
		return "POS.TRANSITION\nポジティブトランジション" if user_has_ball else "NEG.TRANSITION\nネガティブトランジション"
	return "ATTACK\n攻撃" if user_has_ball else "DEFENSE\n守備"


## 「ADVANCE 前進」の形。
static func outcome_label(outcome: GameEnums.TurnOutcome) -> String:
	return "%s %s" % [GameEnums.TurnOutcome.find_key(outcome), outcome_word(outcome)]


## 判定でどちらの手が成功したか（結果の札の色分けに使う。2026-10-24）。
## 保持側（攻守ターンの攻撃側・トランジションの奪った側）の成功は前進・得点・奪い返しの失敗、相手側の成功は膠着・
## ロスト・シュート阻止・奪回成功・オフサイド。奪い合いの無い判定なし（保持 × リトリート）はどちらでもない。
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
## 人数を比べない手（リトリート・保持）は空。スルーパスだけは人数の代わりに「読み次第」（マーカーがついてくるなら「マーク注意」）を出す。
static func hint_tag(hint: ChoiceHint) -> String:
	# 今の配置のままオフサイドになる運ぶ先は、ほかの札より先に注意を出す（作戦ボードの札の幅に収まる5文字。2026-10-25）
	if hint.is_offside:
		return "オフサイド"
	# スルーパスは人数を比べないが、通るかが読み次第であることを札で示す（作戦ボードの札の幅に収まる4文字。2026-10-25）
	if hint.family == GameEnums.ChoiceFamily.ATTACK and hint.action == GameEnums.PlayType.THROUGH_PASS:
		# 相手が何もしなくてもマーカーがついて入ってくる運ぶ先は、読みに関係なく奪われるので注意を出す（2026-10-28）
		return "マーク注意" if hint.is_marked else "読み次第"
	if not hint.is_compared:
		return ""
	var diff: int = hint.diff()
	if diff > 0:
		return "+%d" % diff
	if diff < 0:
		return "%s%d" % [MINUS_SIGN, -diff]
	var cover: String = cover_short(hint.cover)
	return "±0" if cover.is_empty() else "±0 %s" % cover


## ヒントの札を控えめな色にするか。人数を比べる札の ±0 だけ（スルーパスの「読み次第」とオフサイドの注意は、
## 隠れた人数差が ±0 でも目立たせる。色から人数差を漏らさず、注意を埋もれさせないため。2026-10-25）。
static func is_hint_muted(hint: ChoiceHint) -> bool:
	return hint.is_compared and hint.diff() == 0 and not hint.is_offside


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

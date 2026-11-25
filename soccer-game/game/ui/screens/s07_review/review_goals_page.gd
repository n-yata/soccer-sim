## S-07 振り返りの「得失点」のページ（screen-07-review.md の GoalsPage）。左に得点ごとのカード、右に選んだ得点の
## 直前のターン（判定時の両チームの人数と動きの矢印のミニピッチ・見出し・両者の手・結果の札・判定理由）を出す。
## カードを押しても画面の中の表示を切り替えるだけ（アプリケーション層は呼ばない）。
class_name ReviewGoalsPage
extends HBoxContainer

## 得点のカードの列の幅。screen-07-review.md の 560px では、右の各ターンの文が折り返しすぎて読みにくかったため、
## 見出し（「▼ 失点 後半 15＋2ターン目（1 − 1）」）が1行に入る幅まで詰めた（2026-10-29。スクリーンショットで確認）
const GOAL_LIST_WIDTH: float = 400.0
const GOAL_CARD_HEIGHT: float = 96.0
## 得失点の流れのミニピッチの1マス（「1−0」が 24px で入る大きさ。screen-common.md §5）
const TURN_PITCH_CELL: Vector2 = Vector2(56, 34)

## ReviewView.goals（各要素の形はそちら）
var _goals: Array[Dictionary] = []
var _turns_per_half: int = 0
## 選んでいる得点のカード（得点の順番。0 始まり。得点が無ければ -1）
var _selected: int = -1
var _no_goals_label: Label
var _cards: VBoxContainer
var _turn_list: VBoxContainer


func _init() -> void:
	name = "GoalsPage"
	add_theme_constant_override("separation", 24)
	var left := ScrollContainer.new()
	left.name = "GoalList"
	left.custom_minimum_size = Vector2(GOAL_LIST_WIDTH, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(left)
	var left_body := VBoxContainer.new()
	left_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_body.add_theme_constant_override("separation", 12)
	left.add_child(left_body)
	_no_goals_label = MatchScreenLayout.text(left_body, "NoGoalsLabel", &"")
	_cards = VBoxContainer.new()
	_cards.name = "GoalCards"
	_cards.add_theme_constant_override("separation", 12)
	left_body.add_child(_cards)
	var right := ScrollContainer.new()
	right.name = "TurnList"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(right)
	_turn_list = VBoxContainer.new()
	_turn_list.name = "TurnRows"
	_turn_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_list.add_theme_constant_override("separation", 24)
	right.add_child(_turn_list)


## 得点のカードを作り直し、最初の得点を選んだ状態にする（右が空にならないように）。得点が無ければ案内文を出す。
func show_goals(goals: Array[Dictionary], turns_per_half: int) -> void:
	_goals = goals
	_turns_per_half = turns_per_half
	MatchScreenLayout.clear(_cards)
	_no_goals_label.visible = goals.is_empty()
	_no_goals_label.text = ReviewTexts.no_goals_text()
	for index: int in range(goals.size()):
		var card := Button.new()
		card.name = "GoalCard%d" % index
		card.text = ReviewTexts.goal_title(goals[index], turns_per_half)
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(0, GOAL_CARD_HEIGHT)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.pressed.connect(select_goal.bind(index))
		_cards.add_child(card)
	_selected = 0 if not goals.is_empty() else -1
	_show_selected()


## 得点のカードを選ぶ（右に直前のターンを出す）。範囲外は何もしない。
func select_goal(index: int) -> void:
	if index < 0 or index >= _goals.size():
		return
	_selected = index
	_show_selected()


func selected_goal() -> int:
	return _selected


func goal_cards() -> Array[Button]:
	var cards: Array[Button] = []
	for child: Node in _cards.get_children():
		cards.append(child as Button)
	return cards


func no_goals_message() -> String:
	return _no_goals_label.text if _no_goals_label.visible else ""


## 右の一覧の各ターンの [見出し, 両者の手, 結果の札, 判定理由]。
func turn_rows() -> Array[Array]:
	var rows: Array[Array] = []
	for row: Node in _turn_list.get_children():
		var texts: Array = []
		for label: Node in row.find_children("*", "Label", true, false):
			texts.append((label as Label).text)
		rows.append(texts)
	return rows


## 右の一覧の各ターンのミニピッチ。
func turn_pitches() -> Array[MiniPitch]:
	var pitches: Array[MiniPitch] = []
	for row: Node in _turn_list.get_children():
		pitches.append(row.find_children("*", "MiniPitch", true, false)[0] as MiniPitch)
	return pitches


func _show_selected() -> void:
	MatchScreenLayout.clear(_turn_list)
	var cards: Array[Button] = goal_cards()
	for index: int in range(cards.size()):
		cards[index].set_pressed_no_signal(index == _selected)
	if _selected < 0:
		return
	for reveal: RevealView in (_goals[_selected]["turns"] as Array):
		_turn_list.add_child(_turn_row(reveal))


## 1ターンの行: 左に判定時の両チームの人数と動きの矢印のミニピッチ、右に見出し・両者の手・結果・判定理由。
## ボールは判定前の位置（手を選んだときにボールがあったエリア）に出す。
func _turn_row(reveal: RevealView) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var pitch := MiniPitch.new(TURN_PITCH_CELL)
	pitch.show_turn(_count_areas(reveal.user_players_at_judgement), _count_areas(reveal.opponent_players_at_judgement),
			reveal.movements, reveal.ball_before)
	row.add_child(pitch)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 6)
	row.add_child(texts)
	MatchScreenLayout.text(texts, "Heading", &"SectionTitleLabel").text = ReviewTexts.turn_heading(reveal, _turns_per_half)
	MatchScreenLayout.text(texts, "Choices", &"").text = ReviewTexts.choices_text(reveal)
	MatchScreenLayout.text(texts, "Outcome", &"CardTitleLabel").text = MatchTexts.outcome_tag(reveal)
	MatchScreenLayout.text(texts, "Reason", &"").text = JudgeReasonFormatter.format(reveal)
	return row


## 選手の配置（各要素に "area"）をエリアごとに数える。
static func _count_areas(players: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for player: Dictionary in players:
		var key: String = player["area"] as String
		counts[key] = (counts.get(key, 0) as int) + 1
	return counts

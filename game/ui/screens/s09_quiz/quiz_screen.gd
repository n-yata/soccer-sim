## S-09 理解度チェック（screen-09-quiz.md。FR-22）。学習目標ごとの一覧と、その学習目標の場面問題を順に出す。
## 正誤の判定は、選んだ選択肢が問題の正解と一致するかだけ（ルールの計算は伴わない）。回答は App.user_data に保存する
## （保存に失敗しても表示は進める。通知は MainShell）。
class_name QuizScreen
extends AppScreen

## LIST: 学習目標の一覧／ASKING: 問題と選択肢／ANSWERED: 正誤と解説（screen-09-quiz.md「画面の状態」）
enum State { LIST, ASKING, ANSWERED }

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")
const TITLE: String = "理解度チェック"
## 場面の図の1マス。基準解像度（1280×720）で、本体（ヘッダーと余白を除いた高さ 576px、操作の列 480px を除いた幅 728px）に
## 6列×5レーンの図（650×456）と下の2行の文が収まる大きさ
const SCENE_CELL: Vector2 = Vector2(130, 76)
const CHOICE_HEIGHT: float = 96.0
const ANSWER_TEXT: String = "回答する"
const NEXT_TEXT: String = "次の問題"
const LIST_TEXT: String = "一覧へ"

var _state: State = State.LIST
## 選んだ学習目標の問題（quiz.json の並び順）
var _questions: Array[QuizQuestionDef] = []
var _index: int = 0
## 選んだ選択肢の ID（未選択は空文字）
var _picked: String = ""

var _header: ScreenHeader
var _list_view: GridContainer
var _question_view: HBoxContainer
var _scene_pitch: MiniPitch
var _scene_info: Label
var _question_text: Label
var _choices: VBoxContainer
var _feedback: PanelContainer
var _side_scroll: ScrollContainer
var _result_label: Label
var _answer_label: Label
var _explanation_label: Label
var _principles_label: Label
var _action_button: Button


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、戻るはここでつなぐ。
func _ready() -> void:
	_header.back_pressed.connect(func() -> void: handle_back())


func enter(_params: Dictionary) -> void:
	_show_list()


## 問題の表示中は一覧へ（回答前の問題は記録しない）、一覧ではタイトルへ（screen-09-quiz.md「戻る・Android の戻る操作」）。
func handle_back() -> bool:
	if _state == State.LIST:
		App.request_screen(AppScreens.Id.S01_TITLE)
	else:
		_show_list()
	return true


func state() -> State:
	return _state


## 学習目標のカード（並びは QuizQuestionDef.GOAL_IDS）。
func goal_cards() -> Array[Button]:
	var cards: Array[Button] = []
	for child: Node in _list_view.get_children():
		cards.append(child as Button)
	return cards


## 選択肢のボタン（並びは問題の選択肢の順）。
func choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _choices.get_children():
		buttons.append(child as Button)
	return buttons


func action_button() -> Button:
	return _action_button


func header_title() -> String:
	return _header.title_text()


func question_text() -> String:
	return _question_text.text


func scene_pitch() -> MiniPitch:
	return _scene_pitch


func scene_info_text() -> String:
	return _scene_info.text


func feedback_visible() -> bool:
	return _feedback.visible


func choices_visible() -> bool:
	return _choices.visible


## 回答後の正誤・選んだ答えと正解・解説・根拠の原則の文。
func feedback_texts() -> Array[String]:
	return [_result_label.text, _answer_label.text, _explanation_label.text, _principles_label.text]


## 学習目標の一覧を出す（正答状況は開くたびに読み直す）。
func _show_list() -> void:
	_state = State.LIST
	_header.set_title(TITLE)
	_list_view.visible = true
	_question_view.visible = false
	MatchScreenLayout.clear(_list_view)
	var progress: Dictionary = App.user_data.quiz_progress()
	for goal_id: String in QuizQuestionDef.GOAL_IDS:
		_list_view.add_child(_goal_card(goal_id, progress.get(goal_id, {}) as Dictionary))


func _goal_card(goal_id: String, counts: Dictionary) -> Button:
	var card := Button.new()
	card.name = goal_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.disabled = counts.get("total", 0) as int == 0
	card.pressed.connect(_start_goal.bind(goal_id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	MatchScreenLayout.text(box, "Title", &"CardTitleLabel").text = QuizTexts.goal_title(goal_id)
	MatchScreenLayout.text(box, "Summary", &"MutedLabel").text = QuizTexts.goal_summary(counts)
	return card


func _start_goal(goal_id: String) -> void:
	_questions.clear()
	for question: QuizQuestionDef in App.library.quiz_questions():
		if question.goal_id == goal_id:
			_questions.append(question)
	if _questions.is_empty():
		return
	_index = 0
	_show_question()


func _show_question() -> void:
	var question: QuizQuestionDef = _questions[_index]
	_state = State.ASKING
	_picked = ""
	_header.set_title(QuizTexts.question_header(question.goal_id, _index, _questions.size()))
	_list_view.visible = false
	_question_view.visible = true
	_scene_pitch.show_turn(question.user_counts, question.opponent_counts, [], question.ball_area.to_key())
	_scene_info.text = QuizTexts.scene_info(question)
	_question_text.text = QuizTexts.fill(question.text)
	MatchScreenLayout.clear(_choices)
	for index: int in range(question.choice_ids.size()):
		var button := Button.new()
		button.name = question.choice_ids[index]
		button.text = QuizTexts.fill(question.choice_texts[index])
		button.custom_minimum_size = Vector2(0, CHOICE_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.theme_type_variation = &"ChoiceButton"
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_choice_pressed.bind(question.choice_ids[index]))
		_choices.add_child(button)
	_choices.visible = true
	_feedback.visible = false
	_side_scroll.scroll_vertical = 0
	_action_button.text = ANSWER_TEXT
	_action_button.disabled = true


## 選んだ選択肢に枠を付ける（選び直せる）。回答後は選べない。
func _on_choice_pressed(choice_id: String) -> void:
	if _state != State.ASKING:
		return
	_picked = choice_id
	for button: Button in choice_buttons():
		button.set_pressed_no_signal(String(button.name) == choice_id)
	_action_button.disabled = false


func _on_action_pressed() -> void:
	match _state:
		State.ASKING:
			_answer()
		State.ANSWERED:
			if _index + 1 < _questions.size():
				_index += 1
				_show_question()
			else:
				_show_list()


func _answer() -> void:
	if _picked.is_empty():
		return
	var question: QuizQuestionDef = _questions[_index]
	var is_correct: bool = question.is_correct(_picked)
	# 保存に失敗しても次へ進む（通知は MainShell。UserDataService が storage_failed を出す）
	App.user_data.save_quiz_answer(QuizAnswer.new(question.id, is_correct, Time.get_datetime_string_from_system(false, false)))
	_state = State.ANSWERED
	# 操作の列を、選択肢から正誤・解説に替える（screen-design.md「S-09」のレイアウト）。選択肢を残すと、解説が列の下に隠れて
	# 回答しても何も変わらないように見えるため（2026-10-31）。選んだ答えと正解は、正誤の下の文で示す
	_choices.visible = false
	_result_label.text = QuizTexts.CORRECT_MARK if is_correct else QuizTexts.WRONG_MARK
	_result_label.theme_type_variation = &"CheckMarkLabel" if is_correct else &"CautionLabel"
	_answer_label.text = QuizTexts.answer_line(QuizTexts.fill(question.choice_text(_picked)),
			QuizTexts.fill(question.choice_text(question.answer)), is_correct)
	_explanation_label.text = QuizTexts.fill(question.explanation)
	_principles_label.text = QuizTexts.principles_line(_principles_of(question))
	_feedback.visible = true
	_side_scroll.scroll_vertical = 0
	_action_button.text = NEXT_TEXT if _index + 1 < _questions.size() else LIST_TEXT
	_action_button.disabled = false


## 根拠の原則（読み込みで原則カタログにあることを確かめてあるが、引けないものは飛ばす）。
func _principles_of(question: QuizQuestionDef) -> Array[PrincipleDef]:
	var principles: Array[PrincipleDef] = []
	for principle_id: String in question.principle_ids:
		var principle: PrincipleDef = App.library.principle(principle_id)
		if principle != null:
			principles.append(principle)
	return principles


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = ScreenHeader.TOP_MARGIN
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	_header = HEADER_SCENE.instantiate() as ScreenHeader
	_header.name = "Header"
	layout.add_child(_header)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side_name: String in ["left", "right", "bottom", "top"]:
		margin.add_theme_constant_override("margin_" + side_name, 24)
	layout.add_child(margin)
	var views := Control.new()
	views.name = "Views"
	margin.add_child(views)

	_list_view = GridContainer.new()
	_list_view.name = "ListView"
	_list_view.columns = 2
	_list_view.add_theme_constant_override("h_separation", 24)
	_list_view.add_theme_constant_override("v_separation", 24)
	_list_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	views.add_child(_list_view)

	_question_view = HBoxContainer.new()
	_question_view.name = "QuestionView"
	_question_view.add_theme_constant_override("separation", 24)
	_question_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	views.add_child(_question_view)
	_build_scene_pane()
	_build_side_column()


## 本体: 場面の図と、その下の方式・ボールの文。
func _build_scene_pane() -> void:
	var scene_pane := VBoxContainer.new()
	scene_pane.name = "ScenePane"
	scene_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_pane.alignment = BoxContainer.ALIGNMENT_CENTER
	scene_pane.add_theme_constant_override("separation", 16)
	_question_view.add_child(scene_pane)
	_scene_pitch = MiniPitch.new(SCENE_CELL)
	_scene_pitch.name = "ScenePitch"
	_scene_pitch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scene_pane.add_child(_scene_pitch)
	_scene_info = MatchScreenLayout.text(scene_pane, "SceneInfo", &"MutedLabel")
	_scene_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 操作の列: 問題文・選択肢・正誤と解説を縦にスクロールし、「回答する」／「次の問題」を下端に固定する。
func _build_side_column() -> void:
	var column := VBoxContainer.new()
	column.name = "SideColumn"
	column.custom_minimum_size = Vector2(MatchScreenLayout.SIDE_WIDTH, 0)
	column.add_theme_constant_override("separation", 16)
	_question_view.add_child(column)
	_side_scroll = ScrollContainer.new()
	_side_scroll.name = "SideScroll"
	_side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_side_scroll)
	var side := VBoxContainer.new()
	side.name = "SideBody"
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 16)
	_side_scroll.add_child(side)
	_question_text = MatchScreenLayout.text(side, "QuestionText", &"CardTitleLabel")
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 12)
	side.add_child(_choices)
	_feedback = PanelContainer.new()
	_feedback.name = "Feedback"
	_feedback.theme_type_variation = &"SurfaceCard"
	side.add_child(_feedback)
	var feedback_box := VBoxContainer.new()
	feedback_box.add_theme_constant_override("separation", 8)
	_feedback.add_child(feedback_box)
	_result_label = MatchScreenLayout.text(feedback_box, "Result", &"CheckMarkLabel")
	_answer_label = MatchScreenLayout.text(feedback_box, "Answer", &"SubLabel")
	_explanation_label = MatchScreenLayout.text(feedback_box, "Explanation", &"")
	_principles_label = MatchScreenLayout.text(feedback_box, "Principles", &"MutedLabel")
	_action_button = Button.new()
	_action_button.name = "ActionButton"
	_action_button.custom_minimum_size = Vector2(0, MatchScreenLayout.PRIMARY_HEIGHT)
	_action_button.theme_type_variation = &"AccentCard"
	_action_button.pressed.connect(_on_action_pressed)
	column.add_child(_action_button)

## S-09 理解度チェック（screen-09-quiz.md。FR-22）のテスト。問題は同梱の quiz.json（App.library）、回答結果は一時ディレクトリに
## 保存するサービス（ScreenTestHelper.use_user_data_in）を使う。
extends GdUnitTestSuite

const QUIZ_SCENE: String = "res://ui/screens/s09_quiz/quiz_screen.tscn"

var _requested: Array[int] = []
var _original_user_data: UserDataService
var _test_count: int = 0
var _dir: String


func before_test() -> void:
	_test_count += 1
	_dir = create_temp_dir("quiz_screen/user_%d" % _test_count)
	_original_user_data = ScreenTestHelper.use_user_data_in(_dir)
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> QuizScreen:
	var screen: QuizScreen = auto_free((load(QUIZ_SCENE) as PackedScene).instantiate() as QuizScreen) as QuizScreen
	add_child(screen)
	screen.enter({})
	return screen


func _goal_questions(goal_id: String) -> Array[QuizQuestionDef]:
	var questions: Array[QuizQuestionDef] = []
	for question: QuizQuestionDef in App.library.quiz_questions():
		if question.goal_id == goal_id:
			questions.append(question)
	return questions


func _card_texts(card: Button) -> Array[String]:
	return [(card.find_child("Title", true, false) as Label).text, (card.find_child("Summary", true, false) as Label).text]


func _choice(screen: QuizScreen, choice_id: String) -> Button:
	for button: Button in screen.choice_buttons():
		if String(button.name) == choice_id:
			return button
	return null


## 正解でない最初の選択肢
func _wrong_choice(question: QuizQuestionDef) -> String:
	for choice_id: String in question.choice_ids:
		if not question.is_correct(choice_id):
			return choice_id
	return ""


func _saved_answers() -> Array[QuizAnswer]:
	return QuizAnswerStore.new(_dir).load_all()


func test_the_list_shows_every_goal_with_its_progress() -> void:
	var screen: QuizScreen = _open()
	assert_int(screen.state()).is_equal(QuizScreen.State.LIST)
	assert_str(screen.header_title()).is_equal("理解度チェック")
	var cards: Array[Button] = screen.goal_cards()
	assert_int(cards.size()).is_equal(4)
	assert_array(_card_texts(cards[0])).is_equal(["LG-1 位置的・数的優位を見つける", "未回答"] as Array[String])
	assert_array(_card_texts(cards[3])).is_equal(["LG-4 噛み合わせ", "未回答"] as Array[String])


## 学習目標のカードを押すと、その学習目標の最初の問題を、図・場面の文・問題文・選択肢で出す
func test_a_goal_card_opens_its_first_question() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[1].pressed.emit()
	var question: QuizQuestionDef = _goal_questions("LG-2")[0]
	assert_int(screen.state()).is_equal(QuizScreen.State.ASKING)
	assert_str(screen.header_title()).is_equal("LG-2　1／%d" % _goal_questions("LG-2").size())
	assert_str(screen.question_text()).is_equal(QuizTexts.fill(question.text))
	# エリアのキーは、試合の画面と同じ呼び名にして出す
	assert_str(screen.question_text()).contains(MatchTexts.area_name(question.ball_area.to_key())).not_contains("{")
	assert_dict(screen.scene_pitch().counts()).is_equal(question.user_counts)
	assert_dict(screen.scene_pitch().opponent_counts()).is_equal(question.opponent_counts)
	assert_str(screen.scene_pitch().ball_area()).is_equal(question.ball_area.to_key())
	assert_str(screen.scene_info_text()).is_equal(QuizTexts.scene_info(question))
	var buttons: Array[Button] = screen.choice_buttons()
	assert_int(buttons.size()).is_equal(question.choice_ids.size())
	for index: int in range(buttons.size()):
		assert_str(buttons[index].text).is_equal(QuizTexts.fill(question.choice_texts[index]))
		assert_float(buttons[index].custom_minimum_size.y).is_greater_equal(96.0)
	assert_bool(screen.feedback_visible()).is_false()


## 選択肢を選ぶまで「回答する」は押せない。選び直せ、選んだものだけに印が付く
func test_answer_is_enabled_only_after_picking_and_picks_can_change() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	assert_str(screen.action_button().text).is_equal("回答する")
	assert_bool(screen.action_button().disabled).is_true()
	var buttons: Array[Button] = screen.choice_buttons()
	buttons[0].pressed.emit()
	buttons[1].pressed.emit()
	assert_bool(screen.action_button().disabled).is_false()
	assert_array([buttons[0].button_pressed, buttons[1].button_pressed, buttons[2].button_pressed]) \
			.is_equal([false, true, false])


## 回答後は、操作の列の選択肢を正誤・選んだ答えと正解・解説・根拠の原則に替える（screen-design.md「S-09」）
func test_a_wrong_answer_shows_the_correct_choice_and_the_explanation_and_is_saved() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	var question: QuizQuestionDef = _goal_questions("LG-1")[0]
	var wrong: String = _wrong_choice(question)
	_choice(screen, wrong).pressed.emit()
	screen.action_button().pressed.emit()
	assert_int(screen.state()).is_equal(QuizScreen.State.ANSWERED)
	assert_bool(screen.feedback_visible()).is_true()
	assert_bool(screen.choices_visible()).is_false()
	var principles: Array[PrincipleDef] = []
	for principle_id: String in question.principle_ids:
		principles.append(App.library.principle(principle_id))
	assert_array(screen.feedback_texts()).is_equal(["× 不正解",
			"あなたの答え: %s／正解: %s" % [QuizTexts.fill(question.choice_text(wrong)),
					QuizTexts.fill(question.choice_text(question.answer))],
			QuizTexts.fill(question.explanation), QuizTexts.principles_line(principles)] as Array[String])
	assert_str(screen.feedback_texts()[3]).starts_with("根拠: TP-01 5レーン・ハーフスペース")
	assert_str(screen.action_button().text).is_equal("次の問題")
	var saved: Array[QuizAnswer] = _saved_answers()
	assert_int(saved.size()).is_equal(1)
	assert_str(saved[0].question_id).is_equal(question.id)
	assert_bool(saved[0].correct).is_false()


func test_a_correct_answer_is_saved_as_correct() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[2].pressed.emit()
	var question: QuizQuestionDef = _goal_questions("LG-3")[0]
	_choice(screen, question.answer).pressed.emit()
	screen.action_button().pressed.emit()
	assert_str(screen.feedback_texts()[0]).is_equal("○ 正解")
	assert_str(screen.feedback_texts()[1]).is_equal("あなたの答え: " + QuizTexts.fill(question.choice_text(question.answer)))
	assert_bool(_saved_answers()[0].correct).is_true()


## 次の問題では、選択肢を出し直し、正誤を隠す
func test_the_next_question_shows_choices_again() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	screen.choice_buttons()[0].pressed.emit()
	screen.action_button().pressed.emit()
	screen.action_button().pressed.emit()
	assert_int(screen.state()).is_equal(QuizScreen.State.ASKING)
	assert_bool(screen.choices_visible()).is_true()
	assert_bool(screen.feedback_visible()).is_false()
	assert_int(screen.choice_buttons().size()).is_equal(_goal_questions("LG-1")[1].choice_ids.size())
	assert_bool(screen.action_button().disabled).is_true()


## 「次の問題」で同じ学習目標の次の問題、最後の問題の後は「一覧へ」で一覧に戻り、正答状況を描き直す
func test_answering_every_question_of_a_goal_returns_to_the_updated_list() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[3].pressed.emit()
	var questions: Array[QuizQuestionDef] = _goal_questions("LG-4")
	for index: int in range(questions.size()):
		assert_str(screen.header_title()).is_equal("LG-4　%d／%d" % [index + 1, questions.size()])
		var pick: String = questions[index].answer if index == 0 else _wrong_choice(questions[index])
		_choice(screen, pick).pressed.emit()
		screen.action_button().pressed.emit()
		var is_last: bool = index == questions.size() - 1
		assert_str(screen.action_button().text).is_equal("一覧へ" if is_last else "次の問題")
		screen.action_button().pressed.emit()
	assert_int(screen.state()).is_equal(QuizScreen.State.LIST)
	assert_str(_card_texts(screen.goal_cards()[3])[1]).is_equal("%d問中 1問正解" % questions.size())
	assert_str(_card_texts(screen.goal_cards()[0])[1]).is_equal("未回答")


## 問題の表示中の戻る操作は一覧へ（回答前の問題は記録しない）。一覧ではタイトルへ
func test_back_goes_to_the_list_then_to_the_title() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	screen.choice_buttons()[0].pressed.emit()
	assert_bool(screen.handle_back()).is_true()
	assert_int(screen.state()).is_equal(QuizScreen.State.LIST)
	assert_array(_saved_answers()).is_empty()
	assert_array(_requested).is_empty()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


func test_the_header_back_button_behaves_like_back() -> void:
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	var back_button: Button = screen.find_child("BackButton", true, false) as Button
	back_button.pressed.emit()
	assert_int(screen.state()).is_equal(QuizScreen.State.LIST)
	back_button.pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


## 保存に失敗しても正誤と解説を出し、次へ進める（通知は MainShell。screen-09-quiz.md「画面イベント」）
func test_a_failed_save_still_shows_the_result() -> void:
	var blocked: String = create_temp_dir("quiz_screen/blocked_%d" % _test_count).path_join("not_a_dir")
	var file: FileAccess = FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	ScreenTestHelper.use_user_data_in(blocked)
	var failures: Array[int] = []
	var on_error: Callable = func(kind: AppScreens.StorageErrorKind) -> void: failures.append(kind)
	App.storage_error.connect(on_error)
	var screen: QuizScreen = _open()
	screen.goal_cards()[0].pressed.emit()
	screen.choice_buttons()[0].pressed.emit()
	screen.action_button().pressed.emit()
	App.storage_error.disconnect(on_error)
	assert_int(screen.state()).is_equal(QuizScreen.State.ANSWERED)
	assert_bool(screen.feedback_visible()).is_true()
	assert_array(failures).is_equal([AppScreens.StorageErrorKind.USER_DATA_SAVE] as Array[int])
	screen.action_button().pressed.emit()
	assert_str(screen.header_title()).is_equal("LG-1　2／%d" % _goal_questions("LG-1").size())


func test_opening_again_does_not_duplicate_cards() -> void:
	var screen: QuizScreen = _open()
	screen.enter({})
	assert_int(screen.goal_cards().size()).is_equal(4)


func test_the_quiz_screen_is_registered() -> void:
	assert_bool(MainShell.has_screen(AppScreens.Id.S09_QUIZ)).is_true()

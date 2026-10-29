## S-08 チュートリアル（screen-08-tutorial.md）のテスト。App.user_data を一時ディレクトリへ保存するサービスに差し替える
## （完了フラグを開発用の PC の設定に書かないため）。段階は同梱の tutorial.json を使い、画面の操作（手のボタン・エリア・次へ）で進める。
extends GdUnitTestSuite

const TUTORIAL_SCENE: String = "res://ui/screens/s08_tutorial/tutorial_screen.tscn"

var _original_user_data: UserDataService
var _requested: Array[int] = []
var _test_count: int = 0


func before_test() -> void:
	_test_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("tutorial_screen/user_%d" % _test_count))
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


func _open() -> TutorialScreen:
	var screen: TutorialScreen = auto_free((load(TUTORIAL_SCENE) as PackedScene).instantiate() as TutorialScreen) \
			as TutorialScreen
	add_child(screen)
	screen.size = Vector2(1280, 720)
	screen.enter({})
	return screen


func _steps() -> Array[TutorialStepDef]:
	return App.library.tutorial_steps()


## 今の段階（OPERATE）の選べる手の最初を、画面の操作で選んで決定する
func _play_current_step(screen: TutorialScreen) -> void:
	var step: TutorialStepDef = _steps()[screen.step_index()]
	var panel: MatchBoardPanel = screen.board_panel()
	var action: int = _allowed_actions(step)[0]
	panel.choice_panel().button_for(action).pressed.emit()
	if panel.state() == MatchBoardPanel.State.SELECT_TARGET:
		panel.board().area_pressed.emit(panel.board().selectable_areas()[0])
	panel.primary_button().pressed.emit()


func _allowed_actions(step: TutorialStepDef) -> Array[int]:
	var family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind, step.possession == GameEnums.TeamSide.HOME)
	var actions: Array[int] = []
	for action_name: String in step.allowed_actions:
		actions.append(TurnChoice.ACTION_ENUMS[family][action_name] as int)
	return actions


## 「次へ」を押せるところまで進めて押す（OPERATE は手を決定してから）
func _advance(screen: TutorialScreen) -> void:
	if _steps()[screen.step_index()].kind == TutorialStepDef.Kind.OPERATE:
		_play_current_step(screen)
	screen.next_button().pressed.emit()


func test_the_first_step_explains_the_pitch_without_choices() -> void:
	var screen: TutorialScreen = _open()
	var first: TutorialStepDef = _steps()[0]
	assert_str(screen.title_text()).is_equal("チュートリアル 1／%d" % _steps().size())
	assert_str(screen.coach_text()).is_equal(first.text)
	assert_bool(screen.can_next()).is_true()
	assert_bool(screen.next_button().visible).is_true()
	assert_bool(screen.board_panel().choice_panel().visible).is_false()
	assert_bool(screen.board_panel().primary_button().visible).is_false()
	assert_str(screen.phase_text()).is_not_empty()


## OPERATE: 段階で絞った手だけが選べ、決定して判定理由が出たら「次へ」が出る（パネルの主ボタンは出ない）
func test_an_operate_step_allows_only_its_actions_and_shows_next_after_the_result() -> void:
	var screen: TutorialScreen = _open()
	while _steps()[screen.step_index()].kind != TutorialStepDef.Kind.OPERATE:
		screen.next_button().pressed.emit()
	var step: TutorialStepDef = _steps()[screen.step_index()]
	assert_bool(screen.can_next()).is_false()
	assert_bool(screen.next_button().visible).is_false()
	# 判定理由が出る前は、「次へ」を押しても進まない
	var index_before: int = screen.step_index()
	screen.next_button().pressed.emit()
	assert_int(screen.step_index()).is_equal(index_before)
	var panel: MatchBoardPanel = screen.board_panel()
	var allowed: Array[int] = _allowed_actions(step)
	for action: int in range(panel.choice_panel().button_count()):
		assert_bool(panel.choice_panel().button_for(action).disabled) \
				.override_failure_message("%s の手 %d" % [step.id, action]).is_equal(not allowed.has(action))
	_play_current_step(screen)
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.SHOW_RESULT)
	assert_bool(panel.primary_button().visible).is_false()
	assert_bool(screen.can_next()).is_true()
	assert_bool(screen.next_button().visible).is_true()
	assert_str(screen.reveal_text()).starts_with("あなた: ")
	# 判定理由を読めるよう、説明の吹き出しは畳む。次の段階でまた出す
	assert_str(screen.coach_text()).is_empty()
	screen.next_button().pressed.emit()
	assert_int(screen.step_index()).is_equal(_steps().find(step) + 1)
	assert_str(screen.coach_text()).is_equal(_steps()[screen.step_index()].text)


## 最後まで進むと単純化の一覧が出て、「完了」で完了フラグを保存してタイトルへ
func test_the_last_step_shows_the_scope_and_complete_saves_the_flag() -> void:
	var screen: TutorialScreen = _open()
	while screen.step_index() < _steps().size() - 1:
		_advance(screen)
	assert_bool(screen.is_scope_shown()).is_true()
	assert_str(screen.title_text()).is_equal("チュートリアル %d／%d" % [_steps().size(), _steps().size()])
	assert_int(screen.scope_list().card_texts().size()).is_equal(App.library.simplifications().size())
	var first: SimplificationDef = App.library.simplifications()[0]
	assert_array(screen.scope_list().card_texts()[0]).is_equal([first.name, SimplificationList.IN_GAME_PREFIX + first.in_game,
			SimplificationList.IN_REAL_PREFIX + first.in_real])
	assert_bool(App.user_data.settings().tutorial_completed).is_false()
	screen.complete_button().pressed.emit()
	assert_bool(App.user_data.settings().tutorial_completed).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


## 「やめる」・戻る操作は確かめてからタイトルへ。「続ける」なら続ける。完了フラグは変えない
func test_quitting_asks_first_and_keeps_the_tutorial_unfinished() -> void:
	var screen: TutorialScreen = _open()
	screen.next_button().pressed.emit()
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.confirm_dialog().is_open()).is_true()
	assert_str(screen.confirm_dialog().message()).is_equal(TutorialScreen.QUIT_MESSAGE)
	assert_bool(screen.handle_back()).is_true()
	assert_bool(screen.confirm_dialog().is_open()).is_false()
	assert_int(screen.step_index()).is_equal(1)
	assert_array(_requested).is_empty()
	screen.handle_back()
	screen.confirm_dialog().ok_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_bool(App.user_data.settings().tutorial_completed).is_false()


## 同じ画面で enter がもう一度呼ばれても、作り直さない（パネルのつながる先と食い違わないため）
func test_a_second_enter_keeps_the_current_step() -> void:
	var screen: TutorialScreen = _open()
	screen.next_button().pressed.emit()
	screen.enter({})
	assert_int(screen.step_index()).is_equal(1)
	assert_str(screen.coach_text()).is_equal(_steps()[1].text)


## 段階が無い（静的データの誤り）ときは、一覧だけを出し、「完了」でも完了にしない
func test_without_steps_complete_does_not_mark_the_tutorial_done() -> void:
	var original_library: LibraryService = App.library
	App.library = LibraryService.new(ContentCatalog.new())
	var screen: TutorialScreen = auto_free((load(TUTORIAL_SCENE) as PackedScene).instantiate() as TutorialScreen) \
			as TutorialScreen
	add_child(screen)
	await assert_error(func() -> void: screen.enter({})).is_push_error("TutorialScreen: 段階が無い")
	assert_bool(screen.is_scope_shown()).is_true()
	screen.complete_button().pressed.emit()
	App.library = original_library
	assert_bool(App.user_data.settings().tutorial_completed).is_false()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])


## チュートリアルを通しても、本番の試合（App.match_controller）は始まらない
func test_the_tutorial_leaves_the_real_match_alone() -> void:
	var original: MatchController = App.match_controller
	var screen: TutorialScreen = _open()
	while screen.step_index() < _steps().size() - 1:
		_advance(screen)
	assert_object(App.match_controller).is_same(original)
	assert_bool(App.match_controller.is_match_started()).is_false()

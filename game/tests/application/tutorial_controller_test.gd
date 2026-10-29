## チュートリアル用の MatchController（App.new_tutorial_controller・start_tutorial_step・ScriptedOpponent）と
## LibraryService の単純化・段階のテスト（component-design.md §3.1〜3.4・UC-06）。
## App はスクリプトから新しく作り、保存先を一時ディレクトリにする（本番のオートロードの状態と、開発用の PC の保存データに触れない）。
extends GdUnitTestSuite

const APP_SCRIPT: String = "res://application/app.gd"

var _app: Node
var _save_dir: String
var _requests: Array[int] = []
var _test_count: int = 0


func before_test() -> void:
	_test_count += 1
	_requests.clear()
	_app = auto_free((load(APP_SCRIPT) as GDScript).new() as Node) as Node
	_save_dir = create_temp_dir("tutorial_controller/save_%d" % _test_count)
	_app.set("save_dir", _save_dir)
	add_child(_app)
	_app.connect("screen_requested", func(screen: AppScreens.Id, _params: Dictionary) -> void: _requests.append(screen))


func _controller() -> MatchController:
	return _app.call("new_tutorial_controller") as MatchController


func _steps() -> Array[TutorialStepDef]:
	return (_app.get("library") as LibraryService).tutorial_steps()


func _step(kind: TutorialStepDef.Kind, step_id: String = "") -> TutorialStepDef:
	for step: TutorialStepDef in _steps():
		if step.kind == kind and (step_id.is_empty() or step.id == step_id):
			return step
	return null


## 選べる手（段階で絞った手）の最初の手と、その運ぶ先の最初
func _first_allowed_choice(controller: MatchController, step: TutorialStepDef) -> TurnChoice:
	var options: MoveOptions = controller.user_options()
	var family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind, step.possession == GameEnums.TeamSide.HOME)
	var action: int = TurnChoice.ACTION_ENUMS[family][step.allowed_actions[0]]
	if MoveOptions.needs_target(family, action):
		return TurnChoice.new(family, action, options.targets(family, action)[0])
	return TurnChoice.new(family, action)


func test_the_library_returns_the_steps_and_the_simplifications() -> void:
	var library: LibraryService = _app.get("library") as LibraryService
	assert_int(library.tutorial_steps().size()).is_greater(1)
	assert_int(library.simplifications().size()).is_greater(0)
	library.tutorial_steps().clear()
	assert_int(library.tutorial_steps().size()).is_greater(1)


func test_a_step_builds_its_board_and_the_opponent_plays_the_script() -> void:
	var controller: MatchController = _controller()
	var step: TutorialStepDef = _step(TutorialStepDef.Kind.OPERATE)
	assert_bool(controller.start_tutorial_step(step)).is_true()
	assert_bool(controller.is_match_started()).is_true()
	assert_str(controller.snapshot().ball_area).is_equal(ViewConverter.to_user(step.ball_area, step.possession).to_key())
	var revealed: Array[RevealView] = []
	controller.turn_resolved.connect(func(reveal: RevealView, _snapshot: BoardSnapshot) -> void: revealed.append(reveal))
	assert_bool(controller.submit_turn(_first_allowed_choice(controller, step))).is_true()
	assert_int(revealed.size()).is_equal(1)
	var opponent_choice: TurnChoice = ViewConverter.choice_to_user(step.opponent_choice, step.possession)
	assert_int(revealed[0].opponent_choice.action).is_equal(opponent_choice.action)


## チュートリアルでは中断データ・戦績を保存せず、画面の切り替えも頼まない（本番の試合の状態にも触れない）
func test_the_tutorial_saves_nothing_and_requests_no_screen() -> void:
	var controller: MatchController = _controller()
	for step: TutorialStepDef in _steps():
		if step.kind != TutorialStepDef.Kind.OPERATE:
			continue
		controller.start_tutorial_step(step)
		controller.submit_turn(_first_allowed_choice(controller, step))
		controller.continue_after_reveal()
	assert_array(_requests).is_empty()
	assert_bool(FileAccess.file_exists(_save_dir.path_join(SuspendedMatchStore.FILE_NAME))).is_false()
	assert_bool(FileAccess.file_exists(_save_dir.path_join(RecordStore.FILE_NAME))).is_false()
	assert_bool((_app.get("match_controller") as MatchController).is_match_started()).is_false()


## 次の段階は、前の段階の開示を確認しなくても作り直せる（チュートリアルは continue_after_reveal を呼ばない）
func test_the_next_step_replaces_the_board_even_while_a_reveal_is_pending() -> void:
	var controller: MatchController = _controller()
	var operate: TutorialStepDef = _step(TutorialStepDef.Kind.OPERATE)
	controller.start_tutorial_step(operate)
	controller.submit_turn(_first_allowed_choice(controller, operate))
	var next: TutorialStepDef = _step(TutorialStepDef.Kind.OPERATE, "shot")
	assert_bool(controller.start_tutorial_step(next)).is_true()
	assert_bool(controller.submit_turn(_first_allowed_choice(controller, next))).is_true()
	assert_int(controller.state().turn_records.size()).is_equal(1)


func test_a_step_without_a_board_is_refused() -> void:
	var controller: MatchController = _controller()
	var scope: TutorialStepDef = _step(TutorialStepDef.Kind.SCOPE)
	await assert_error(func() -> void: controller.start_tutorial_step(scope)) \
			.is_push_error("MatchController: 盤面の無い段階は始められない: %s" % scope.id)
	assert_bool(controller.is_match_started()).is_false()


func test_each_tutorial_controller_is_a_new_instance() -> void:
	var first: MatchController = _controller()
	var second: MatchController = _controller()
	assert_bool(first == second).is_false()
	assert_bool(first == _app.get("match_controller")).is_false()

## MatchBoardPanel（試合画面の盤面と手の選択。screen-03-match.md の状態と手順）のテスト。
## 本物の MatchController（固定シード・本物の CpuOpponent）につなぐ。3D 演出は今回の範囲外なので、開示の後すぐ判定理由を出す。
extends GdUnitTestSuite

const State := MatchBoardPanel.State

var _catalog: ContentCatalog
var _panel: MatchBoardPanel
var _controller: MatchController
var _requests: Array[int] = []


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func before_test() -> void:
	_requests.clear()
	_controller = null
	_panel = auto_free(MatchBoardPanel.new()) as MatchBoardPanel
	add_child(_panel)
	_panel.size = Vector2(1232, 576)


func _record(screen: AppScreens.Id, _params: Dictionary = {}) -> void:
	_requests.append(screen)


## 前半のキックオフで利用者がボールを持つ（user_has_ball）試合を作り、パネルにつないで最初のターンを始める
func _start(user_has_ball: bool) -> void:
	for seed_value: int in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var config := ConfigRepository.new()
		var controller := MatchController.new(_catalog, config, rng, CpuOpponent.new(_catalog, config.cpu(), rng),
				_record, true)
		controller.start_match(TeamSetup.new("4-4-2",
				TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)))
		if controller.snapshot().user_has_ball == user_has_ball:
			_controller = controller
			break
	assert_object(_controller).override_failure_message("条件に合うシードが無い").is_not_null()
	_requests.clear()
	_panel.bind(_controller)
	_panel.start_turn()


func _keys(areas: Array[PitchArea]) -> Array[String]:
	var keys: Array[String] = []
	for area: PitchArea in areas:
		keys.append(area.to_key())
	return keys


## 運ぶ先を持つ手のうち、選べる最初の手
func _first_targeted_action(family: GameEnums.ChoiceFamily) -> int:
	var options: MoveOptions = _controller.user_options()
	for action: int in range((MatchTexts.ACTION_NAMES[family] as Array).size()):
		if MoveOptions.needs_target(family, action) and options.is_available(family, action):
			return action
	return -1


func _press(action: int) -> void:
	_panel.choice_panel().button_for(action).pressed.emit()


func test_a_turn_starts_with_nothing_selected() -> void:
	_start(true)
	assert_int(_panel.state()).is_equal(State.SELECT_ACTION)
	assert_bool(_panel.primary_button().disabled).is_true()
	assert_int(_panel.choice_panel().family()).is_equal(GameEnums.ChoiceFamily.ATTACK)
	assert_array(_panel.board().selectable_areas()).is_empty()
	assert_bool(_panel.telop_visible()).is_false()
	var snapshot: BoardSnapshot = _controller.snapshot()
	assert_array(_panel.setup_texts()).is_equal([
		"● 自分 %s" % MatchTexts.setup_text(snapshot.user_setup),
		"◆ CPU %s" % MatchTexts.setup_text(snapshot.opponent_setup)])


func test_a_move_with_targets_waits_for_an_area_and_shows_hints() -> void:
	_start(true)
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.ATTACK)
	_press(action)
	assert_int(_panel.state()).is_equal(State.SELECT_TARGET)
	assert_bool(_panel.primary_button().disabled).is_true()
	var targets: Array[String] = _keys(_controller.user_options().targets(GameEnums.ChoiceFamily.ATTACK, action))
	assert_array(_panel.board().selectable_areas()).is_equal(targets)
	# 選べる各エリアにヒントの札（FR-19）。値は MatchController のヒントと同じ
	var checked: int = 0
	for hint: ChoiceHint in _controller.user_hints():
		if hint.family == GameEnums.ChoiceFamily.ATTACK and hint.action == action:
			assert_str(_panel.board().hint_of(hint.target.to_key())).is_equal(MatchTexts.hint_tag(hint))
			# 差が ±0 の札は控えめに描く。区別は札の文字ではなく、ヒントの人数差で渡す
			assert_bool(_panel.board().is_hint_even(hint.target.to_key())) \
					.override_failure_message(hint.target.to_key()).is_equal(hint.diff() == 0)
			checked += 1
	# 選べる各エリアに札がある（ヒントが1件も無くて空振りしない）
	assert_int(checked).is_equal(targets.size())


func test_choosing_a_selectable_area_makes_the_choice_ready() -> void:
	_start(true)
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.ATTACK)
	_press(action)
	var target: String = _panel.board().selectable_areas()[0]
	_panel.board().area_pressed.emit(target)
	assert_int(_panel.state()).is_equal(State.READY)
	assert_bool(_panel.primary_button().disabled).is_false()
	assert_str(_panel.board().selected_area()).is_equal(target)
	assert_bool(_panel.board().has_intent()).is_true()
	assert_str(_panel.primary_summary()).is_equal("%s → %s" % [
		MatchTexts.action_name(GameEnums.ChoiceFamily.ATTACK, action), MatchTexts.area_name(target)])
	assert_str(_panel.target_info_text()).starts_with(MatchTexts.area_name(target))


func test_an_area_that_is_not_selectable_is_ignored() -> void:
	_start(true)
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	var not_selectable: String = ""
	for area: PitchArea in PitchArea.all():
		if not _panel.board().selectable_areas().has(area.to_key()):
			not_selectable = area.to_key()
			break
	_panel.board().area_pressed.emit(not_selectable)
	assert_int(_panel.state()).is_equal(State.SELECT_TARGET)
	assert_str(_panel.board().selected_area()).is_empty()


func test_submitting_shows_the_result_and_the_reason() -> void:
	_start(true)
	var shown: Array = []
	_panel.reveal_started.connect(func(reveal: RevealView) -> void: shown.append(reveal))
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	_panel.primary_button().pressed.emit()
	assert_int(_controller.state().turn_records.size()).is_equal(1)
	assert_int(_panel.state()).is_equal(State.SHOW_RESULT)
	var reveal: RevealView = _controller.last_reveal()
	assert_array(shown).is_equal([reveal])
	assert_bool(_panel.telop_visible()).is_true()
	assert_bool(_panel.choice_panel().visible).is_false()
	assert_str(_panel.outcome_text()).is_equal(MatchTexts.outcome_label(reveal.outcome))
	assert_str(_panel.reason_text()).is_equal(JudgeReasonFormatter.format(reveal))
	assert_str(_panel.detail_text()).is_equal(JudgeReasonFormatter.detail(reveal))
	if reveal.has_detail:
		assert_str(_panel.board().compare_tag()).is_equal("%d対%d" % [reveal.user_count, reveal.opponent_count])
	assert_int(_panel.board().movement_count()).is_equal(reveal.movements.size())
	assert_str(_panel.primary_summary()).is_equal("次のターンへ")


func test_next_is_sent_only_once() -> void:
	_start(true)
	var leaves: Array[int] = [0]
	_panel.turn_ready_to_leave.connect(func() -> void: leaves[0] += 1)
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	assert_int(leaves[0]).is_equal(1)
	assert_int(_panel.state()).is_equal(State.LEAVING)
	# LEAVING では手もエリアも受け付けない
	_press(0)
	_panel.board().area_pressed.emit("M-C")
	assert_int(_panel.state()).is_equal(State.LEAVING)
	assert_int(_controller.state().turn_records.size()).is_equal(1)


func test_the_next_turn_starts_clean() -> void:
	_start(true)
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	_controller.continue_after_reveal()
	_panel.start_turn()
	assert_int(_panel.state()).is_equal(State.SELECT_ACTION)
	assert_str(_panel.board().selected_area()).is_empty()
	assert_array(_panel.board().selectable_areas()).is_empty()
	assert_int(_panel.board().movement_count()).is_equal(0)
	assert_str(_panel.board().compare_tag()).is_empty()
	assert_bool(_panel.board().has_intent()).is_false()
	assert_bool(_panel.telop_visible()).is_false()
	assert_bool(_panel.choice_panel().visible).is_true()
	assert_str(_panel.primary_summary()).is_empty()


func test_the_user_defends_with_the_board_in_the_user_view() -> void:
	_start(false)
	assert_int(_panel.choice_panel().family()).is_equal(GameEnums.ChoiceFamily.DEFENSE)
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.DEFENSE)
	_press(action)
	# 選べるエリアは利用者の視点のまま（UI では変換しない）
	assert_array(_panel.board().selectable_areas()).is_equal(
			_keys(_controller.user_options().targets(GameEnums.ChoiceFamily.DEFENSE, action)))
	assert_str(_panel.board().ball_area()).is_equal(_controller.snapshot().ball_area)


func test_a_disabled_move_cannot_be_chosen() -> void:
	_start(true)
	# キックオフ（中盤・中央）ではシュートを選べない
	var shot: Button = _panel.choice_panel().button_for(GameEnums.PlayType.SHOT)
	assert_bool(shot.disabled).is_true()


func test_unbind_stops_receiving_results() -> void:
	_start(true)
	_panel.unbind()
	assert_bool(_controller.turn_resolved.is_connected(_panel._on_turn_resolved)).is_false()
	assert_int(_panel.state()).is_equal(State.IDLE)

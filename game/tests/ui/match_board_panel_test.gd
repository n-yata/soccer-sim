## MatchBoardPanel（試合画面の盤面と手の選択。screen-03-match.md の状態と手順）のテスト。
## 本物の MatchController（固定シード・本物の CpuOpponent）につなぐ。開示の後すぐ判定理由を出す（駒とボールは盤面の上で動く。3D 演出は 2026-10-23 にやめた）。
extends GdUnitTestSuite

const State := MatchBoardPanel.State
## 失ったトランジションに数ターンで届くシード（_start_in_a_lost_transition が最初に試す）
const LOST_TRANSITION_SEED: int = 67

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
	assert_str(_panel.outcome_text()).is_equal(MatchTexts.outcome_tag(reveal))
	# 結果の札は、成功した側の色（自分は水色、相手はオレンジ。駒と同じ）。判定なしは元の札
	var expected_variation: Dictionary = {MatchTexts.TurnWinner.USER: "YouOutcomeTagLabel",
			MatchTexts.TurnWinner.OPPONENT: "OpponentOutcomeTagLabel", MatchTexts.TurnWinner.NONE: "OutcomeTagLabel"}
	assert_str(_panel.outcome_variation()).is_equal(expected_variation[MatchTexts.turn_winner(reveal)] as String)
	assert_str(_panel.reason_text()).is_equal(JudgeReasonFormatter.format(reveal))
	assert_str(_panel.detail_text()).is_equal(JudgeReasonFormatter.detail(reveal))
	if reveal.has_detail:
		assert_str(_panel.board().compare_tag()).is_equal("%d対%d" % [reveal.user_count, reveal.opponent_count])
	assert_int(_panel.board().movement_count()).is_equal(reveal.movements.size())
	assert_str(_panel.primary_summary()).is_equal("次のターンへ")


func test_the_outcome_tag_color_follows_the_side_that_succeeded() -> void:
	assert_str(MatchBoardPanel.outcome_variation_for(MatchTexts.TurnWinner.USER)).is_equal("YouOutcomeTagLabel")
	assert_str(MatchBoardPanel.outcome_variation_for(MatchTexts.TurnWinner.OPPONENT)).is_equal("OpponentOutcomeTagLabel")
	assert_str(MatchBoardPanel.outcome_variation_for(MatchTexts.TurnWinner.NONE)).is_equal("OutcomeTagLabel")
	# 地はチームの色（駒と同じ。TacticsBoard の you・opponent）で、2つは違う色。文字は元の札の暗い色を受け継ぐ
	var you: StyleBoxFlat = _panel.get_theme_stylebox("normal", &"YouOutcomeTagLabel") as StyleBoxFlat
	var opponent: StyleBoxFlat = _panel.get_theme_stylebox("normal", &"OpponentOutcomeTagLabel") as StyleBoxFlat
	assert_object(you).is_not_null()
	assert_object(opponent).is_not_null()
	assert_bool(you.bg_color.is_equal_approx(_panel.get_theme_color(&"you", TacticsBoard.THEME_TYPE))).is_true()
	assert_bool(opponent.bg_color.is_equal_approx(_panel.get_theme_color(&"opponent", TacticsBoard.THEME_TYPE))).is_true()
	assert_bool(you.bg_color.is_equal_approx(opponent.bg_color)).is_false()
	# 札に付けたときの文字の色と大きさは、元の札（OutcomeTagLabel）から受け継ぐ（Label に付けて、種類の継承を通して確かめる）
	var base: Label = _tag_label(&"OutcomeTagLabel")
	for variation: StringName in [&"YouOutcomeTagLabel", &"OpponentOutcomeTagLabel"]:
		var label: Label = _tag_label(variation)
		assert_bool(label.get_theme_color(&"font_color").is_equal_approx(base.get_theme_color(&"font_color"))) \
				.override_failure_message(variation).is_true()
		assert_int(label.get_theme_font_size(&"font_size")).is_equal(base.get_theme_font_size(&"font_size"))


func _tag_label(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	_panel.add_child(label)
	return label


func test_next_is_sent_only_once() -> void:
	_start(true)
	var leaves: Array[int] = [0]
	_panel.turn_ready_to_leave.connect(func() -> void: leaves[0] += 1)
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	# このターンに選べたエリア（有効なキー）。LEAVING で押しても受け付けないことを、無効なキーでなく確かめる
	var chosen: String = _panel.board().selectable_areas()[0]
	_panel.board().area_pressed.emit(chosen)
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	assert_int(leaves[0]).is_equal(1)
	assert_int(_panel.state()).is_equal(State.LEAVING)
	# LEAVING では手もエリアも受け付けない
	_press(0)
	_panel.board().area_pressed.emit(chosen)
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
	assert_array(_panel.board().preview_movements()).is_empty()
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
	# キックオフ（中盤（自陣）・中央）ではシュートを選べない
	var shot: Button = _panel.choice_panel().button_for(GameEnums.PlayType.SHOT)
	assert_bool(shot.disabled).is_true()


func test_unbind_stops_receiving_results() -> void:
	_start(true)
	_panel.unbind()
	assert_bool(_controller.turn_resolved.is_connected(_panel._on_turn_resolved)).is_false()
	assert_int(_panel.state()).is_equal(State.IDLE)


# --- 決定前のプレビュー ---

func _keys_of(movements: Array[Movement]) -> Array[String]:
	var keys: Array[String] = []
	for movement: Movement in movements:
		keys.append("%s %s>%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key()])
	return keys


func test_a_defensive_area_previews_the_movers_without_the_ball_arrow() -> void:
	_start(false)
	var action: int = GameEnums.DefenseAction.PRESS
	_press(action)
	var target: String = _panel.board().selectable_areas()[0]
	_panel.board().area_pressed.emit(target)
	var expected: Array[Movement] = _controller.user_preview(
			TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, action, PitchArea.from_key(target)))
	# プレスは必ず1人が寄せる（空振りしない）
	assert_int(expected.size()).is_greater_equal(1)
	assert_array(_keys_of(_panel.board().preview_movements())).is_equal(_keys_of(expected))
	# 守備の手では、ボールから選んだエリアへの矢印を出さない
	assert_bool(_panel.board().has_intent()).is_false()


func test_an_attacking_area_keeps_the_ball_arrow_and_previews_the_dribbler() -> void:
	_start(true)
	var action: int = GameEnums.PlayType.DRIBBLE
	_press(action)
	var target: String = _panel.board().selectable_areas()[0]
	_panel.board().area_pressed.emit(target)
	var expected: Array[Movement] = _controller.user_preview(
			TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, action, PitchArea.from_key(target)))
	# ボールのエリアには必ず保持者がいるので、ドリブルは1人が運ぶ
	assert_int(expected.size()).is_equal(1)
	assert_array(_keys_of(_panel.board().preview_movements())).is_equal(_keys_of(expected))
	assert_bool(_panel.board().has_intent()).is_true()


func test_choosing_another_move_or_submitting_clears_the_preview() -> void:
	_start(false)
	_press(GameEnums.DefenseAction.PRESS)
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	assert_array(_panel.board().preview_movements()).is_not_empty()
	_press(GameEnums.DefenseAction.COVER)
	assert_array(_panel.board().preview_movements()).is_empty()
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	_panel.primary_button().pressed.emit()
	assert_int(_panel.state()).is_equal(State.SHOW_RESULT)
	assert_array(_panel.board().preview_movements()).is_empty()


func test_through_pass_tags_are_never_muted_by_the_hidden_numbers() -> void:
	# スルーパスの札は「読み次第」か、マーカーがついてくる運ぶ先の「マーク注意」（2026-10-28）。人数を比べない手なので、
	# 隠れた人数差が ±0 でも控えめな色にしない（色から人数差を漏らさない）
	_start(true)
	var even_through: int = 0
	var expected: Dictionary = {}
	for hint: ChoiceHint in _controller.user_hints():
		if hint.action == GameEnums.PlayType.THROUGH_PASS and hint.family == GameEnums.ChoiceFamily.ATTACK:
			expected[hint.target.to_key()] = "マーク注意" if hint.is_marked else "読み次第"
			if hint.diff() == 0:
				even_through += 1
	assert_int(even_through).override_failure_message("人数差が ±0 のスルーパスの運ぶ先がある場面であること").is_greater(0)
	_press(GameEnums.PlayType.THROUGH_PASS)
	for key: String in _panel.board().selectable_areas():
		assert_str(_panel.board().hint_of(key)).override_failure_message(key).is_equal(expected[key])
		assert_bool(_panel.board().is_hint_even(key)).override_failure_message(key).is_false()


func test_through_pass_explains_its_rule() -> void:
	# スルーパス（2026-10-25）を選ぶと、出せる先と判定の規則を説明に出す（スクロールは match_screens_test で画面の実寸で確かめる）
	_start(true)
	assert_bool(_controller.user_options().is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.THROUGH_PASS)) \
			.override_failure_message("キックオフでスルーパスを選べる場面であること").is_true()
	_press(GameEnums.PlayType.THROUGH_PASS)
	assert_str(_panel.target_info_text()).is_equal(MatchTexts.target_rule(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.THROUGH_PASS))


func test_press_and_cover_explain_which_areas_can_be_chosen() -> void:
	_start(false)
	for action: int in [GameEnums.DefenseAction.PRESS, GameEnums.DefenseAction.COVER]:
		_press(action)
		assert_str(_panel.target_info_text()).is_equal(MatchTexts.target_rule(GameEnums.ChoiceFamily.DEFENSE, action))
	# エリアを選ぶと、そのエリアの説明に置き換わる
	var target: String = _panel.board().selectable_areas()[0]
	_panel.board().area_pressed.emit(target)
	assert_str(_panel.target_info_text()).starts_with(MatchTexts.area_name(target))


## 利用者が喪失側のトランジションで、リトリートで誰かが動く場面まで、両者に選べる手の先頭を選ばせて進める
func _start_in_a_lost_transition() -> void:
	# 0 から探すと条件に合うまで数十試合を回す（約10秒）ので、2026-11-03 に見つかったシードから試す。
	# 規則や CPU が変わってそのシードで合わなくなっても、続けて 0 から探す
	for seed_value: int in [LOST_TRANSITION_SEED] + range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var config := ConfigRepository.new()
		var controller := MatchController.new(_catalog, config, rng, CpuOpponent.new(_catalog, config.cpu(), rng),
				_record, true)
		controller.start_match(TeamSetup.new("4-4-2",
				TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)))
		for _turn: int in range(8):
			if controller.stage() != GameEnums.MatchStage.TURN:
				break
			var snapshot: BoardSnapshot = controller.snapshot()
			var retreat := TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
			if snapshot.turn_kind == GameEnums.TurnKind.TRANSITION and not snapshot.user_has_ball \
					and not controller.user_preview(retreat).is_empty():
				_controller = controller
				break
			controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
			controller.continue_after_reveal()
		if _controller != null:
			break
	assert_object(_controller).override_failure_message("条件に合うシードが無い").is_not_null()
	_requests.clear()
	_panel.bind(_controller)
	_panel.start_turn()


func test_a_move_without_a_target_previews_as_soon_as_it_is_chosen() -> void:
	_start_in_a_lost_transition()
	_press(GameEnums.NegTransAction.RETREAT)
	assert_int(_panel.state()).is_equal(State.READY)
	var expected: Array[Movement] = _controller.user_preview(
			TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT))
	assert_array(expected).is_not_empty()
	assert_array(_keys_of(_panel.board().preview_movements())).is_equal(_keys_of(expected))
	assert_bool(_panel.board().has_intent()).is_false()


# --- 開示で駒を動かす ---

## before と after で、エリアが変わった選手の ID
func _moved_ids(before: Array[Dictionary], after: Array[Dictionary]) -> Array[String]:
	var before_areas: Dictionary = {}
	for player: Dictionary in before:
		before_areas[player["player_id"]] = player["area"]
	var moved: Array[String] = []
	for player: Dictionary in after:
		if before_areas.has(player["player_id"]) and before_areas[player["player_id"]] != player["area"]:
			moved.append(player["player_id"] as String)
	return moved


func _path_ids(paths: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for path: Dictionary in paths:
		ids.append(path["player_id"] as String)
	return ids


func test_binding_gives_the_board_the_ball_style_from_the_settings() -> void:
	# bind で設定の軌道の値を盤面に入れる。入れないと、浮き球が高さ 0 のまま静かに動く
	_start(true)
	var board: TacticsBoard = _panel.board()
	var snapshot: BoardSnapshot = _controller.snapshot()
	var ball_area: String = snapshot.ball_area
	var from_key: String = "D1-C" if ball_area != "D1-C" else "D2-C"
	board.start_shift([{"user": snapshot.user_players, "opponent": snapshot.opponent_players, "ball": from_key,
			"sec": 1.0, "flight": BallFlight.Kind.LOFTED}])
	await await_millis(500)
	# 同梱の浮き球の高さ（半径の6倍）の弧の途中。値が入っていなければ 0
	assert_float(board.ball_lift()).is_greater(1.0)
	assert_float(board.ball_lift()).is_less_equal(_controller.ball_style()["loft"] as float)


func test_the_reveal_shifts_the_play_then_the_reshape_and_the_next_turn_stops_it() -> void:
	_start(false)
	_press(GameEnums.DefenseAction.PRESS)
	_panel.board().area_pressed.emit(_panel.board().selectable_areas()[0])
	_panel.primary_button().pressed.emit()
	var reveal: RevealView = _controller.last_reveal()
	var snapshot: BoardSnapshot = _controller.snapshot()
	var board: TacticsBoard = _panel.board()
	# 1拍目（プレー）: 判定前 → 判定時。プレスで1人は必ず動く（空振りしない）
	var play: Array[String] = _moved_ids(reveal.user_players_before, reveal.user_players_at_judgement)
	play.append_array(_moved_ids(reveal.opponent_players_before, reveal.opponent_players_at_judgement))
	assert_array(play).is_not_empty()
	assert_array(_path_ids(board.shift_beat_paths(0))).contains(play)
	# 2拍目（詰め直し）: 判定時 → 次のターン開始時。この場面（固定シード）では、奪ったボールに合わせて組み直す選手がいる
	# （動きの無い拍を飛ばすことは tactics_board_test で確かめる）
	var reshape: Array[String] = _moved_ids(reveal.user_players_at_judgement, snapshot.user_players)
	reshape.append_array(_moved_ids(reveal.opponent_players_at_judgement, snapshot.opponent_players))
	assert_array(reshape).is_not_empty()
	assert_int(board.shift_beat_count()).is_equal(2)
	assert_array(_path_ids(board.shift_beat_paths(1))).contains(reshape)
	# エリアが変わった選手のほかに動くのは、同じエリアで列の位置だけが変わった選手で、どの道筋も位置が変わっている
	for beat: int in range(board.shift_beat_count()):
		for path: Dictionary in board.shift_beat_paths(beat):
			assert_bool((path["from"] as Vector2).is_equal_approx(path["to"] as Vector2)).is_false()
	assert_bool(board.is_shifting()).is_true()
	assert_int(board.shift_beat_index()).is_equal(0)
	# ボールは1拍目で、判定前の位置から判定後の位置へ動く（この場面ではボールの位置が変わる。空振りしない）
	assert_str(reveal.ball_before).is_not_equal(reveal.ball_after)
	var ball_path: Dictionary = board.shift_beat_ball_path(0)
	assert_str(board.plan_area_at(ball_path["from"] as Vector2)).is_equal(reveal.ball_before)
	assert_str(board.plan_area_at(ball_path["to"] as Vector2)).is_equal(reveal.ball_after)
	# 1拍目のボールの軌道は、ボールを持つ側（この場面では CPU の攻撃）の手で決まる
	assert_int(reveal.opponent_choice.family).is_equal(GameEnums.ChoiceFamily.ATTACK)
	assert_int(ball_path["flight"] as int).is_equal(BallFlight.kind_for(reveal.opponent_choice))
	_panel.primary_button().pressed.emit()
	_controller.continue_after_reveal()
	_panel.start_turn()
	assert_bool(board.is_shifting()).is_false()

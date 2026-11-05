## MatchBoardPanel（試合画面の盤面と手の選択。screen-03-match.md の状態と手順）のテスト。
## 本物の MatchController（固定シード・本物の CpuOpponent）につなぐ。開示の後すぐ判定理由を出す（駒とボールは盤面の上で動く。3D 演出は 2026-10-23 にやめた）。
extends GdUnitTestSuite

const State := MatchBoardPanel.State
## 失ったトランジションに数ターンで届くシード（_start_in_a_lost_transition が最初に試す）
const LOST_TRANSITION_SEED: int = 67

var _catalog: ContentCatalog
var _panel: MatchBoardPanel
var _controller: MatchController
## _start が使ったシード
var _controller_seed: int = 0
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


## 前半のキックオフで利用者がボールを持つ（user_has_ball）試合を作り、パネルにつないで最初のターンを始める。
## シードは first_seed から順に試す
func _start(user_has_ball: bool, first_seed: int = 0) -> void:
	for seed_value: int in range(first_seed, first_seed + 100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var config := ConfigRepository.new()
		var controller := MatchController.new(_catalog, config, rng, CpuOpponent.new(_catalog, config.cpu(), rng),
				_record, true)
		controller.start_match(TeamSetup.new("4-4-2",
				TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)))
		if controller.snapshot().user_has_ball == user_has_ball:
			_controller = controller
			_controller_seed = seed_value
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


## 運ぶ先を持つ手のうち、画面に出ている最初の手（ボタンの並び）
func _first_targeted_action(family: GameEnums.ChoiceFamily) -> int:
	var options: MoveOptions = _controller.user_options()
	for action: int in _panel.choice_panel().actions():
		if MoveOptions.needs_target(family, action) and options.is_available(family, action):
			return action
	return -1


## 画面に出す手の行き先（利用者の視点のキー）
func _target_of(family: GameEnums.ChoiceFamily, action: int) -> String:
	return _controller.user_options().targets(family, action)[0].to_key()


func _press(action: int) -> void:
	_panel.choice_panel().button_for(action).pressed.emit()


func test_a_turn_starts_with_nothing_selected() -> void:
	_start(true)
	assert_int(_panel.state()).is_equal(State.SELECT_ACTION)
	assert_bool(_panel.primary_button().disabled).is_true()
	assert_int(_panel.choice_panel().family()).is_equal(GameEnums.ChoiceFamily.ATTACK)
	assert_str(_panel.board().selected_area()).is_empty()
	assert_bool(_panel.board().has_intent()).is_false()
	assert_bool(_panel.telop_visible()).is_false()
	var snapshot: BoardSnapshot = _controller.snapshot()
	assert_array(_panel.setup_texts()).is_equal([
		"● 自分 %s" % MatchTexts.setup_text(snapshot.user_setup),
		"◆ CPU %s" % MatchTexts.setup_text(snapshot.opponent_setup)])


func test_a_turn_shows_every_own_destination_with_its_number_and_hint() -> void:
	# 自分の手の行き先は、選ぶ前に盤面にすべて出す（2026-11-03）。札は手の番号（ボタンと同じ）と、ヒントの人数差
	_start(true)
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	var expected_keys: Array[String] = []
	for action: int in _panel.choice_panel().actions():
		if MoveOptions.needs_target(family, action) and not expected_keys.has(_target_of(family, action)):
			expected_keys.append(_target_of(family, action))
	assert_array(_panel.board().selectable_areas()).is_equal(expected_keys)
	# 札の値は MatchController のヒントと同じ。行き先を持つ手の数だけ確かめる（空振りしない）
	var checked: int = 0
	var seen: Array[String] = []
	for action: int in _panel.choice_panel().actions():
		# 同じ行き先の2つ目以降の手は、先の手（ボタンの並び）の札に番号を並べるだけなので、先の手で確かめる
		if not MoveOptions.needs_target(family, action) or seen.has(_target_of(family, action)):
			continue
		var key: String = _target_of(family, action)
		seen.append(key)
		var hint: ChoiceHint = null
		for candidate: ChoiceHint in _controller.user_hints():
			if candidate.action == action and candidate.target != null and candidate.target.to_key() == key:
				hint = candidate
		var number: String = _panel.choice_panel().number_of(action)
		var tag: String = MatchTexts.hint_tag(hint)
		# 札は番号を先に（同じ行き先の手が複数あれば「①②」）、先の手のヒントを後ろに置く
		assert_str(_panel.board().hint_of(key)).starts_with(number)
		if not tag.is_empty():
			assert_str(_panel.board().hint_of(key)).ends_with(" " + tag)
		# 差が ±0 の札は控えめに描く。区別は札の文字ではなく、ヒントの人数差で渡す
		assert_bool(_panel.board().is_hint_even(key)).override_failure_message(key).is_equal(MatchTexts.is_hint_muted(hint))
		checked += 1
	assert_int(checked).is_greater(0)


func test_choosing_a_move_makes_it_ready_with_the_destination_the_game_chose() -> void:
	_start(true)
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	var action: int = _first_targeted_action(family)
	_press(action)
	var target: String = _target_of(family, action)
	assert_int(_panel.state()).is_equal(State.READY)
	assert_bool(_panel.primary_button().disabled).is_false()
	assert_str(_panel.board().selected_area()).is_equal(target)
	assert_bool(_panel.board().has_intent()).is_true()
	assert_str(_panel.primary_summary()).is_equal("%s → %s" % [MatchTexts.action_name(family, action), MatchTexts.area_name(target)])
	# 行き先は「詳細」のポップアップで見せる（2026-11-05）
	assert_bool(_panel.detail_button().disabled).is_false()
	_panel.detail_button().pressed.emit()
	assert_bool(_panel.detail_view().is_open()).is_true()
	assert_str(_panel.detail_view().text()).starts_with("行き先: %s" % MatchTexts.area_name(target))
	# 閉じても選んだ手はそのまま
	_panel.detail_view().close_button().pressed.emit()
	assert_bool(_panel.detail_view().is_open()).is_false()
	assert_int(_panel.state()).is_equal(State.READY)


func test_the_detail_shows_the_button_name_the_destination_the_numbers_and_the_rule() -> void:
	_start(true)
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	for action: int in _panel.choice_panel().actions():
		_press(action)
		_panel.detail_button().pressed.emit()
		# 見出しは押したボタンと同じ番号と名前。中身の手が違えば添える（「① ショートパス（スルーパス）」）
		var title: String = "%s %s" % [_panel.choice_panel().number_of(action), MatchTexts.slot_name(family, action)]
		if MatchTexts.action_name(family, action) != MatchTexts.slot_name(family, action):
			title = "%s（%s）" % [title, MatchTexts.action_name(family, action)]
		assert_str(_panel.detail_view().title()).is_equal(title)
		# 本文は行き先・判断材料（ヒントの札と人数。どちらも無ければ出さない）・手の説明の順で、空の行を出さない
		var lines: Array[String] = []
		if MoveOptions.needs_target(family, action):
			lines.append("行き先: %s" % MatchTexts.area_name(_target_of(family, action)))
		for hint: ChoiceHint in _controller.user_hints():
			if hint.action == action:
				var parts: Array[String] = []
				for part: String in [MatchTexts.hint_tag(hint), MatchTexts.hint_counts(hint)]:
					if not part.is_empty():
						parts.append(part)
				if not parts.is_empty():
					lines.append("判断材料: %s" % "　".join(parts))
		if not MatchTexts.target_rule(family, action).is_empty():
			lines.append(MatchTexts.target_rule(family, action))
		assert_str(_panel.detail_view().text()).override_failure_message(str(action)).is_equal("\n".join(lines))
		_panel.close_detail()


func test_turning_hints_off_with_the_detail_open_redraws_it_without_the_numbers() -> void:
	_start(true)
	_press(GameEnums.PlayType.DRIBBLE)
	_panel.detail_button().pressed.emit()
	assert_str(_panel.detail_view().text()).contains("判断材料: ")
	_panel.set_show_hints(false)
	assert_bool(_panel.detail_view().is_open()).is_true()
	assert_str(_panel.detail_view().text()).not_contains("判断材料: ")


func test_the_detail_button_works_only_while_a_move_is_chosen() -> void:
	_start(true)
	# 手を選ぶ前は押せない
	assert_bool(_panel.detail_button().disabled).is_true()
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	assert_bool(_panel.detail_button().disabled).is_false()
	# 詳細を開いたまま決定しても、判定理由を出すときに閉じて隠す
	_panel.detail_button().pressed.emit()
	assert_bool(_panel.detail_view().is_open()).is_true()
	_panel.primary_button().pressed.emit()
	assert_bool(_panel.detail_button().visible).is_false()
	assert_bool(_panel.detail_view().is_open()).is_false()
	# 次のターンでは、また選ぶまで押せない
	_panel.primary_button().pressed.emit()
	_controller.continue_after_reveal()
	_panel.start_turn()
	assert_bool(_panel.detail_button().visible).is_true()
	assert_bool(_panel.detail_button().disabled).is_true()


func test_pressing_a_destination_on_the_board_chooses_its_move() -> void:
	_start(true)
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	var actions: Array[int] = _panel.choice_panel().actions()
	# 盤面で最後のボタンの手の行き先を押すと、その行き先を持つ手（ボタンの並びで先の手）を選ぶ
	var last: int = actions[actions.size() - 1]
	var target: String = _target_of(family, last)
	var expected: int = last
	for action: int in actions:
		if MoveOptions.needs_target(family, action) and _target_of(family, action) == target:
			expected = action
			break
	_panel.board().area_pressed.emit(target)
	assert_int(_panel.state()).is_equal(State.READY)
	assert_str(_panel.board().selected_area()).is_equal(target)
	assert_bool(_panel.choice_panel().button_for(expected).button_pressed).is_true()


func test_an_area_that_is_not_selectable_is_ignored() -> void:
	_start(true)
	var not_selectable: String = ""
	for area: PitchArea in PitchArea.all():
		if not _panel.board().selectable_areas().has(area.to_key()):
			not_selectable = area.to_key()
			break
	_panel.board().area_pressed.emit(not_selectable)
	assert_int(_panel.state()).is_equal(State.SELECT_ACTION)
	assert_str(_panel.board().selected_area()).is_empty()


func test_submitting_shows_the_result_and_the_reason() -> void:
	_start(true)
	var shown: Array = []
	_panel.reveal_started.connect(func(reveal: RevealView) -> void: shown.append(reveal))
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	_panel.primary_button().pressed.emit()
	assert_int(_controller.state().turn_records.size()).is_equal(1)
	assert_int(_panel.state()).is_equal(State.SHOW_RESULT)
	var reveal: RevealView = _controller.last_reveal()
	assert_array(shown).is_equal([reveal])
	# 判定理由は、1拍目（ボールを運ぶプレー）が着地してから出す。「次へ」はすぐ押せる
	assert_bool(_panel.board().is_shifting()).is_true()
	assert_bool(_panel.telop_visible()).is_false()
	assert_bool(_panel.primary_button().disabled).is_false()
	await _await_landing()
	assert_bool(_panel.telop_visible()).is_true()
	# 着地で、この開示の結果の演出を盤面に出す（結果ごとの種類・場所・色は result_effect_test で固定する。ここはつなぎ込み）。
	# 盤面に印を描くのは得点・セーブ・ロスト・奪回成功・オフサイドだけ
	var marked: Array[int] = [GameEnums.TurnOutcome.GOAL, GameEnums.TurnOutcome.SAVE, GameEnums.TurnOutcome.LOSS,
			GameEnums.TurnOutcome.REGAIN, GameEnums.TurnOutcome.OFFSIDE]
	if reveal.outcome in marked:
		assert_dict(_panel.board().result_effect()).is_equal(ResultEffect.for_reveal(reveal))
	else:
		assert_dict(_panel.board().result_effect()).is_empty()
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


## 1拍目の着地まで待つ（1拍目の時間と少しの余裕）
func _await_landing() -> void:
	await await_millis(int(_controller.board_play_sec() * 1000.0) + 300)


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
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.ATTACK)
	_press(action)
	# このターンに選べたエリア（有効なキー）。LEAVING で押しても受け付けないことを、無効なキーでなく確かめる
	var chosen: String = _target_of(GameEnums.ChoiceFamily.ATTACK, action)
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	assert_int(leaves[0]).is_equal(1)
	assert_int(_panel.state()).is_equal(State.LEAVING)
	# LEAVING では手もエリアも受け付けない
	_press(action)
	_panel.board().area_pressed.emit(chosen)
	assert_int(_panel.state()).is_equal(State.LEAVING)
	assert_int(_controller.state().turn_records.size()).is_equal(1)


func test_the_next_turn_starts_clean() -> void:
	_start(true)
	_press(_first_targeted_action(GameEnums.ChoiceFamily.ATTACK))
	_panel.primary_button().pressed.emit()
	_panel.primary_button().pressed.emit()
	_controller.continue_after_reveal()
	_panel.start_turn()
	assert_int(_panel.state()).is_equal(State.SELECT_ACTION)
	assert_str(_panel.board().selected_area()).is_empty()
	assert_int(_panel.board().movement_count()).is_equal(0)
	assert_str(_panel.board().compare_tag()).is_empty()
	assert_bool(_panel.board().has_intent()).is_false()
	assert_array(_panel.board().preview_movements()).is_empty()
	assert_bool(_panel.telop_visible()).is_false()
	assert_bool(_panel.choice_panel().visible).is_true()
	assert_str(_panel.primary_summary()).is_empty()
	# 前のターンの1拍目が着地する前に次のターンへ進んだ。前のターンのテロップは後からも出ない
	await _await_landing()
	assert_bool(_panel.telop_visible()).is_false()
	assert_dict(_panel.board().result_effect()).is_empty()


func test_the_user_defends_with_the_board_in_the_user_view() -> void:
	_start(false)
	assert_int(_panel.choice_panel().family()).is_equal(GameEnums.ChoiceFamily.DEFENSE)
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.DEFENSE)
	_press(action)
	# 守る位置は利用者の視点のまま（UI では変換しない）
	assert_str(_panel.board().selected_area()).is_equal(
			_keys(_controller.user_options().targets(GameEnums.ChoiceFamily.DEFENSE, action))[0])
	assert_str(_panel.board().ball_area()).is_equal(_controller.snapshot().ball_area)


func test_a_move_that_cannot_be_chosen_is_not_shown() -> void:
	_start(true)
	# キックオフ（中盤（自陣）・中央）ではシュートを選べないので、ボタンを出さない（2026-11-03）
	assert_object(_panel.choice_panel().button_for(GameEnums.PlayType.SHOT)).is_null()


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
	var action: int = _first_targeted_action(GameEnums.ChoiceFamily.DEFENSE)
	_press(action)
	var target: String = _target_of(GameEnums.ChoiceFamily.DEFENSE, action)
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
	var target: String = _target_of(GameEnums.ChoiceFamily.ATTACK, action)
	var expected: Array[Movement] = _controller.user_preview(
			TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, action, PitchArea.from_key(target)))
	# ボールのエリアには必ず保持者がいるので、ドリブルは1人が運ぶ
	assert_int(expected.size()).is_equal(1)
	assert_array(_keys_of(_panel.board().preview_movements())).is_equal(_keys_of(expected))
	assert_bool(_panel.board().has_intent()).is_true()


func test_choosing_another_move_replaces_the_preview_and_submitting_clears_it() -> void:
	# キックオフの攻撃は、ショートパス・ドリブル・バックパスなど2つ以上の手が出る
	_start(true)
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	var actions: Array[int] = _panel.choice_panel().actions()
	assert_int(actions.size()).override_failure_message("攻撃の手が2つ以上ある場面であること").is_greater_equal(2)
	for action: int in [actions[0], actions[1]]:
		_press(action)
		var expected: Array[Movement] = _controller.user_preview(
				TurnChoice.new(family, action, PitchArea.from_key(_target_of(family, action))))
		assert_array(_keys_of(_panel.board().preview_movements())).is_equal(_keys_of(expected))
	_panel.primary_button().pressed.emit()
	assert_int(_panel.state()).is_equal(State.SHOW_RESULT)
	assert_array(_panel.board().preview_movements()).is_empty()


func test_the_detail_explains_the_rule_of_the_chosen_move() -> void:
	# スルーパス・バックパス・守備の手は、詳細の最後の行に手の説明（誰が動くか・何を読む手か）を出す（2026-11-05）
	for user_has_ball: bool in [true, false]:
		_start(user_has_ball)
		var family: GameEnums.ChoiceFamily = _panel.choice_panel().family()
		var explained: int = 0
		for action: int in _panel.choice_panel().actions():
			var rule: String = MatchTexts.target_rule(family, action)
			if rule.is_empty():
				continue
			_press(action)
			_panel.detail_button().pressed.emit()
			assert_str(_panel.detail_view().text()).ends_with(rule)
			_panel.detail_view().close()
			explained += 1
		assert_int(explained).override_failure_message("規則の一言がある手が出ている場面であること").is_greater(0)
		_panel.unbind()
		_controller = null


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


func test_binding_gives_the_board_the_result_time_from_the_settings() -> void:
	# bind で設定の演出の時間を盤面に入れる。入れないと、着地しても演出が出ない
	_start(true)
	var board: TacticsBoard = _panel.board()
	var snapshot: BoardSnapshot = _controller.snapshot()
	var from_key: String = "D1-C" if snapshot.ball_area != "D1-C" else "D2-C"
	board.start_shift([{"user": snapshot.user_players, "opponent": snapshot.opponent_players, "ball": from_key,
			"sec": 0.05}], {"kind": ResultEffect.Kind.WIN_BALL, "area": snapshot.ball_area, "is_user": true, "toward": ""})
	await await_millis(300)
	assert_int(board.result_effect()["kind"] as int).is_equal(ResultEffect.Kind.WIN_BALL)
	# 同梱の 0.8 秒が過ぎたら消える
	await await_millis(int(_controller.board_result_sec() * 1000.0) + 200)
	assert_dict(board.result_effect()).is_empty()


func test_binding_gives_the_board_the_piece_motion_from_the_settings() -> void:
	# bind で設定の駒の動き（弾み）と小休止を盤面に入れる。入れないと、駒が浮かず、拍の間も空かない
	_start(true)
	var board: TacticsBoard = _panel.board()
	var snapshot: BoardSnapshot = _controller.snapshot()
	var mover: Dictionary = snapshot.user_players[0]
	var moved_from: Dictionary = mover.duplicate()
	var area: PitchArea = PitchArea.from_key(mover["area"] as String)
	moved_from["area"] = PitchArea.new(area.lane, (area.zone + 1 if area.zone < GameEnums.Zone.A2 else area.zone - 1) as GameEnums.Zone).to_key()
	var moved_before: Array[Dictionary] = snapshot.user_players.duplicate()
	moved_before[0] = moved_from
	var from_key: String = "D1-C" if snapshot.ball_area != "D1-C" else "D2-C"
	# 1拍目はボールだけが動く（0.05 秒）。2拍目で駒が1人だけ、いまの位置へ動く（1 秒）
	board.start_shift([
		{"user": moved_before, "opponent": snapshot.opponent_players, "ball": from_key, "sec": 0.05},
		{"user": moved_before, "opponent": snapshot.opponent_players, "ball": snapshot.ball_area, "sec": 1.0},
	])
	assert_int(board.shift_beat_count()).is_equal(2)
	# 小休止は設定の値が入っている（小休止で2拍目が遅れることは tactics_board_test で確かめる）
	assert_float(board.beat_gap_sec()).is_equal(_controller.board_beat_gap_sec())
	# 2拍目の途中: 1人だけが動くのでずらしは無く、浮いている（同梱の弾みは駒の半径の 0.35 倍）
	await await_millis(600)
	assert_int(board.shift_beat_index()).is_equal(1)
	assert_float(board.shifting_piece_lift(mover["player_id"] as String)).is_greater(0.05)
	assert_float(board.shifting_piece_lift(mover["player_id"] as String)) \
			.is_less_equal(_controller.piece_style()["hop"] as float + 0.0001)


## 利用者が守備の最初のターンで、画面に出た最初の守備の手を決定し、開示が2拍（プレーと詰め直し）になり、ボールが動く場面を
## シードを変えて探す（2026-11-03 に手の選び方が変わり、最初のシードでは詰め直す選手がいなくなったため）
func _start_with_a_two_beat_reveal() -> void:
	var first_seed: int = 0
	for _attempt: int in range(30):
		_start(false, first_seed)
		_press(_first_targeted_action(GameEnums.ChoiceFamily.DEFENSE))
		_panel.primary_button().pressed.emit()
		var reveal: RevealView = _controller.last_reveal()
		if _panel.board().shift_beat_count() == 2 and reveal.ball_before != reveal.ball_after:
			return
		first_seed = _controller_seed + 1
		_panel.unbind()
		remove_child(_panel)
		_panel.free()
		_panel = auto_free(MatchBoardPanel.new()) as MatchBoardPanel
		add_child(_panel)
		_panel.size = Vector2(1232, 576)
		_controller = null
	fail("開示が2拍になる場面が無い")


func test_the_reveal_shifts_the_play_then_the_reshape_and_the_next_turn_stops_it() -> void:
	_start_with_a_two_beat_reveal()
	var reveal: RevealView = _controller.last_reveal()
	var snapshot: BoardSnapshot = _controller.snapshot()
	var board: TacticsBoard = _panel.board()
	# 1拍目（プレー）: 判定前 → 判定時。プレスで1人は必ず動く（空振りしない）
	var play: Array[String] = _moved_ids(reveal.user_players_before, reveal.user_players_at_judgement)
	play.append_array(_moved_ids(reveal.opponent_players_before, reveal.opponent_players_at_judgement))
	assert_array(play).is_not_empty()
	assert_array(_path_ids(board.shift_beat_paths(0))).contains(play)
	# 2拍目（詰め直し）: 判定時 → 次のターン開始時。この場面では、ボールに合わせて組み直す選手がいる
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
	# ボールは1拍目で、判定前の位置から判定後の位置へ動く（ボールの位置が変わる場面を選んだ。空振りしない）
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

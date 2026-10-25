## S-03 試合・S-04 方式の選び直し・S-05 ハーフタイム・S-06 試合結果のテスト（screen-03〜06 の詳細設計の今回の範囲）。
## App.match_controller を固定シードの試合に差し替え、画面の要求は App.screen_requested で受けて記録する
## （MainShell を置かないので、画面は切り替わらない）。
extends GdUnitTestSuite

var _original_controller: MatchController
var _requested: Array[int] = []


func before_test() -> void:
	_original_controller = App.match_controller
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.match_controller = _original_controller
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


## stop に届くシードで試合を始め、advance が真なら stop まで進めて App に置く（画面の要求は App 経由）
func _match_at(stop: ScreenTestHelper.Stop, advance: bool = true) -> MatchController:
	var seed_value: int = ScreenTestHelper.seed_reaching(stop)
	assert_int(seed_value).override_failure_message("stop に届くシードが無い").is_not_equal(-1)
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value, App.request_screen)
	controller.start_match(ScreenTestHelper.user_setup())
	if advance:
		ScreenTestHelper.advance_until(controller, stop)
	App.match_controller = controller
	_requested.clear()
	return controller


func _open(path: String) -> AppScreen:
	var screen: AppScreen = auto_free((load(path) as PackedScene).instantiate() as AppScreen) as AppScreen
	add_child(screen)
	screen.size = Vector2(1280, 720)
	screen.enter({})
	return screen


## ScreenTestHelper.forward_choice と同じ手を、画面の操作（手のボタン・選べるエリアの最後）で選んで決定する
func _play_turn(screen: MatchScreen) -> void:
	var panel: MatchBoardPanel = screen.board_panel()
	var choice: TurnChoice = ScreenTestHelper.forward_choice(App.match_controller.user_options())
	panel.choice_panel().button_for(choice.action).pressed.emit()
	if choice.target != null:
		panel.board().area_pressed.emit(panel.board().selectable_areas().back())
	panel.primary_button().pressed.emit()


# --- S-03 ---

func test_match_screen_shows_the_score_and_the_phase() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(screen.score_bug().score_text()).is_equal("0 – 0")
	assert_str(screen.score_bug().clock_text()).is_equal("前半 1／15")
	assert_str(screen.phase_text()).is_equal(MatchTexts.phase_tag(snapshot.turn_kind, snapshot.user_has_ball))
	assert_array(screen.reveal_texts()).is_empty()
	assert_int(screen.board_panel().state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
	# どちらのボールかを、上部バーに常に出す（2026-10-24）
	assert_str(screen.possession_text()).is_equal(MatchTexts.possession_text(snapshot.user_has_ball))


func test_possession_stays_visible_through_the_reveal_and_follows_the_result() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var sides_seen: Dictionary = {}
	for _turn: int in range(12):
		_play_turn(screen)
		# 開示中（局面のタグが両者の選択の帯に替わっている間）も消えず、判定後の保持を、保持側のチームの色で出す
		assert_str(screen.phase_text()).is_empty()
		_assert_possession(screen, controller.snapshot().user_has_ball)
		sides_seen[controller.snapshot().user_has_ball] = true
		if controller.state().stage != GameEnums.MatchStage.TURN:
			break
		screen.board_panel().primary_button().pressed.emit()
		_assert_possession(screen, controller.snapshot().user_has_ball)
	# 両方の保持を通っている（色の切り替えを確かめたことになる）
	assert_int(sides_seen.size()).is_equal(2)


func _assert_possession(screen: MatchScreen, user_has_ball: bool) -> void:
	assert_bool((screen.find_child("PossessionLabel", true, false) as Label).is_visible_in_tree()).is_true()
	assert_str(screen.possession_text()).is_equal("● 自分のボール" if user_has_ball else "◆ CPU のボール")
	assert_str(screen.possession_variation()).is_equal("YouChipLabel" if user_has_ball else "OpponentChipLabel")


func test_the_board_fits_the_base_resolution_with_areas_large_enough_to_press() -> void:
	# 基準解像度 1280×720 で開いた試合画面の実寸で確かめる（screen-common.md §1.1。NFR-19: 1エリア 96dp×56dp 以上）
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	await get_tree().process_frame
	var panel: MatchBoardPanel = screen.board_panel()
	var board: TacticsBoard = panel.board()
	assert_float(board.size.y).is_greater_equal(TacticsBoard.MIN_CELL.y * PitchArea.ZONE_COUNT)
	assert_float(board.size.x).is_greater_equal(TacticsBoard.MIN_CELL.x * PitchArea.LANE_COUNT)
	assert_float(board.cell_size().x).is_greater_equal(TacticsBoard.MIN_CELL.x)
	assert_float(board.cell_size().y).is_greater_equal(TacticsBoard.MIN_CELL.y)
	# 盤面はパネルの中に収まり、パネルは画面の上下の外周の余白（12px）の内側に収まる
	assert_float(panel.size.y).is_greater_equal(board.size.y)
	assert_float(panel.get_global_rect().end.y).is_less_equal(720.0 - MatchScreen.VERTICAL_MARGIN + 0.5)


func test_the_through_pass_rule_is_scrolled_into_view_on_the_match_screen() -> void:
	# 試合画面の実寸（1280×720）で、6つの手のボタンの下にはみ出すスルーパスの説明が、見える所までスクロールされる
	# （2026-10-25。パネル単体では入れ子の並べ直しの順が違い、遅らせて呼ぶだけの実装でも通ってしまうため、画面で確かめる）
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	await get_tree().process_frame
	assert_bool(controller.user_options().is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.THROUGH_PASS)) \
			.override_failure_message("キックオフでスルーパスを選べる場面であること").is_true()
	var panel: MatchBoardPanel = screen.board_panel()
	panel.choice_panel().button_for(GameEnums.PlayType.THROUGH_PASS).pressed.emit()
	for _frame: int in range(4):
		await get_tree().process_frame
	var scroll: ScrollContainer = panel.find_child("SideScroll", true, false) as ScrollContainer
	var info: Control = panel.find_child("TargetInfo", true, false) as Control
	assert_bool(scroll.get_global_rect().encloses(info.get_global_rect())) \
			.override_failure_message("%s が %s の外" % [info.get_global_rect(), scroll.get_global_rect()]).is_true()


func test_reveal_shows_both_choices_and_the_score_only_after_the_result() -> void:
	# 得点のターンで、開示の時点のスコアはまだ前のまま（得点を判定理由より先に見せない）。
	# 得点が起きるシードで、試合の始めから画面で進める
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.STYLE_CHANGE, false)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var scores_at_reveal: Array[String] = []
	screen.board_panel().reveal_started.connect(func(_reveal: RevealView) -> void:
		scores_at_reveal.append(screen.score_bug().score_text()))
	var goal_seen: bool = false
	# 得点までのターン数はシードと規則しだい（2026-10-25 にシュートをペナルティエリアに絞って延びた）。上限はシードを探す側と同じ
	for turn: int in range(ScreenTestHelper.MAX_STEPS):
		if controller.state().stage == GameEnums.MatchStage.HALFTIME:
			# S-05 を経ずに後半へ（S-03 は state_changed を受けて次のターンを始める）
			controller.submit_halftime(controller.snapshot().user_setup)
		var before: String = screen.score_bug().score_text()
		_play_turn(screen)
		var reveal: RevealView = controller.last_reveal()
		assert_array(screen.reveal_texts()).is_equal([
			"あなた: %s" % MatchTexts.choice_summary(reveal.user_choice),
			"CPU: %s" % MatchTexts.choice_summary(reveal.opponent_choice)])
		assert_str(screen.phase_text()).is_empty()
		assert_str(scores_at_reveal.back()).is_equal(before)
		var snapshot: BoardSnapshot = controller.snapshot()
		assert_str(screen.score_bug().score_text()).is_equal("%d – %d" % [snapshot.score_user, snapshot.score_opponent])
		if reveal.outcome == GameEnums.TurnOutcome.GOAL:
			goal_seen = true
			assert_str(screen.score_bug().score_text()).is_not_equal(before)
			break
		screen.board_panel().primary_button().pressed.emit()
	assert_bool(goal_seen).override_failure_message("得点のターンを通っていない").is_true()


func test_a_move_without_a_target_is_ready_at_once() -> void:
	# トランジションの手（リトリート・保持など）は運ぶ先を持たないので、選んだ時点で決定できる
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.TRANSITION)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var panel: MatchBoardPanel = screen.board_panel()
	var family: GameEnums.ChoiceFamily = panel.choice_panel().family()
	assert_bool(family in [GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.ChoiceFamily.POS_TRANS]).is_true()
	# 即時奪回（喪失側）・保持（奪取側）。どちらも運ぶ先を持たない
	var action: int = GameEnums.NegTransAction.COUNTER_PRESS if family == GameEnums.ChoiceFamily.NEG_TRANS \
			else GameEnums.PosTransAction.SECURE
	assert_bool(MoveOptions.needs_target(family, action)).is_false()
	panel.choice_panel().button_for(action).pressed.emit()
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.READY)
	assert_bool(panel.primary_button().disabled).is_false()
	assert_array(panel.board().selectable_areas()).is_empty()
	assert_str(panel.primary_summary()).is_equal(MatchTexts.action_name(family, action))
	# 人数を比べる手（即時奪回）なら、比べる人数を説明に出す。比べない手（保持）なら出さない
	var expected_info: String = ""
	for hint: ChoiceHint in controller.user_hints():
		if hint.family == family and hint.action == action and hint.is_compared:
			expected_info = "比べる人数 %s" % MatchTexts.hint_counts(hint)
	assert_str(panel.target_info_text()).is_equal(expected_info)
	panel.primary_button().pressed.emit()
	assert_int(panel.state()).is_equal(MatchBoardPanel.State.SHOW_RESULT)


func test_next_starts_the_next_turn_in_the_middle_of_a_half() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	# キックオフ（中盤（自陣）・中央）の1ターン目はシュートを選べず、得点もハーフの終わりも無い
	_play_turn(screen)
	assert_int(controller.state().stage).is_equal(GameEnums.MatchStage.TURN)
	screen.board_panel().primary_button().pressed.emit()
	assert_int(controller.state().turn_records.size()).is_equal(1)
	assert_int(screen.board_panel().state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
	assert_array(screen.reveal_texts()).is_empty()
	assert_str(screen.score_bug().clock_text()).is_equal("前半 2／15")
	assert_array(_requested).is_empty()


func test_match_screen_back_does_nothing_and_exit_disconnects() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	assert_bool(screen.handle_back()).is_true()
	assert_int(screen.board_panel().state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
	assert_array(_requested).is_empty()
	screen.exit()
	assert_bool(controller.state_changed.is_connected(screen._on_state_changed)).is_false()
	assert_bool(controller.turn_resolved.is_connected(screen.board_panel()._on_turn_resolved)).is_false()


# --- S-04 ---

func test_style_change_starts_from_the_current_styles_and_kicks_off_once() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.STYLE_CHANGE)
	var screen: StyleChangeScreen = _open("res://ui/screens/s04_style_change/style_change_screen.tscn") as StyleChangeScreen
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(screen.goal_message()).is_equal(StyleChangeScreen.goal_text(snapshot.last_goal_by))
	assert_str(screen.goal_message()).is_not_empty()
	assert_str(screen.opponent_text()).is_equal("◆ CPU %s" % MatchTexts.setup_text(controller.opponent_setup()))
	var picked: TeamStyles = screen.picker().styles()
	assert_int(picked.defense).is_equal(snapshot.user_setup.styles.defense)
	assert_int(picked.attack).is_equal(snapshot.user_setup.styles.attack)
	(screen.picker().find_child("ZoneButton", true, false) as Button).pressed.emit()
	(screen.picker().find_child("PossessionButton", true, false) as Button).pressed.emit()
	screen.kick_off_button().pressed.emit()
	screen.kick_off_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S03_MATCH] as Array[int])
	assert_int(controller.state().stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(controller.snapshot().user_setup.styles.defense).is_equal(GameEnums.DefenseStyle.ZONE)
	assert_int(controller.snapshot().user_setup.styles.attack).is_equal(GameEnums.AttackStyle.POSSESSION)
	assert_int(screen.state()).is_equal(StyleChangeScreen.State.SUBMITTING)


func test_goal_text_names_the_scorer() -> void:
	assert_str(StyleChangeScreen.goal_text(GameEnums.TeamSide.HOME)).is_equal("あなたが得点しました")
	assert_str(StyleChangeScreen.goal_text(GameEnums.TeamSide.AWAY)).is_equal("CPU が得点しました")
	assert_str(StyleChangeScreen.goal_text(-1)).is_empty()


# --- S-05 ---

func test_halftime_starts_from_the_first_half_setup_and_starts_the_second_half_once() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.HALFTIME)
	var screen: HalftimeScreen = _open("res://ui/screens/s05_halftime/halftime_screen.tscn") as HalftimeScreen
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(screen.selected_formation()).is_equal(snapshot.user_setup.formation_id)
	assert_int(screen.picker().styles().defense).is_equal(snapshot.user_setup.styles.defense)
	assert_str(screen.opponent_text()).is_equal("◆ CPU %s" % MatchTexts.setup_text(controller.opponent_setup()))
	assert_str((screen.find_child("ScoreBug", true, false) as ScoreBug).clock_text()).is_equal("HT")
	(screen.card_for("3-5-2").find_child("CardButton", true, false) as Button).pressed.emit()
	assert_str(screen.selected_formation()).is_equal("3-5-2")
	screen.second_half_button().pressed.emit()
	screen.second_half_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S03_MATCH] as Array[int])
	assert_int(controller.snapshot().half).is_equal(2)
	assert_str(controller.snapshot().user_setup.formation_id).is_equal("3-5-2")


func test_halftime_cards_are_compact_but_large_enough_to_press() -> void:
	_match_at(ScreenTestHelper.Stop.HALFTIME)
	var screen: HalftimeScreen = _open("res://ui/screens/s05_halftime/halftime_screen.tscn") as HalftimeScreen
	var card: FormationCard = screen.card_for("4-4-2")
	assert_bool((card.find_child("MiniPitch", true, false) as Control).visible).is_false()
	assert_float(card.custom_minimum_size.y).is_greater_equal(96.0)


# --- S-06 ---

func test_result_text_for_win_draw_and_loss() -> void:
	assert_str(ResultScreen.outcome_text(2, 1)).is_equal("勝ち")
	assert_str(ResultScreen.outcome_text(1, 1)).is_equal("引き分け")
	assert_str(ResultScreen.outcome_text(0, 3)).is_equal("負け")


func test_result_shows_the_final_score_and_returns_to_the_title_once() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.OVER)
	var screen: ResultScreen = _open("res://ui/screens/s06_result/result_screen.tscn") as ResultScreen
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(screen.outcome()).is_equal(ResultScreen.outcome_text(snapshot.score_user, snapshot.score_opponent))
	assert_str(screen.score_bug().score_text()).is_equal("%d – %d" % [snapshot.score_user, snapshot.score_opponent])
	assert_str(screen.score_bug().clock_text()).is_equal("FT")
	screen.title_button().pressed.emit()
	screen.title_button().pressed.emit()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(screen.state()).is_equal(ResultScreen.State.LEAVING)

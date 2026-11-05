## 通しの試合（.steering/20261019-match-screen/requirements.md の受け入れ条件「通しの試合」）。
## MainShell を置き、画面の操作（ボタンの押下・作戦ボードのエリアの押下）だけで S-01 → S-02 → S-03 →（S-04）→ S-05 →
## S-03 → S-06 → S-01 まで進める。乱数は固定シードで、得点（S-04）を通るシードを使う。
extends GdUnitTestSuite

const MAIN_SHELL_SCENE: String = "res://ui/main_shell.tscn"
const MAX_STEPS: int = 300

var _original_controller: MatchController
## App.user_data の元のサービス（テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0


func before_test() -> void:
	_user_data_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("match_flow/records_%d" % _user_data_count))
	_original_controller = App.match_controller


func after_test() -> void:
	App.user_data = _original_user_data
	App.match_controller = _original_controller


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _press(screen: Node, node_name: String) -> void:
	var button: Button = screen.find_child(node_name, true, false) as Button
	assert_object(button).override_failure_message(node_name).is_not_null()
	button.pressed.emit()


func test_a_whole_match_can_be_played_through_the_screens() -> void:
	var seed_value: int = ScreenTestHelper.seed_reaching(ScreenTestHelper.Stop.STYLE_CHANGE)
	assert_int(seed_value).is_not_equal(-1)
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value, App.request_screen)
	App.match_controller = controller
	# 途中の assert で失敗しても MainShell を残さない
	var shell: MainShell = auto_free((load(MAIN_SHELL_SCENE) as PackedScene).instantiate()) as MainShell
	add_child(shell)
	await _frames()
	await _start_from_title(shell)

	var visited: Dictionary = {}
	for step: int in range(MAX_STEPS):
		var screen: AppScreen = shell.current_screen()
		visited[shell.current_screen_id()] = true
		if screen is TitleScreen:
			break
		if screen is MatchScreen:
			var panel: MatchBoardPanel = (screen as MatchScreen).board_panel()
			assert_int(panel.state()).is_equal(MatchBoardPanel.State.SELECT_ACTION)
			# 相手の陣形・方式は、選び直しの後も常に今の値を出す（FR-16・21）
			assert_str(panel.setup_texts()[1]).is_equal("◆ %s" % MatchTexts.setup_text(controller.opponent_setup()))
			var choice: TurnChoice = ScreenTestHelper.forward_choice(controller.user_options())
			# 行き先はゲームが決めるので、手を押せばすぐ決定できる（2026-11-03）
			panel.choice_panel().button_for(choice.action).pressed.emit()
			assert_int(panel.state()).is_equal(MatchBoardPanel.State.READY)
			panel.primary_button().pressed.emit()
			assert_int(panel.state()).is_equal(MatchBoardPanel.State.SHOW_RESULT)
			panel.primary_button().pressed.emit()
		elif screen is StyleChangeScreen:
			_press(screen, "KickOffButton")
		elif screen is HalftimeScreen:
			_press(screen, "SecondHalfButton")
		elif screen is ResultScreen:
			var snapshot: BoardSnapshot = controller.snapshot()
			assert_str((screen as ResultScreen).outcome()) \
					.is_equal(RecordTexts.result_word(MatchRecord.result_of(snapshot.score_user, snapshot.score_opponent)))
			_press(screen, "TitleButton")
		await _frames()

	assert_bool(shell.current_screen() is TitleScreen).is_true()
	# 各ハーフは規定のターン数＋アディショナルタイム（0〜上限）
	var rules: MatchRuleConfig = ConfigRepository.new().match_rules()
	for half: int in [1, 2]:
		var turns: int = 0
		for record: TurnRecord in controller.state().turn_records:
			if record.half == half:
				turns += 1
		assert_int(turns).is_between(rules.turns_per_half, rules.turns_per_half + rules.max_additional_turns)
	# S-02 はループの前に通っている（上で MatchSetupScreen であることを確かめた）
	for screen_id: int in [AppScreens.Id.S03_MATCH, AppScreens.Id.S04_STYLE_CHANGE,
			AppScreens.Id.S05_HALFTIME, AppScreens.Id.S06_RESULT, AppScreens.Id.S01_TITLE]:
		assert_bool(visited.has(screen_id)).override_failure_message(AppScreens.Id.find_key(screen_id) as String).is_true()

	# タイトルに戻った後、同じ操作で新しい試合を始められる（前の試合の状態を持ち越さない）
	await _start_from_title(shell)
	assert_bool(shell.current_screen() is MatchScreen).is_true()
	assert_array(controller.state().turn_records).is_empty()
	assert_str((shell.current_screen() as MatchScreen).score_bug().clock_text()).is_equal("前半 1／15")
	assert_str((shell.current_screen() as MatchScreen).score_bug().score_text()).is_equal("0 – 0")


## S-01 で「CPU 対戦」を押し、S-02 で 4-3-3・マンツーマン・カウンター型（ScreenTestHelper.user_setup と同じ）を選んで始める
func _start_from_title(shell: MainShell) -> void:
	assert_bool(shell.current_screen() is TitleScreen).is_true()
	_press(shell.current_screen(), "KickOffCard")
	await _frames()
	var setup_screen: MatchSetupScreen = shell.current_screen() as MatchSetupScreen
	assert_object(setup_screen).is_not_null()
	for card: Node in setup_screen.find_child("FormationGrid", true, false).get_children():
		if ((card as FormationCard).find_child("NameLabel", true, false) as Label).text == "4-3-3":
			((card as FormationCard).find_child("CardButton", true, false) as Button).pressed.emit()
	_press(setup_screen, "ManButton")
	_press(setup_screen, "CounterButton")
	_press(setup_screen, "StartButton")
	await _frames()

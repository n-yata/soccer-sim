## S-03 試合・S-04 方式の選び直し・S-05 ハーフタイム・S-06 試合結果のテスト（screen-03〜06 の詳細設計の今回の範囲）。
## App.match_controller を固定シードの試合に差し替え、画面の要求は App.screen_requested で受けて記録する
## （MainShell を置かないので、画面は切り替わらない）。
extends GdUnitTestSuite

var _original_controller: MatchController
var _requested: Array[int] = []
## App.user_data の元のサービス（テストの間は一時ディレクトリへ保存するものに差し替える）
var _original_user_data: UserDataService
var _user_data_count: int = 0
## 効果音のテストが Sfx.cue_played につなぐ受け手（after_test で切る）
var _on_cue: Callable


func before_test() -> void:
	_user_data_count += 1
	_original_user_data = ScreenTestHelper.use_user_data_in(create_temp_dir("match_screens/records_%d" % _user_data_count))
	_original_controller = App.match_controller
	_requested.clear()
	App.screen_requested.connect(_on_screen_requested)


func after_test() -> void:
	App.user_data = _original_user_data
	App.match_controller = _original_controller
	if _on_cue.is_valid() and Sfx.cue_played.is_connected(_on_cue):
		Sfx.cue_played.disconnect(_on_cue)
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


func _on_screen_requested(screen: AppScreens.Id, _params: Dictionary) -> void:
	_requested.append(screen)


## stop の段階の試合を App に置く（画面の要求は App 経由）。START は新しく始め、ほかの段階は覚えた時点から再開する
## （ScreenTestHelper.controller_at。試合を毎回回さない）。advance が偽なら、stop に届くシードで始めたところで止める
## （試合の初めから画面で進める結合のテスト用）
func _match_at(stop: ScreenTestHelper.Stop, advance: bool = true) -> MatchController:
	var controller: MatchController
	if stop == ScreenTestHelper.Stop.START or not advance:
		var seed_value: int = ScreenTestHelper.seed_reaching(stop)
		assert_int(seed_value).override_failure_message("stop に届くシードが無い").is_not_equal(-1)
		controller = ScreenTestHelper.new_controller(seed_value, App.request_screen)
		controller.start_match(ScreenTestHelper.user_setup())
	else:
		controller = ScreenTestHelper.controller_at(stop, App.request_screen)
	assert_object(controller).override_failure_message("段階から始められない").is_not_null()
	App.match_controller = controller
	_requested.clear()
	return controller


## stop に入る1手の直前の試合を App に置く（その1手を画面で進めるテスト用）
func _match_before(stop: ScreenTestHelper.Stop) -> MatchController:
	var controller: MatchController = ScreenTestHelper.controller_before(stop, App.request_screen)
	assert_object(controller).override_failure_message("段階の直前から始められない").is_not_null()
	App.match_controller = controller
	_requested.clear()
	return controller


func _open(path: String) -> AppScreen:
	var screen: AppScreen = auto_free((load(path) as PackedScene).instantiate() as AppScreen) as AppScreen
	add_child(screen)
	screen.size = Vector2(1280, 720)
	screen.enter({})
	return screen


## ScreenTestHelper.forward_choice と同じ手を、画面の操作（手のボタン）で選んで決定する
func _play_turn(screen: MatchScreen) -> void:
	var panel: MatchBoardPanel = screen.board_panel()
	var choice: TurnChoice = ScreenTestHelper.forward_choice(App.match_controller.user_options())
	# 行き先はゲームが決めるので、手を押せばすぐ決定できる（2026-11-03）
	panel.choice_panel().button_for(choice.action).pressed.emit()
	panel.primary_button().pressed.emit()


# --- S-03 ---

## トランジションのターンでも、上部バーが基準の幅（1280px）から左右の余白（24px ずつ）を除いた幅に収まる。
## 局面のタグが1行で約 480px あった頃は、上部バーが 1364px になり画面からはみ出した（2026-10-29）。
## どちらの側がボールを持っていても収まるよう、4つのタグすべてで測る
func test_the_top_bar_fits_the_screen_width_in_every_phase() -> void:
	_match_at(ScreenTestHelper.Stop.TRANSITION)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	assert_str(screen.phase_text()).contains("TRANSITION")
	var top_bar: HBoxContainer = screen.find_child("TopBar", true, false) as HBoxContainer
	var phase_tag: Label = screen.find_child("PhaseTag", true, false) as Label
	for turn_kind: GameEnums.TurnKind in [GameEnums.TurnKind.OPEN_PLAY, GameEnums.TurnKind.TRANSITION]:
		for user_has_ball: bool in [true, false]:
			phase_tag.text = MatchTexts.phase_tag(turn_kind, user_has_ball)
			assert_float(top_bar.get_combined_minimum_size().x).override_failure_message(phase_tag.text) \
					.is_less_equal(1280.0 - 48.0)
			assert_float(top_bar.get_combined_minimum_size().y).override_failure_message(phase_tag.text) \
					.is_less_equal(96.0)


## 開示の帯（両者の手）は、どの手でも、どちらのボールでも、省略記号を出さずに1行に入る
## （2026-11-06。「あなた: パスコースを切る …」「CPU: ドリブル → 中盤（敵…」で切れていた）
func test_every_reveal_line_fits_the_banner() -> void:
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	_play_turn(screen)
	var possession: Label = screen.find_child("PossessionLabel", true, false) as Label
	for label_name: String in ["UserChoiceLabel", "OpponentChoiceLabel"]:
		var label: Label = screen.find_child(label_name, true, false) as Label
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		assert_int(font_size).is_greater_equal(24)
		var box: StyleBox = label.get_theme_stylebox("normal")
		for user_has_ball: bool in [true, false]:
			possession.text = MatchTexts.possession_text(user_has_ball)
			await await_idle_frame()
			var width: float = label.size.x - box.get_content_margin(SIDE_LEFT) - box.get_content_margin(SIDE_RIGHT)
			assert_float(width).is_greater(0.0)
			for family: int in MatchTexts.ACTION_NAMES:
				for action: int in range((MatchTexts.ACTION_NAMES[family] as Array).size()):
					var choice := TurnChoice.new(family as GameEnums.ChoiceFamily, action)
					var text: String = MatchScreen.reveal_line(label_name == "UserChoiceLabel", choice)
					var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					assert_float(text_width).override_failure_message("入らない: %s（幅 %.1f > %.1f）" % [text, text_width,
							width]).is_less_equal(width)


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


func test_every_move_button_is_visible_without_scrolling_on_the_match_screen() -> void:
	# 試合画面の実寸（1280×720）で、手のボタンはスクロールせずにすべて見え、手を選んでも説明でずれない（2026-11-05。
	# 説明はボタンの下に出さず、「詳細」のポップアップへ移した）。パネル単体では入れ子の並べ直しの順が違うため、画面で確かめる
	_match_at(ScreenTestHelper.Stop.START)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	await get_tree().process_frame
	var panel: MatchBoardPanel = screen.board_panel()
	var actions: Array[int] = panel.choice_panel().actions()
	panel.choice_panel().button_for(actions[actions.size() - 1]).pressed.emit()
	for _frame: int in range(4):
		await get_tree().process_frame
	var scroll: ScrollContainer = panel.find_child("SideScroll", true, false) as ScrollContainer
	assert_int(scroll.scroll_vertical).is_equal(0)
	for action: int in actions:
		var button: Button = panel.choice_panel().button_for(action)
		assert_bool(scroll.get_global_rect().encloses(button.get_global_rect())) \
				.override_failure_message("%s が %s の外" % [button.get_global_rect(), scroll.get_global_rect()]).is_true()
	# 「詳細」は主ボタンの横にあり、画面の中に収まる
	assert_bool(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.detail_button().get_global_rect())).is_true()


func test_reveal_shows_both_choices_and_the_score_only_after_the_result() -> void:
	# 得点のターンで、開示の時点のスコアはまだ前のまま（得点を判定理由より先に見せない）。
	# 得点のターンの直前から画面で進める（乱数も元の試合と同じなので、そのターンで得点が起きる）
	var controller: MatchController = _match_before(ScreenTestHelper.Stop.STYLE_CHANGE)
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
		# 帯は手の名前だけ（行き先は盤面の矢印と判定理由で読む。行き先まで書くと幅に入らない。2026-11-06）
		assert_array(screen.reveal_texts()).is_equal([
			"● %s" % MatchTexts.action_name(reveal.user_choice.family, reveal.user_choice.action),
			"◆ %s" % MatchTexts.action_name(reveal.opponent_choice.family, reveal.opponent_choice.action)])
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
	# 人数を比べる手（即時奪回）なら、比べる人数を詳細に出す。比べない手（保持）なら出さない
	var expected_info: String = ""
	for hint: ChoiceHint in controller.user_hints():
		if hint.family == family and hint.action == action and hint.is_compared:
			expected_info = "比べる人数 %s" % MatchTexts.hint_counts(hint)
	panel.detail_button().pressed.emit()
	assert_str(panel.detail_view().text()).is_equal(expected_info)
	panel.detail_view().close()
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


## 効果音（.steering/20261030-sound-effects）: 試合を最後まで画面で進め、ターンごとに鳴らした音を確かめる。
## ハーフの最初のターンを始めたら笛、得点の開示なら得点した側の音、ハーフの終わりの開示なら笛。それ以外は鳴らさない
## （ボタンのクリック音は数えない）。得点が起きるシードを使う
func test_the_match_screen_plays_the_whistle_and_the_goal_sounds_at_their_moments() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.STYLE_CHANGE, false)
	var played: Array[int] = []
	# 途中の assert が失敗しても後のテストに残らないよう、after_test で切る
	_on_cue = func(cue: SoundCues.Cue) -> void:
		if cue != SoundCues.Cue.CLICK:
			played.append(cue)
	Sfx.cue_played.connect(_on_cue)
	var screen: MatchScreen = _open("res://ui/screens/s03_match/match_screen.tscn") as MatchScreen
	var counts: Dictionary = {"kickoff": 0, "goal": 0, "half_over": 0}
	for step: int in range(ScreenTestHelper.MAX_STEPS):
		if controller.is_match_over():
			break
		if controller.state().stage == GameEnums.MatchStage.STYLE_CHANGE:
			controller.submit_style_change(controller.snapshot().user_setup.styles)
		elif controller.state().stage == GameEnums.MatchStage.HALFTIME:
			controller.submit_halftime(controller.snapshot().user_setup)
		# ターンを始めたときの音
		var is_kickoff: bool = controller.snapshot().turn_number == 1
		assert_array(played).override_failure_message("ターンの始め: %d" % controller.snapshot().turn_number) \
				.is_equal([SoundCues.Cue.WHISTLE] as Array[int] if is_kickoff else [] as Array[int])
		counts["kickoff"] += 1 if is_kickoff else 0
		played.clear()
		_play_turn(screen)
		# 開示の音
		var reveal: RevealView = controller.last_reveal()
		var expected: Array[int] = []
		if reveal.outcome == GameEnums.TurnOutcome.GOAL:
			expected.append(SoundCues.Cue.GOAL_FOR if MatchTexts.turn_winner(reveal) == MatchTexts.TurnWinner.USER
					else SoundCues.Cue.GOAL_AGAINST)
			counts["goal"] += 1
		if controller.snapshot().is_half_over:
			expected.append(SoundCues.Cue.WHISTLE)
			counts["half_over"] += 1
		assert_array(played).override_failure_message("開示: %s" % reveal.outcome).is_equal(expected)
		played.clear()
		screen.board_panel().primary_button().pressed.emit()
	assert_bool(controller.is_match_over()).is_true()
	assert_dict(counts).is_equal({"kickoff": 2, "goal": controller.snapshot().score_user + controller.snapshot().score_opponent,
			"half_over": 2})
	assert_int(counts["goal"] as int).is_greater(0)


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


func _bulleted(notes: Array[MatchupNote]) -> Array[String]:
	var result: Array[String] = []
	for note: MatchupNote in notes:
		result.append(NotesView.BULLET + note.text)
	return result


## 直前の噛み合わせ（両者の今の方式）を出す。方式を変えたら変えた項目の単独の解説を出し、元に戻したら隠す（screen-04-style-change.md）
func test_style_change_shows_the_last_style_matchup_and_the_changed_style() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.STYLE_CHANGE)
	var screen: StyleChangeScreen = _open("res://ui/screens/s04_style_change/style_change_screen.tscn") as StyleChangeScreen
	var current: TeamStyles = controller.snapshot().user_setup.styles
	var opponent: TeamStyles = controller.opponent_setup().styles
	assert_array(screen.matchup_notes().texts()).is_equal(_bulleted(App.library.style_notes(current, opponent)))
	assert_array(screen.matchup_notes().headings()).is_equal(["方式の噛み合わせ"])
	assert_bool(screen.picked_notes().visible).is_false()
	var other_defense: GameEnums.DefenseStyle = GameEnums.DefenseStyle.MAN \
			if current.defense == GameEnums.DefenseStyle.ZONE else GameEnums.DefenseStyle.ZONE
	var buttons: Dictionary = {GameEnums.DefenseStyle.ZONE: "ZoneButton", GameEnums.DefenseStyle.MAN: "ManButton"}
	(screen.picker().find_child(buttons[other_defense] as String, true, false) as Button).pressed.emit()
	assert_bool(screen.picked_notes().visible).is_true()
	assert_array(screen.picked_notes().texts()).is_equal(_bulleted(App.library.defense_style_notes(other_defense)))
	# 守備方式の解説は SIM-07（ゾーンとマンツーマンの併用）に関わるので「実戦では」が添わる（FR-23。カタログを渡しているか）
	var sim_07: Array[SimplificationDef] = App.library.simplifications().filter(
			func(simplification: SimplificationDef) -> bool: return simplification.id == "SIM-07")
	assert_array(screen.picked_notes().in_real_texts()).is_equal([SimplificationList.IN_REAL_PREFIX + sim_07[0].in_real])
	var other_attack: String = "CounterButton" if current.attack == GameEnums.AttackStyle.POSSESSION \
			else "PossessionButton"
	(screen.picker().find_child(other_attack, true, false) as Button).pressed.emit()
	assert_int(screen.picked_notes().headings().size()).is_equal(2)
	(screen.picker().find_child(buttons[current.defense] as String, true, false) as Button).pressed.emit()
	assert_int(screen.picked_notes().headings().size()).is_equal(1)
	assert_str(screen.picked_notes().headings()[0]).starts_with("攻撃方式 ")
	var original_attack: String = "PossessionButton" if other_attack == "CounterButton" else "CounterButton"
	(screen.picker().find_child(original_attack, true, false) as Button).pressed.emit()
	assert_bool(screen.picked_notes().visible).is_false()
	# 直前の噛み合わせは、選んでいる方式で変わらない
	assert_array(screen.matchup_notes().texts()).is_equal(_bulleted(App.library.style_notes(current, opponent)))


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


## 前半の噛み合わせ（基本配置の人数と優劣記号・陣形と方式の解説）。選び直すと「後半の噛み合わせ（予測）」に描き直す
func test_halftime_shows_the_first_half_matchup_and_redraws_when_picking() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.HALFTIME)
	var screen: HalftimeScreen = _open("res://ui/screens/s05_halftime/halftime_screen.tscn") as HalftimeScreen
	var user: TeamSetup = controller.snapshot().user_setup
	var opponent: TeamSetup = controller.opponent_setup()
	_assert_halftime_matchup(screen, user.formation_id, user.styles, opponent)
	assert_str(screen.matchup_title()).is_equal("前半の噛み合わせ（基本配置）")
	var other_formation: String = "4-4-2" if user.formation_id != "4-4-2" else "3-5-2"
	(screen.card_for(other_formation).find_child("CardButton", true, false) as Button).pressed.emit()
	assert_str(screen.matchup_title()).is_equal("後半の噛み合わせ（予測）")
	_assert_halftime_matchup(screen, other_formation, user.styles, opponent)
	(screen.card_for(user.formation_id).find_child("CardButton", true, false) as Button).pressed.emit()
	assert_str(screen.matchup_title()).is_equal("前半の噛み合わせ（基本配置）")
	var other_attack: String = "CounterButton" if user.styles.attack == GameEnums.AttackStyle.POSSESSION \
			else "PossessionButton"
	(screen.picker().find_child(other_attack, true, false) as Button).pressed.emit()
	assert_str(screen.matchup_title()).is_equal("後半の噛み合わせ（予測）")
	_assert_halftime_matchup(screen, user.formation_id, screen.picker().styles(), opponent)


func _assert_halftime_matchup(screen: HalftimeScreen, formation_id: String, styles: TeamStyles,
		opponent: TeamSetup) -> void:
	var counts: Dictionary = App.library.matchup_counts(formation_id, opponent.formation_id)
	var pitch: MiniPitch = screen.matchup_pitch()
	for key: String in counts:
		assert_int(pitch.counts().get(key, 0) as int).override_failure_message(key).is_equal((counts[key] as Array)[0] as int)
		assert_int(pitch.opponent_counts().get(key, 0) as int).override_failure_message(key) \
				.is_equal((counts[key] as Array)[1] as int)
	# 人数のあるマスには優劣記号が付く
	var marked: int = 0
	for key: String in counts:
		var text: String = pitch.count_text(key)
		if not text.is_empty():
			assert_bool(text.right(1) in ["▲", "＝", "▼"]).override_failure_message(key + ": " + text).is_true()
			marked += 1
	assert_int(marked).is_greater(0)
	var expected: Array[MatchupNote] = App.library.formation_notes(formation_id, opponent.formation_id)
	expected.append_array(App.library.style_notes(styles, opponent.styles))
	assert_array(screen.matchup_notes().texts()).is_equal(_bulleted(expected))


func test_halftime_cards_are_compact_but_large_enough_to_press() -> void:
	_match_at(ScreenTestHelper.Stop.HALFTIME)
	var screen: HalftimeScreen = _open("res://ui/screens/s05_halftime/halftime_screen.tscn") as HalftimeScreen
	var card: FormationCard = screen.card_for("4-4-2")
	assert_bool((card.find_child("MiniPitch", true, false) as Control).visible).is_false()
	assert_float(card.custom_minimum_size.y).is_greater_equal(96.0)


# --- S-06 ---

func test_result_text_for_win_draw_and_loss() -> void:
	assert_str(RecordTexts.result_word(MatchRecord.result_of(2, 1))).is_equal("勝ち")
	assert_str(RecordTexts.result_word(MatchRecord.result_of(1, 1))).is_equal("引き分け")
	assert_str(RecordTexts.result_word(MatchRecord.result_of(0, 3))).is_equal("負け")


func test_result_shows_the_final_score_and_returns_to_the_title_once() -> void:
	var controller: MatchController = _match_at(ScreenTestHelper.Stop.OVER)
	var screen: ResultScreen = _open("res://ui/screens/s06_result/result_screen.tscn") as ResultScreen
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_str(screen.outcome()).is_equal(RecordTexts.result_word(MatchRecord.result_of(snapshot.score_user,
			snapshot.score_opponent)))
	# 陣形・方式の推移は前半の行から始まり、後半の行を含む
	var history: Array[String] = screen.history_texts()
	assert_str(history[0]).starts_with("前半: ● %s" % ScreenTestHelper.user_setup().formation_id)
	assert_bool(history.any(func(line: String) -> bool: return line.begins_with("後半: "))).is_true()
	assert_str(screen.score_bug().score_text()).is_equal("%d – %d" % [snapshot.score_user, snapshot.score_opponent])
	assert_str(screen.score_bug().clock_text()).is_equal("FT")
	screen.title_button().pressed.emit()
	screen.title_button().pressed.emit()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S01_TITLE] as Array[int])
	assert_int(screen.state()).is_equal(ResultScreen.State.LEAVING)

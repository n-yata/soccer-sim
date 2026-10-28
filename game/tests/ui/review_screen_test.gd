## S-07 振り返り（screen-07-review.md）と、S-06 試合結果の「振り返り」ボタンのテスト。
## App.match_controller を固定シードの終わった試合（得点あり）に差し替え、画面の要求は App.screen_requested で受けて記録する。
## 得点の無い試合・記録の無い場合は、review() の値を差し替えた MatchController で確かめる。
extends GdUnitTestSuite

const REVIEW_SCENE: String = "res://ui/screens/s07_review/review_screen.tscn"
const RESULT_SCENE: String = "res://ui/screens/s06_result/result_screen.tscn"


## review() の値だけを決めた MatchController（試合は始まっている扱い）
class ReviewStub extends MatchController:
	var view: ReviewView

	func _init(p_view: ReviewView) -> void:
		var catalog: ContentCatalog = ContentRepository.new().load_catalog()
		var config := ConfigRepository.new()
		var rng := RandomNumberGenerator.new()
		super(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
				func(_s: AppScreens.Id, _p: Dictionary) -> void: pass)
		view = p_view

	func is_match_started() -> bool:
		return true

	func review() -> ReviewView:
		return view


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


## 得点のある試合を最後まで進め、App に置く
func _finished_match_with_a_goal() -> MatchController:
	var seed_value: int = ScreenTestHelper.seed_reaching(ScreenTestHelper.Stop.STYLE_CHANGE)
	assert_int(seed_value).override_failure_message("得点の起きるシードが無い").is_not_equal(-1)
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value, App.request_screen)
	controller.start_match(ScreenTestHelper.user_setup())
	assert_bool(ScreenTestHelper.advance_until(controller, ScreenTestHelper.Stop.OVER)).is_true()
	App.match_controller = controller
	_requested.clear()
	return controller


func _open(path: String) -> AppScreen:
	var screen: AppScreen = auto_free((load(path) as PackedScene).instantiate() as AppScreen) as AppScreen
	add_child(screen)
	screen.size = Vector2(1280, 720)
	screen.enter({})
	return screen


func _count_areas(players: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for player: Dictionary in players:
		counts[player["area"]] = (counts.get(player["area"], 0) as int) + 1
	return counts


# --- S-07 ---


func test_review_opens_on_the_area_tab_with_a_tally_on_every_judged_area() -> void:
	var view: ReviewView = _finished_match_with_a_goal().review()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	assert_int(screen.current_tab()).is_equal(ReviewScreen.Tab.AREA)
	assert_str(screen.message()).is_empty()
	var board: TacticsBoard = screen.area_board()
	assert_bool(board.is_visible_in_tree()).is_true()
	var keys: Array[String] = board.drawn_tally_keys()
	assert_int(keys.size()).is_equal(view.area_tallies.size())
	assert_int(keys.size()).is_greater(0)
	for key: String in view.area_tallies:
		assert_str(board.tally_of(key)).is_equal(ReviewTexts.tally_text(view.area_tallies[key] as Array))
	# 駒もボールも出さない
	assert_array(board.players(true)).is_empty()
	assert_str(board.ball_area()).is_empty()


func test_phase_rows_show_the_four_phases_in_order() -> void:
	var view: ReviewView = _finished_match_with_a_goal().review()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.PHASE)
	var expected: Array[Array] = []
	for phase: int in GameEnums.Phase.values():
		expected.append([ReviewTexts.phase_name(phase as GameEnums.Phase),
				ReviewTexts.phase_counts_text(view.phase_tallies[phase] as Array)])
	assert_array(screen.phase_page().rows()).is_equal(expected)
	assert_bool(screen.area_board().is_visible_in_tree()).is_false()


func test_goals_tab_starts_on_the_first_goal_and_lists_its_turns() -> void:
	var view: ReviewView = _finished_match_with_a_goal().review()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.GOALS)
	var cards: Array[Button] = screen.goals_page().goal_cards()
	assert_int(cards.size()).is_equal(view.goals.size())
	assert_int(screen.goals_page().selected_goal()).is_equal(0)
	assert_bool(cards[0].button_pressed).is_true()
	assert_str(cards[0].text).is_equal(ReviewTexts.goal_title(view.goals[0], view.turns_per_half))
	assert_str(screen.goals_page().no_goals_message()).is_empty()
	var turns: Array = view.goals[0]["turns"]
	var rows: Array[Array] = screen.goals_page().turn_rows()
	assert_int(rows.size()).is_equal(turns.size())
	for index: int in range(turns.size()):
		var reveal: RevealView = turns[index] as RevealView
		assert_array(rows[index]).is_equal([ReviewTexts.turn_heading(reveal, view.turns_per_half),
				ReviewTexts.choices_text(reveal), MatchTexts.outcome_tag(reveal), JudgeReasonFormatter.format(reveal)])
		var pitch: MiniPitch = screen.goals_page().turn_pitches()[index]
		assert_dict(pitch.counts()).is_equal(_count_areas(reveal.user_players_at_judgement))
		assert_dict(pitch.opponent_counts()).is_equal(_count_areas(reveal.opponent_players_at_judgement))
		assert_str(pitch.ball_area()).is_equal(reveal.ball_before)
	# 最後の行が得点のターン
	assert_str(rows.back()[2] as String).contains("GOAL")


func test_pressing_another_goal_card_shows_that_goal() -> void:
	var view: ReviewView = _finished_match_with_a_goal().review()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.GOALS)
	var last: int = view.goals.size() - 1
	screen.goals_page().goal_cards()[last].pressed.emit()
	assert_int(screen.goals_page().selected_goal()).is_equal(last)
	assert_int(screen.goals_page().turn_rows().size()).is_equal((view.goals[last]["turns"] as Array).size())
	for index: int in range(screen.goals_page().goal_cards().size()):
		assert_bool(screen.goals_page().goal_cards()[index].button_pressed).is_equal(index == last)
	# 範囲外は何もしない
	screen.goals_page().select_goal(view.goals.size())
	assert_int(screen.goals_page().selected_goal()).is_equal(last)


func test_timeline_lists_every_segment() -> void:
	var view: ReviewView = _finished_match_with_a_goal().review()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.TIMELINE)
	var expected: Array[String] = []
	for segment: Dictionary in view.segments:
		expected.append(ReviewTexts.segment_text(segment, view.turns_per_half))
	assert_array(screen.segment_texts()).is_equal(expected)
	# 前半と後半で、少なくとも2つの時間帯に分かれる
	assert_int(expected.size()).is_greater_equal(2)


func test_reopening_goes_back_to_the_area_tab() -> void:
	_finished_match_with_a_goal()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.TIMELINE)
	screen.enter({})
	assert_int(screen.current_tab()).is_equal(ReviewScreen.Tab.AREA)


func test_back_and_the_header_return_to_the_result() -> void:
	_finished_match_with_a_goal()
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	assert_bool(screen.handle_back()).is_true()
	screen.header().back_pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S06_RESULT, AppScreens.Id.S06_RESULT] as Array[int])


func test_a_match_without_goals_says_so_and_phases_that_did_not_happen_are_marked() -> void:
	var view := ReviewView.new()
	view.turn_count = 3
	view.turns_per_half = 15
	view.area_tallies = {"M2-C": [1, 0, 2]}
	view.phase_tallies = {GameEnums.Phase.ATTACK: [1, 0, 2], GameEnums.Phase.NEG_TRANSITION: [0, 0, 0],
			GameEnums.Phase.DEFENSE: [0, 0, 0], GameEnums.Phase.POS_TRANSITION: [0, 0, 0]}
	App.match_controller = auto_free(ReviewStub.new(view)) as MatchController
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	screen.select_tab(ReviewScreen.Tab.GOALS)
	assert_array(screen.goals_page().goal_cards()).is_empty()
	assert_int(screen.goals_page().selected_goal()).is_equal(-1)
	assert_array(screen.goals_page().turn_rows()).is_empty()
	assert_str(screen.goals_page().no_goals_message()).is_equal(ReviewTexts.no_goals_text())
	var rows: Array[Array] = screen.phase_page().rows()
	assert_str(rows[GameEnums.Phase.ATTACK][1] as String).is_equal("勝 1　負 0　膠着 2")
	assert_str(rows[GameEnums.Phase.DEFENSE][1] as String).is_equal(ReviewTexts.NOT_OCCURRED_TEXT)


func test_without_turn_records_only_the_message_and_back_are_shown() -> void:
	App.match_controller = auto_free(ReviewStub.new(ReviewView.new())) as MatchController
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	assert_str(screen.message()).is_equal(ReviewTexts.NO_DATA_TEXT)
	assert_bool(screen.area_board().is_visible_in_tree()).is_false()
	assert_bool(screen.handle_back()).is_true()
	assert_array(_requested).is_equal([AppScreens.Id.S06_RESULT] as Array[int])


func test_before_a_match_the_review_shows_the_message_without_errors() -> void:
	App.match_controller = ScreenTestHelper.new_controller(0, App.request_screen)
	var screen: ReviewScreen = _open(REVIEW_SCENE) as ReviewScreen
	assert_str(screen.message()).is_equal(ReviewTexts.NO_DATA_TEXT)


# --- S-06 の「振り返り」 ---


func test_result_review_button_requests_the_review_and_is_disabled_while_leaving() -> void:
	_finished_match_with_a_goal()
	var screen: ResultScreen = _open(RESULT_SCENE) as ResultScreen
	assert_bool(screen.review_button().disabled).is_false()
	# 振り返りは「タイトルへ」の上
	assert_int(screen.review_button().get_index()).is_less(screen.title_button().get_index())
	screen.review_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S07_REVIEW] as Array[int])
	screen.title_button().pressed.emit()
	assert_int(screen.state()).is_equal(ResultScreen.State.LEAVING)
	assert_bool(screen.review_button().disabled).is_true()
	screen.review_button().pressed.emit()
	assert_array(_requested).is_equal([AppScreens.Id.S07_REVIEW, AppScreens.Id.S01_TITLE] as Array[int])

## ChoicePanel（手のボタン。screen-common.md §5）と ScoreBug（スコア表示）のテスト。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE

var _panel: ChoicePanel
var _selected: Array = []


func before_test() -> void:
	_panel = auto_free(ChoicePanel.new()) as ChoicePanel
	add_child(_panel)
	_selected.clear()
	_panel.action_selected.connect(func(family: GameEnums.ChoiceFamily, action: int) -> void:
		_selected.append([family, action]))


func _attack_options() -> MoveOptions:
	var options := MoveOptions.new()
	options.add_target(ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("M2-L1"))
	options.add_target(ATTACK, GameEnums.PlayType.DRIBBLE, PitchArea.from_key("A1-C"))
	options.allow(ATTACK, GameEnums.PlayType.SHOT)
	return options


func test_attack_shows_the_six_plays_and_disables_unavailable_ones() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	assert_int(_panel.family()).is_equal(ATTACK)
	assert_int(_panel.button_count()).is_equal(6)
	assert_bool(_panel.button_for(GameEnums.PlayType.SHORT_PASS).disabled).is_false()
	assert_bool(_panel.button_for(GameEnums.PlayType.SHOT).disabled).is_false()
	var long_ball: Button = _panel.button_for(GameEnums.PlayType.LONG_BEHIND)
	assert_bool(long_ball.disabled).is_true()
	# 色だけでなく文字でも示す（screen-design.md S-03「選択不可」）
	assert_str(long_ball.text).is_equal("背後へのロングボール\n選択不可")
	assert_str(_panel.button_for(GameEnums.PlayType.DRIBBLE).text).is_equal("ドリブル")
	# スルーパス（2026-10-25）は運ぶ先が無いので選択不可。並びはドリブルの次
	assert_str(_panel.button_for(GameEnums.PlayType.THROUGH_PASS).text).is_equal("スルーパス\n選択不可")


func test_each_phase_shows_its_own_moves() -> void:
	var options := MoveOptions.new()
	options.add_target(DEFENSE, GameEnums.DefenseAction.PRESS, PitchArea.from_key("D2-C"))
	_panel.show_options(options, GameEnums.TurnKind.OPEN_PLAY, false)
	assert_int(_panel.family()).is_equal(DEFENSE)
	assert_int(_panel.button_count()).is_equal(2)
	assert_bool(_panel.button_for(GameEnums.DefenseAction.COVER).disabled).is_true()
	_panel.show_options(MoveOptions.new(), GameEnums.TurnKind.TRANSITION, false)
	assert_int(_panel.family()).is_equal(GameEnums.ChoiceFamily.NEG_TRANS)
	assert_str(_panel.button_for(GameEnums.NegTransAction.RETREAT).text).starts_with("リトリート")
	_panel.show_options(MoveOptions.new(), GameEnums.TurnKind.TRANSITION, true)
	assert_int(_panel.family()).is_equal(GameEnums.ChoiceFamily.POS_TRANS)
	assert_str(_panel.button_for(GameEnums.PosTransAction.SECURE).text).starts_with("保持")


func test_pressing_a_button_emits_the_move_and_marks_it_after_select() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	_panel.button_for(GameEnums.PlayType.DRIBBLE).pressed.emit()
	assert_array(_selected).is_equal([[ATTACK, GameEnums.PlayType.DRIBBLE]])
	# 印を付けるのは画面（select_action）。押しただけでは付けない
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_false()
	_panel.select_action(GameEnums.PlayType.DRIBBLE)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_true()
	_panel.select_action(GameEnums.PlayType.SHOT)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_false()
	assert_bool(_panel.button_for(GameEnums.PlayType.SHOT).button_pressed).is_true()


func test_disabled_panel_keeps_unavailable_moves_disabled_after_enabling_again() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	_panel.set_enabled(false)
	assert_bool(_panel.button_for(GameEnums.PlayType.SHORT_PASS).disabled).is_true()
	_panel.set_enabled(true)
	assert_bool(_panel.button_for(GameEnums.PlayType.SHORT_PASS).disabled).is_false()
	assert_bool(_panel.button_for(GameEnums.PlayType.LONG_BEHIND).disabled).is_true()


func test_buttons_are_large_enough_to_press() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	assert_float(_panel.button_for(GameEnums.PlayType.SHOT).custom_minimum_size.y).is_greater_equal(96.0)


func test_score_bug_shows_the_score_and_the_clock() -> void:
	var bug: ScoreBug = auto_free(ScoreBug.new()) as ScoreBug
	add_child(bug)
	var snapshot := BoardSnapshot.new()
	snapshot.score_user = 2
	snapshot.score_opponent = 1
	snapshot.half = 2
	snapshot.turn_number = 3
	snapshot.turns_per_half = 12
	bug.show_snapshot(snapshot)
	assert_str(bug.score_text()).is_equal("2 – 1")
	assert_str(bug.clock_text()).is_equal("後半 3／12")
	bug.show_snapshot(snapshot, "FT")
	assert_str(bug.clock_text()).is_equal("FT")

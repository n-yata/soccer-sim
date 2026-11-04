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


## 画面に出す攻撃の手（2026-11-03）: ショートパスの枠はスルーパス、ドリブル、4つ目の枠はバックパス（ロングパスの枠は無い）
func _attack_options() -> MoveOptions:
	var options := MoveOptions.new()
	options.add_target(ATTACK, GameEnums.PlayType.THROUGH_PASS, PitchArea.from_key("A1-C"))
	options.add_target(ATTACK, GameEnums.PlayType.DRIBBLE, PitchArea.from_key("M2-L1"))
	options.add_target(ATTACK, GameEnums.PlayType.BACK_PASS, PitchArea.from_key("D2-C"))
	return options


func test_attack_shows_only_the_moves_on_the_menu_in_slot_order() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	assert_int(_panel.family()).is_equal(ATTACK)
	# 選べない手（ロングパスの枠・シュート）は出さない。並びはショートパス → ロングパス → ドリブル → 4つ目の枠
	assert_array(_panel.actions()).is_equal([GameEnums.PlayType.THROUGH_PASS, GameEnums.PlayType.DRIBBLE,
			GameEnums.PlayType.BACK_PASS])
	assert_object(_panel.button_for(GameEnums.PlayType.SHOT)).is_null()
	assert_object(_panel.button_for(GameEnums.PlayType.SHORT_PASS)).is_null()
	# ボタンは番号と行動の名前だけ（2026-11-05。中身の手がスルーパスでも枠の名前。行き先は「詳細」で見せる）
	assert_str(_panel.button_for(GameEnums.PlayType.THROUGH_PASS).text).is_equal("① ショートパス")
	assert_str(_panel.button_for(GameEnums.PlayType.DRIBBLE).text).is_equal("② ドリブル")
	assert_str(_panel.button_for(GameEnums.PlayType.BACK_PASS).text).is_equal("③ バックパス")
	assert_str(_panel.number_of(GameEnums.PlayType.BACK_PASS)).is_equal("③")
	assert_str(_panel.number_of(GameEnums.PlayType.SHOT)).is_empty()
	# 4つまでの手を2列に並べ、スクロールせずに選べる
	assert_int(_panel.columns).is_equal(2)


func test_each_phase_shows_its_own_moves() -> void:
	var options := MoveOptions.new()
	options.add_target(DEFENSE, GameEnums.DefenseAction.PRESS, PitchArea.from_key("D2-C"))
	options.add_target(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN, PitchArea.from_key("M1-C"))
	_panel.show_options(options, GameEnums.TurnKind.OPEN_PLAY, false)
	assert_int(_panel.family()).is_equal(DEFENSE)
	assert_array(_panel.actions()).is_equal([GameEnums.DefenseAction.PRESS, GameEnums.DefenseAction.CLOSE_DOWN])
	assert_str(_panel.button_for(GameEnums.DefenseAction.PRESS).text).is_equal("① パスコースを切る")
	var transition := MoveOptions.new()
	transition.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
	transition.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	_panel.show_options(transition, GameEnums.TurnKind.TRANSITION, false)
	assert_int(_panel.family()).is_equal(GameEnums.ChoiceFamily.NEG_TRANS)
	assert_str(_panel.button_for(GameEnums.NegTransAction.RETREAT).text).is_equal("② リトリート")
	var winner := MoveOptions.new()
	winner.add_target(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.COUNTER, PitchArea.from_key("A1-C"))
	winner.allow(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)
	_panel.show_options(winner, GameEnums.TurnKind.TRANSITION, true)
	assert_int(_panel.family()).is_equal(GameEnums.ChoiceFamily.POS_TRANS)
	assert_str(_panel.button_for(GameEnums.PosTransAction.COUNTER).text).is_equal("① カウンター")
	assert_str(_panel.button_for(GameEnums.PosTransAction.SECURE).text).is_equal("② 保持")


func test_pressing_a_button_emits_the_move_and_marks_it_after_select() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	_panel.button_for(GameEnums.PlayType.DRIBBLE).pressed.emit()
	assert_array(_selected).is_equal([[ATTACK, GameEnums.PlayType.DRIBBLE]])
	# 印を付けるのは画面（select_action）。押しただけでは付けない
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_false()
	_panel.select_action(GameEnums.PlayType.DRIBBLE)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_true()
	_panel.select_action(GameEnums.PlayType.BACK_PASS)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).button_pressed).is_false()
	assert_bool(_panel.button_for(GameEnums.PlayType.BACK_PASS).button_pressed).is_true()


func test_disabling_the_panel_disables_every_button_until_enabled_again() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	_panel.set_enabled(false)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).disabled).is_true()
	# 押せない間に並べ直しても、押せないまま（決定の処理中に描き直しても押せない）
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).disabled).is_true()
	_panel.set_enabled(true)
	assert_bool(_panel.button_for(GameEnums.PlayType.DRIBBLE).disabled).is_false()


func test_buttons_are_large_enough_to_press() -> void:
	_panel.show_options(_attack_options(), GameEnums.TurnKind.OPEN_PLAY, true)
	assert_float(_panel.button_for(GameEnums.PlayType.BACK_PASS).custom_minimum_size.y).is_greater_equal(96.0)


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

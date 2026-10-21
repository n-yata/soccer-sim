## TacticsBoard（作戦ボード。screen-common.md §5）のテスト。盤面の値は本物の試合（固定シード）から取る。
extends GdUnitTestSuite

const BOARD_SIZE: Vector2 = Vector2(726, 575)

var _board: TacticsBoard
var _pressed: Array[String] = []


func before_test() -> void:
	_board = auto_free(TacticsBoard.new()) as TacticsBoard
	add_child(_board)
	_board.size = BOARD_SIZE
	_pressed.clear()
	_board.area_pressed.connect(func(key: String) -> void: _pressed.append(key))


## 試合を始めた直後の盤面（kickoff が side になるまでシードを進める）
func _snapshot(user_has_ball: bool) -> BoardSnapshot:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	for seed_value: int in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var config := ConfigRepository.new()
		var controller := MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
				func(_screen: AppScreens.Id, _params: Dictionary) -> void: pass)
		controller.start_match(TeamSetup.new("4-4-2",
				TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)))
		var snapshot: BoardSnapshot = controller.snapshot()
		if snapshot.user_has_ball == user_has_ball:
			return snapshot
	return null


func _numbers_in(players: Array[Dictionary], key: String) -> Array[int]:
	var numbers: Array[int] = []
	for player: Dictionary in players:
		if player["area"] == key:
			numbers.append(player["number"] as int)
	numbers.sort()
	return numbers


func _click(key: String, release_key: String = "") -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _board.area_rect(key).get_center()
	_board._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = _board.area_rect(key if release_key.is_empty() else release_key).get_center()
	_board._gui_input(release)


func test_areas_are_laid_out_with_the_user_attacking_to_the_right() -> void:
	# 列は左から自陣・中盤・敵陣、行は上から左大外〜右大外
	var cell := Vector2(BOARD_SIZE.x / 3.0, BOARD_SIZE.y / 5.0)
	assert_vector(_board.area_rect("D-L2").position).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))
	assert_vector(_board.area_rect("A-R2").end).is_equal_approx(BOARD_SIZE, Vector2(0.01, 0.01))
	assert_vector(_board.area_rect("M-C").position).is_equal_approx(Vector2(cell.x, cell.y * 2), Vector2(0.01, 0.01))
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		assert_str(_board.area_at(_board.area_rect(key).get_center())).is_equal(key)
	assert_str(_board.area_at(Vector2(-1, 10))).is_empty()
	assert_str(_board.area_at(BOARD_SIZE + Vector2(1, 1))).is_empty()


func test_pieces_and_marks_match_the_snapshot_when_the_user_attacks() -> void:
	var snapshot: BoardSnapshot = _snapshot(true)
	_board.show_snapshot(snapshot)
	_assert_pieces_and_marks(snapshot)


func test_pieces_and_marks_match_the_snapshot_when_the_user_defends() -> void:
	# 利用者が守備のときも、盤面の値（利用者の視点）をそのまま置く。ボードはエリアを変換しない
	var snapshot: BoardSnapshot = _snapshot(false)
	_board.show_snapshot(snapshot)
	_assert_pieces_and_marks(snapshot)
	assert_str(_board.ball_area()).is_equal(snapshot.ball_area)


func _assert_pieces_and_marks(snapshot: BoardSnapshot) -> void:
	var total_user: int = 0
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		var pieces: Dictionary = _board.pieces_in(key)
		assert_array(pieces["user"] as Array).override_failure_message(key) \
				.is_equal(_numbers_in(snapshot.user_players, key))
		assert_array(pieces["opponent"] as Array).override_failure_message(key) \
				.is_equal(_numbers_in(snapshot.opponent_players, key))
		total_user += (pieces["user"] as Array).size()
		var user_count: int = snapshot.user_counts[key] as int
		var opponent_count: int = snapshot.opponent_counts[key] as int
		var expected_mark: String = "▲" if user_count > opponent_count else ("▼" if user_count < opponent_count else "＝")
		assert_str(_board.mark_of(key)).override_failure_message(key).is_equal(expected_mark)
	assert_int(total_user).is_equal(10)


func test_marks_are_shown_on_every_area_even_when_empty() -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_counts = {"M-C": 2}
	snapshot.opponent_counts = {"M-C": 1, "A-C": 1}
	_board.show_snapshot(snapshot)
	assert_str(_board.mark_of("M-C")).is_equal("▲")
	assert_str(_board.mark_of("A-C")).is_equal("▼")
	assert_str(_board.mark_of("D-L2")).is_equal("＝")


func test_only_selectable_areas_emit_when_pressed() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["M-L1", "A-C"])
	_click("M-C")
	assert_array(_pressed).is_empty()
	_click("A-C")
	assert_array(_pressed).is_equal(["A-C"])


func test_releasing_outside_the_pressed_area_cancels_the_press() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["M-L1", "M-C"])
	_click("M-L1", "M-C")
	assert_array(_pressed).is_empty()


func test_overlays_are_cleared() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["M-L1"])
	_board.set_selected("M-L1")
	_board.set_hints({"M-L1": "+1"})
	_board.show_intent("M-C", "M-L1")
	_board.show_movements([Movement.new(GameEnums.TeamSide.HOME, "4-4-2-lb", PitchArea.from_key("D-L2"),
			PitchArea.from_key("M-L2"), GameEnums.MovementReason.SLIDE)])
	_board.show_compare("M-L1", 1, 0)
	assert_array(_board.selectable_areas()).is_equal(["M-L1"])
	assert_str(_board.selected_area()).is_equal("M-L1")
	assert_str(_board.hint_of("M-L1")).is_equal("+1")
	assert_bool(_board.has_intent()).is_true()
	assert_int(_board.movement_count()).is_equal(1)
	assert_str(_board.compare_tag()).is_equal("1対0")
	_board.clear_overlays()
	assert_array(_board.selectable_areas()).is_empty()
	assert_str(_board.selected_area()).is_empty()
	assert_str(_board.hint_of("M-L1")).is_empty()
	assert_bool(_board.has_intent()).is_false()
	assert_int(_board.movement_count()).is_equal(0)
	assert_str(_board.compare_tag()).is_empty()
	# 選べるエリアが無くなったので、押しても出ない
	_click("M-L1")
	assert_array(_pressed).is_empty()


func test_pieces_in_a_crowded_area_are_folded() -> void:
	# 5人以上は駒を3つと「+N」にする（screen-common.md §5）
	var snapshot := BoardSnapshot.new()
	var players: Array[Dictionary] = []
	for number: int in [2, 3, 4, 5, 6]:
		players.append({"player_id": "p%d" % number, "number": number, "area": "D-C"})
	snapshot.user_players = players
	snapshot.user_counts = {"D-C": 5}
	_board.show_snapshot(snapshot)
	assert_array(_board.pieces_in("D-C")["user"] as Array).is_equal([2, 3, 4, 5, 6])
	assert_int(_board.visible_piece_count("D-C", true)).is_equal(3)
	assert_str(_board.overflow_tag("D-C", true)).is_equal("+2")
	assert_int(_board.visible_piece_count("M-C", true)).is_equal(0)

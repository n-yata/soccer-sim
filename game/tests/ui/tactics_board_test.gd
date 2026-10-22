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


func test_pieces_match_the_snapshot_when_the_user_attacks() -> void:
	var snapshot: BoardSnapshot = _snapshot(true)
	_board.show_snapshot(snapshot)
	_assert_pieces(snapshot)


func test_pieces_match_the_snapshot_when_the_user_defends() -> void:
	# 利用者が守備のときも、盤面の値（利用者の視点）をそのまま置く。ボードはエリアを変換しない
	var snapshot: BoardSnapshot = _snapshot(false)
	_board.show_snapshot(snapshot)
	_assert_pieces(snapshot)
	assert_str(_board.ball_area()).is_equal(snapshot.ball_area)


## 優劣は角の記号ではなく、エリアの中の ● と ◆ の数で読む（FR-16）。駒の数が人数と一致すること
func _assert_pieces(snapshot: BoardSnapshot) -> void:
	var total_user: int = 0
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		var pieces: Dictionary = _board.pieces_in(key)
		var user_pieces: Array = pieces["user"] as Array
		var opponent_pieces: Array = pieces["opponent"] as Array
		assert_array(user_pieces).override_failure_message(key).is_equal(_numbers_in(snapshot.user_players, key))
		assert_array(opponent_pieces).override_failure_message(key).is_equal(_numbers_in(snapshot.opponent_players, key))
		assert_int(user_pieces.size()).override_failure_message(key).is_equal(snapshot.user_counts.get(key, 0) as int)
		assert_int(opponent_pieces.size()).override_failure_message(key).is_equal(snapshot.opponent_counts.get(key, 0) as int)
		total_user += (pieces["user"] as Array).size()
	assert_int(total_user).is_equal(10)


func test_pieces_stay_inside_their_area_down_to_the_minimum_cell_size() -> void:
	# 1チームの上限（4つ。超えたら3つと「+N」）まで、駒の外周がエリアの自分の側の半分に収まる（隣のエリアへはみ出すと人数を読み違える）
	for board_size: Vector2 in [BOARD_SIZE, TacticsBoard.MIN_CELL * Vector2(PitchArea.ZONE_COUNT, PitchArea.LANE_COUNT)]:
		_board.size = board_size
		var rect: Rect2 = _board.area_rect("M-C")
		var radius: float = _board.piece_radius()
		assert_float(radius).override_failure_message(str(board_size)).is_greater(0.0)
		for index: int in range(TacticsBoard.MAX_PIECES):
			var user_center: Vector2 = _board.piece_center("M-C", true, index)
			var opponent_center: Vector2 = _board.piece_center("M-C", false, index)
			var label: String = "%s index %d" % [board_size, index]
			assert_float(user_center.x - radius).override_failure_message(label).is_greater_equal(rect.position.x)
			assert_float(user_center.x + radius).override_failure_message(label).is_less(rect.get_center().x)
			assert_float(opponent_center.x + radius).override_failure_message(label).is_less_equal(rect.end.x)
			assert_float(opponent_center.x - radius).override_failure_message(label).is_greater(rect.get_center().x)
			if index > 0:
				# 隣の駒と重ならない
				var previous: Vector2 = _board.piece_center("M-C", true, index - 1)
				assert_float(previous.x - user_center.x).override_failure_message(label).is_greater_equal(radius * 2.0)


func test_only_dribble_press_and_cover_are_drawn() -> void:
	# 方式の動き（スライド・マーク・前進・リトリート）と、保持者の動き（戻る・置かれる）は描かない
	var movements: Array[Movement] = []
	for reason: int in GameEnums.MovementReason.values():
		movements.append(Movement.new(GameEnums.TeamSide.HOME, "p%d" % reason, PitchArea.from_key("D-C"),
				PitchArea.from_key("M-C"), reason as GameEnums.MovementReason))
	_board.show_movements(movements)
	assert_int(_board.movement_count()).is_equal(GameEnums.MovementReason.size())
	var drawn: Array[int] = []
	for movement: Movement in _board.drawn_movements():
		drawn.append(movement.reason)
	assert_array(drawn).is_equal([GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER,
			GameEnums.MovementReason.DRIBBLE])


func test_hints_are_drawn_only_on_selectable_areas_and_even_ones_are_muted() -> void:
	_board.set_selectable(["M-L1", "A-C"])
	var even: Array[String] = ["A-C"]
	_board.set_hints({"M-L1": "+1", "A-C": "±0 GK", "D-C": "−1"}, even)
	assert_array(_board.drawn_hint_keys()).is_equal(["M-L1", "A-C"])
	assert_bool(_board.is_hint_even("A-C")).is_true()
	assert_bool(_board.is_hint_even("M-L1")).is_false()
	_board.clear_overlays()
	assert_array(_board.drawn_hint_keys()).is_empty()
	assert_bool(_board.is_hint_even("A-C")).is_false()


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


# --- 決定前のプレビュー ---

func _preview_snapshot(user_spec: Dictionary) -> BoardSnapshot:
	var snapshot := BoardSnapshot.new()
	var players: Array[Dictionary] = []
	for player_id: String in user_spec:
		players.append({"player_id": player_id, "number": 0, "area": user_spec[player_id]})
	snapshot.user_players = players
	snapshot.opponent_players = [{"player_id": "o1", "number": 0, "area": "D-C"}]
	return snapshot


func _move(player_id: String, from_key: String, to_key: String,
		reason: GameEnums.MovementReason = GameEnums.MovementReason.COVER) -> Movement:
	return Movement.new(GameEnums.TeamSide.HOME, player_id, PitchArea.from_key(from_key), PitchArea.from_key(to_key), reason)


func test_preview_rings_continue_the_row_of_pieces_in_the_destination() -> void:
	# D-C には自分の p1 がいる。M-C の p2 と M-L1 の p3 が D-C へ動くと、輪は p1 の隣から順に並ぶ
	_board.show_snapshot(_preview_snapshot({"p1": "D-C", "p2": "M-C", "p3": "M-L1"}))
	_board.show_preview([_move("p2", "M-C", "D-C"), _move("p3", "M-L1", "D-C")])
	assert_int(_board.preview_movements().size()).is_equal(2)
	assert_vector(_board.preview_center(0)).is_equal(_board.piece_center("D-C", true, 1))
	assert_vector(_board.preview_center(1)).is_equal(_board.piece_center("D-C", true, 2))
	# 駒は動かさない（相手の駒も、自分の駒も、いまの位置のまま）
	assert_int((_board.pieces_in("M-C")["user"] as Array).size()).is_equal(1)
	assert_int((_board.pieces_in("D-C")["opponent"] as Array).size()).is_equal(1)


func test_preview_rings_stop_at_the_last_slot_of_a_crowded_area() -> void:
	_board.show_snapshot(_preview_snapshot({"p1": "D-C", "p2": "D-C", "p3": "D-C", "p4": "D-C", "p5": "M-C"}))
	_board.show_preview([_move("p5", "M-C", "D-C")])
	assert_vector(_board.preview_center(0)).is_equal(_board.piece_center("D-C", true, TacticsBoard.MAX_PIECES - 1))


func test_preview_keeps_every_reason_and_is_cleared_with_the_overlays() -> void:
	# 開示後の矢印と違い、プレビューは方式の動き（リトリート・マークの付け直し）も出す
	_board.show_snapshot(_preview_snapshot({"p1": "M-C", "p2": "M-L1"}))
	_board.show_preview([_move("p1", "M-C", "D-C", GameEnums.MovementReason.RETREAT_RESET),
			_move("p2", "M-L1", "M-C", GameEnums.MovementReason.MARK)])
	assert_int(_board.preview_movements().size()).is_equal(2)
	_board.clear_overlays()
	assert_array(_board.preview_movements()).is_empty()


func test_preview_arrows_start_from_the_piece_of_the_moving_player() -> void:
	# M-C の自分の駒は盤面の選手の順に p0・p2。p2 の矢印は2つ目の駒から出る
	_board.show_snapshot(_preview_snapshot({"p0": "M-C", "p1": "D-C", "p2": "M-C"}))
	_board.show_preview([_move("p2", "M-C", "D-C")])
	assert_vector(_board.preview_origin(0)).is_equal(_board.piece_center("M-C", true, 1))

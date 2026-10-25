## TacticsBoard（作戦ボード。screen-common.md §5）のテスト。盤面の値は本物の試合（固定シード）から取る。
extends GdUnitTestSuite

const BOARD_SIZE: Vector2 = Vector2(726, 600)

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
	press.position = _board.screen_center(key)
	_board._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = _board.screen_center(key if release_key.is_empty() else release_key)
	_board._gui_input(release)


func test_areas_are_laid_out_with_the_user_attacking_upward() -> void:
	# 平面図: 列は左から左大外〜右大外、行は上から敵陣ゴール前（A2）〜自陣ゴール前（D1）の6行
	var cell := Vector2(BOARD_SIZE.x / 5.0, BOARD_SIZE.y / 6.0)
	assert_vector(_board.area_rect("A2-L2").position).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))
	assert_vector(_board.area_rect("D1-R2").end).is_equal_approx(BOARD_SIZE, Vector2(0.01, 0.01))
	assert_vector(_board.area_rect("A1-C").position).is_equal_approx(Vector2(cell.x * 2, cell.y), Vector2(0.01, 0.01))
	# 画面でも、敵陣は自陣より上、左大外は右大外より左
	assert_float(_board.screen_center("A2-C").y).is_less(_board.screen_center("A1-C").y)
	assert_float(_board.screen_center("A1-C").y).is_less(_board.screen_center("D1-C").y)
	assert_float(_board.screen_center("A1-L2").x).is_less(_board.screen_center("A1-R2").x)


func test_pressing_the_middle_of_an_area_on_screen_selects_that_area() -> void:
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		assert_str(_board.area_at(_board.screen_center(key))).override_failure_message(key).is_equal(key)
		assert_str(_board.plan_area_at(_board.area_rect(key).get_center())).override_failure_message(key).is_equal(key)
	# ピッチの外（奥の行の左外・上の余白・盤面の外）は空
	var far_left: Vector2 = BoardProjection.to_screen(Vector2(0, 0), BOARD_SIZE)
	assert_str(_board.area_at(far_left + Vector2(-10, 5))).is_empty()
	assert_str(_board.area_at(Vector2(BOARD_SIZE.x / 2.0, 2.0))).is_empty()
	assert_str(_board.area_at(BOARD_SIZE + Vector2(1, 1))).is_empty()


func test_far_row_areas_are_large_enough_to_press_down_to_the_minimum_size() -> void:
	# NFR-19: 押せる範囲は 48dp（96px）以上。いちばん奥の行（敵陣）が、画面でいちばん小さい
	for board_size: Vector2 in [BOARD_SIZE, TacticsBoard.MIN_CELL * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)]:
		_board.size = board_size
		for lane: int in GameEnums.Lane.values():
			var rect: Rect2 = _board.area_rect(PitchArea.new(lane as GameEnums.Lane, GameEnums.Zone.A2).to_key())
			var top_left: Vector2 = BoardProjection.to_screen(rect.position, board_size)
			var top_right: Vector2 = BoardProjection.to_screen(Vector2(rect.end.x, rect.position.y), board_size)
			var bottom_left: Vector2 = BoardProjection.to_screen(Vector2(rect.position.x, rect.end.y), board_size)
			var label: String = "%s lane %d" % [board_size, lane]
			assert_float(top_right.x - top_left.x).override_failure_message(label).is_greater_equal(96.0)
			assert_float(bottom_left.y - top_left.y).override_failure_message(label).is_greater_equal(96.0)


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
	# 1チームの上限（4つ。超えたら3つと「+N」）まで、2列×2段の駒の外周がエリアの自分の側の半分に収まる
	# （自分は左半分・相手は右半分。隣のエリアへはみ出すと人数を読み違える）
	for board_size: Vector2 in [BOARD_SIZE, TacticsBoard.MIN_CELL * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)]:
		_board.size = board_size
		var rect: Rect2 = _board.area_rect("A1-C")
		var radius: float = _board.piece_radius()
		assert_float(radius).override_failure_message(str(board_size)).is_greater(0.0)
		for index: int in range(TacticsBoard.MAX_PIECES):
			var user_center: Vector2 = _board.piece_center("A1-C", true, index)
			var opponent_center: Vector2 = _board.piece_center("A1-C", false, index)
			var label: String = "%s index %d" % [board_size, index]
			assert_float(user_center.x - radius).override_failure_message(label).is_greater_equal(rect.position.x)
			assert_float(user_center.x + radius).override_failure_message(label).is_less(rect.get_center().x)
			assert_float(opponent_center.x + radius).override_failure_message(label).is_less_equal(rect.end.x)
			assert_float(opponent_center.x - radius).override_failure_message(label).is_greater(rect.get_center().x)
			assert_bool(rect.has_point(user_center)).override_failure_message(label).is_true()
			assert_bool(rect.has_point(opponent_center)).override_failure_message(label).is_true()
		# 同じ段の2つは横に重ならず、段は奥（0・1）が手前（2・3）より上
		var first: Vector2 = _board.piece_center("A1-C", true, 0)
		var second: Vector2 = _board.piece_center("A1-C", true, 1)
		var third: Vector2 = _board.piece_center("A1-C", true, 2)
		assert_float(absf(first.x - second.x)).override_failure_message(str(board_size)).is_greater_equal(radius * 2.0)
		assert_float(first.y).is_equal_approx(second.y, 0.001)
		assert_float(first.y).override_failure_message(str(board_size)).is_less(third.y)


func test_only_dribble_through_run_press_and_cover_are_drawn() -> void:
	# 方式の動き（スライド・マーク・前進・リトリート）と、保持者の動き（戻る・置かれる）は描かない
	var movements: Array[Movement] = []
	for reason: int in GameEnums.MovementReason.values():
		movements.append(Movement.new(GameEnums.TeamSide.HOME, "p%d" % reason, PitchArea.from_key("D1-C"),
				PitchArea.from_key("A1-C"), reason as GameEnums.MovementReason))
	_board.show_movements(movements)
	assert_int(_board.movement_count()).is_equal(GameEnums.MovementReason.size())
	var drawn: Array[int] = []
	for movement: Movement in _board.drawn_movements():
		drawn.append(movement.reason)
	# スルーパスの受け手の走り込み（2026-10-25）も、ボールを運ぶ手の動きとして描く
	assert_array(drawn).is_equal([GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER,
			GameEnums.MovementReason.DRIBBLE, GameEnums.MovementReason.THROUGH_RUN])


func test_board_keeps_the_offside_line_of_the_snapshot() -> void:
	# スナップショットのライン（利用者の視点の列）をそのまま持ち、-1 なら描かない（2026-10-25）
	var snapshot := BoardSnapshot.new()
	snapshot.offside_line_zone = 3
	_board.show_snapshot(snapshot)
	assert_int(_board.offside_line_zone()).is_equal(3)
	# 線は、その列の上端（相手ゴール側の境界。平面図の y）に引く
	assert_float(_board.offside_line_plan_y()).is_equal_approx(_board.area_rect("M2-C").position.y, 0.01)
	assert_bool(_board.is_offside_line_drawn()).is_true()
	# 最終ラインが敵陣ゴール前の列（5）なら、誰もオフサイドにならないので、ゴールラインに重なる線は描かない
	snapshot.offside_line_zone = 5
	_board.show_snapshot(snapshot)
	assert_bool(_board.is_offside_line_drawn()).is_false()
	snapshot.offside_line_zone = -1
	_board.show_snapshot(snapshot)
	assert_int(_board.offside_line_zone()).is_equal(-1)
	assert_bool(_board.is_offside_line_drawn()).is_false()


func test_penalty_areas_match_the_three_shooting_squares_at_both_ends() -> void:
	# シュートを打てるのはペナルティエリアの3マス（6列目の L1・C・R1）。白線をこの3マスにぴったり合わせる（2026-10-25）
	# 幅は5レーンの2〜4本目（L1〜R1）、奥行きは6列の1列分。手で書いた値（ボード 726×600）
	var top := Rect2(Vector2(145.2, 0), Vector2(435.6, 100))
	var bottom := Rect2(Vector2(145.2, 500), Vector2(435.6, 100))
	var areas: Array[Rect2] = BoardPainter.penalty_areas(_board)
	assert_int(areas.size()).is_equal(2)
	assert_vector(areas[0].position).is_equal_approx(top.position, Vector2(0.01, 0.01))
	assert_vector(areas[0].size).is_equal_approx(top.size, Vector2(0.01, 0.01))
	assert_vector(areas[1].position).is_equal_approx(bottom.position, Vector2(0.01, 0.01))
	assert_vector(areas[1].size).is_equal_approx(bottom.size, Vector2(0.01, 0.01))


func test_hints_are_drawn_only_on_selectable_areas_and_even_ones_are_muted() -> void:
	_board.set_selectable(["A1-L1", "A2-C"])
	var even: Array[String] = ["A2-C"]
	_board.set_hints({"A1-L1": "+1", "A2-C": "±0 カバーあり", "D1-C": "−1"}, even)
	assert_array(_board.drawn_hint_keys()).is_equal(["A1-L1", "A2-C"])
	assert_bool(_board.is_hint_even("A2-C")).is_true()
	assert_bool(_board.is_hint_even("A1-L1")).is_false()
	_board.clear_overlays()
	assert_array(_board.drawn_hint_keys()).is_empty()
	assert_bool(_board.is_hint_even("A2-C")).is_false()


func test_only_selectable_areas_emit_when_pressed() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["A1-L1", "A2-C"])
	_click("A1-C")
	assert_array(_pressed).is_empty()
	_click("A2-C")
	assert_array(_pressed).is_equal(["A2-C"])


func test_releasing_outside_the_pressed_area_cancels_the_press() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["A1-L1", "A1-C"])
	_click("A1-L1", "A1-C")
	assert_array(_pressed).is_empty()


func test_overlays_are_cleared() -> void:
	_board.show_snapshot(_snapshot(true))
	_board.set_selectable(["A1-L1"])
	_board.set_selected("A1-L1")
	_board.set_hints({"A1-L1": "+1"})
	_board.show_intent("A1-C", "A1-L1")
	_board.show_movements([Movement.new(GameEnums.TeamSide.HOME, "4-4-2-lb", PitchArea.from_key("D1-L2"),
			PitchArea.from_key("A1-L2"), GameEnums.MovementReason.SLIDE)])
	_board.show_compare("A1-L1", 1, 0)
	assert_array(_board.selectable_areas()).is_equal(["A1-L1"])
	assert_str(_board.selected_area()).is_equal("A1-L1")
	assert_str(_board.hint_of("A1-L1")).is_equal("+1")
	assert_bool(_board.has_intent()).is_true()
	assert_int(_board.movement_count()).is_equal(1)
	assert_str(_board.compare_tag()).is_equal("1対0")
	_board.clear_overlays()
	assert_array(_board.selectable_areas()).is_empty()
	assert_str(_board.selected_area()).is_empty()
	assert_str(_board.hint_of("A1-L1")).is_empty()
	assert_bool(_board.has_intent()).is_false()
	assert_int(_board.movement_count()).is_equal(0)
	assert_str(_board.compare_tag()).is_empty()
	# 選べるエリアが無くなったので、押しても出ない
	_click("A1-L1")
	assert_array(_pressed).is_empty()


func test_pieces_in_a_crowded_area_are_folded() -> void:
	# 5人以上は駒を3つと「+N」にする（screen-common.md §5）
	var snapshot := BoardSnapshot.new()
	var players: Array[Dictionary] = []
	for number: int in [2, 3, 4, 5, 6]:
		players.append({"player_id": "p%d" % number, "number": number, "area": "D1-C"})
	snapshot.user_players = players
	snapshot.user_counts = {"D1-C": 5}
	_board.show_snapshot(snapshot)
	assert_array(_board.pieces_in("D1-C")["user"] as Array).is_equal([2, 3, 4, 5, 6])
	assert_int(_board.visible_piece_count("D1-C", true)).is_equal(3)
	assert_str(_board.overflow_tag("D1-C", true)).is_equal("+2")
	assert_int(_board.visible_piece_count("A1-C", true)).is_equal(0)


# --- 決定前のプレビュー ---

func _preview_snapshot(user_spec: Dictionary) -> BoardSnapshot:
	var snapshot := BoardSnapshot.new()
	var players: Array[Dictionary] = []
	for player_id: String in user_spec:
		players.append({"player_id": player_id, "number": 0, "area": user_spec[player_id]})
	snapshot.user_players = players
	snapshot.opponent_players = [{"player_id": "o1", "number": 0, "area": "D1-C"}]
	return snapshot


func _move(player_id: String, from_key: String, to_key: String,
		reason: GameEnums.MovementReason = GameEnums.MovementReason.COVER) -> Movement:
	return Movement.new(GameEnums.TeamSide.HOME, player_id, PitchArea.from_key(from_key), PitchArea.from_key(to_key), reason)


func test_preview_rings_continue_the_row_of_pieces_in_the_destination() -> void:
	# D1-C には自分の p1 がいる。A1-C の p2 と A1-L1 の p3 が D1-C へ動くと、輪は p1 の隣から順に並ぶ
	_board.show_snapshot(_preview_snapshot({"p1": "D1-C", "p2": "A1-C", "p3": "A1-L1"}))
	_board.show_preview([_move("p2", "A1-C", "D1-C"), _move("p3", "A1-L1", "D1-C")])
	assert_int(_board.preview_movements().size()).is_equal(2)
	assert_vector(_board.preview_center(0)).is_equal(_board.piece_center("D1-C", true, 1))
	assert_vector(_board.preview_center(1)).is_equal(_board.piece_center("D1-C", true, 2))
	# 駒は動かさない（相手の駒も、自分の駒も、いまの位置のまま）
	assert_int((_board.pieces_in("A1-C")["user"] as Array).size()).is_equal(1)
	assert_int((_board.pieces_in("D1-C")["opponent"] as Array).size()).is_equal(1)


func test_preview_rings_stop_at_the_last_slot_of_a_crowded_area() -> void:
	_board.show_snapshot(_preview_snapshot({"p1": "D1-C", "p2": "D1-C", "p3": "D1-C", "p4": "D1-C", "p5": "A1-C"}))
	_board.show_preview([_move("p5", "A1-C", "D1-C")])
	assert_vector(_board.preview_center(0)).is_equal(_board.piece_center("D1-C", true, TacticsBoard.MAX_PIECES - 1))


func test_preview_keeps_every_reason_and_is_cleared_with_the_overlays() -> void:
	# 開示後の矢印と違い、プレビューは方式の動き（リトリート・マークの付け直し）も出す
	_board.show_snapshot(_preview_snapshot({"p1": "A1-C", "p2": "A1-L1"}))
	_board.show_preview([_move("p1", "A1-C", "D1-C", GameEnums.MovementReason.RETREAT_RESET),
			_move("p2", "A1-L1", "A1-C", GameEnums.MovementReason.MARK)])
	assert_int(_board.preview_movements().size()).is_equal(2)
	_board.clear_overlays()
	assert_array(_board.preview_movements()).is_empty()


func test_preview_arrows_start_from_the_piece_of_the_moving_player() -> void:
	# A1-C の自分の駒は盤面の選手の順に p0・p2。p2 の矢印は2つ目の駒から出る
	_board.show_snapshot(_preview_snapshot({"p0": "A1-C", "p1": "D1-C", "p2": "A1-C"}))
	_board.show_preview([_move("p2", "A1-C", "D1-C")])
	assert_vector(_board.preview_origin(0)).is_equal(_board.piece_center("A1-C", true, 1))


# --- 開示で駒を動かす ---

func _players_of(spec: Dictionary) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player_id: String in spec:
		players.append({"player_id": player_id, "number": 0, "area": spec[player_id]})
	return players


## 動いた後の盤面: 自分 p1 D1-C・p2 A1-C・p3 A1-L1・p4 A2-C、相手 o1 A1-C
func _shift_board(duration_sec: float) -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "D1-C", "p2": "A1-C", "p3": "A1-L1", "p4": "A2-C"})
	snapshot.opponent_players = _players_of({"o1": "A1-C"})
	_board.show_snapshot(snapshot)
	# 動く前: p2 は D1-C（p1 の次）、o1 は A2-C。p1・p3 は動かない。p4 は動く前に居ない（動かさない）
	_board.start_shift(_players_of({"p1": "D1-C", "p2": "D1-C", "p3": "A1-L1"}), _players_of({"o1": "A2-C"}), "", duration_sec)


func _path_of(player_id: String) -> Dictionary:
	for path: Dictionary in _board.shift_paths():
		if path["player_id"] == player_id:
			return path
	return {}


func test_shift_moves_only_the_players_whose_area_changed_in_both_teams() -> void:
	_shift_board(1.0)
	assert_bool(_board.is_shifting()).is_true()
	var moved: Array[String] = []
	for path: Dictionary in _board.shift_paths():
		moved.append(path["player_id"] as String)
	assert_array(moved).contains_exactly_in_any_order(["p2", "o1"])


func test_shift_runs_from_the_row_slot_before_to_the_row_slot_after() -> void:
	_shift_board(1.0)
	# p2 は動く前の D1-C で自分の2つ目、動いた後の A1-C で自分の1つ目
	assert_vector(_path_of("p2")["from"] as Vector2).is_equal(_board.piece_center("D1-C", true, 1))
	assert_vector(_path_of("p2")["to"] as Vector2).is_equal(_board.piece_center("A1-C", true, 0))
	assert_vector(_path_of("o1")["from"] as Vector2).is_equal(_board.piece_center("A2-C", false, 0))
	assert_vector(_path_of("o1")["to"] as Vector2).is_equal(_board.piece_center("A1-C", false, 0))


func test_shift_stops_on_the_next_snapshot_or_when_the_overlays_are_cleared() -> void:
	_shift_board(1.0)
	_board.show_snapshot(BoardSnapshot.new())
	assert_bool(_board.is_shifting()).is_false()
	assert_array(_board.shift_paths()).is_empty()
	_shift_board(1.0)
	_board.clear_overlays()
	assert_bool(_board.is_shifting()).is_false()
	assert_array(_board.shift_paths()).is_empty()


func test_shift_with_no_time_does_not_move() -> void:
	_shift_board(0.0)
	assert_bool(_board.is_shifting()).is_false()
	assert_array(_board.shift_paths()).is_empty()


func test_a_player_who_only_moves_along_the_row_is_shifted_too() -> void:
	# p1 が D1-C から出ていくと、D1-C に残る p2 は列の2つ目から1つ目へ詰まる（エリアは同じでも、駒は動く）
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C", "p2": "D1-C"})
	_board.show_snapshot(snapshot)
	_board.start_shift(_players_of({"p1": "D1-C", "p2": "D1-C"}), [], "", 1.0)
	assert_vector(_path_of("p2")["from"] as Vector2).is_equal(_board.piece_center("D1-C", true, 1))
	assert_vector(_path_of("p2")["to"] as Vector2).is_equal(_board.piece_center("D1-C", true, 0))
	assert_int(_board.shift_paths().size()).is_equal(2)


func test_shift_ends_by_itself_after_the_duration() -> void:
	_shift_board(0.05)
	assert_bool(_board.is_shifting()).is_true()
	await await_millis(300)
	assert_bool(_board.is_shifting()).is_false()
	assert_array(_board.shift_paths()).is_empty()


# --- 開示でボールを動かす ---

## ボールの位置が key のエリアの上側の中央にあること（screen-common.md: ボールはエリアの上側の中央。
## 実装の式を写さず、エリア・横の中央・上半分で確かめる）
func _assert_ball_in(point: Vector2, key: String) -> void:
	var rect: Rect2 = _board.area_rect(key)
	assert_str(_board.plan_area_at(point)).override_failure_message(key).is_equal(key)
	assert_float(point.x).override_failure_message(key).is_equal_approx(rect.get_center().x, 0.001)
	assert_float(point.y).override_failure_message(key).is_less(rect.get_center().y)


func _ball_board(ball_after: String, ball_before: String, user_before: Dictionary, duration_sec: float = 1.0) -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C"})
	snapshot.ball_area = ball_after
	_board.show_snapshot(snapshot)
	_board.start_shift(_players_of(user_before), [], ball_before, duration_sec)


func test_the_ball_moves_with_the_pieces_from_its_area_before_the_turn() -> void:
	_ball_board("A2-C", "A1-C", {"p1": "D1-C"})
	var path: Dictionary = _board.shift_ball_path()
	_assert_ball_in(path["from"] as Vector2, "A1-C")
	_assert_ball_in(path["to"] as Vector2, "A2-C")
	# 動き始めは判定前の位置に描く
	assert_vector(_board.ball_center()).is_equal(path["from"] as Vector2)


func test_the_ball_alone_moves_when_no_piece_does() -> void:
	_ball_board("A2-C", "A1-C", {"p1": "A1-C"})
	assert_array(_board.shift_paths()).is_empty()
	assert_bool(_board.is_shifting()).is_true()
	assert_dict(_board.shift_ball_path()).is_not_empty()
	# 駒は動いていないので、駒はいつもの描き方（エリアごとの列と「+N」）のまま
	assert_bool(_board.is_shifting_pieces()).is_false()


func test_the_ball_does_not_move_without_a_readable_area_or_time() -> void:
	# 判定前のキーが読めない
	_ball_board("A2-C", "X-9", {"p1": "A1-C"})
	assert_dict(_board.shift_ball_path()).is_empty()
	assert_bool(_board.is_shifting()).is_false()
	# いまの盤面にボールが無い
	_ball_board("", "A1-C", {"p1": "A1-C"})
	assert_dict(_board.shift_ball_path()).is_empty()
	# 時間が 0
	_ball_board("A2-C", "A1-C", {"p1": "A1-C"}, 0.0)
	assert_dict(_board.shift_ball_path()).is_empty()
	assert_bool(_board.is_shifting()).is_false()


func test_the_ball_stays_when_its_area_does_not_change() -> void:
	_ball_board("A1-C", "A1-C", {"p1": "D1-C"})
	assert_dict(_board.shift_ball_path()).is_empty()
	assert_bool(_board.is_shifting()).is_true()
	_board.clear_overlays()
	# 判定前のボールが無い（空文字）ときも動かさない
	_ball_board("A1-C", "", {"p1": "A1-C"})
	assert_dict(_board.shift_ball_path()).is_empty()
	assert_bool(_board.is_shifting()).is_false()


func test_the_ball_is_drawn_where_it_now_is_after_the_shift_stops() -> void:
	_ball_board("A2-C", "A1-C", {"p1": "D1-C"}, 0.05)
	await await_millis(300)
	assert_bool(_board.is_shifting()).is_false()
	assert_dict(_board.shift_ball_path()).is_empty()
	_assert_ball_in(_board.ball_center(), "A2-C")
	_ball_board("A2-C", "A1-C", {"p1": "D1-C"})
	_board.show_snapshot(BoardSnapshot.new())
	assert_dict(_board.shift_ball_path()).is_empty()


# --- 立っているもの（駒・プレビューの駒・ボール・「+N」）を描く順 ---

func test_standing_things_are_drawn_from_the_far_side_to_the_near_side() -> void:
	# 奥（敵陣）の駒が先、手前（自陣）の駒が後。手前の駒が奥の駒に重なって描かれる
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"near": "D1-C", "far": "A2-C", "mid": "A1-L2"})
	snapshot.opponent_players = _players_of({"o_far": "A2-R2"})
	snapshot.ball_area = "A1-C"
	_board.show_snapshot(snapshot)
	_board.show_preview([_move("mid", "A1-L2", "D1-L2", GameEnums.MovementReason.PRESS)])
	var order: Array[Dictionary] = _board.standing_order()
	# 駒 4（自分3・相手1）＋プレビューの駒 1＋ボール 1
	assert_int(order.size()).is_equal(6)
	for index: int in range(1, order.size()):
		assert_float((order[index - 1]["plan"] as Vector2).y).override_failure_message(str(index)) \
				.is_less_equal((order[index]["plan"] as Vector2).y)
	assert_array(["A2-C", "A2-R2"]).contains([_board.plan_area_at(order[0]["plan"] as Vector2)])
	assert_array(["D1-C", "D1-L2"]).contains([_board.plan_area_at(order[order.size() - 1]["plan"] as Vector2)])
	var kinds: Array[String] = []
	var previews: int = 0
	for thing: Dictionary in order:
		kinds.append(thing["kind"] as String)
		if thing.get("is_preview", false):
			previews += 1
	assert_int(kinds.count("ball")).is_equal(1)
	assert_int(previews).is_equal(1)


func test_standing_things_in_a_crowded_area_end_with_the_overflow_tag() -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "D1-C", "p2": "D1-C", "p3": "D1-C", "p4": "D1-C", "p5": "D1-C"})
	_board.show_snapshot(snapshot)
	var pieces: int = 0
	var tags: Array[String] = []
	for thing: Dictionary in _board.standing_order():
		if thing["kind"] == "piece":
			pieces += 1
		elif thing["kind"] == "tag":
			tags.append(thing["text"] as String)
	assert_int(pieces).is_equal(TacticsBoard.MAX_PIECES - 1)
	assert_array(tags).is_equal(["+2"])


func test_points_far_outside_the_pitch_select_nothing() -> void:
	# 押した後に盤面の外で離すと、離した点が届く。上の余白のすぐ上・ずっと上（逆の写し方の判別式が負）・
	# 手前の行の台形の外（左下の角の外）は、どれもエリアにならない
	assert_str(_board.area_at(Vector2(BOARD_SIZE.x / 2.0, -10.0))).is_empty()
	assert_str(_board.area_at(Vector2(BOARD_SIZE.x / 2.0, -BOARD_SIZE.y))).is_empty()
	assert_str(_board.area_at(Vector2(-5.0, BOARD_SIZE.y - 2.0))).is_empty()


func test_standing_things_follow_the_shift_while_pieces_are_moving() -> void:
	# 開示で駒が動いている間は、駒を道筋の途中に置いて、奥から手前の順に並べる
	_shift_board(1.0)
	assert_bool(_board.is_shifting_pieces()).is_true()
	var order: Array[Dictionary] = _board.standing_order()
	var plans: Array[Vector2] = []
	for thing: Dictionary in order:
		if thing["kind"] == "piece":
			plans.append(thing["plan"] as Vector2)
	# 動いている p2 は、道筋の途中（始めの時点では移動元）に置かれる
	assert_array(plans).contains([_path_of("p2")["from"] as Vector2])
	assert_int(plans.size()).is_equal(5)
	for index: int in range(1, order.size()):
		assert_float((order[index - 1]["plan"] as Vector2).y).is_less_equal((order[index]["plan"] as Vector2).y)

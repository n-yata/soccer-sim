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


func test_tally_is_drawn_on_every_area_with_a_text_and_cleared_with_the_overlays() -> void:
	# 振り返りの集計は、選べるエリアに関係なく札のあるエリアに描く。空の文は描かない
	_board.show_tally({"A2-C": "勝1", "M1-R1": "勝1 負1", "D1-L2": ""})
	assert_array(_board.drawn_tally_keys()).is_equal(["M1-R1", "A2-C"])
	assert_str(_board.tally_of("M1-R1")).is_equal("勝1 負1")
	assert_str(_board.tally_of("D2-C")).is_empty()
	# ヒントの札とは別に持つ
	assert_array(_board.drawn_hint_keys()).is_empty()
	_board.clear_overlays()
	assert_array(_board.drawn_tally_keys()).is_empty()


func test_tally_fits_the_narrowest_far_area_by_shrinking_the_font() -> void:
	# 2桁が3つ並ぶ札でも、いちばん奥の行のエリアの幅に収まる（下限の字の大きさを割らない）
	var text: String = ReviewTexts.tally_text([12, 10, 11])
	var font: Font = _board.get_theme_default_font()
	for board_size: Vector2 in [BOARD_SIZE, TacticsBoard.MIN_CELL * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)]:
		_board.size = board_size
		var rect: Rect2 = _board.area_rect("A2-L2")
		var room: float = _board.to_screen(Vector2(rect.end.x, rect.position.y)).x - _board.to_screen(rect.position).x
		var font_size: int = BoardPainter.tally_font_size(_board, "A2-L2", text)
		assert_int(font_size).override_failure_message(str(board_size)).is_greater_equal(BoardPainter.MIN_TALLY_FONT_SIZE)
		assert_float(BoardPainter.tag_width(font, text, font_size)).override_failure_message(str(board_size)) \
				.is_less_equal(room)
	# 手前の行の短い札は、ヒントの札と同じ大きさのまま
	var hint_size: int = _board.get_theme_font_size(&"hint_size", TacticsBoard.THEME_TYPE)
	assert_int(BoardPainter.tally_font_size(_board, "D1-C", "勝1")).is_equal(hint_size)


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


## 1拍だけで、動く前（user_before・opponent_before・ball_before）からいまの盤面へ動かす。
func _start_one(user_before: Array[Dictionary], opponent_before: Array[Dictionary], ball_before: String,
		duration_sec: float) -> void:
	_board.start_shift([_keyframe(user_before, opponent_before, ball_before, duration_sec)])


func _keyframe(user: Array[Dictionary], opponent: Array[Dictionary], ball: String, sec: float) -> Dictionary:
	return {"user": user, "opponent": opponent, "ball": ball, "sec": sec}


## 動いた後の盤面: 自分 p1 D1-C・p2 A1-C・p3 A1-L1・p4 A2-C、相手 o1 A1-C
func _shift_board(duration_sec: float) -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "D1-C", "p2": "A1-C", "p3": "A1-L1", "p4": "A2-C"})
	snapshot.opponent_players = _players_of({"o1": "A1-C"})
	_board.show_snapshot(snapshot)
	# 動く前: p2 は D1-C（p1 の次）、o1 は A2-C。p1・p3 は動かない。p4 は動く前に居ない（動かさない）
	_start_one(_players_of({"p1": "D1-C", "p2": "D1-C", "p3": "A1-L1"}), _players_of({"o1": "A2-C"}), "", duration_sec)


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
	_start_one(_players_of({"p1": "D1-C", "p2": "D1-C"}), [], "", 1.0)
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
	_start_one(_players_of(user_before), [], ball_before, duration_sec)


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


# --- 開示を2拍で動かす（1拍目 = 判定前 → 判定時、2拍目 = 判定時 → いまの盤面） ---

## 判定前: 自分 p1 M2-C・p2 M1-C、相手 o1 M2-C、ボール M2-C
func _before() -> Dictionary:
	return {"user": _players_of({"p1": "M2-C", "p2": "M1-C"}), "opponent": _players_of({"o1": "M2-C"}), "ball": "M2-C"}


## 判定時: p1 だけが A1-C へ運び、ボールも A1-C へ
func _at_judgement() -> Dictionary:
	return {"user": _players_of({"p1": "A1-C", "p2": "M1-C"}), "opponent": _players_of({"o1": "M2-C"}), "ball": "A1-C"}


## いまの盤面（次のターン開始時）: p2 が M2-C へ、o1 が A1-C へ詰め直す。ボールは A1-C のまま
func _two_beat_board(before: Dictionary, at_judgement: Dictionary, play_sec: float, settle_sec: float) -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C", "p2": "M2-C"})
	snapshot.opponent_players = _players_of({"o1": "A1-C"})
	snapshot.ball_area = "A1-C"
	_board.show_snapshot(snapshot)
	_board.start_shift([
		_keyframe(before["user"], before["opponent"], before["ball"], play_sec),
		_keyframe(at_judgement["user"], at_judgement["opponent"], at_judgement["ball"], settle_sec),
	])


func _ids_of(paths: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for path: Dictionary in paths:
		ids.append(path["player_id"] as String)
	return ids


func test_the_first_beat_moves_the_play_and_the_second_beat_moves_the_reshape() -> void:
	_two_beat_board(_before(), _at_judgement(), 1.0, 1.0)
	assert_int(_board.shift_beat_count()).is_equal(2)
	assert_int(_board.shift_beat_index()).is_equal(0)
	assert_array(_ids_of(_board.shift_beat_paths(0))).contains_exactly(["p1"])
	assert_array(_ids_of(_board.shift_beat_paths(1))).contains_exactly_in_any_order(["p2", "o1"])
	# いまの拍の問い合わせは、1拍目と同じ
	assert_array(_ids_of(_board.shift_paths())).contains_exactly(["p1"])
	var p1: Dictionary = _board.shift_beat_paths(0)[0]
	assert_vector(p1["from"] as Vector2).is_equal(_board.piece_center("M2-C", true, 0))
	assert_vector(p1["to"] as Vector2).is_equal(_board.piece_center("A1-C", true, 0))
	# 2拍目は判定時の位置から出る
	for path: Dictionary in _board.shift_beat_paths(1):
		if path["player_id"] == "p2":
			assert_vector(path["from"] as Vector2).is_equal(_board.piece_center("M1-C", true, 0))
			assert_vector(path["to"] as Vector2).is_equal(_board.piece_center("M2-C", true, 0))
		else:
			assert_vector(path["from"] as Vector2).is_equal(_board.piece_center("M2-C", false, 0))
			assert_vector(path["to"] as Vector2).is_equal(_board.piece_center("A1-C", false, 0))


func test_the_ball_moves_in_the_first_beat_and_stays_in_the_second() -> void:
	_two_beat_board(_before(), _at_judgement(), 1.0, 1.0)
	var path: Dictionary = _board.shift_beat_ball_path(0)
	_assert_ball_in(path["from"] as Vector2, "M2-C")
	_assert_ball_in(path["to"] as Vector2, "A1-C")
	assert_dict(_board.shift_beat_ball_path(1)).is_empty()
	assert_vector(_board.ball_center()).is_equal(path["from"] as Vector2)


func test_the_ball_moves_in_the_second_beat_when_the_next_turn_puts_it_elsewhere() -> void:
	# 判定時のボールが A2-C でも、次のターンは A1-C から（得点後のキックオフのように、置き直されるとき）
	var at_judgement: Dictionary = _at_judgement()
	at_judgement["ball"] = "A2-C"
	_two_beat_board(_before(), at_judgement, 1.0, 1.0)
	_assert_ball_in(_board.shift_beat_ball_path(0)["to"] as Vector2, "A2-C")
	var second: Dictionary = _board.shift_beat_ball_path(1)
	_assert_ball_in(second["from"] as Vector2, "A2-C")
	_assert_ball_in(second["to"] as Vector2, "A1-C")


func test_during_the_first_beat_players_who_move_later_wait_where_the_play_left_them() -> void:
	_two_beat_board(_before(), _at_judgement(), 1.0, 1.0)
	# p2・o1 は2拍目で動く。1拍目の間は、いまの盤面の位置へ飛ばず、判定時の位置（= 判定前と同じ）に描く
	assert_vector(_board.shifting_piece_center("p2", _board.piece_center("M2-C", true, 0))) \
			.is_equal(_board.piece_center("M1-C", true, 0))
	assert_vector(_board.shifting_piece_center("o1", _board.piece_center("A1-C", false, 0))) \
			.is_equal(_board.piece_center("M2-C", false, 0))
	# 駒は選手ごとに描く（1拍目に動く駒があり、2拍目にもある）
	assert_bool(_board.is_shifting_pieces()).is_true()


func test_pieces_are_drawn_one_by_one_when_only_a_later_beat_moves_them() -> void:
	# 1拍目はボールだけが動き、駒は2拍目で動く。1拍目の間も、2拍目で動く駒を判定時の位置に描くため、選手ごとに描く
	var at_judgement: Dictionary = _at_judgement()
	at_judgement["user"] = _players_of({"p1": "M2-C", "p2": "M1-C"})
	_two_beat_board(_before(), at_judgement, 1.0, 1.0)
	assert_array(_board.shift_paths()).is_empty()
	assert_dict(_board.shift_ball_path()).is_not_empty()
	assert_bool(_board.is_shifting_pieces()).is_true()


func test_a_beat_without_movement_is_skipped() -> void:
	# 判定時が判定前と同じ（1拍目に動きが無い）なら、2拍目だけ
	_two_beat_board(_before(), _before(), 1.0, 1.0)
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_array(_ids_of(_board.shift_paths())).contains_exactly_in_any_order(["p1", "p2", "o1"])
	_board.clear_overlays()
	# 判定時がいまの盤面と同じ（2拍目に動きが無い）なら、1拍目だけ
	var settled: Dictionary = {"user": _players_of({"p1": "A1-C", "p2": "M2-C"}),
			"opponent": _players_of({"o1": "A1-C"}), "ball": "A1-C"}
	_two_beat_board(_before(), settled, 1.0, 1.0)
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_array(_ids_of(_board.shift_paths())).contains_exactly_in_any_order(["p1", "p2", "o1"])


func test_a_beat_with_no_time_is_skipped() -> void:
	_two_beat_board(_before(), _at_judgement(), 0.0, 1.0)
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_array(_ids_of(_board.shift_paths())).contains_exactly_in_any_order(["p2", "o1"])
	_two_beat_board(_before(), _at_judgement(), 0.0, 0.0)
	assert_bool(_board.is_shifting()).is_false()
	assert_int(_board.shift_beat_count()).is_equal(0)
	# 時間が負・NaN の拍も飛ばす（NaN との比較は偽になるので、肯定形の「0 より大きい」で落ちる）
	_two_beat_board(_before(), _at_judgement(), -1.0, NAN)
	assert_bool(_board.is_shifting()).is_false()
	_two_beat_board(_before(), _at_judgement(), NAN, 1.0)
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_array(_ids_of(_board.shift_paths())).contains_exactly_in_any_order(["p2", "o1"])


func test_the_second_beat_starts_after_the_first_and_both_end_by_themselves() -> void:
	_two_beat_board(_before(), _at_judgement(), 0.05, 1.0)
	await await_millis(300)
	# 1拍目が終わり、2拍目の途中。p1 は動き終わりの位置
	assert_bool(_board.is_shifting()).is_true()
	assert_int(_board.shift_beat_index()).is_equal(1)
	assert_array(_ids_of(_board.shift_paths())).contains_exactly_in_any_order(["p2", "o1"])
	var p1_rest: Vector2 = _board.piece_center("A1-C", true, 0)
	assert_vector(_board.shifting_piece_center("p1", p1_rest)).is_equal(p1_rest)
	_two_beat_board(_before(), _at_judgement(), 0.05, 0.05)
	await await_millis(400)
	assert_bool(_board.is_shifting()).is_false()
	assert_int(_board.shift_beat_count()).is_equal(0)


func test_a_gap_between_beats_holds_the_second_beat_but_not_the_landing() -> void:
	var landed: Array[int] = []
	_board.play_landed.connect(func() -> void: landed.append(1))
	_board.set_beat_gap_sec(0.5)
	_two_beat_board(_before(), _at_judgement(), 0.05, 1.0)
	await await_millis(250)
	# 1拍目は終わって着地したが、小休止の間なので2拍目はまだ始まっていない（1拍目の終わりの位置のまま）
	assert_array(landed).has_size(1)
	assert_int(_board.shift_beat_index()).is_equal(0)
	var p1_landed: Vector2 = _board.piece_center("A1-C", true, 0)
	assert_vector(_board.shifting_piece_center("p1", Vector2.ZERO)).is_equal_approx(p1_landed, Vector2(0.001, 0.001))
	await await_millis(500)
	assert_int(_board.shift_beat_index()).is_equal(1)


func test_no_gap_is_left_after_the_last_beat_and_bad_gaps_mean_none() -> void:
	# 小休止は拍と拍の間だけ。2拍（0.05 秒ずつ）と小休止 0.5 秒なら、0.6 秒ほどで終わる（最後の拍の後にも置くと 1.1 秒）
	_board.set_beat_gap_sec(0.5)
	_two_beat_board(_before(), _at_judgement(), 0.05, 0.05)
	await await_millis(850)
	assert_bool(_board.is_shifting()).is_false()
	# 負・NaN・無限大の小休止は 0（置かない）
	for bad: float in [-1.0, NAN, INF]:
		_board.set_beat_gap_sec(bad)
		assert_float(_board.beat_gap_sec()).override_failure_message(str(bad)).is_equal(0.0)


func test_bad_piece_motion_values_mean_no_stagger_or_hop() -> void:
	# 有限でない値は 0。NaN のまま入れると駒の位置が NaN になる
	_board.set_piece_style({"stagger": NAN, "hop": INF})
	_two_beat_board(_before(), _at_judgement(), 1.0, 1.0)
	await await_millis(300)
	var position: Vector2 = _board.shifting_piece_center("p1", Vector2.ZERO)
	assert_bool(is_finite(position.x) and is_finite(position.y)).is_true()
	assert_float(_board.shifting_piece_lift("p1")).is_equal(0.0)
	# 負の値も 0。負の弾みで駒が地面より下へ沈み（影の計算が 0 で割れる）、負のずらしで拍の終わりに着かなくならない
	_board.set_piece_style({"stagger": -0.5, "hop": -1.0})
	# 1拍目（0.3 秒）の終わりの位置を、長い小休止の間（1拍目の進み具合が 1 のまま）に確かめる
	_board.set_beat_gap_sec(0.5)
	_two_beat_board(_before(), _at_judgement(), 0.3, 1.0)
	await await_millis(150)
	assert_float(_board.shifting_piece_lift("p1")).is_greater_equal(0.0)
	await await_millis(300)
	assert_int(_board.shift_beat_index()).is_equal(0)
	var p1_landed: Vector2 = _board.piece_center("A1-C", true, 0)
	assert_vector(_board.shifting_piece_center("p1", Vector2.ZERO)).is_equal_approx(p1_landed, Vector2(0.001, 0.001))


func test_moving_pieces_are_drawn_at_their_lift() -> void:
	_board.set_piece_style({"stagger": 0.0, "hop": 0.5})
	_two_beat_board(_before(), _at_judgement(), 1.0, 1.0)
	# 動き始めは地面
	for thing: Dictionary in _board.standing_order():
		if thing["kind"] == "piece":
			assert_float(thing["lift"] as float).is_equal_approx(0.0, 0.0001)
	await await_millis(500)
	# 1拍目の途中: 動いている p1 は浮き、動いていない駒は地面。描く高さは shifting_piece_lift と同じ
	var lifts: Dictionary = {}
	for thing: Dictionary in _board.standing_order():
		if thing["kind"] == "piece":
			lifts[thing["plan"]] = thing["lift"]
	assert_float(_board.shifting_piece_lift("p1")).is_greater(0.1)
	assert_array(lifts.values()).contains([_board.shifting_piece_lift("p1")])
	assert_float(_board.shifting_piece_lift("p2")).is_equal(0.0)
	_board.clear_overlays()
	assert_float(_board.shifting_piece_lift("p1")).is_equal(0.0)


# --- 結果の演出 ---

const Effect := ResultEffect.Kind


## 盤面: 自分 p1 A1-C、相手 o1 A2-C、ボール ball_now。1拍目は判定前 → 判定時（ball_play → ball_judge）、2拍目はいまの盤面へ。
## 駒は1拍目に p1 が M2-C から A1-C へ動く（1拍目の拍が残る）
func _result_board(ball_play: String, ball_judge: String, ball_now: String, result: Dictionary,
		play_sec: float = 1.0, p1_before: String = "M2-C") -> void:
	_board.set_result_sec(0.8)
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C"})
	snapshot.opponent_players = _players_of({"o1": "A2-C"})
	snapshot.ball_area = ball_now
	_board.show_snapshot(snapshot)
	var at_judgement: Array[Dictionary] = _players_of({"p1": "A1-C"})
	_board.start_shift([
		_keyframe(_players_of({"p1": p1_before}), _players_of({"o1": "A2-C"}), ball_play, play_sec),
		_keyframe(at_judgement, _players_of({"o1": "A2-C"}), ball_judge, 1.0),
	], result)


func _effect(kind: int, area: String, is_user: bool, toward: String = "") -> Dictionary:
	return {"kind": kind, "area": area, "is_user": is_user, "toward": toward}


func test_the_goal_mouths_are_inside_the_goals_at_the_top_and_bottom() -> void:
	for is_top: bool in [true, false]:
		var rect: Rect2 = _board.goal_rect(is_top)
		assert_bool(rect.has_point(_board.goal_mouth(is_top))).override_failure_message(str(is_top)).is_true()
		assert_float(rect.get_center().x).is_equal_approx(BOARD_SIZE.x / 2.0, 0.001)
	# 上のゴールは上端、下のゴールは下端
	assert_float(_board.goal_rect(true).position.y).is_equal(0.0)
	assert_float(_board.goal_rect(false).end.y).is_equal_approx(BOARD_SIZE.y, 0.001)


func test_a_goal_shoots_the_ball_into_the_goal_and_kicks_off_from_there() -> void:
	# 決めたエリア A1-C（判定前も判定時も同じ）→ 上のゴール。2拍目はゴールからキックオフの位置 M1-C へ
	_result_board("A1-C", "A1-C", "M1-C", _effect(Effect.GOAL, "A1-C", true))
	var shot: Dictionary = _board.shift_beat_ball_path(0)
	_assert_ball_in(shot["from"] as Vector2, "A1-C")
	assert_vector(shot["to"] as Vector2).is_equal(_board.goal_mouth(true))
	assert_int(shot["flight"] as int).is_equal(BallFlight.Kind.DRIVEN)
	var kickoff: Dictionary = _board.shift_beat_ball_path(1)
	assert_vector(kickoff["from"] as Vector2).is_equal(_board.goal_mouth(true))
	_assert_ball_in(kickoff["to"] as Vector2, "M1-C")


func test_a_goal_by_the_opponent_goes_into_the_bottom_goal() -> void:
	_result_board("D1-C", "D1-C", "M1-C", _effect(Effect.GOAL, "D1-C", false))
	assert_vector(_board.shift_beat_ball_path(0)["to"] as Vector2).is_equal(_board.goal_mouth(false))
	assert_vector(_board.shift_beat_ball_path(1)["from"] as Vector2).is_equal(_board.goal_mouth(false))


func test_a_goal_makes_a_kickoff_path_when_the_second_beat_had_no_ball_path() -> void:
	# 判定時のボールが次のターンの位置と同じ M1-C（2拍目にボールの道筋が無い）でも、ゴールの口から M1-C へ戻す
	_result_board("A1-C", "M1-C", "M1-C", _effect(Effect.GOAL, "A1-C", true))
	var kickoff: Dictionary = _board.shift_beat_ball_path(1)
	assert_vector(kickoff["from"] as Vector2).is_equal(_board.goal_mouth(true))
	_assert_ball_in(kickoff["to"] as Vector2, "M1-C")


func test_a_goal_with_one_beat_or_an_unreadable_start_keeps_to_what_it_can() -> void:
	# 1拍だけなら、ゴールの口で終わる（2拍目を作らない）
	_board.set_result_sec(0.8)
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C"})
	snapshot.ball_area = "M1-C"
	_board.show_snapshot(snapshot)
	_board.start_shift([_keyframe(_players_of({"p1": "A1-C"}), [], "A1-C", 1.0)], _effect(Effect.GOAL, "A1-C", true))
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_vector(_board.shift_beat_ball_path(0)["to"] as Vector2).is_equal(_board.goal_mouth(true))
	# 1拍目の始まりのボールが読めなければ、道筋を変えない（ボールは動かない）
	_board.start_shift([_keyframe(_players_of({"p1": "A1-C"}), [], "X-9", 1.0)], _effect(Effect.GOAL, "A1-C", true))
	assert_bool(_board.is_shifting()).is_false()


func test_a_stall_bounces_the_ball_toward_the_target_and_back() -> void:
	# ボールは M2-C のまま。運ぶ先 A1-C の方へ跳ね返る
	_result_board("M2-C", "M2-C", "M2-C", _effect(Effect.STALL, "M2-C", false, "A1-C"))
	var bounce: Dictionary = _board.shift_beat_ball_path(0)
	_assert_ball_in(bounce["from"] as Vector2, "M2-C")
	_assert_ball_in(bounce["to"] as Vector2, "A1-C")
	assert_int(bounce["flight"] as int).is_equal(BallFlight.Kind.BOUNCE)
	# 2拍目のボールは動かない
	assert_dict(_board.shift_beat_ball_path(1)).is_empty()


func test_the_play_lands_once_at_the_end_of_the_first_beat_and_shows_the_effect() -> void:
	var landed: Array[int] = []
	_board.play_landed.connect(func() -> void: landed.append(1))
	var lost: Dictionary = _effect(Effect.WIN_BALL, "A1-C", false)
	_result_board("M2-C", "A1-C", "A1-C", lost, 0.05)
	assert_array(landed).is_empty()
	assert_dict(_board.result_effect()).is_empty()
	await await_millis(300)
	# 1拍目が終わった（この場面は2拍目に動きが無いので、動きも止まっている）。着地は1回、演出が出ている
	assert_bool(_board.is_shifting()).is_false()
	assert_array(landed).has_size(1)
	assert_dict(_board.result_effect()).is_equal(lost)
	assert_float(_board.result_progress()).is_between(0.0, 1.0)
	# 演出の時間（0.8 秒）が過ぎたら消える。着地は二重に出ない
	await await_millis(900)
	assert_dict(_board.result_effect()).is_empty()
	assert_array(landed).has_size(1)
	# 着地の後に盤面を消しても、次の盤面を出しても、着地はもう出ない
	_board.clear_overlays()
	_board.show_snapshot(BoardSnapshot.new())
	assert_array(landed).has_size(1)


func test_the_play_lands_at_once_without_a_first_beat() -> void:
	var landed: Array[int] = []
	_board.play_landed.connect(func() -> void: landed.append(1))
	# 1拍目に駒もボールも動かない（p1 は判定前から A1-C、ボールも同じ）
	_result_board("A1-C", "A1-C", "A1-C", _effect(Effect.NONE, "", false), 1.0, "A1-C")
	assert_array(landed).has_size(1)
	assert_dict(_board.result_effect()).is_empty()
	# 1拍目は無いが2拍目はある（ボールだけが次のターンの位置 M1-C へ動く）ときも、すぐ着地する
	_result_board("A1-C", "A1-C", "M1-C", _effect(Effect.NONE, "", false), 1.0, "A1-C")
	assert_int(_board.shift_beat_count()).is_equal(1)
	assert_bool(_board.is_shifting()).is_true()
	assert_array(landed).has_size(2)


func test_stopping_before_the_landing_still_lands_but_shows_no_effect() -> void:
	var landed: Array[int] = []
	_board.play_landed.connect(func() -> void: landed.append(1))
	_result_board("M2-C", "A1-C", "A1-C", _effect(Effect.WIN_BALL, "A1-C", false))
	_board.clear_overlays()
	assert_array(landed).has_size(1)
	assert_dict(_board.result_effect()).is_empty()
	# もう一度消しても、二重に出ない
	_board.clear_overlays()
	assert_array(landed).has_size(1)


func test_the_effect_is_cleared_with_the_overlays_and_the_next_snapshot() -> void:
	_result_board("M2-C", "A1-C", "A1-C", _effect(Effect.OFFSIDE, "A1-C", false), 0.05)
	await await_millis(300)
	assert_dict(_board.result_effect()).is_not_empty()
	_board.clear_overlays()
	assert_dict(_board.result_effect()).is_empty()
	_result_board("M2-C", "A1-C", "A1-C", _effect(Effect.OFFSIDE, "A1-C", false), 0.05)
	await await_millis(300)
	_board.show_snapshot(BoardSnapshot.new())
	assert_dict(_board.result_effect()).is_empty()


func test_without_a_result_time_the_landing_shows_no_effect() -> void:
	# 時間を入れていない盤面（振り返りなど）では、着地しても演出を出さない
	var landed: Array[int] = []
	_board.play_landed.connect(func() -> void: landed.append(1))
	_result_board("M2-C", "A1-C", "A1-C", _effect(Effect.WIN_BALL, "A1-C", false), 0.05)
	_board.set_result_sec(0.0)
	await await_millis(300)
	assert_array(landed).has_size(1)
	assert_dict(_board.result_effect()).is_empty()


func test_a_stall_or_no_effect_draws_nothing_on_landing() -> void:
	_result_board("M2-C", "M2-C", "M2-C", _effect(Effect.STALL, "M2-C", false, "A1-C"), 0.05)
	await await_millis(300)
	assert_dict(_board.result_effect()).is_empty()


# --- 1拍目のボールの軌道 ---

func test_the_first_beat_carries_the_flight_of_its_keyframe_and_the_ball_is_drawn_at_its_lift() -> void:
	_board.set_ball_style({"loft": 6.0, "touch": 1.0, "touches": 3})
	var snapshot := BoardSnapshot.new()
	snapshot.user_players = _players_of({"p1": "A1-C"})
	snapshot.ball_area = "A1-C"
	_board.show_snapshot(snapshot)
	var before: Dictionary = _before()
	var first: Dictionary = _keyframe(before["user"], before["opponent"], before["ball"], 1.0)
	first["flight"] = BallFlight.Kind.LOFTED
	_board.start_shift([first])
	assert_int(_board.shift_ball_path()["flight"] as int).is_equal(BallFlight.Kind.LOFTED)
	# 動き始めは地面
	assert_float(_board.ball_lift()).is_equal_approx(0.0, 0.0001)
	# 浮き球の途中で、ボールが浮き、描くボールの高さも同じだけ浮く
	await await_millis(500)
	var lift: float = _board.ball_lift()
	assert_float(lift).is_greater(1.0)
	assert_array(_drawn_ball_lifts()).is_equal([lift])
	_board.clear_overlays()
	assert_float(_board.ball_lift()).is_equal(0.0)
	assert_array(_drawn_ball_lifts()).is_equal([0.0])


func _drawn_ball_lifts() -> Array[float]:
	var lifts: Array[float] = []
	for thing: Dictionary in _board.standing_order():
		if thing["kind"] == "ball":
			lifts.append(thing["lift"] as float)
	return lifts


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

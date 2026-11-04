## BoardGeometry（作戦ボードの平面図での位置の計算）のテスト。大きさだけから決まる計算を、ボードを木に載せずに確かめる。
## ボードを通した見え方（駒の並び・ボールの位置）は tactics_board_test で確かめる。
extends GdUnitTestSuite

## 1エリアが 136 × 100 になる大きさ（5レーン × 6列）
const SIZE := Vector2(680, 600)


func test_area_rects_tile_the_pitch_with_the_user_attacking_upward() -> void:
	assert_vector(BoardGeometry.cell_size(SIZE)).is_equal(Vector2(136, 100))
	# 左上は敵陣ゴール前・左大外、右下は自陣ゴール前・右大外
	assert_object(BoardGeometry.area_rect("A2-L2", SIZE)).is_equal(Rect2(0, 0, 136, 100))
	assert_object(BoardGeometry.area_rect("D1-R2", SIZE)).is_equal(Rect2(544, 500, 136, 100))
	assert_object(BoardGeometry.area_rect("X-9", SIZE)).is_equal(Rect2())


func test_points_map_back_to_their_area_and_points_outside_the_pitch_to_none() -> void:
	for key: String in ["A2-L2", "M1-C", "D1-R2"]:
		var center: Vector2 = BoardGeometry.area_rect(key, SIZE).get_center()
		assert_str(BoardGeometry.plan_area_at(center, SIZE)).override_failure_message(key).is_equal(key)
	# 右端・下端ちょうどはピッチの外（矩形は端を含まない）。左上の角はピッチの中
	assert_str(BoardGeometry.plan_area_at(Vector2(SIZE.x, 10), SIZE)).is_empty()
	assert_str(BoardGeometry.plan_area_at(Vector2(10, SIZE.y), SIZE)).is_empty()
	assert_str(BoardGeometry.plan_area_at(Vector2(-1, 10), SIZE)).is_empty()
	assert_str(BoardGeometry.plan_area_at(Vector2.ZERO, SIZE)).is_equal("A2-L2")


func test_the_goals_sit_at_the_top_and_bottom_center() -> void:
	var top: Rect2 = BoardGeometry.goal_rect(true, SIZE)
	var bottom: Rect2 = BoardGeometry.goal_rect(false, SIZE)
	assert_float(top.position.y).is_equal(0.0)
	assert_float(bottom.end.y).is_equal(SIZE.y)
	assert_float(top.get_center().x).is_equal_approx(SIZE.x / 2.0, 0.001)
	assert_float(top.size.x).is_equal_approx(SIZE.x * BoardGeometry.GOAL_WIDTH_RATE, 0.001)


func test_the_ball_sits_in_the_upper_middle_of_its_area() -> void:
	var rect: Rect2 = BoardGeometry.area_rect("M2-C", SIZE)
	var point: Vector2 = BoardGeometry.ball_point("M2-C", SIZE)
	assert_float(point.x).is_equal(rect.get_center().x)
	assert_float(point.y).is_between(rect.position.y, rect.get_center().y)


func test_pieces_line_up_on_their_own_side_and_stop_at_the_last_slot() -> void:
	var center_x: float = BoardGeometry.area_rect("M1-C", SIZE).get_center().x
	for index: int in range(BoardGeometry.MAX_PIECES):
		assert_float(BoardGeometry.piece_center("M1-C", true, index, SIZE).x).is_less(center_x)
		assert_float(BoardGeometry.piece_center("M1-C", false, index, SIZE).x).is_greater(center_x)
	# 添字 0・1 は奥の段、2・3 は手前の段
	assert_float(BoardGeometry.piece_center("M1-C", true, 2, SIZE).y) \
			.is_greater(BoardGeometry.piece_center("M1-C", true, 0, SIZE).y)
	# 列に収まらない添字は、最後の位置で止める
	var last: Vector2 = BoardGeometry.piece_center("M1-C", true, BoardGeometry.MAX_PIECES - 1, SIZE)
	assert_vector(BoardGeometry.slot_center("M1-C", true, BoardGeometry.MAX_PIECES + 3, SIZE)).is_equal(last)


func test_pieces_shrink_on_a_narrow_board_so_two_columns_still_fit_in_half_an_area() -> void:
	# 広い盤では上限の間隔と直径。狭い盤では、中央の余白と端の余白を除いた半分に2列が収まるよう縮める
	# 1エリアの幅 160 なら、半分 80 に中央の余白 6・端の余白 2・2列 × 36 がちょうど収まる
	var wide := Vector2(800, 600)
	assert_float(BoardGeometry.piece_step(wide)).is_equal(BoardGeometry.PIECE_STEP)
	assert_float(BoardGeometry.piece_radius(wide)).is_equal(BoardGeometry.PIECE_DIAMETER / 2.0)
	var narrow := Vector2(300, 600)
	var half_width: float = BoardGeometry.cell_size(narrow).x / 2.0
	var step: float = BoardGeometry.piece_step(narrow)
	assert_float(step).is_less(BoardGeometry.PIECE_STEP)
	assert_float(BoardGeometry.PIECE_CENTER_GAP + step * BoardGeometry.PIECE_COLUMNS + BoardGeometry.PIECE_EDGE_MARGIN) \
			.is_less_equal(half_width + 0.001)
	assert_float(BoardGeometry.piece_radius(narrow)).is_less(step / 2.0)

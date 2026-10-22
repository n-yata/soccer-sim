## BoardProjection（作戦ボードの遠近の写し方。平面図 ⇔ 画面）のテスト。
## 平面図は縦向きのピッチを真上から見た図（上が敵陣）。画面は奥（上）ほど狭く・縦を詰めて描く。
extends GdUnitTestSuite

const SIZE: Vector2 = Vector2(726, 575)


func _screen(plan: Vector2) -> Vector2:
	return BoardProjection.to_screen(plan, SIZE)


func test_a_point_goes_to_the_screen_and_back_to_the_same_plan_point() -> void:
	for x: float in [0.0, 100.0, SIZE.x / 2.0, 600.0, SIZE.x]:
		for y: float in [0.0, 50.0, SIZE.y / 3.0, SIZE.y / 2.0, 500.0, SIZE.y]:
			var plan := Vector2(x, y)
			assert_vector(BoardProjection.to_plan(_screen(plan), SIZE)).override_failure_message(str(plan)) \
					.is_equal_approx(plan, Vector2(0.01, 0.01))


func test_the_near_edge_fills_the_width_and_the_far_edge_is_narrower() -> void:
	# 手前（下端）は幅いっぱい・下端に届く
	assert_vector(_screen(Vector2(0, SIZE.y))).is_equal_approx(Vector2(0, SIZE.y), Vector2(0.01, 0.01))
	assert_vector(_screen(SIZE)).is_equal_approx(SIZE, Vector2(0.01, 0.01))
	# 奥（上端）は中央へ寄って狭く、上の余白の分だけ下がる
	var far_left: Vector2 = _screen(Vector2.ZERO)
	var far_right: Vector2 = _screen(Vector2(SIZE.x, 0))
	assert_float(far_right.x - far_left.x).is_equal_approx(SIZE.x * BoardProjection.FAR_SCALE, 0.01)
	assert_float(far_left.y).is_equal_approx(SIZE.y * BoardProjection.TOP_MARGIN_RATE, 0.01)
	assert_float(BoardProjection.scale_at(far_left.y, SIZE)).is_equal_approx(BoardProjection.FAR_SCALE, 0.001)
	assert_float(BoardProjection.scale_at(SIZE.y, SIZE)).is_equal_approx(1.0, 0.001)


func test_far_rows_are_squeezed_more_than_near_rows() -> void:
	# 平面図で同じ高さの3行が、画面では奥ほど低くなる
	var row: float = SIZE.y / 3.0
	var heights: Array[float] = []
	for index: int in range(3):
		heights.append(_screen(Vector2(0, row * (index + 1))).y - _screen(Vector2(0, row * index)).y)
	assert_float(heights[0]).is_less(heights[1])
	assert_float(heights[1]).is_less(heights[2])


func test_vertical_lines_of_the_plan_stay_straight() -> void:
	# 平面図の縦の線の中点は、写した後も両端を結ぶ線の上にある（エリアの境界を直線で描いてよい）
	for x: float in [0.0, 145.0, 400.0, SIZE.x]:
		var top: Vector2 = _screen(Vector2(x, 0))
		var bottom: Vector2 = _screen(Vector2(x, SIZE.y))
		for y: float in [100.0, SIZE.y / 2.0, 450.0]:
			var middle: Vector2 = _screen(Vector2(x, y))
			var cross: float = (bottom - top).cross(middle - top)
			assert_float(absf(cross) / (bottom - top).length()).override_failure_message("%s %s" % [x, y]).is_less(0.01)

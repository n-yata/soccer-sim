## PieceMotion（開示で駒が動くときの進み方と高さ）のテスト。
extends GdUnitTestSuite


func test_without_stagger_every_piece_follows_the_beat() -> void:
	for t: float in [0.0, 0.3, 1.0]:
		for order: float in [0.0, 0.5, 1.0]:
			assert_float(PieceMotion.local_t(t, order, 0.0)).is_equal_approx(t, 0.0001)


func test_with_stagger_the_far_pieces_start_later_and_all_arrive_together() -> void:
	# ずらしの幅 0.4: いちばん遠い駒（order 1）は 0.4 まで動かず、全員が拍の終わりにそろって着く
	assert_float(PieceMotion.local_t(0.3, 1.0, 0.4)).is_equal(0.0)
	assert_float(PieceMotion.local_t(0.4, 1.0, 0.4)).is_equal_approx(0.0, 0.0001)
	assert_float(PieceMotion.local_t(0.3, 0.0, 0.4)).is_equal_approx(0.5, 0.0001)
	assert_float(PieceMotion.local_t(0.5, 0.5, 0.4)).is_equal_approx(0.5, 0.0001)
	for order: float in [0.0, 0.5, 1.0]:
		assert_float(PieceMotion.local_t(1.0, order, 0.4)).override_failure_message(str(order)).is_equal_approx(1.0, 0.0001)
	# 近い駒ほど先に進む
	assert_float(PieceMotion.local_t(0.5, 0.0, 0.4)).is_greater(PieceMotion.local_t(0.5, 1.0, 0.4))


func test_a_stagger_of_one_or_more_does_not_divide_by_zero() -> void:
	# 遅れの幅が拍の時間をすべて使うと、動く時間が残らない。途中は動かず、拍の終わりに着く
	for stagger: float in [1.0, 1.5]:
		assert_float(PieceMotion.local_t(0.5, 0.0, stagger)).override_failure_message(str(stagger)).is_equal(0.0)
		assert_float(PieceMotion.local_t(1.0, 1.0, stagger)).override_failure_message(str(stagger)).is_equal(1.0)


func test_progress_outside_the_beat_is_held_at_the_ends() -> void:
	assert_float(PieceMotion.local_t(-0.1, 0.0, 0.4)).is_equal(0.0)
	assert_float(PieceMotion.local_t(1.1, 1.0, 0.4)).is_equal(1.0)


func test_easing_starts_and_stops_gently_and_is_symmetric() -> void:
	assert_float(PieceMotion.smooth(0.0)).is_equal(0.0)
	assert_float(PieceMotion.smooth(1.0)).is_equal(1.0)
	assert_float(PieceMotion.smooth(0.5)).is_equal_approx(0.5, 0.0001)
	# 出だしは等速より遅く、終わりは等速より先（そのぶん最後に減速する）
	assert_float(PieceMotion.smooth(0.2)).is_less(0.2)
	assert_float(PieceMotion.smooth(0.8)).is_greater(0.8)
	assert_float(PieceMotion.smooth(0.2) + PieceMotion.smooth(0.8)).is_equal_approx(1.0, 0.0001)


func test_a_moving_piece_hops_once_and_lands() -> void:
	assert_float(PieceMotion.hop(0.0, 0.35)).is_equal_approx(0.0, 0.0001)
	assert_float(PieceMotion.hop(1.0, 0.35)).is_equal_approx(0.0, 0.0001)
	assert_float(PieceMotion.hop(0.5, 0.35)).is_equal_approx(0.35, 0.0001)
	assert_float(PieceMotion.hop(0.5, 0.0)).is_equal(0.0)
	assert_float(PieceMotion.hop(1.2, 0.35)).is_greater_equal(0.0)

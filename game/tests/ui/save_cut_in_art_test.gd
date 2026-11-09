## シュートを止めた・止められたときのカットインの動きと時間割（SaveCutInArt）のテスト。
extends GdUnitTestSuite


func test_it_shows_the_goal_timeline_from_just_before_the_kick_to_after_the_catch() -> void:
	assert_float(SaveCutInArt.goal_p(0.0)).is_equal(SaveCutInArt.SAVE_FROM)
	assert_float(SaveCutInArt.goal_p(1.0)).is_equal_approx(SaveCutInArt.SAVE_FROM + SaveCutInArt.SAVE_SPAN, 0.0001)
	# 蹴る瞬間と、つかむ瞬間が見える範囲に入っている
	assert_float(SaveCutInArt.SAVE_FROM).is_less(GoalCutInArt.CONTACT_AT)
	assert_float(SaveCutInArt.catch_at()).is_between(0.2, 0.6)
	assert_float(SaveCutInArt.goal_p(SaveCutInArt.catch_at())).is_equal_approx(SaveCutInArt.CATCH_AT_GOAL, 0.0001)


func test_the_title_comes_after_the_catch_and_the_flash_only_for_the_users_save() -> void:
	var caught: float = SaveCutInArt.catch_at()
	assert_float(SaveCutInArt.frame(caught, true)["title_alpha"] as float).is_equal(0.0)
	assert_float(SaveCutInArt.frame(caught + 0.2, true)["title_alpha"] as float).is_equal(1.0)
	var flashing: float = caught + SaveCutInArt.FLASH_LEN / 2.0
	assert_float(SaveCutInArt.frame(flashing, true)["flash"] as float).is_greater(0.5)
	assert_float(SaveCutInArt.frame(flashing, false)["flash"] as float).is_equal(0.0)
	assert_float(SaveCutInArt.frame(1.0, true)["fade"] as float).is_equal(1.0)


func test_the_texts_tell_a_save_from_a_saved_shot() -> void:
	assert_dict(SaveCutInArt.texts(true)).is_equal(
			{"title": "SAVE!", "sub": "ポジティブトランジション", "score": "● シュートを止めた"})
	assert_dict(SaveCutInArt.texts(false)).is_equal(
			{"title": "SAVED", "sub": "ネガティブトランジション", "score": "● シュートを止められた"})


func test_the_ball_flies_to_the_catch_point_and_then_stays_in_the_hands() -> void:
	assert_vector(SaveCutInArt.ball_position(0.0)).is_equal(GoalCutInArt.BALL_SPOT)
	var caught: float = SaveCutInArt.catch_at()
	assert_vector(SaveCutInArt.ball_position(caught)).is_equal_approx(SaveCutInArt.CATCH_POINT, Vector3(0.001, 0.001, 0.001))
	assert_bool(SaveCutInArt.ball_in_hands(caught - 0.01)).is_false()
	assert_bool(SaveCutInArt.ball_in_hands(caught)).is_true()
	# つかむ点はゴールの枠の内側の手前（ゴールラインの前・ポストの間・バーの下）
	assert_float(SaveCutInArt.CATCH_POINT.x).is_greater(0.0)
	assert_float(absf(SaveCutInArt.CATCH_POINT.z)).is_less(GoalCutInArt.GOAL_HALF_WIDTH)
	assert_float(SaveCutInArt.CATCH_POINT.y).is_less(GoalCutInArt.GOAL_HEIGHT)


func test_the_shooter_kicks_like_the_goal_then_hangs_his_head_without_jumping() -> void:
	# 蹴るまでは得点と同じ動き
	var kick: float = (GoalCutInArt.CONTACT_AT - SaveCutInArt.SAVE_FROM) / SaveCutInArt.SAVE_SPAN
	assert_dict(SaveCutInArt.striker_motion(kick)).is_equal(GoalCutInArt.striker_motion(GoalCutInArt.CONTACT_AT))
	# 最後はうなだれる姿勢（素材の Yes で喜ばない）。足元は地面のまま（喜んで跳ばない）
	var last: Dictionary = SaveCutInArt.striker_motion(1.0)
	assert_str(last["clip"] as String).is_equal("Idle")
	assert_float(last["weight"] as float).is_equal(1.0)
	assert_float((last["pose"] as Dictionary)["head"] as float).is_equal_approx(SaveCutInArt.DEJECTED_POSE["head"] as float, 0.001)
	for p: float in [0.8, 0.9, 1.0]:
		assert_float(SaveCutInArt.striker_transform(p).origin.y).override_failure_message(str(p)).is_equal(0.0)


func test_the_keeper_moves_like_the_goal_keeper() -> void:
	for p: float in [0.0, 0.3, 0.6]:
		assert_bool(SaveCutInArt.keeper_transform(p).is_equal_approx(GoalCutInArt.keeper_model_transform(SaveCutInArt.goal_p(p)))) \
				.override_failure_message(str(p)).is_true()

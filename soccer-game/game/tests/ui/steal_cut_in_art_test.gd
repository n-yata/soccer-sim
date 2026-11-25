## ボールを奪った・奪われたときのカットインの動きと時間割（StealCutInArt）のテスト（見え方はスクリーンショットと、遊んで確かめる）。
extends GdUnitTestSuite


func test_the_timeline_runs_slide_contact_trip_title_then_fade() -> void:
	assert_float(StealCutInArt.BARS_IN_END).is_less(StealCutInArt.SLIDE_AT)
	assert_float(StealCutInArt.SLIDE_AT).is_less(StealCutInArt.CONTACT_AT)
	assert_float(StealCutInArt.CONTACT_AT).is_less(StealCutInArt.TRIP_AT)
	assert_float(StealCutInArt.CONTACT_AT).is_less_equal(StealCutInArt.TITLE_START)
	assert_float(StealCutInArt.TITLE_END).is_less_equal(StealCutInArt.SUB_START)
	assert_float(StealCutInArt.SUB_END).is_less(StealCutInArt.FADE_START)
	# 題は奪った瞬間の後に出て、出始めは大きく、出きったら等倍
	assert_float(StealCutInArt.frame(StealCutInArt.CONTACT_AT, true)["title_alpha"] as float).is_equal(0.0)
	assert_float(StealCutInArt.frame(StealCutInArt.TITLE_END, true)["title_alpha"] as float).is_equal(1.0)
	assert_float(StealCutInArt.frame(StealCutInArt.TITLE_END, true)["title_scale"] as float).is_equal_approx(1.0, 0.0001)
	assert_float(StealCutInArt.frame(1.0, true)["fade"] as float).is_equal(1.0)


func test_the_flash_and_the_strong_shake_are_only_when_the_user_wins_the_ball() -> void:
	var middle: float = (StealCutInArt.FLASH_START + StealCutInArt.FLASH_END) / 2.0
	assert_float(StealCutInArt.frame(middle, true)["flash"] as float).is_greater(0.5)
	assert_float(StealCutInArt.frame(middle, false)["flash"] as float).is_equal(0.0)
	var shaking: float = StealCutInArt.CONTACT_AT + 0.01
	assert_float((StealCutInArt.frame(shaking, true)["shake"] as Vector2).length()) \
			.is_greater((StealCutInArt.frame(shaking, false)["shake"] as Vector2).length())
	assert_vector(StealCutInArt.frame(0.2, true)["shake"] as Vector2).is_equal(Vector2.ZERO)


func test_the_texts_tell_winning_from_losing_the_ball() -> void:
	assert_dict(StealCutInArt.texts(true)).is_equal(
			{"title": "BALL WON!", "sub": "ポジティブトランジション", "score": "● ボールを奪った"})
	assert_dict(StealCutInArt.texts(false)).is_equal(
			{"title": "BALL LOST", "sub": "ネガティブトランジション", "score": "● ボールを失った"})


func test_the_dribbler_runs_with_the_ball_ahead_until_the_contact() -> void:
	# -x へ走り、ボールは体の前。奪われる瞬間、ボールは奪う点にある
	assert_float(StealCutInArt.dribbler_root(0.3).x).is_less(StealCutInArt.dribbler_root(0.1).x)
	for p: float in [0.1, 0.3]:
		var ahead: Vector3 = StealCutInArt.ball_position(p) - StealCutInArt.dribbler_root(p)
		assert_float(ahead.x).override_failure_message(str(p)).is_less(-0.3)
	var at_contact: Vector3 = StealCutInArt.ball_position(StealCutInArt.CONTACT_AT)
	assert_vector(at_contact * Vector3(1.0, 0.0, 1.0)).is_equal_approx(StealCutInArt.CONTACT_POINT,
			Vector3(0.001, 0.001, 0.001))
	assert_str(StealCutInArt.dribbler_motion(0.2)["clip"] as String).is_equal("Sprint")
	# つまずいたら前へ転がり、止まる
	assert_str(StealCutInArt.dribbler_motion(StealCutInArt.TRIP_AT + 0.05)["clip"] as String).is_equal("Roll")
	assert_float(StealCutInArt.dribbler_root(StealCutInArt.FADE_START).x).is_less(StealCutInArt.dribbler_root(StealCutInArt.TRIP_AT).x - 1.0)
	assert_vector(StealCutInArt.dribbler_root(1.0)).is_equal(StealCutInArt.dribbler_root(StealCutInArt.FADE_START))


func test_the_tackler_runs_in_slides_and_gets_up() -> void:
	assert_str(StealCutInArt.tackler_motion(0.1)["clip"] as String).is_equal("Sprint")
	assert_str(StealCutInArt.tackler_motion(StealCutInArt.CONTACT_AT)["clip"] as String).is_equal("Slide_Start")
	assert_str(StealCutInArt.tackler_motion(StealCutInArt.EXIT_AT + 0.05)["clip"] as String).is_equal("Slide_Exit")
	# 滑り込む向きに近づき、触れた後は少しだけ滑って止まる
	var along: Vector3 = StealCutInArt.tackler_root(0.3) - StealCutInArt.tackler_root(0.1)
	assert_float(along.normalized().dot(StealCutInArt.SLIDE_DIRECTION.normalized())).is_greater(0.99)
	var after: float = StealCutInArt.tackler_root(StealCutInArt.EXIT_AT).distance_to(StealCutInArt.tackler_root(StealCutInArt.CONTACT_AT))
	assert_float(after).is_equal_approx(StealCutInArt.SLIDE_ON, 0.001)
	# 体は滑り込む向きを向く（素材の体の前 +z が SLIDE_DIRECTION）
	var facing: Vector3 = StealCutInArt.tackler_transform(0.3).basis * Vector3(0.0, 0.0, 1.0)
	assert_vector(facing).is_equal_approx(StealCutInArt.SLIDE_DIRECTION.normalized(), Vector3(0.001, 0.001, 0.001))


func test_the_ball_flies_off_the_dribblers_path_and_ends_on_the_ground() -> void:
	var end: Vector3 = StealCutInArt.ball_position(1.0)
	assert_float(end.z).is_less(StealCutInArt.CONTACT_POINT.z - 1.5)
	assert_float(end.y).is_equal_approx(StealCutInArt.BALL_RADIUS, 0.001)
	# 触れた直後は跳ねる
	assert_float(StealCutInArt.ball_position(StealCutInArt.CONTACT_AT + 0.06).y).is_greater(StealCutInArt.BALL_RADIUS + 0.2)
	for step: int in range(41):
		var p: float = step / 40.0
		assert_float(StealCutInArt.ball_position(p).y).override_failure_message(str(p)).is_greater(StealCutInArt.BALL_RADIUS - 0.0001)


func test_the_camera_stays_above_the_ground_and_looks_at_the_action() -> void:
	for step: int in range(21):
		var p: float = step / 20.0
		var view: Dictionary = StealCutInArt.camera_at(p)
		var position: Vector3 = view["position"] as Vector3
		var target: Vector3 = view["target"] as Vector3
		assert_float(position.y).override_failure_message(str(p)).is_greater(0.3)
		# 奪う点の近く（6 m 以内）を見る
		assert_float((target * Vector3(1.0, 0.0, 1.0)).distance_to(StealCutInArt.CONTACT_POINT)).is_less(6.0)
		var forward: Vector3 = (target - position).normalized()
		var to_ball: Vector3 = (StealCutInArt.ball_position(minf(p, StealCutInArt.CONTACT_AT)) - position).normalized()
		assert_float(forward.dot(to_ball)).override_failure_message(str(p)).is_greater(cos(deg_to_rad(view["fov"] as float) / 2.0))

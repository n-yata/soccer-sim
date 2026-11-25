## 得点のカットインの3Dの舞台の動きと時間割（GoalCutInArt）のテスト。舞台はこの値をそのまま使うので、性質をここで確かめる
## （見え方はスクリーンショットと、遊んで確かめる）。
extends GdUnitTestSuite


# --- 時間割 ---

func test_the_flash_is_only_for_the_users_goal_and_only_around_the_net() -> void:
	var middle: float = (GoalCutInArt.FLASH_START + GoalCutInArt.FLASH_END) / 2.0
	assert_float(GoalCutInArt.frame(middle, true)["flash"] as float).is_greater(0.5)
	assert_float(GoalCutInArt.frame(middle, false)["flash"] as float).is_equal(0.0)
	assert_float(GoalCutInArt.frame(0.2, true)["flash"] as float).is_equal(0.0)
	assert_float(GoalCutInArt.frame(0.8, true)["flash"] as float).is_equal(0.0)


func test_the_film_bars_come_in_first_and_the_picture_fades_out_at_the_end() -> void:
	assert_float(GoalCutInArt.frame(0.0, true)["bars"] as float).is_equal(0.0)
	assert_float(GoalCutInArt.frame(0.3, true)["bars"] as float).is_equal(1.0)
	assert_float(GoalCutInArt.frame(0.5, true)["fade"] as float).is_equal(0.0)
	assert_float(GoalCutInArt.frame(1.0, true)["fade"] as float).is_equal(1.0)


func test_the_title_slams_in_after_the_ball_hits_the_net_and_settles_at_full_size() -> void:
	# ネットに刺さる瞬間は文字を出さない（刺さるところを隠さない）
	assert_float(GoalCutInArt.frame(GoalCutInArt.BALL_NET, true)["title_alpha"] as float).is_equal(0.0)
	assert_float(GoalCutInArt.TITLE_START).is_greater(GoalCutInArt.BALL_NET)
	var start: Dictionary = GoalCutInArt.frame(GoalCutInArt.TITLE_START + 0.005, true)
	assert_float(start["title_alpha"] as float).is_greater(0.0)
	assert_float(start["title_scale"] as float).is_greater(1.5)
	var hold: Dictionary = GoalCutInArt.frame(0.85, true)
	assert_float(hold["title_alpha"] as float).is_equal(1.0)
	assert_float(hold["title_scale"] as float).is_equal_approx(1.0, 0.001)
	# 「得点」とスコアは題の後
	assert_float(GoalCutInArt.frame(GoalCutInArt.TITLE_END, true)["sub_alpha"] as float).is_equal(0.0)
	assert_float(hold["sub_alpha"] as float).is_equal(1.0)


func test_the_screen_shakes_only_right_after_the_ball_hits_the_net() -> void:
	assert_vector(GoalCutInArt.frame(0.3, true)["shake"] as Vector2).is_equal(Vector2.ZERO)
	var shaking: Vector2 = GoalCutInArt.frame(GoalCutInArt.BALL_NET + 0.02, true)["shake"] as Vector2
	assert_float(shaking.length()).is_greater(0.0)
	assert_vector(GoalCutInArt.frame(0.85, true)["shake"] as Vector2).is_equal(Vector2.ZERO)
	# 相手の得点は控えめ（揺れが小さい）
	var opponent: Vector2 = GoalCutInArt.frame(GoalCutInArt.BALL_NET + 0.02, false)["shake"] as Vector2
	assert_float(opponent.length()).is_less(shaking.length())


func test_the_net_bulges_when_the_ball_arrives_and_settles_back() -> void:
	assert_float(GoalCutInArt.net_bulge(GoalCutInArt.BALL_IN - 0.01)).is_equal(0.0)
	assert_float(GoalCutInArt.net_bulge(GoalCutInArt.BALL_NET)).is_equal_approx(1.0, 0.01)
	assert_float(GoalCutInArt.net_bulge(GoalCutInArt.NET_SETTLE_END + 0.01)).is_equal(0.0)


# --- ボール ---

func test_the_ball_waits_on_the_spot_then_crosses_the_goal_line_inside_the_frame() -> void:
	assert_vector(GoalCutInArt.ball_position(0.2)).is_equal(GoalCutInArt.BALL_SPOT)
	# ゴールラインを越える点は、ポストの内側・バーの下
	var crossing: Vector3 = GoalCutInArt.ball_position(GoalCutInArt.BALL_IN)
	assert_float(absf(crossing.x)).is_less(0.05)
	assert_float(absf(crossing.z)).is_less(GoalCutInArt.GOAL_HALF_WIDTH - GoalCutInArt.BALL_RADIUS)
	assert_float(crossing.y).is_less(GoalCutInArt.GOAL_HEIGHT - GoalCutInArt.BALL_RADIUS)
	# 飛んでいる途中は、置いた場所とゴールの間で、地面より上
	var flying: Vector3 = GoalCutInArt.ball_position((GoalCutInArt.BALL_START + GoalCutInArt.BALL_IN) / 2.0)
	assert_float(flying.x).is_between(0.0, GoalCutInArt.BALL_SPOT.x)
	assert_float(flying.y).is_greater(GoalCutInArt.BALL_RADIUS)


func test_the_ball_ends_inside_the_goal_on_the_ground() -> void:
	for p: float in [GoalCutInArt.BALL_NET, 0.6, GoalCutInArt.BALL_DROP_END, 1.0]:
		var at: Vector3 = GoalCutInArt.ball_position(p)
		assert_float(at.x).override_failure_message(str(p)).is_less(0.0)
		assert_float(at.x).override_failure_message(str(p)).is_greater(-GoalCutInArt.GOAL_DEPTH - GoalCutInArt.NET_BULGE_DEPTH)
		assert_float(absf(at.z)).override_failure_message(str(p)).is_less(GoalCutInArt.GOAL_HALF_WIDTH)
		assert_float(at.y).override_failure_message(str(p)).is_greater_equal(GoalCutInArt.BALL_RADIUS - 0.001)
	assert_float(GoalCutInArt.ball_position(1.0).y).is_equal_approx(GoalCutInArt.BALL_RADIUS, 0.001)


func test_the_ball_pushes_the_net_back_when_it_hits() -> void:
	# 刺さった瞬間のボールは、ふくらんだネットの分だけ奥（ネットの面より後ろ）にある
	var hit: Vector3 = GoalCutInArt.ball_position(GoalCutInArt.BALL_NET)
	assert_float(hit.x).is_less(-GoalCutInArt.GOAL_DEPTH + GoalCutInArt.BALL_RADIUS)


# --- 選手 ---

func test_the_recorded_kick_runs_around_the_contact_and_ends_before_the_celebration() -> void:
	# 記録は助走の終わりから始まり、インパクトをはさみ、喜ぶ前に終わる
	assert_float(GoalCutInArt.kick_start()).is_between(GoalCutInArt.MOTION_BLEND, GoalCutInArt.CONTACT_AT)
	assert_float(GoalCutInArt.kick_end()).is_between(GoalCutInArt.CONTACT_AT, GoalCutInArt.CELEBRATE_AT)
	assert_float(GoalCutInArt.kick_sec(GoalCutInArt.CONTACT_AT)).is_equal(0.0)
	assert_float(GoalCutInArt.kick_sec(GoalCutInArt.CONTACT_AT + GoalCutInArt.KICK_P_PER_SEC)).is_equal_approx(1.0, 0.0001)


func test_the_recorded_kick_swings_the_right_leg_from_behind_up_to_the_front() -> void:
	# 体の空間（前が +z）: 振りかぶりでは蹴り足のすねが後ろを向き、振り抜きでは腿が水平近くまで上がる
	var back: Dictionary = GoalCutInArt.kick_frame(-0.2)["directions"]
	assert_float((back["kick_shin"] as Vector3).z).is_less(-0.5)
	var follow: Dictionary = GoalCutInArt.kick_frame(0.3)["directions"]
	assert_float((follow["kick_thigh"] as Vector3).y).is_greater(-0.3)
	# 軸足は、インパクトの瞬間にほぼ真下へ伸びている
	var contact: Dictionary = GoalCutInArt.kick_frame(0.0)["directions"]
	assert_float((contact["stand_shin"] as Vector3).y).is_less(-0.8)


func test_the_recorded_kick_has_every_part_for_every_frame() -> void:
	# 同梱の記録の形: 各キーが同じ長さの並びで、向きは3つ・腰の位置は2つの数。インパクトの番号は並びの中
	var data: Dictionary = GoalCutInArt.KICK_MOTION.data
	var count: int = (data["hips"] as Array).size()
	assert_int(count).is_greater(60)
	for key: String in GoalCutInArt.KICK_KEYS + ["root"]:
		var size: int = 2 if key == "root" else 3
		var frames: Array = data[key]
		assert_int(frames.size()).override_failure_message(key).is_equal(count)
		for frame: Array in frames:
			assert_int(frame.size()).override_failure_message(key).is_equal(size)
	for key: String in ["chest", "head"]:
		assert_int((data[key] as Array).size()).override_failure_message(key).is_equal(count)
	var meta: Dictionary = data["meta"]
	assert_float(meta["fps"] as float).is_greater(0.0)
	assert_int(int(meta["contact_index"])).is_between(1, count - 2)


func test_a_kick_frame_between_records_is_blended_and_outside_holds_the_ends() -> void:
	var step: float = 1.0 / 60.0
	var a: Dictionary = GoalCutInArt.kick_frame(0.0)
	var b: Dictionary = GoalCutInArt.kick_frame(step)
	var mid: Dictionary = GoalCutInArt.kick_frame(step / 2.0)
	for key: String in GoalCutInArt.KICK_KEYS:
		var along: Vector3 = mid["directions"][key] as Vector3
		assert_float(along.length()).override_failure_message(key).is_equal_approx(1.0, 0.0001)
		var expected: Vector3 = ((a["directions"][key] as Vector3).lerp(b["directions"][key] as Vector3, 0.5)).normalized()
		assert_vector(along).override_failure_message(key).is_equal_approx(expected, Vector3(0.0001, 0.0001, 0.0001))
	assert_float(mid["hips"] as float).is_equal_approx(((a["hips"] as float) + (b["hips"] as float)) / 2.0, 0.0001)
	# 記録の外は端の値
	var hips: Array = GoalCutInArt.KICK_MOTION.data["hips"]
	assert_float(GoalCutInArt.kick_frame(-10.0)["hips"] as float).is_equal(hips[0] as float)
	assert_float(GoalCutInArt.kick_frame(10.0)["hips"] as float).is_equal(hips[-1] as float)


func test_the_kicking_foot_is_fastest_at_the_ball() -> void:
	# インパクトで止まりかけない: 当たる瞬間のすねの振りは、踏み込む前と振り抜いた後より速い
	var swing := func(sec: float) -> float:
		var now: Vector3 = GoalCutInArt.kick_frame(sec)["directions"]["kick_shin"]
		return now.angle_to(GoalCutInArt.kick_frame(sec + 0.02)["directions"]["kick_shin"] as Vector3)
	var at_ball: float = swing.call(-0.01)
	assert_float(at_ball).is_greater(swing.call(-0.4) as float)
	assert_float(at_ball).is_greater(swing.call(0.5) as float)


func test_the_standing_foot_is_held_from_the_plant_until_the_hop_after_the_kick() -> void:
	var at := func(sec: float) -> float:
		return GoalCutInArt.CONTACT_AT + sec * GoalCutInArt.KICK_P_PER_SEC
	for sec: float in [-0.4, GoalCutInArt.PLANT_FROM_SEC, GoalCutInArt.PLANT_UNTIL_SEC, 0.4]:
		assert_float(GoalCutInArt.plant_weight(at.call(sec) as float)).override_failure_message(str(sec)).is_equal_approx(0.0, 0.0001)
	for sec: float in [GoalCutInArt.PLANT_HOLD_FROM_SEC, 0.0, GoalCutInArt.PLANT_HOLD_UNTIL_SEC]:
		assert_float(GoalCutInArt.plant_weight(at.call(sec) as float)).override_failure_message(str(sec)).is_equal_approx(1.0, 0.0001)
	# 軸足はボールの左（+z）の横、地面の上
	var spot: Vector3 = GoalCutInArt.plant_spot()
	assert_float(spot.z - GoalCutInArt.BALL_SPOT.z).is_between(0.2, 0.5)
	assert_float(absf(spot.x - GoalCutInArt.BALL_SPOT.x)).is_less(0.5)
	assert_float(spot.y).is_equal(0.0)


func test_the_striker_runs_in_without_a_jump_and_follows_the_record() -> void:
	var start: float = GoalCutInArt.kick_start()
	var contact: Vector3 = GoalCutInArt.BALL_SPOT * Vector3(1.0, 0.0, 1.0) + GoalCutInArt.CONTACT_OFFSET
	# 助走の始まりは後ろ（+x）。記録の始まりへ途切れずにつながる
	assert_float(GoalCutInArt.striker_root(0.0).x).is_greater(GoalCutInArt.striker_root(start).x + 1.0)
	assert_vector(GoalCutInArt.striker_root(start - 0.0001)).is_equal_approx(GoalCutInArt.striker_root(start),
			Vector3(0.01, 0.01, 0.01))
	# インパクトでは決めた場所。記録の後は、喜ぶまで止まる
	assert_vector(GoalCutInArt.striker_root(GoalCutInArt.CONTACT_AT)).is_equal_approx(contact, Vector3(0.001, 0.001, 0.001))
	var end: Vector3 = GoalCutInArt.striker_root(GoalCutInArt.kick_end())
	assert_vector(GoalCutInArt.striker_root(GoalCutInArt.CELEBRATE_AT)).is_equal_approx(end, Vector3(0.001, 0.001, 0.001))
	# 喜ぶときは跳ぶ
	assert_float(GoalCutInArt.striker_root(0.8).y).is_greater(0.05)


func test_the_striker_moves_from_the_record_into_the_celebration() -> void:
	assert_dict(GoalCutInArt.striker_pose(GoalCutInArt.CONTACT_AT)).is_equal(GoalCutInArt.kick_frame(0.0))
	# 喜び始めには、喜ぶ姿勢になっている（両腕を突き上げる）
	var cheer: Dictionary = GoalCutInArt.striker_pose(GoalCutInArt.CELEBRATE_AT)
	var celebrate: Dictionary = GoalCutInArt.celebrate_frame()
	for key: String in GoalCutInArt.KICK_KEYS:
		assert_vector(cheer["directions"][key] as Vector3).override_failure_message(key) \
				.is_equal_approx(celebrate["directions"][key] as Vector3, Vector3(0.0001, 0.0001, 0.0001))
	assert_float(cheer["hips"] as float).is_equal_approx(0.0, 0.0001)
	var up: Dictionary = celebrate["directions"]
	assert_float((up["lead_upper"] as Vector3).y).is_greater(0.8)
	assert_float((up["trail_upper"] as Vector3).y).is_greater(0.8)


func test_the_striker_sprints_then_kicks_by_the_record_then_celebrates() -> void:
	# 助走は素材の Sprint、蹴る間は記録の手足の向き（Idle の上から骨を向ける）、喜ぶときは Yes
	var run: Dictionary = GoalCutInArt.striker_motion(0.1)
	assert_str(run["clip"] as String).is_equal("Sprint")
	assert_float(run["weight"] as float).is_equal(0.0)
	var kick: Dictionary = GoalCutInArt.striker_motion(GoalCutInArt.CONTACT_AT)
	assert_str(kick["clip"] as String).is_equal("Idle")
	assert_float(kick["weight"] as float).is_equal(1.0)
	assert_dict(kick["pose"] as Dictionary).is_equal(GoalCutInArt.striker_pose(GoalCutInArt.CONTACT_AT))
	# 蹴る間は軸足を地面に着けて留める
	assert_float(kick["ground"] as float).is_equal(1.0)
	assert_float(kick["plant_weight"] as float).is_equal(1.0)
	assert_vector(kick["plant"] as Vector3).is_equal(GoalCutInArt.plant_spot())
	var cheer: Dictionary = GoalCutInArt.striker_motion(0.95)
	assert_str(cheer["clip"] as String).is_equal("Yes")
	assert_float(cheer["weight"] as float).is_equal(0.0)
	# 素材の動きの間は、足の置き方も素材のまま
	assert_float(run["ground"] as float).is_equal(0.0)
	assert_float(cheer["ground"] as float).is_equal(0.0)
	# 助走の Sprint は時刻とともに進む
	assert_float(GoalCutInArt.striker_motion(0.15)["time"] as float).is_greater(run["time"] as float)


func test_the_keeper_moves_by_aimed_bones_all_the_way() -> void:
	for p: float in [0.1, GoalCutInArt.KEEPER_JUMP_AT, 0.8]:
		var motion: Dictionary = GoalCutInArt.keeper_motion(p)
		assert_float(motion["weight"] as float).is_equal(1.0)
		assert_dict(motion["pose"] as Dictionary).is_equal(GoalCutInArt.keeper_pose(p))
		assert_float(motion["plant_weight"] as float).is_equal(0.0)
	# 構えている間は足を地面に着け、跳んだら放す
	assert_float(GoalCutInArt.keeper_motion(0.1)["ground"] as float).is_equal(1.0)
	assert_float(GoalCutInArt.keeper_motion(GoalCutInArt.KEEPER_PEAK_AT)["ground"] as float).is_equal(0.0)


func test_model_directions_turn_the_skeleton_space_into_the_body_space() -> void:
	# 姿勢の空間（前が -x、左が +z）→ 体の空間（前が +z、左が +x）
	assert_vector(GoalCutInArt.model_direction(Vector3(-1.0, 0.0, 0.0))).is_equal(Vector3(0.0, 0.0, 1.0))
	assert_vector(GoalCutInArt.model_direction(Vector3(0.0, 0.0, 1.0))).is_equal(Vector3(1.0, 0.0, 0.0))
	assert_vector(GoalCutInArt.model_direction(Vector3.UP)).is_equal(Vector3.UP)
	var pose: Dictionary = GoalCutInArt.CELEBRATE_POSE.duplicate()
	pose["kick_thigh"] = -90.0
	# 腿を前へ水平に上げると、体の前（+z）を向く
	assert_vector(GoalCutInArt.model_directions(pose)["kick_thigh"] as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0),
			Vector3(0.0001, 0.0001, 0.0001))


func test_the_models_face_their_way() -> void:
	# 素材の体は +z を向く。選手は -x、キーパーは +x を向くように置く
	var striker: Transform3D = GoalCutInArt.striker_model_transform(0.3)
	assert_vector(striker.basis * Vector3(0.0, 0.0, 1.0)).is_equal_approx(Vector3(-1.0, 0.0, 0.0), Vector3(0.001, 0.001, 0.001))
	var keeper: Transform3D = GoalCutInArt.keeper_model_transform(0.2)
	assert_vector(keeper.basis * Vector3(0.0, 0.0, 1.0)).is_equal_approx(Vector3(1.0, 0.0, 0.0), Vector3(0.001, 0.001, 0.001))


func test_the_body_leans_sideways_and_the_feet_follow_the_shins() -> void:
	var pose: Dictionary = {"torso": 0.0, "stand_thigh": 0.0, "stand_shin": 10.0, "kick_thigh": 0.0,
			"kick_shin": 0.0, "lead_upper": 0.0, "lead_fore": 0.0, "trail_upper": 0.0, "trail_fore": 0.0}
	var plain: Dictionary = GoalCutInArt.directions(pose)
	assert_vector(plain["torso"] as Vector3).is_equal(Vector3.UP)
	# 足首の角度が無ければ普段の足首（すねの向きから FOOT_NEUTRAL）
	var neutral: float = deg_to_rad(10.0 + GoalCutInArt.FOOT_NEUTRAL)
	assert_vector(plain["stand_foot"] as Vector3).is_equal_approx(Vector3(sin(neutral), -cos(neutral), 0.0),
			Vector3(0.0001, 0.0001, 0.0001))
	# lean が正なら左（+z）へ傾く
	pose["lean"] = 15.0
	var leaning: Vector3 = GoalCutInArt.directions(pose)["torso"] as Vector3
	assert_float(leaning.z).is_equal_approx(sin(deg_to_rad(15.0)), 0.0001)
	assert_float(leaning.length()).is_equal_approx(1.0, 0.0001)


# --- 骨の置き方 ---

func test_a_bone_transform_stretches_a_unit_bone_from_one_joint_to_the_other() -> void:
	var a := Vector3(1.0, 2.0, 3.0)
	var b := Vector3(1.5, 1.2, 2.6)
	var bone: Transform3D = GoalCutInArt.bone_transform(a, b)
	# 長さ 1 の骨（Y が -0.5〜0.5）の両端が、a と b に重なる
	assert_vector(bone * Vector3(0.0, -0.5, 0.0)).is_equal_approx(a, Vector3(0.0001, 0.0001, 0.0001))
	assert_vector(bone * Vector3(0.0, 0.5, 0.0)).is_equal_approx(b, Vector3(0.0001, 0.0001, 0.0001))
	# 太さ（X・Z）は変えない
	assert_float(bone.basis.x.length()).is_equal_approx(1.0, 0.0001)
	assert_float(bone.basis.z.length()).is_equal_approx(1.0, 0.0001)


func test_a_vertical_bone_also_gets_a_valid_transform() -> void:
	var bone: Transform3D = GoalCutInArt.bone_transform(Vector3.ZERO, Vector3(0.0, 0.0, -2.0))
	assert_vector(bone * Vector3(0.0, 0.5, 0.0)).is_equal_approx(Vector3(0.0, 0.0, -2.0), Vector3(0.0001, 0.0001, 0.0001))
	assert_float(bone.basis.determinant()).is_not_equal(0.0)


# --- カメラ ---

func test_the_camera_cuts_through_the_shots_in_order() -> void:
	var shots: Array[int] = []
	for step: int in range(101):
		var shot: int = GoalCutInArt.camera_at(step / 100.0)["shot"] as int
		if shots.is_empty() or shots[-1] != shot:
			shots.append(shot)
	assert_array(shots).is_equal([0, 1, 2, 3, 4])


func test_the_camera_stays_above_the_ground_and_looks_at_the_action() -> void:
	for step: int in range(101):
		var p: float = step / 100.0
		var view: Dictionary = GoalCutInArt.camera_at(p)
		var position: Vector3 = view["position"] as Vector3
		var target: Vector3 = view["target"] as Vector3
		assert_float(position.y).override_failure_message(str(p)).is_greater(0.2)
		assert_float(position.distance_to(target)).override_failure_message(str(p)).is_greater(1.0)
		# いま見せたいもの（助走・蹴る瞬間・喜ぶカットは選手、ボールを追うカットとネットのカットはボール）が、
		# カメラの前（画角の内側）にある。蹴る瞬間のカットでは、ボールはカメラの横を抜けていく
		var shot: int = view["shot"] as int
		var subject: Vector3 = GoalCutInArt.ball_position(p) if shot in [2, 3] \
				else GoalCutInArt.striker_root(p) + Vector3(0.0, 1.0, 0.0)
		var forward: Vector3 = (target - position).normalized()
		var angle: float = rad_to_deg(forward.angle_to(subject - position))
		assert_float(angle).override_failure_message("%s %s" % [p, angle]).is_less((view["fov"] as float) / 2.0 + 4.0)


func test_the_net_shot_is_from_behind_the_goal() -> void:
	var view: Dictionary = GoalCutInArt.camera_at(GoalCutInArt.BALL_NET)
	assert_float((view["position"] as Vector3).x).is_less(-GoalCutInArt.GOAL_DEPTH)


# --- 文 ---

func test_the_texts_tell_a_goal_for_from_a_goal_against() -> void:
	var for_user: Dictionary = GoalCutInArt.texts(true, 2, 1)
	assert_str(for_user["title"] as String).is_equal("GOAL!")
	assert_str(for_user["sub"] as String).is_equal("得点")
	assert_str(for_user["score"] as String).is_equal("● 2 − 1 ◆")
	var against: Dictionary = GoalCutInArt.texts(false, 0, 3)
	assert_str(against["title"] as String).is_equal("GOAL")
	assert_str(against["sub"] as String).is_equal("失点")
	assert_str(against["score"] as String).is_equal("● 0 − 3 ◆")

## カットインの3Dの選手（GoalPlayerModel。Quaternius の素材の骨に人形の部品を付け、動きを置く）のテスト
## （見え方はスクリーンショットと、遊んで確かめる）。
extends GdUnitTestSuite


func _kit(overrides: Dictionary = {}) -> Dictionary:
	var kit: Dictionary = {"shirt": Color(0.3, 0.76, 1.0), "shorts": Color(0.1, 0.3, 0.4), "sock": Color(0.3, 0.76, 1.0),
			"trim": Color(0.1, 0.3, 0.4), "boot": Color(0.03, 0.05, 0.09), "dark": Color(0.03, 0.05, 0.09),
			"number_color": Color(0.03, 0.05, 0.09), "round_emblem": true, "stripes": false, "number": 9, "font": null}
	kit.merge(overrides, true)
	return kit


func _model(overrides: Dictionary = {}) -> GoalPlayerModel:
	var model := auto_free(GoalPlayerModel.new()) as GoalPlayerModel
	add_child(model)
	model.build(_kit(overrides))
	return model


func _count(model: GoalPlayerModel, part_name: String) -> int:
	var count: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if node.name.begins_with(part_name):
			count += 1
	return count


func test_the_kit_colors_go_to_the_parts() -> void:
	# 自分のチーム: 無地。袖は半袖なので前腕・手は肌
	var model: GoalPlayerModel = _model()
	assert_array(model.shirt_colors()).is_equal([_kit()["shirt"]])
	assert_object(model.part_material("arm").albedo_color).is_equal(_kit()["shirt"])
	assert_object(model.part_material("shorts").albedo_color).is_equal(_kit()["shorts"])
	assert_object(model.part_material("sock").albedo_color).is_equal(_kit()["sock"])
	assert_object(model.part_material("boot").albedo_color).is_equal(_kit()["boot"])
	assert_object(model.part_material("sleeve")).is_same(model.part_material("skin"))
	assert_object(model.part_material("hand")).is_same(model.part_material("skin"))
	assert_object(model.part_material("skin").albedo_color).is_equal(GoalPlayerModel.SKIN_COLORS["dark"])
	assert_object(_model({"skin": "light"}).part_material("skin").albedo_color).is_equal(GoalPlayerModel.SKIN_COLORS["light"])


func test_the_opponent_shirt_has_stripes_of_the_shirt_and_trim_colors() -> void:
	var model: GoalPlayerModel = _model({"stripes": true})
	var colors: Array[Color] = model.shirt_colors()
	assert_int(colors.size()).is_equal(2)
	assert_bool(colors[0].is_equal_approx(_kit()["shirt"] as Color)).is_true()
	assert_bool(colors[1].is_equal_approx(_kit()["trim"] as Color)).is_true()
	assert_float(model.part_material("shirt").uv1_scale.x).is_equal(float(GoalPlayerModel.STRIPE_COUNT))
	# 袖は縦じまにしない
	assert_object(model.part_material("arm").albedo_texture).is_null()


func test_the_keeper_wears_long_sleeves_and_gloves() -> void:
	var model: GoalPlayerModel = _model({"long_sleeves": true, "glove": Color(0.95, 0.95, 0.96)})
	assert_object(model.part_material("sleeve").albedo_color).is_equal(_kit()["shirt"])
	assert_object(model.part_material("hand").albedo_color).is_equal(Color(0.95, 0.95, 0.96))


func test_the_hair_style_follows_the_kit() -> void:
	# 横に流した前髪は2房、つんつんは8本、モヒカンは5房。どれも頭にかぶせる髪（Hair）を1つ持つ
	var expected: Dictionary = {GoalPlayerModel.HairStyle.FRINGE: [2, 0, 0], GoalPlayerModel.HairStyle.SPIKY: [0, 8, 0],
			GoalPlayerModel.HairStyle.MOHAWK: [0, 0, 5]}
	for style: GoalPlayerModel.HairStyle in expected:
		var model: GoalPlayerModel = _model({"hair_style": style})
		var counts: Array = [_count(model, "Fringe"), _count(model, "Spike"), _count(model, "Crest")]
		assert_array(counts).override_failure_message(str(style)).is_equal(expected[style])
		assert_int(_count(model, "Hair")).is_equal(1)


func test_only_the_doll_parts_are_drawn_and_each_follows_a_bone() -> void:
	# 素材の写実の体は出さない。描く部品はどれも骨に付いていて、骨と一緒に動く
	var model: GoalPlayerModel = _model()
	var parts: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	assert_int(parts.size()).is_greater(20)
	for part: Node in parts:
		assert_object(part.get_parent()).override_failure_message(str(part.name)).is_instanceof(BoneAttachment3D)
	for part_name: String in ["Head", "Torso", "Shorts", "UpperArm", "Forearm", "Hand", "Thigh", "Shin", "Boot"]:
		assert_int(_count(model, part_name)).override_failure_message(part_name).is_greater(0)


func test_the_number_is_on_the_back_and_the_badge_shape_tells_the_team() -> void:
	var user: GoalPlayerModel = _model({"number": 1})
	var number := user.find_child("Number", true, false) as Label3D
	assert_str(number.text).is_equal("1")
	assert_object((user.find_child("Emblem", true, false) as MeshInstance3D).mesh).is_instanceof(CylinderMesh)
	var opponent: GoalPlayerModel = _model({"round_emblem": false})
	assert_object((opponent.find_child("Emblem", true, false) as MeshInstance3D).mesh).is_instanceof(BoxMesh)


func test_the_same_time_gives_the_same_pose_and_the_clip_moves_the_body() -> void:
	var model: GoalPlayerModel = _model()
	model.set_motion("Sprint", 0.1)
	var first: Vector3 = model.bone_position("hand_r")
	model.set_motion("Yes", 1.0)
	model.set_motion("Sprint", 0.1)
	assert_vector(model.bone_position("hand_r")).is_equal_approx(first, Vector3(0.0001, 0.0001, 0.0001))
	model.set_motion("Sprint", 0.4)
	assert_float(model.bone_position("hand_r").distance_to(first)).is_greater(0.05)


func test_aimed_bones_point_where_the_pose_says() -> void:
	# 角度の姿勢（喜び）でも、記録の向き（振り抜き）でも、骨がその向きを向く
	# 向ける骨は、記録が持つ手足・胴・足の向きのすべて（蹴り足の足首を含む）
	var aimed_keys: PackedStringArray = []
	for spec: Array in GoalPlayerModel.AIMED_BONES:
		aimed_keys.append(spec[2] as String)
	aimed_keys.sort()
	var recorded_keys := PackedStringArray(GoalCutInArt.KICK_KEYS)
	recorded_keys.sort()
	assert_str(",".join(aimed_keys)).is_equal(",".join(recorded_keys))
	var model: GoalPlayerModel = _model()
	var angles: Dictionary = GoalCutInArt.CELEBRATE_POSE
	var recorded: Dictionary = GoalCutInArt.kick_frame(0.3)
	for case: Array in [[angles, GoalCutInArt.model_directions(angles)], [recorded, recorded["directions"]]]:
		model.set_motion("Idle", 0.0, case[0] as Dictionary, 1.0)
		var directions: Dictionary = case[1]
		for spec: Array in GoalPlayerModel.AIMED_BONES:
			var along: Vector3 = (model.bone_position(spec[1] as String) - model.bone_position(spec[0] as String)).normalized()
			assert_float(along.dot((directions[spec[2]] as Vector3).normalized())).override_failure_message(str(spec)) \
					.is_greater(0.99)


func test_the_hips_turn_brings_the_right_side_forward() -> void:
	# hips が正なら、上から見て右の側（体の空間の -x）が前（+z）へ出る
	var model: GoalPlayerModel = _model()
	var pose: Dictionary = GoalCutInArt.CELEBRATE_POSE.duplicate()
	pose["hips"] = 0.0
	model.set_motion("Idle", 0.0, pose, 1.0)
	var square: float = model.bone_position("thigh_r").z - model.bone_position("thigh_l").z
	pose["hips"] = 30.0
	model.set_motion("Idle", 0.0, pose, 1.0)
	assert_float(model.bone_position("thigh_r").z - model.bone_position("thigh_l").z).is_greater(square + 0.05)


func test_the_lower_foot_is_put_on_the_ground() -> void:
	# 膝を曲げた姿勢でも、低いほうの足が基準の姿勢の高さ（地面に立つ高さ）に来る
	var model: GoalPlayerModel = _model()
	model.set_motion("Idle", 0.0, GoalCutInArt.keeper_pose(GoalCutInArt.KEEPER_JUMP_AT), 1.0)
	model.place_feet(1.0, Vector3.ZERO, 0.0)
	var lowest: float = INF
	for bone_name: String in GoalPlayerModel.FOOT_BONES:
		var bone: int = model.skeleton().find_bone(bone_name)
		lowest = minf(lowest, model.bone_position(bone_name).y - model.skeleton().get_bone_global_rest(bone).origin.y)
	assert_float(lowest).is_equal_approx(0.0, 0.001)
	# 割合 0 なら動かさない
	model.set_motion("Idle", 0.0, GoalCutInArt.keeper_pose(GoalCutInArt.KEEPER_JUMP_AT), 1.0)
	var before: Vector3 = model.bone_position("pelvis")
	model.place_feet(0.0, Vector3(1.0, 0.0, 1.0), 0.0)
	assert_vector(model.bone_position("pelvis")).is_equal(before)


func test_the_planted_foot_is_moved_over_the_spot_and_onto_the_ground() -> void:
	# 軸足を留めるときは、蹴り足が低くても軸足の側を地面に着ける
	# （軸足の膝を曲げ、蹴り足を真下へ伸ばして、蹴り足のほうを低くした姿勢）
	var model: GoalPlayerModel = _model()
	var pose: Dictionary = GoalCutInArt.CELEBRATE_POSE.duplicate()
	pose.merge({"stand_thigh": -45.0, "stand_shin": 35.0, "kick_thigh": 0.0, "kick_shin": 0.0}, true)
	var height := func(bone_name: String) -> float:
		var bone: int = model.skeleton().find_bone(bone_name)
		return model.bone_position(bone_name).y - model.skeleton().get_bone_global_rest(bone).origin.y
	model.set_motion("Idle", 0.0, pose, 1.0)
	model.place_feet(1.0, Vector3(0.3, 0.0, 0.5), 1.0)
	var foot: Vector3 = model.bone_position(GoalPlayerModel.PLANT_BONE)
	assert_float(foot.x).is_equal_approx(0.3, 0.001)
	assert_float(foot.z).is_equal_approx(0.5, 0.001)
	assert_float(minf(height.call("foot_l") as float, height.call("ball_l") as float)).is_equal_approx(0.0, 0.001)
	# 蹴り足は地面より下を通る（軸足を浮かせないため、低いほうの足には合わせない）
	assert_float(minf(height.call("foot_r") as float, height.call("ball_r") as float)).is_less(-0.02)


func test_every_clip_the_cut_ins_use_is_in_the_library() -> void:
	# 場面の関数（GoalCutInArt・SaveCutInArt・StealCutInArt）が選ぶ動きは、どれも素材の動きにある
	for clip: String in ["Sprint", "Idle", "Yes", "Roll", "Slide_Start", "Slide_Exit"]:
		assert_bool(GoalPlayerModel.ANIMATIONS.has_animation(clip)).override_failure_message(clip).is_true()


func test_looping_clips_wrap_and_one_shot_clips_hold_the_end() -> void:
	var model: GoalPlayerModel = _model()
	var sprint: float = GoalPlayerModel.ANIMATIONS.get_animation("Sprint").length
	assert_float(model.clamp_time("Sprint", sprint + 0.1)).is_equal_approx(0.1, 0.0001)
	var yes: float = GoalPlayerModel.ANIMATIONS.get_animation("Yes").length
	assert_float(model.clamp_time("Yes", yes + 1.0)).is_equal(yes)


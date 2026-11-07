## カットインの3Dの選手（GoalPlayerModel。Quaternius の素材の体にユニフォームを着せ、動きを置く）のテスト
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


func test_the_kit_colors_and_patterns_go_to_the_body_shader() -> void:
	var material: ShaderMaterial = _model({"stripes": true}).body_material()
	assert_object(material.get_shader_parameter(&"shirt_color")).is_equal(_kit()["shirt"])
	assert_object(material.get_shader_parameter(&"shorts_color")).is_equal(_kit()["shorts"])
	assert_float(material.get_shader_parameter(&"stripes") as float).is_equal(1.0)
	assert_float(material.get_shader_parameter(&"gloves") as float).is_equal(0.0)
	assert_float(material.get_shader_parameter(&"long_sleeves") as float).is_equal(0.0)


func test_the_keeper_wears_long_sleeves_and_gloves() -> void:
	var material: ShaderMaterial = _model({"long_sleeves": true, "glove": Color(0.95, 0.95, 0.96)}).body_material()
	assert_float(material.get_shader_parameter(&"long_sleeves") as float).is_equal(1.0)
	assert_float(material.get_shader_parameter(&"gloves") as float).is_equal(1.0)
	assert_object(material.get_shader_parameter(&"glove_color")).is_equal(Color(0.95, 0.95, 0.96))


func test_the_rest_position_of_every_vertex_is_kept_for_the_kit() -> void:
	# シェーダーは UV2 の基準の姿勢の位置（x, y）で部位を決める
	var source := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.2, 1.4, 0.1), Vector3(-0.1, 0.3, 0.0), Vector3(0.0, 0.05, 0.1)])
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh: ArrayMesh = GoalPlayerModel.with_rest_positions(source)
	var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_array(Array(uv2)).is_equal([Vector2(0.2, 1.4), Vector2(-0.1, 0.3), Vector2(0.0, 0.05)])


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


func test_looping_clips_wrap_and_one_shot_clips_hold_the_end() -> void:
	var model: GoalPlayerModel = _model()
	var sprint: float = GoalPlayerModel.ANIMATIONS.get_animation("Sprint").length
	assert_float(model.clamp_time("Sprint", sprint + 0.1)).is_equal_approx(0.1, 0.0001)
	var yes: float = GoalPlayerModel.ANIMATIONS.get_animation("Yes").length
	assert_float(model.clamp_time("Yes", yes + 1.0)).is_equal(yes)

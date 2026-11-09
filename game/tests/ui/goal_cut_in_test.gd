## 得点のカットイン（GoalCutIn）の出し方・消え方のテスト。
extends GdUnitTestSuite

var _cut_in: GoalCutIn
var _finished: Array[int] = []


func before_test() -> void:
	_cut_in = auto_free(GoalCutIn.new()) as GoalCutIn
	_cut_in.size = Vector2(1600, 600)
	add_child(_cut_in)
	_finished = []
	_cut_in.finished.connect(func() -> void: _finished.append(1))


func test_play_shows_the_cut_in_with_the_texts_of_the_goal() -> void:
	assert_bool(_cut_in.visible).is_false()
	assert_bool(_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 1.0)).is_true()
	assert_bool(_cut_in.visible).is_true()
	assert_bool(_cut_in.is_playing()).is_true()
	assert_str(_cut_in.texts()["title"] as String).is_equal("GOAL!")
	assert_str(_cut_in.texts()["score"] as String).is_equal("● 1 − 0 ◆")
	assert_bool(_cut_in.is_user_goal()).is_true()
	# 押せる（下の盤面・ボタンへの入力を止め、押すと飛ばす）
	assert_int(_cut_in.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_every_scene_runs_through_the_stage_from_start_to_end() -> void:
	# どの場面も、時刻の初めから終わりまで舞台に置ける（素材に無い動きの名前を使うと、途中で止まる）。
	# 2人の選手は時刻とともに動く
	for kind: GoalCutIn.Kind in [GoalCutIn.Kind.GOAL, GoalCutIn.Kind.SAVE, GoalCutIn.Kind.STEAL]:
		_cut_in.play(kind, true, 1, 0, 2.0)
		var starts: Array[Vector3] = []
		for step: int in range(11):
			_cut_in._set_progress(step / 10.0)
			var hands: Array[Vector3] = [_cut_in.stage().holder().bone_position("hand_r"),
					_cut_in.stage().stopper().bone_position("hand_r")]
			if step == 0:
				starts = hands
		for index: int in range(2):
			var figure: GoalPlayerModel = _cut_in.stage().holder() if index == 0 else _cut_in.stage().stopper()
			var moved: float = figure.bone_position("hand_r").distance_to(starts[index])
			assert_float(moved).override_failure_message("%s %d" % [kind, index]).is_greater(0.05)
		_cut_in.stop()


func test_play_builds_a_3d_stage_and_the_end_removes_it() -> void:
	assert_object(_cut_in.stage()).is_null()
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	var stage: GoalStage3D = _cut_in.stage()
	assert_object(stage).is_not_null()
	# カメラ・ボール・選手の手足がそろい、時刻に合わせて置かれる
	assert_bool(stage.camera().current).is_true()
	assert_vector(stage.ball().position).is_equal(GoalCutInArt.ball_position(_cut_in.progress()))
	# 点を決める選手と、得点された側のゴールキーパー（素材の体）
	assert_object(stage.holder().skeleton()).is_not_null()
	assert_object(stage.stopper().skeleton()).is_not_null()
	_cut_in.stop()
	assert_object(_cut_in.stage()).is_null()


func test_the_3d_picture_is_full_size_only_while_playing() -> void:
	# 出していない間は、描く先の画を最小にして全画面の分を持たない
	assert_object(_cut_in._viewport.size).is_equal(GoalCutIn.IDLE_VIEWPORT_SIZE)
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	await await_idle_frame()
	assert_int(_cut_in._viewport.size.x).is_greater(GoalCutIn.IDLE_VIEWPORT_SIZE.x * 100)
	_cut_in.stop()
	assert_object(_cut_in._viewport.size).is_equal(GoalCutIn.IDLE_VIEWPORT_SIZE)


func test_the_stage_follows_the_progress() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, false, 0, 1, 2.0)
	_cut_in._set_progress(0.6)
	assert_vector(_cut_in.stage().ball().position).is_equal(GoalCutInArt.ball_position(0.6))
	var view: Dictionary = GoalCutInArt.camera_at(0.6)
	assert_vector(_cut_in.stage().camera().position).is_equal_approx(view["position"] as Vector3, Vector3(0.001, 0.001, 0.001))
	# 選手とキーパーは、時刻の置き方に置かれる
	assert_bool(_cut_in.stage().holder().transform.is_equal_approx(GoalCutInArt.striker_model_transform(0.6))).is_true()
	assert_bool(_cut_in.stage().stopper().transform.is_equal_approx(GoalCutInArt.keeper_model_transform(0.6))).is_true()


func test_the_striker_meets_the_ball_with_the_kicking_foot() -> void:
	# インパクトの瞬間、右足（ball_r。足の指の付け根）がボールに届いている
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	_cut_in._set_progress(GoalCutInArt.CONTACT_AT)
	var striker: GoalPlayerModel = _cut_in.stage().holder()
	var foot: Vector3 = striker.transform * striker.bone_position("ball_r")
	assert_float(foot.distance_to(GoalCutInArt.BALL_SPOT)).override_failure_message(str(foot)).is_less(0.3)
	# 足はボールの後ろ（+x）から当たる（ボールの中に入り込まない）
	assert_float(foot.x).is_greater(GoalCutInArt.BALL_SPOT.x)


func test_the_standing_foot_stays_on_its_spot_from_the_plant_to_the_follow_through() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	var spot: Vector3 = GoalCutInArt.plant_spot()
	for sec: float in [GoalCutInArt.PLANT_HOLD_FROM_SEC, 0.0, GoalCutInArt.PLANT_HOLD_UNTIL_SEC]:
		var p: float = GoalCutInArt.CONTACT_AT + sec * GoalCutInArt.KICK_P_PER_SEC
		_cut_in._set_progress(p)
		var striker: GoalPlayerModel = _cut_in.stage().holder()
		var foot: Vector3 = striker.transform * striker.bone_position(GoalPlayerModel.PLANT_BONE)
		assert_vector(foot * Vector3(1.0, 0.0, 1.0)).override_failure_message("%s %s" % [p, foot]) \
				.is_equal_approx(spot, Vector3(0.001, 0.001, 0.001))
		# 地面に着いている（指の付け根が、基準の姿勢の高さから 5 cm 以内）
		assert_float(foot.y).override_failure_message("%s %s" % [p, foot]).is_less(0.07)


# --- ボールを奪った・奪われた（描く体の骨で確かめる。2026-11-08） ---

func test_the_tackler_slides_in_and_reaches_the_ball_with_his_foot() -> void:
	_cut_in.play(GoalCutIn.Kind.STEAL, true, 1, 0, 2.0)
	assert_int(_cut_in.kind()).is_equal(GoalCutIn.Kind.STEAL)
	_cut_in._set_progress(StealCutInArt.CONTACT_AT)
	var tackler: GoalPlayerModel = _cut_in.stage().stopper()
	var foot: Vector3 = tackler.transform * tackler.bone_position("ball_r")
	assert_float(foot.distance_to(_cut_in.stage().ball().position)).override_failure_message(str(foot)).is_less(0.35)
	# ドリブルしていた選手の体は、ボールの後ろ（+x）にある
	var dribbler: GoalPlayerModel = _cut_in.stage().holder()
	assert_float(dribbler.transform.origin.x).is_greater(_cut_in.stage().ball().position.x)


func test_the_ball_winner_wears_the_winning_teams_kit() -> void:
	# 利用者が奪った: 奪う選手は利用者の無地（●）、ドリブルしていた選手は相手の縦じま（◆）
	_cut_in.play(GoalCutIn.Kind.STEAL, true, 1, 0, 2.0)
	var you: Color = _cut_in.get_theme_color(&"you", GoalCutIn.THEME_TYPE)
	assert_array(_cut_in.stage().stopper().shirt_colors()).is_equal([you])
	assert_int(_cut_in.stage().holder().shirt_colors().size()).is_equal(2)
	# 利用者が奪われた: 逆
	_cut_in.play(GoalCutIn.Kind.STEAL, false, 1, 0, 2.0)
	assert_int(_cut_in.stage().stopper().shirt_colors().size()).is_equal(2)
	assert_array(_cut_in.stage().holder().shirt_colors()).is_equal([you])


func test_the_keeper_catches_the_saved_shot_and_holds_it() -> void:
	_cut_in.play(GoalCutIn.Kind.SAVE, true, 1, 0, 2.0)
	assert_str(_cut_in.texts()["title"] as String).is_equal("SAVE!")
	# 利用者が止めた: キーパーは利用者のキーパーの色。蹴った選手は相手の縦じま
	var keeper_you: Color = _cut_in.get_theme_color(&"keeper_you", GoalCutIn.OWN_THEME_TYPE)
	assert_array(_cut_in.stage().stopper().shirt_colors()).is_equal([keeper_you])
	assert_int(_cut_in.stage().holder().shirt_colors().size()).is_equal(2)
	for p: float in [SaveCutInArt.catch_at(), SaveCutInArt.catch_at() + 0.2, 0.95]:
		_cut_in._set_progress(p)
		var keeper: GoalPlayerModel = _cut_in.stage().stopper()
		var hands: Vector3 = (keeper.transform * keeper.bone_position("hand_l") + keeper.transform * keeper.bone_position("hand_r")) / 2.0
		assert_float(_cut_in.stage().ball().position.distance_to(hands)).override_failure_message(str(p)).is_less(0.01)
	# つかむ瞬間の手は、ボールの飛んでくる先（CATCH_POINT）にある（ボールが手へ跳ばない）
	_cut_in._set_progress(SaveCutInArt.catch_at())
	assert_float(_cut_in.stage().ball().position.distance_to(SaveCutInArt.CATCH_POINT)).is_less(0.1)


# --- ゴールキーパー（描く体の骨で確かめる） ---

## 時刻 p のキーパーの骨 bone_name の、舞台での位置
func _keeper_bone(p: float, bone_name: String) -> Vector3:
	_cut_in._set_progress(p)
	var keeper: GoalPlayerModel = _cut_in.stage().stopper()
	return keeper.transform * keeper.bone_position(bone_name)


## 時刻 p のキーパーの全部の骨のうち、いちばん低い高さ
func _keeper_lowest(p: float) -> float:
	_cut_in._set_progress(p)
	var keeper: GoalPlayerModel = _cut_in.stage().stopper()
	var lowest: float = INF
	for bone: int in range(keeper.skeleton().get_bone_count()):
		lowest = minf(lowest, (keeper.transform * keeper.global_bone_pose(bone).origin).y)
	return lowest


func test_the_keeper_waits_crouched_on_the_goal_line_between_the_posts() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	var hips: Vector3 = _keeper_bone(0.2, "pelvis")
	assert_float(hips.x).is_between(0.0, 1.5)
	assert_float(absf(hips.z)).is_less(1.0)
	# 構え: 腰は立ったときより低い（膝を曲げている）。足は地面に着いている
	var keeper: GoalPlayerModel = _cut_in.stage().stopper()
	var standing: float = keeper.skeleton().get_bone_global_rest(keeper.skeleton().find_bone("pelvis")).origin.y
	assert_float(hips.y).is_less(standing - 0.1)
	assert_float(_keeper_lowest(0.2)).is_between(-0.02, 0.05)


func test_the_keeper_dives_toward_the_corner_of_the_ball() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	# ボールの来る隅は -z の側。手はそちらへ伸び、跳んで足が地面を離れる
	assert_float(GoalCutInArt.GOAL_LINE_POINT.z).is_less(0.0)
	var before: Vector3 = _keeper_bone(GoalCutInArt.KEEPER_JUMP_AT, "hand_r")
	var peak: Vector3 = _keeper_bone(GoalCutInArt.KEEPER_PEAK_AT, "hand_r")
	assert_float(minf(peak.z, _keeper_bone(GoalCutInArt.KEEPER_PEAK_AT, "hand_l").z)).is_less(before.z - 1.0)
	assert_float(minf(_keeper_bone(GoalCutInArt.KEEPER_PEAK_AT, "foot_l").y,
			_keeper_bone(GoalCutInArt.KEEPER_PEAK_AT, "foot_r").y)).is_greater(0.3)


func test_the_keeper_never_reaches_the_ball() -> void:
	# 指先が届かない（ボールが飛んでいる間、両手はボールから離れている）
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	for step: int in range(21):
		var p: float = lerpf(GoalCutInArt.BALL_START, GoalCutInArt.BALL_NET, step / 20.0)
		for hand: String in ["hand_l", "hand_r"]:
			var gap: float = _keeper_bone(p, hand).distance_to(GoalCutInArt.ball_position(p))
			assert_float(gap).override_failure_message("%s %s %s" % [p, hand, gap]).is_greater(0.3)


func test_the_keeper_lands_on_the_ground_and_never_sinks_into_it() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, false, 0, 1, 2.0)
	# 着地したら地面の近くに横たわる。どの時刻も、体のどの骨も芝の下へ沈まない
	assert_float(_keeper_lowest(0.9)).is_between(-0.03, 0.4)
	for step: int in range(41):
		var p: float = step / 40.0
		assert_float(_keeper_lowest(p)).override_failure_message(str(p)).is_greater(-0.03)


func test_the_cut_in_ends_by_itself_and_reports_it_once() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, false, 0, 1, 0.6)
	await await_millis(250)
	assert_float(_cut_in.progress()).override_failure_message(str(_cut_in.progress())).is_between(0.05, 0.95)
	assert_array(_finished).is_empty()
	await await_millis(600)
	assert_bool(_cut_in.visible).is_false()
	assert_bool(_cut_in.is_playing()).is_false()
	assert_array(_finished).has_size(1)


func test_a_tap_skips_the_cut_in() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	_cut_in._gui_input(tap)
	assert_bool(_cut_in.visible).is_false()
	assert_array(_finished).has_size(1)
	# 飛ばした後に時間が来ても、もう一度は知らせない
	await await_millis(100)
	_cut_in.stop()
	assert_array(_finished).has_size(1)


func test_a_touch_also_skips_the_cut_in() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	_cut_in._gui_input(touch)
	assert_bool(_cut_in.is_playing()).is_false()


func test_stop_ends_a_playing_cut_in_and_does_nothing_otherwise() -> void:
	_cut_in.stop()
	assert_array(_finished).is_empty()
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 2.0)
	_cut_in.stop()
	assert_bool(_cut_in.visible).is_false()
	assert_array(_finished).has_size(1)


func test_no_time_means_no_cut_in() -> void:
	for sec: float in [0.0, -1.0, NAN, INF]:
		assert_bool(_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, sec)).override_failure_message(str(sec)).is_false()
		assert_bool(_cut_in.visible).is_false()
	assert_array(_finished).is_empty()


func test_playing_again_restarts_from_the_beginning_without_reporting_the_old_one() -> void:
	_cut_in.play(GoalCutIn.Kind.GOAL, true, 1, 0, 0.3)
	await await_millis(150)
	_cut_in.play(GoalCutIn.Kind.GOAL, false, 1, 1, 0.3)
	assert_float(_cut_in.progress()).is_less(0.2)
	assert_bool(_cut_in.is_user_goal()).is_false()
	await await_millis(450)
	assert_array(_finished).has_size(1)

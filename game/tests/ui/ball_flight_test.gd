## BallFlight（開示の1拍目のボールの軌道の種類と、その形）のテスト。
extends GdUnitTestSuite

const Kind := BallFlight.Kind
const STYLE: Dictionary = {"loft": 6.0, "touch": 1.0, "touches": 3}
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const POS := GameEnums.ChoiceFamily.POS_TRANS
const NEG := GameEnums.ChoiceFamily.NEG_TRANS


func _choice(family: GameEnums.ChoiceFamily, action: int) -> TurnChoice:
	return TurnChoice.new(family, action, PitchArea.from_key("A1-C"))


# --- 手 → 軌道の種類 ---

func test_each_attacking_play_has_its_own_flight() -> void:
	var expected: Dictionary = {
		GameEnums.PlayType.SHORT_PASS: Kind.GROUND,
		GameEnums.PlayType.THROUGH_PASS: Kind.GROUND,
		GameEnums.PlayType.LONG_BEHIND: Kind.LOFTED,
		GameEnums.PlayType.SWITCH: Kind.LOFTED,
		GameEnums.PlayType.DRIBBLE: Kind.CARRIED,
		GameEnums.PlayType.SHOT: Kind.DRIVEN,
	}
	# 攻撃の手をすべて当てる（手を足したら、このテストで軌道を決め忘れに気づく）
	assert_int(expected.size()).is_equal(GameEnums.PlayType.size())
	for play: int in expected:
		assert_int(BallFlight.kind_for(_choice(ATTACK, play))).override_failure_message(str(play)).is_equal(expected[play])


func test_the_counter_is_a_ground_ball_and_the_other_hands_go_straight() -> void:
	assert_int(BallFlight.kind_for(_choice(POS, GameEnums.PosTransAction.COUNTER))).is_equal(Kind.GROUND)
	# 保持はボールを運ばない。守備・喪失側の手はボールを持たない
	assert_int(BallFlight.kind_for(TurnChoice.new(POS, GameEnums.PosTransAction.SECURE))).is_equal(Kind.STRAIGHT)
	assert_int(BallFlight.kind_for(_choice(DEFENSE, GameEnums.DefenseAction.PRESS))).is_equal(Kind.STRAIGHT)
	assert_int(BallFlight.kind_for(TurnChoice.new(NEG, GameEnums.NegTransAction.RETREAT))).is_equal(Kind.STRAIGHT)
	assert_int(BallFlight.kind_for(null)).is_equal(Kind.STRAIGHT)


func _reveal(user: TurnChoice, opponent: TurnChoice) -> RevealView:
	var reveal := RevealView.new()
	reveal.user_choice = user
	reveal.opponent_choice = opponent
	return reveal


func test_the_flight_follows_the_hand_of_the_side_holding_the_ball() -> void:
	var pass_choice: TurnChoice = _choice(ATTACK, GameEnums.PlayType.LONG_BEHIND)
	var press: TurnChoice = _choice(DEFENSE, GameEnums.DefenseAction.PRESS)
	var counter: TurnChoice = _choice(POS, GameEnums.PosTransAction.COUNTER)
	var retreat := TurnChoice.new(NEG, GameEnums.NegTransAction.RETREAT)
	# 利用者が攻撃・守備・奪取・喪失のどれでも、ボールを持つ側の手を選ぶ
	assert_object(BallFlight.holder_choice(_reveal(pass_choice, press))).is_same(pass_choice)
	assert_object(BallFlight.holder_choice(_reveal(press, pass_choice))).is_same(pass_choice)
	assert_object(BallFlight.holder_choice(_reveal(counter, retreat))).is_same(counter)
	assert_object(BallFlight.holder_choice(_reveal(retreat, counter))).is_same(counter)
	assert_object(BallFlight.holder_choice(_reveal(null, null))).is_null()
	assert_object(BallFlight.holder_choice(_reveal(press, retreat))).is_null()


# --- 軌道の形 ---

## 道筋の終わりまで進む種類（跳ね返り BOUNCE は元の位置へ戻るので除く）
func _reaching_kinds() -> Array[int]:
	var kinds: Array[int] = []
	for kind: int in Kind.values():
		if kind != Kind.BOUNCE:
			kinds.append(kind)
	return kinds


func test_every_flight_starts_and_ends_on_the_ground_at_the_ends_of_the_path() -> void:
	for kind: int in Kind.values():
		assert_float(BallFlight.along(kind, 0.0)).override_failure_message(str(kind)).is_equal(0.0)
		if kind != Kind.BOUNCE:
			assert_float(BallFlight.along(kind, 1.0)).override_failure_message(str(kind)).is_equal(1.0)
		assert_float(BallFlight.lift(kind, 0.0, STYLE)).override_failure_message(str(kind)).is_equal_approx(0.0, 0.0001)
		assert_float(BallFlight.lift(kind, 1.0, STYLE)).override_failure_message(str(kind)).is_equal_approx(0.0, 0.0001)


func test_ground_balls_and_shots_leave_fast_and_stay_on_the_ground() -> void:
	for kind: int in [Kind.GROUND, Kind.DRIVEN]:
		for t: float in [0.25, 0.5, 0.75]:
			assert_float(BallFlight.along(kind, t)).override_failure_message("%d %s" % [kind, t]).is_greater(t)
			assert_float(BallFlight.lift(kind, t, STYLE)).is_equal(0.0)
	# シュートはグラウンダーより、はじめに一気に進む
	assert_float(BallFlight.along(Kind.DRIVEN, 0.25)).is_greater(BallFlight.along(Kind.GROUND, 0.25))


func test_straight_lofted_and_carried_balls_move_at_an_even_pace() -> void:
	for kind: int in [Kind.STRAIGHT, Kind.LOFTED, Kind.CARRIED]:
		for t: float in [0.25, 0.5, 0.75]:
			assert_float(BallFlight.along(kind, t)).override_failure_message("%d %s" % [kind, t]).is_equal_approx(t, 0.0001)
	assert_float(BallFlight.lift(Kind.STRAIGHT, 0.5, STYLE)).is_equal(0.0)


func test_a_lofted_ball_peaks_at_the_loft_height_in_the_middle() -> void:
	assert_float(BallFlight.lift(Kind.LOFTED, 0.5, STYLE)).is_equal_approx(6.0, 0.0001)
	assert_float(BallFlight.lift(Kind.LOFTED, 0.25, STYLE)).is_between(0.1, 5.9)
	# 弧は左右対称
	assert_float(BallFlight.lift(Kind.LOFTED, 0.25, STYLE)).is_equal_approx(BallFlight.lift(Kind.LOFTED, 0.75, STYLE), 0.0001)
	assert_float(BallFlight.lift(Kind.LOFTED, 0.5, {"loft": 2.0, "touch": 1.0, "touches": 3})).is_equal_approx(2.0, 0.0001)


func test_a_carried_ball_bounces_as_many_times_as_the_touches() -> void:
	# 3回なら、弾みの頂点は 1/6・3/6・5/6、地面に着くのは 1/3・2/3
	for t: float in [1.0 / 6.0, 0.5, 5.0 / 6.0]:
		assert_float(BallFlight.lift(Kind.CARRIED, t, STYLE)).override_failure_message(str(t)).is_equal_approx(1.0, 0.0001)
	for t: float in [1.0 / 3.0, 2.0 / 3.0]:
		assert_float(BallFlight.lift(Kind.CARRIED, t, STYLE)).override_failure_message(str(t)).is_equal_approx(0.0, 0.0001)
	# 2回なら、真ん中で地面に着く
	var twice: Dictionary = {"loft": 6.0, "touch": 0.5, "touches": 2}
	assert_float(BallFlight.lift(Kind.CARRIED, 0.5, twice)).is_equal_approx(0.0, 0.0001)
	assert_float(BallFlight.lift(Kind.CARRIED, 0.25, twice)).is_equal_approx(0.5, 0.0001)


func test_a_stalled_ball_goes_partway_toward_the_target_and_comes_back() -> void:
	# 膠着の跳ね返り: 運ぶ先の方へ4割まで進んで、元の位置へ戻る。地面を転がる
	assert_float(BallFlight.along(Kind.BOUNCE, 0.5)).is_equal_approx(0.4, 0.0001)
	assert_float(BallFlight.along(Kind.BOUNCE, 1.0)).is_equal_approx(0.0, 0.0001)
	assert_float(BallFlight.along(Kind.BOUNCE, 0.25)).is_between(0.1, 0.39)
	assert_float(BallFlight.along(Kind.BOUNCE, 0.25)).is_equal_approx(BallFlight.along(Kind.BOUNCE, 0.75), 0.0001)
	assert_float(BallFlight.lift(Kind.BOUNCE, 0.5, STYLE)).is_equal(0.0)


func test_progress_outside_zero_to_one_is_held_at_the_ends() -> void:
	# Tween の端数で範囲をわずかに外れても、道筋の外へ出ず、地面より下へも行かない
	for kind: int in Kind.values():
		assert_float(BallFlight.along(kind, -0.1)).is_equal(0.0)
		assert_float(BallFlight.along(kind, 1.1)).is_equal(BallFlight.along(kind, 1.0))
	for kind: int in _reaching_kinds():
		assert_float(BallFlight.along(kind, 1.1)).is_equal(1.0)
		assert_float(BallFlight.lift(kind, 1.1, STYLE)).is_greater_equal(0.0)
		assert_float(BallFlight.lift(kind, -0.1, STYLE)).is_greater_equal(0.0)

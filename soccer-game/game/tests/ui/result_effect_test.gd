## ResultEffect（開示の1拍目の終わりに出す結果の演出の区分・場所・色の側）のテスト。
extends GdUnitTestSuite

const Kind := ResultEffect.Kind
const Outcome := GameEnums.TurnOutcome


## 利用者の役割 role・結果 outcome の開示。ボールを持つ側の手は運ぶ先 A1-C のショートパス、相手は守備の手
func _reveal(role: GameEnums.Phase, outcome: GameEnums.TurnOutcome) -> RevealView:
	var reveal := RevealView.new()
	reveal.user_role = role
	reveal.outcome = outcome
	reveal.ball_before = "M2-C"
	reveal.ball_after = "A1-L1"
	reveal.compare_area = "A1-R1"
	var attack := TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("A1-C"))
	var defense := TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.PRESS, PitchArea.from_key("A1-C"))
	var user_attacks: bool = role == GameEnums.Phase.ATTACK
	reveal.user_choice = attack if user_attacks else defense
	reveal.opponent_choice = defense if user_attacks else attack
	return reveal


func test_a_goal_lights_the_goal_of_the_scorer() -> void:
	var mine: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.ATTACK, Outcome.GOAL))
	assert_dict(mine).is_equal({"kind": Kind.GOAL, "area": "A1-L1", "is_user": true, "toward": ""})
	# 相手が決めたときは相手の色（下のゴール）
	var theirs: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.DEFENSE, Outcome.GOAL))
	assert_int(theirs["kind"] as int).is_equal(Kind.GOAL)
	assert_bool(theirs["is_user"] as bool).is_false()


func test_a_save_shows_the_keeper_of_the_side_that_stopped_it() -> void:
	var effect: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.DEFENSE, Outcome.SAVE))
	assert_dict(effect).is_equal({"kind": Kind.SAVE, "area": "A1-L1", "is_user": true, "toward": ""})
	assert_bool(ResultEffect.for_reveal(_reveal(GameEnums.Phase.ATTACK, Outcome.SAVE))["is_user"] as bool).is_false()


func test_winning_the_ball_marks_where_it_was_won_in_the_winner_color() -> void:
	# ロスト: 守備側が奪う。利用者が守備なら利用者の色
	var lost: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.DEFENSE, Outcome.LOSS))
	assert_dict(lost).is_equal({"kind": Kind.WIN_BALL, "area": "A1-L1", "is_user": true, "toward": ""})
	assert_bool(ResultEffect.for_reveal(_reveal(GameEnums.Phase.ATTACK, Outcome.LOSS))["is_user"] as bool).is_false()
	# 奪回成功: 喪失側（即時奪回）が取り返す
	var regained: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.NEG_TRANSITION, Outcome.REGAIN))
	assert_int(regained["kind"] as int).is_equal(Kind.WIN_BALL)
	assert_bool(regained["is_user"] as bool).is_true()


func test_an_offside_raises_the_flag_where_the_receiver_was() -> void:
	var effect: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.ATTACK, Outcome.OFFSIDE))
	# 比較エリア（受け手のいたエリア）。旗は守備側の色
	assert_dict(effect).is_equal({"kind": Kind.OFFSIDE, "area": "A1-R1", "is_user": false, "toward": ""})


func test_an_unreadable_area_shows_nothing_instead_of_a_mark_in_the_corner() -> void:
	# 場所が読めないと、輪や旗が盤面の左上（原点）に出てしまう。印を出さない
	var offside: RevealView = _reveal(GameEnums.Phase.ATTACK, Outcome.OFFSIDE)
	offside.has_detail = false
	offside.compare_area = ""
	assert_dict(ResultEffect.for_reveal(offside)).is_equal({"kind": Kind.NONE, "area": "", "is_user": false, "toward": ""})
	var lost: RevealView = _reveal(GameEnums.Phase.DEFENSE, Outcome.LOSS)
	lost.ball_after = "X-9"
	assert_int(ResultEffect.for_reveal(lost)["kind"] as int).is_equal(Kind.NONE)
	# 得点はゴールに印を出すので、シュートしたエリアが読めなくても出す
	var goal: RevealView = _reveal(GameEnums.Phase.ATTACK, Outcome.GOAL)
	goal.ball_after = ""
	assert_int(ResultEffect.for_reveal(goal)["kind"] as int).is_equal(Kind.GOAL)


func test_a_stall_bounces_the_ball_back_from_the_target_of_the_holder() -> void:
	var effect: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.DEFENSE, Outcome.STALL))
	assert_dict(effect).is_equal({"kind": Kind.STALL, "area": "A1-L1", "is_user": true, "toward": "A1-C"})
	# 運ぶ先の無い手（保持）では跳ね返さない
	var secure: RevealView = _reveal(GameEnums.Phase.POS_TRANSITION, Outcome.STALL)
	secure.user_choice = TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)
	secure.opponent_choice = TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	assert_int(ResultEffect.for_reveal(secure)["kind"] as int).is_equal(Kind.NONE)


func test_other_outcomes_show_nothing() -> void:
	for outcome: int in [Outcome.ADVANCE, Outcome.REGAIN_FAILED, Outcome.NO_CONTEST]:
		var effect: Dictionary = ResultEffect.for_reveal(_reveal(GameEnums.Phase.ATTACK, outcome))
		assert_int(effect["kind"] as int).override_failure_message(str(outcome)).is_equal(Kind.NONE)
		assert_str(effect["area"] as String).is_empty()
	# 結果を足したら、ここで演出を決め忘れに気づく
	assert_int(Outcome.size()).is_equal(9)

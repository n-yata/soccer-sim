## オフサイド（OffsideRule。functional-overview.md アルゴリズム5。2026-10-25）のテスト。
## 期待値は要求書の規則から手で書いた。列番号は攻撃側の視点（0 = D1 … 5 = A2）。攻撃側の配置とボールは攻撃側の視点、
## 守備側の配置は守備側の視点（component-design.md §1.2）。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## エリアのキーの並びから、1エリア1人の配置を作る（選手 ID は p0, p1, ...）
func _team(keys: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	for index: int in range(keys.size()):
		players.append(PlayerState.new("p%d" % index, _area(keys[index] as String)))
	return TeamLayout.at_base(players)


func _pair(attacker_keys: Array, defender_keys: Array) -> LayoutPair:
	return LayoutPair.new(_team(attacker_keys), _team(defender_keys), GameEnums.TeamSide.HOME)


func _attack(play: GameEnums.PlayType, target_key: String = "") -> TurnChoice:
	return TurnChoice.new(ATTACK, play, null if target_key == "" else _area(target_key))


# --- ライン ---

func test_line_is_the_row_of_the_deepest_defender_seen_by_the_attacker() -> void:
	# 守備側の D2-C（攻撃側の視点で A1 = 4）と M1-L1（M2 = 3）。いちばん自陣ゴールに近いのは D2 の選手で、ラインは 4
	assert_int(OffsideRule.line_row(_team(["M1-L1", "D2-C"]), _area("D1-C"))).is_equal(4)
	# 最終ラインの選手が D1 まで下がれば、ラインは 5（誰もオフサイドにならない）
	assert_int(OffsideRule.line_row(_team(["M1-L1", "D1-C"]), _area("D1-C"))).is_equal(5)


func test_line_never_comes_into_the_attackers_own_half() -> void:
	# 守備側が全員敵陣（攻撃側の視点で 0・1 列目）にいても、自陣の受け手はオフサイドにならないので、ラインは自陣の境の 2
	assert_int(OffsideRule.line_row(_team(["A2-C", "A1-L1"]), _area("D1-C"))).is_equal(2)
	# ちょうど自陣の境（守備側の M2 = 攻撃側の M1 = 2）なら 2
	assert_int(OffsideRule.line_row(_team(["M2-C"]), _area("D1-C"))).is_equal(2)


func test_line_is_the_ball_when_the_ball_is_beyond_the_last_defender() -> void:
	# 実際のサッカーと同じく、ボールより前にいない受け手はオフサイドではない。ボールが最終ラインより前なら、ボールの列がライン
	# （守備側の M1-C = 攻撃側の視点で M2 = 3、ボールは A1 = 4）
	assert_int(OffsideRule.line_row(_team(["M1-C"]), _area("A1-C"))).is_equal(4)
	# ボールが最終ラインより後ろなら、最終ラインのまま
	assert_int(OffsideRule.line_row(_team(["M1-C"]), _area("M1-C"))).is_equal(3)


func test_a_through_pass_receiver_level_with_the_ball_is_onside() -> void:
	# ボールは A1-C（4）で、最終ラインの守備者は M2（3）。ボールと同じ列の A1-L1 から A2-C へ走り込むのはオンサイド
	var defenders: Array = ["M1-C"]
	assert_bool(OffsideRule.is_offside(_pair(["A1-C", "A1-L1"], defenders), _area("A1-C"),
			_attack(GameEnums.PlayType.THROUGH_PASS, "A2-C"))).is_false()
	# ボールより前の A2-L1 から走り込めばオフサイド
	assert_bool(OffsideRule.is_offside(_pair(["A1-C", "A2-L1"], defenders), _area("A1-C"),
			_attack(GameEnums.PlayType.THROUGH_PASS, "A2-C"))).is_true()


func test_line_without_defenders_puts_nobody_offside() -> void:
	assert_int(OffsideRule.line_row(_team([]), _area("D1-C"))).is_equal(5)


# --- 受け手 ---

func test_receiver_of_a_through_pass_is_where_the_runner_starts() -> void:
	# 走り込む前の A1-L1 で判定する（走り込んだ先の A1-C ではない）
	var pair: LayoutPair = _pair(["M2-C", "A1-L1"], [])
	var area: PitchArea = OffsideRule.receiver_area(pair, _area("M2-C"), _attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"))
	assert_str(area.to_key()).is_equal("A1-L1")


func test_receiver_of_a_forward_pass_or_long_ball_is_the_target() -> void:
	var pair: LayoutPair = _pair(["M1-C", "A1-L1", "A2-C"], [])
	var ball: PitchArea = _area("M1-C")
	assert_str(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.SHORT_PASS, "A1-L1")).to_key()).is_equal("A1-L1")
	assert_str(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.LONG_BEHIND, "A2-C")).to_key()).is_equal("A2-C")


func test_sideways_and_backward_passes_and_other_moves_have_no_receiver() -> void:
	# 横・後ろへのパス、サイドチェンジ、ドリブル、シュートはオフサイドの対象外
	var pair: LayoutPair = _pair(["A1-C", "A1-L1", "M2-C", "A1-R2", "A2-C"], [])
	var ball: PitchArea = _area("A1-C")
	assert_object(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.SHORT_PASS, "A1-L1"))).is_null()
	assert_object(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.SHORT_PASS, "M2-C"))).is_null()
	assert_object(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.SWITCH, "A1-R2"))).is_null()
	assert_object(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.DRIBBLE, "A2-C"))).is_null()
	assert_object(OffsideRule.receiver_area(pair, ball, _attack(GameEnums.PlayType.SHOT))).is_null()


# --- 判定 ---

func test_a_receiver_one_row_beyond_the_line_is_offside_and_level_is_onside() -> void:
	# 守備の最終ラインは M1（攻撃側の視点で M2 = 3）。ボールは M1-C
	var defenders: Array = ["M1-C", "M2-L1"]
	var ball: PitchArea = _area("M1-C")
	# A1（4）の受け手へのパスはオフサイド、M2（3）はラインと同じ列でオンサイド
	assert_bool(OffsideRule.is_offside(_pair(["M1-C", "A1-C"], defenders), ball,
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"))).is_true()
	assert_bool(OffsideRule.is_offside(_pair(["M1-C", "M2-C"], defenders), ball,
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"))).is_false()


func test_a_receiver_in_the_own_half_is_never_offside() -> void:
	# 守備側は全員が攻撃側の自陣より手前（攻撃側の視点で 0・1 列目）。自陣の M1（2）の受け手はオンサイド、M2（3）はオフサイド
	var defenders: Array = ["A2-C", "A1-C"]
	var ball: PitchArea = _area("D2-C")
	assert_bool(OffsideRule.is_offside(_pair(["D2-C", "M1-C"], defenders), ball,
			_attack(GameEnums.PlayType.SHORT_PASS, "M1-C"))).is_false()
	assert_bool(OffsideRule.is_offside(_pair(["M1-C", "M2-C"], defenders), _area("M1-C"),
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"))).is_true()


func test_a_through_pass_is_judged_where_the_runner_starts() -> void:
	# 最終ラインは A1（守備側の D2-C = 4）。受け手が A1-L1（4。ラインと同じ列）から A2-C へ走り込むのはオンサイド、
	# A2-L1（5。ラインより前）から走り込むのはオフサイド
	var defenders: Array = ["D2-C"]
	var ball: PitchArea = _area("A1-C")
	assert_bool(OffsideRule.is_offside(_pair(["A1-C", "A1-L1"], defenders), ball,
			_attack(GameEnums.PlayType.THROUGH_PASS, "A2-C"))).is_false()
	assert_bool(OffsideRule.is_offside(_pair(["M2-C", "A2-L1"], defenders), _area("M2-C"),
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"))).is_true()

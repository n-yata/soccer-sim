## アルゴリズム8: CPU の選択（CpuPlanner）のテスト。
## 期待値は functional-overview.md アルゴリズム8の式と規則から手で書いた。乱数はテストで固定シードの生成器を作って渡す
## （ドメインは乱数生成器を作らない）。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS
const ZONE := GameEnums.DefenseStyle.ZONE


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 局面の加点（ゴールへ向かう加点・守備の先読み）は 0 にする（評価値・方式の癖の確率を確かめるテストに混ぜないため。加点のテストは _goal_cpu）
func _cpu(temperature: float = 1.0, floor_probability: float = 0.1) -> CpuConfig:
	var cpu := CpuConfig.new()
	cpu.temperature = temperature
	cpu.floor_probability = floor_probability
	cpu.forward_bonus = 0.0
	cpu.shot_bonus = 0.0
	cpu.anticipation_bonus = 0.0
	return cpu


func _players(spec: Array) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String)))
	return players


## HOME が保持する攻守ターン（move_hints_test.gd と同じ場面）: h1 がボールの M2-C、h2 が A1-C。
## 相手の a1 は自陣 D2-C、a2 は A2-L2。HOME のヒントはパス A1-C が ±0、ドリブル8つが +1
func _scene() -> MatchState:
	var state := MatchState.new()
	state.possession = HOME
	state.ball_area = _area("M2-C")
	state.home_setup = TeamSetup.new("x", TeamStyles.new(ZONE, GameEnums.AttackStyle.COUNTER))
	state.away_setup = TeamSetup.new("y", TeamStyles.new(ZONE, GameEnums.AttackStyle.COUNTER))
	state.home_players = _players([["h1", "M2-C"], ["h2", "A1-C"]])
	state.away_players = _players([["a1", "D2-C"], ["a2", "A2-L2"]])
	return state


func _transition_scene() -> MatchState:
	var state: MatchState = _scene()
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.ball_area = _area("M1-C")
	state.transition_origin = LayoutPair.new(TeamLayout.at_base(state.home_players),
			TeamLayout.at_base(state.away_players), HOME)
	return state


func _key(choice: TurnChoice) -> String:
	return "%d:%d:%s" % [choice.family, choice.action, "-" if choice.target == null else choice.target.to_key()]


func _sum(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total


# --- 選択確率 ---

func test_equal_scores_give_equal_probabilities() -> void:
	var probabilities: Array[float] = CpuPlanner.probabilities([0.0, 0.0, 0.0, 0.0], _cpu())
	for p: float in probabilities:
		assert_float(p).is_equal_approx(0.25, 0.000001)


func test_probabilities_follow_the_formula() -> void:
	# τ = 1, floor = 0.1, N = 2: p = 0.05 + 0.9 * softmax。softmax(1, 0) = e / (e + 1)
	var soft: float = exp(1.0) / (exp(1.0) + 1.0)
	var probabilities: Array[float] = CpuPlanner.probabilities([1.0, 0.0], _cpu())
	assert_float(probabilities[0]).is_equal_approx(0.05 + 0.9 * soft, 0.000001)
	assert_float(probabilities[1]).is_equal_approx(0.05 + 0.9 * (1.0 - soft), 0.000001)


func test_every_move_keeps_at_least_floor_over_n_even_with_extreme_scores() -> void:
	var probabilities: Array[float] = CpuPlanner.probabilities([1000.0, -1000.0, 0.0], _cpu())
	assert_float(_sum(probabilities)).is_equal_approx(1.0, 0.000001)
	for p: float in probabilities:
		assert_bool(is_finite(p)).is_true()
		assert_float(p).is_greater_equal(0.1 / 3.0 - 0.000001)
	# 低い2つはほぼ下限ちょうど
	assert_float(probabilities[1]).is_equal_approx(0.1 / 3.0, 0.000001)


func test_lower_temperature_concentrates_on_the_best_move() -> void:
	var warm: Array[float] = CpuPlanner.probabilities([1.0, 0.0], _cpu(1.0))
	var cold: Array[float] = CpuPlanner.probabilities([1.0, 0.0], _cpu(0.25))
	assert_float(cold[0]).is_greater(warm[0])


func test_broken_settings_fall_back_to_uniform_probabilities() -> void:
	# 範囲の検査はデータ層の役目だが、壊れた値が届いても NaN で最後の手へ偏らず、一様にする
	for cpu: CpuConfig in [_cpu(0.0), _cpu(-1.0), _cpu(NAN), _cpu(INF), _cpu(1.0, 1.0), _cpu(1.0, -0.1), _cpu(1.0, NAN)]:
		var probabilities: Array[float] = CpuPlanner.probabilities([3.0, 0.0], cpu)
		var label: String = "τ=%s floor=%s" % [cpu.temperature, cpu.floor_probability]
		assert_float(probabilities[0]).override_failure_message(label).is_equal_approx(0.5, 0.000001)
		assert_float(probabilities[1]).override_failure_message(label).is_equal_approx(0.5, 0.000001)


func test_non_finite_scores_fall_back_to_uniform_probabilities() -> void:
	# 今の評価値は整数から作るので起きないが、公開関数として壊れた入力でも NaN を返さない
	for scores: Array[float] in [[INF, 0.0] as Array[float], [NAN, 0.0] as Array[float], [-INF, 1.0] as Array[float]]:
		var probabilities: Array[float] = CpuPlanner.probabilities(scores, _cpu())
		assert_float(probabilities[0]).override_failure_message(str(scores)).is_equal_approx(0.5, 0.000001)
		assert_float(probabilities[1]).override_failure_message(str(scores)).is_equal_approx(0.5, 0.000001)


func test_no_scores_give_no_probabilities() -> void:
	var none: Array[float] = []
	assert_array(CpuPlanner.probabilities(none, _cpu())).is_empty()


# --- 評価値の向き ---

func test_scores_follow_the_move_kind() -> void:
	var cover := GameEnums.CoverKind.NONE
	# 攻撃・カウンター・即時奪回は 自分 − 相手
	assert_float(CpuPlanner.score(ChoiceHint.new(ATTACK, GameEnums.PlayType.DRIBBLE, _area("A1-C"), true, 2, 1, cover))).is_equal(1.0)
	assert_float(CpuPlanner.score(ChoiceHint.new(POS_TRANS, GameEnums.PosTransAction.COUNTER, _area("A1-C"), true, 1, 3, cover))).is_equal(-2.0)
	assert_float(CpuPlanner.score(ChoiceHint.new(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS, null, true, 2, 1, cover))).is_equal(1.0)
	# 守備は脅威度（攻撃側 − 守備側）。守備側から見た 0対1 は脅威 +1
	assert_float(CpuPlanner.score(ChoiceHint.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("M2-C"), true, 0, 1, cover))).is_equal(1.0)
	# 比べない手は 0
	assert_float(CpuPlanner.score(ChoiceHint.new(POS_TRANS, GameEnums.PosTransAction.SECURE, null, false, 0, 0, cover))).is_equal(0.0)


# --- 方式の癖 ---

func _bonus_cpu(bonus: float) -> CpuConfig:
	var cpu: CpuConfig = _cpu()
	cpu.style_bonus = bonus
	return cpu


func test_style_bonus_goes_to_the_moves_each_style_prefers() -> void:
	var cpu: CpuConfig = _bonus_cpu(1.5)
	var ball: PitchArea = _area("M2-C")
	var counter_man := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	var possession_zone := TeamStyles.new(ZONE, GameEnums.AttackStyle.POSSESSION)
	# [手の種類, 手, 運ぶ先, カウンター型・マンツーマンでの加点, 保持型・ゾーンでの加点]
	var cases: Array = [
		[ATTACK, GameEnums.PlayType.LONG_BEHIND, "A1-C", 1.5, 0.0],
		# スルーパスは背後を直線的に狙う手なので、カウンター型が好む（2026-10-25）
		[ATTACK, GameEnums.PlayType.THROUGH_PASS, "A1-C", 1.5, 0.0],
		[ATTACK, GameEnums.PlayType.DRIBBLE, "A1-C", 1.5, 0.0],
		[ATTACK, GameEnums.PlayType.DRIBBLE, "M2-L1", 0.0, 0.0],
		[ATTACK, GameEnums.PlayType.DRIBBLE, "M1-C", 0.0, 0.0],
		# 斜め前は前（列が前）へのドリブルとして加点、斜め後ろは加点しない（2026-10-24 の8方向のドリブル）
		[ATTACK, GameEnums.PlayType.DRIBBLE, "A1-L1", 1.5, 0.0],
		[ATTACK, GameEnums.PlayType.DRIBBLE, "M1-R1", 0.0, 0.0],
		[ATTACK, GameEnums.PlayType.SHORT_PASS, "A1-C", 0.0, 1.5],
		[ATTACK, GameEnums.PlayType.SWITCH, "M2-L2", 0.0, 1.5],
		[ATTACK, GameEnums.PlayType.SHOT, "", 0.0, 0.0],
		[POS_TRANS, GameEnums.PosTransAction.COUNTER, "A1-C", 1.5, 0.0],
		[POS_TRANS, GameEnums.PosTransAction.SECURE, "", 0.0, 1.5],
		[DEFENSE, GameEnums.DefenseAction.PRESS, "M2-C", 1.5, 0.0],
		[DEFENSE, GameEnums.DefenseAction.COVER, "M2-C", 0.0, 1.5],
		[NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS, "", 1.5, 0.0],
		[NEG_TRANS, GameEnums.NegTransAction.RETREAT, "", 0.0, 1.5],
	]
	for case: Array in cases:
		var target_key: String = case[2] as String
		var hint := ChoiceHint.new(case[0] as GameEnums.ChoiceFamily, case[1] as int,
				null if target_key == "" else _area(target_key), true, 1, 1, GameEnums.CoverKind.NONE)
		assert_float(CpuPlanner.style_bonus(hint, counter_man, ball, cpu)).override_failure_message("counter/man %s" % str(case)) \
				.is_equal(case[3] as float)
		assert_float(CpuPlanner.style_bonus(hint, possession_zone, ball, cpu)).override_failure_message("possession/zone %s" % str(case)) \
				.is_equal(case[4] as float)


## _scene の HOME（カウンター型）の手のうち、ドリブルの運ぶ先 target_key の添字
func _dribble_index(hints: Array[ChoiceHint], target_key: String) -> int:
	for index: int in range(hints.size()):
		var hint: ChoiceHint = hints[index]
		if hint.action == GameEnums.PlayType.DRIBBLE and hint.target.to_key() == target_key:
			return index
	return -1


func test_zero_style_bonus_keeps_the_probabilities_of_the_scores_alone() -> void:
	var state: MatchState = _scene()
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, HOME, MoveRules.options_for(state, HOME))
	var scores: Array[float] = []
	for hint: ChoiceHint in hints:
		scores.append(CpuPlanner.score(hint))
	var plain: Array[float] = CpuPlanner.probabilities(scores, _bonus_cpu(0.0))
	var actual: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _bonus_cpu(0.0))
	assert_int(actual.size()).is_equal(plain.size())
	for index: int in range(plain.size()):
		assert_float(actual[index]).is_equal_approx(plain[index], 0.000001)


func test_style_bonus_raises_the_preferred_moves_probability() -> void:
	# カウンター型の HOME: 前（A1-C）へのドリブルは好む手、横（M2-L1）へのドリブルは好む手でない。評価値はどちらも +1
	var state: MatchState = _scene()
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, HOME, MoveRules.options_for(state, HOME))
	var forward: int = _dribble_index(hints, "A1-C")
	var side: int = _dribble_index(hints, "M2-L1")
	var none: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _bonus_cpu(0.0))
	var biased: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _bonus_cpu(2.0))
	assert_float(none[forward]).is_equal_approx(none[side], 0.000001)
	assert_float(biased[forward]).is_greater(none[forward])
	assert_float(biased[forward]).is_greater(biased[side])
	assert_float(_sum(biased)).is_equal_approx(1.0, 0.000001)
	for p: float in biased:
		assert_float(p).is_greater_equal(0.1 / biased.size() - 0.000001)


func test_choose_turn_follows_the_style_bonus() -> void:
	# 加点が大きいと、カウンター型は前へのドリブルを、横へのドリブルより多く選ぶ
	var state: MatchState = _scene()
	var forward_key: String = "%d:%d:A1-C" % [ATTACK, GameEnums.PlayType.DRIBBLE]
	var side_key: String = "%d:%d:M2-L1" % [ATTACK, GameEnums.PlayType.DRIBBLE]
	var counts: Dictionary = {}
	for seed_value: int in range(500):
		var key: String = _key(CpuPlanner.choose_turn(state, HOME, _bonus_cpu(3.0), _rng(seed_value)))
		counts[key] = (counts.get(key, 0) as int) + 1
	assert_int(counts.get(forward_key, 0) as int).is_greater((counts.get(side_key, 0) as int) * 3)


# --- 局面の加点（ゴールへ向かう加点と守備の先読み） ---

## 方式の癖の加点は 0 にして、局面の加点だけを効かせる
func _goal_cpu(forward_bonus: float, shot_bonus: float, anticipation_bonus: float = 0.0) -> CpuConfig:
	var cpu: CpuConfig = _bonus_cpu(0.0)
	cpu.forward_bonus = forward_bonus
	cpu.shot_bonus = shot_bonus
	cpu.anticipation_bonus = anticipation_bonus
	return cpu


func test_situation_bonus_rewards_moving_forward_shooting_and_anticipating() -> void:
	var cpu: CpuConfig = _goal_cpu(0.5, 2.0, 0.75)
	# [手の種類, 手, 運ぶ先, ボール位置, 加点]
	var cases: Array = [
		[ATTACK, GameEnums.PlayType.SHORT_PASS, "A1-C", "M2-C", 0.5],
		[ATTACK, GameEnums.PlayType.LONG_BEHIND, "A1-L1", "M1-C", 1.0],
		[ATTACK, GameEnums.PlayType.THROUGH_PASS, "A2-C", "M2-C", 1.0],
		[ATTACK, GameEnums.PlayType.DRIBBLE, "M2-L1", "M2-C", 0.0],
		# 後ろへ運ぶ手は負
		[ATTACK, GameEnums.PlayType.SHORT_PASS, "M1-C", "M2-C", -0.5],
		[ATTACK, GameEnums.PlayType.SWITCH, "M2-R2", "M2-L2", 0.0],
		[ATTACK, GameEnums.PlayType.SHOT, "", "A1-C", 2.0],
		[POS_TRANS, GameEnums.PosTransAction.COUNTER, "A1-C", "M1-C", 1.0],
		[POS_TRANS, GameEnums.PosTransAction.SECURE, "", "M1-C", 0.0],
		# 守備の手は先読みの加点。制限するエリアがボールより前（攻撃側の視点）ほど大きく、後ろは負
		[DEFENSE, GameEnums.DefenseAction.PRESS, "A1-C", "M1-C", 1.5],
		[DEFENSE, GameEnums.DefenseAction.COVER, "M2-L1", "M2-C", 0.0],
		[DEFENSE, GameEnums.DefenseAction.PRESS, "M1-C", "M2-C", -0.75],
		[NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS, "", "M2-C", 0.0],
	]
	for case: Array in cases:
		var target_key: String = case[2] as String
		var hint := ChoiceHint.new(case[0] as GameEnums.ChoiceFamily, case[1] as int,
				null if target_key == "" else _area(target_key), true, 1, 1, GameEnums.CoverKind.NONE)
		assert_float(CpuPlanner.situation_bonus(hint, _area(case[3] as String), cpu)).override_failure_message(str(case)) \
				.is_equal(case[4] as float)


func test_zero_situation_bonus_adds_nothing() -> void:
	var cpu: CpuConfig = _goal_cpu(0.0, 0.0)
	var shot := ChoiceHint.new(ATTACK, GameEnums.PlayType.SHOT, null, true, 1, 1, GameEnums.CoverKind.NONE)
	var forward_pass := ChoiceHint.new(ATTACK, GameEnums.PlayType.SHORT_PASS, _area("A1-C"), true, 1, 1, GameEnums.CoverKind.NONE)
	assert_float(CpuPlanner.situation_bonus(shot, _area("A1-C"), cpu)).is_equal(0.0)
	assert_float(CpuPlanner.situation_bonus(forward_pass, _area("M1-C"), cpu)).is_equal(0.0)
	var press := ChoiceHint.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("A1-C"), true, 1, 1, GameEnums.CoverKind.NONE)
	assert_float(CpuPlanner.situation_bonus(press, _area("M1-C"), cpu)).is_equal(0.0)


func test_anticipation_bonus_raises_the_press_ahead_of_the_ball() -> void:
	# AWAY が守備。HOME のボールは M2-C。先読みの加点で、ボールより前の列を制限する手が選ばれやすくなる
	var state: MatchState = _scene()
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, AWAY, MoveRules.options_for(state, AWAY))
	var ahead: int = -1
	var behind: int = -1
	for index: int in range(hints.size()):
		var target: PitchArea = hints[index].target
		if hints[index].family != DEFENSE or target == null:
			continue
		if target.zone > state.ball_area.zone:
			ahead = index
		elif target.zone < state.ball_area.zone:
			behind = index
	assert_int(ahead).is_not_equal(-1)
	assert_int(behind).is_not_equal(-1)
	var none: Array[float] = CpuPlanner.turn_probabilities(state, AWAY, _goal_cpu(0.0, 0.0, 0.0))
	var biased: Array[float] = CpuPlanner.turn_probabilities(state, AWAY, _goal_cpu(0.0, 0.0, 2.0))
	assert_float(biased[ahead]).is_greater(none[ahead])
	assert_float(biased[behind]).is_less(none[behind])


func test_forward_bonus_raises_the_forward_moves_probability() -> void:
	# 前（A1-C）へのドリブルと横（M2-L1）へのドリブルは、評価値がどちらも +1。前へ運ぶ加点で前の手が選ばれやすくなる
	var state: MatchState = _scene()
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, HOME, MoveRules.options_for(state, HOME))
	var forward: int = _dribble_index(hints, "A1-C")
	var side: int = _dribble_index(hints, "M2-L1")
	assert_int(forward).is_not_equal(-1)
	assert_int(side).is_not_equal(-1)
	var none: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _goal_cpu(0.0, 0.0))
	assert_float(none[forward]).is_equal_approx(none[side], 0.000001)
	var biased: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _goal_cpu(2.0, 0.0))
	assert_float(biased[forward]).is_greater(biased[side])
	assert_float(_sum(biased)).is_equal_approx(1.0, 0.000001)


func test_shot_bonus_raises_the_shot_probability() -> void:
	# h1 がボールの A2-C（ペナルティエリア）にいて、シュートを選べる場面
	var state: MatchState = _scene()
	state.ball_area = _area("A2-C")
	state.home_players = _players([["h1", "A2-C"], ["h2", "A2-L1"]])
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, HOME, MoveRules.options_for(state, HOME))
	var shot: int = -1
	for index: int in range(hints.size()):
		if hints[index].family == ATTACK and hints[index].action == GameEnums.PlayType.SHOT:
			shot = index
	assert_int(shot).is_not_equal(-1)
	var none: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _goal_cpu(0.0, 0.0))
	var biased: Array[float] = CpuPlanner.turn_probabilities(state, HOME, _goal_cpu(0.0, 3.0))
	assert_float(biased[shot]).is_greater(none[shot])


# --- 手の選択 ---

func test_choose_turn_only_picks_selectable_moves() -> void:
	for state: MatchState in [_scene(), _transition_scene()]:
		for side: GameEnums.TeamSide in [HOME, AWAY]:
			var options: MoveOptions = MoveRules.options_for(state, side)
			for seed_value: int in range(200):
				var choice: TurnChoice = CpuPlanner.choose_turn(state, side, _cpu(), _rng(seed_value))
				assert_bool(MoveRules.is_allowed(options, choice)) \
						.override_failure_message("side %d seed %d %s" % [side, seed_value, _key(choice)]).is_true()


func test_choose_turn_is_reproducible_with_a_fixed_seed() -> void:
	var state: MatchState = _scene()
	for seed_value: int in [1, 7, 42]:
		var first: TurnChoice = CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(seed_value))
		var second: TurnChoice = CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(seed_value))
		assert_str(_key(second)).is_equal(_key(first))


func test_choose_turn_picks_better_moves_more_often_but_keeps_every_move() -> void:
	# パス（±0）より、ドリブル（+1）と、カウンター型が好むスルーパス（評価値0＋方式の癖）を多く選ぶ。どの手も1回以上は選ばれる（下限確率）
	var state: MatchState = _scene()
	var counts: Dictionary = {}
	for seed_value: int in range(1000):
		var key: String = _key(CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(seed_value)))
		counts[key] = (counts.get(key, 0) as int) + 1
	var pass_key: String = "%d:%d:A1-C" % [ATTACK, GameEnums.PlayType.SHORT_PASS]
	# 選べる手はパス1つ・ドリブル8つ（周り8エリア。2026-10-24）・スルーパス6つ（2026-10-25）。どれも1回以上選ばれる
	assert_int(counts.size()).is_equal(MoveHints.evaluate(state, HOME, MoveRules.options_for(state, HOME)).size())
	assert_int(counts.size()).is_equal(15)
	for key: String in counts:
		if key != pass_key:
			assert_int(counts[key] as int).override_failure_message(key).is_greater(counts[pass_key] as int)


func test_choose_turn_does_not_modify_the_state() -> void:
	var state: MatchState = _scene()
	CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(3))
	CpuPlanner.choose_turn(state, AWAY, _cpu(), _rng(3))
	assert_str(state.ball_area.to_key()).is_equal("M2-C")
	for player: PlayerState in state.home_players + state.away_players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()


func test_choose_turn_without_selectable_moves_returns_null() -> void:
	# 守備側に選手がいなければ、守備の手は選べない
	var state: MatchState = _scene()
	var nobody: Array[PlayerState] = []
	state.away_players = nobody
	assert_object(CpuPlanner.choose_turn(state, AWAY, _cpu(), _rng(1))).is_null()


# --- 陣形と方式 ---

func test_choose_setup_picks_every_formation_and_style_combination() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var seen: Dictionary = {}
	for seed_value: int in range(400):
		var setup: TeamSetup = CpuPlanner.choose_setup(catalog, _rng(seed_value))
		assert_object(catalog.formation(setup.formation_id)).override_failure_message(setup.formation_id).is_not_null()
		seen["%s/%d/%d" % [setup.formation_id, setup.styles.defense, setup.styles.attack]] = true
	# 4陣形 × 守備2 × 攻撃2
	assert_int(seen.size()).is_equal(16)


func test_choose_setup_without_formations_returns_null() -> void:
	var formations: Array[FormationDef] = []
	assert_object(CpuPlanner.choose_setup(ContentCatalog.new(formations), _rng(1))).is_null()


func test_choose_styles_picks_every_style_combination() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(100):
		var styles: TeamStyles = CpuPlanner.choose_styles(_rng(seed_value))
		seen["%d/%d" % [styles.defense, styles.attack]] = true
	assert_int(seen.size()).is_equal(4)

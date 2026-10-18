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


func _cpu(temperature: float = 1.0, floor_probability: float = 0.1) -> CpuConfig:
	var cpu := CpuConfig.new()
	cpu.temperature = temperature
	cpu.floor_probability = floor_probability
	return cpu


func _players(spec: Array) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String)))
	return players


## HOME が保持する攻守ターン（move_hints_test.gd と同じ場面）: h1 がボールの M-C、h2 が A-C。
## 相手の a1 は自陣 D-C、a2 は A-L2。HOME のヒントはパス A-C が ±0、ドリブル3つが +1
func _scene() -> MatchState:
	var state := MatchState.new()
	state.possession = HOME
	state.ball_area = _area("M-C")
	state.home_setup = TeamSetup.new("x", TeamStyles.new(ZONE, GameEnums.AttackStyle.COUNTER))
	state.away_setup = TeamSetup.new("y", TeamStyles.new(ZONE, GameEnums.AttackStyle.COUNTER))
	state.home_players = _players([["h1", "M-C"], ["h2", "A-C"]])
	state.away_players = _players([["a1", "D-C"], ["a2", "A-L2"]])
	return state


func _transition_scene() -> MatchState:
	var state: MatchState = _scene()
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.ball_area = _area("D-C")
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
	assert_float(CpuPlanner.score(ChoiceHint.new(ATTACK, GameEnums.PlayType.DRIBBLE, _area("A-C"), true, 2, 1, cover))).is_equal(1.0)
	assert_float(CpuPlanner.score(ChoiceHint.new(POS_TRANS, GameEnums.PosTransAction.COUNTER, _area("A-C"), true, 1, 3, cover))).is_equal(-2.0)
	assert_float(CpuPlanner.score(ChoiceHint.new(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS, null, true, 2, 1, cover))).is_equal(1.0)
	# 守備は脅威度（攻撃側 − 守備側）。守備側から見た 0対1 は脅威 +1
	assert_float(CpuPlanner.score(ChoiceHint.new(DEFENSE, GameEnums.DefenseAction.PRESS, _area("M-C"), true, 0, 1, cover))).is_equal(1.0)
	# 比べない手は 0
	assert_float(CpuPlanner.score(ChoiceHint.new(POS_TRANS, GameEnums.PosTransAction.SECURE, null, false, 0, 0, cover))).is_equal(0.0)


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
	# パス（±0）よりドリブル（+1）を多く選ぶ。どの手も1回以上は選ばれる（下限確率）
	var state: MatchState = _scene()
	var counts: Dictionary = {}
	for seed_value: int in range(1000):
		var key: String = _key(CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(seed_value)))
		counts[key] = (counts.get(key, 0) as int) + 1
	var pass_key: String = "%d:%d:A-C" % [ATTACK, GameEnums.PlayType.SHORT_PASS]
	assert_int(counts.size()).is_equal(4)
	for key: String in counts:
		if key != pass_key:
			assert_int(counts[key] as int).override_failure_message(key).is_greater(counts[pass_key] as int)


func test_choose_turn_does_not_modify_the_state() -> void:
	var state: MatchState = _scene()
	CpuPlanner.choose_turn(state, HOME, _cpu(), _rng(3))
	CpuPlanner.choose_turn(state, AWAY, _cpu(), _rng(3))
	assert_str(state.ball_area.to_key()).is_equal("M-C")
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

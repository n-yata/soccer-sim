## 1ターンに動けるのは1マス（斜めを含む周り8エリア）までであること（不変条件。2026-10-24）のテスト。
## CPU 同士の試合（固定シード）を最後まで回し、キックオフを除くすべてのターンで、
## ターン開始の位置 S から判定時の位置 J、S から次のターン開始の位置 S' が、どの選手も1マス以内であることを確かめる。
extends GdUnitTestSuite

const MATCHES: int = 20
const MAX_STEPS: int = 200


func test_every_player_moves_at_most_one_area_per_turn_in_cpu_matches() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var config := ConfigRepository.new()
	var rules: MatchRuleConfig = config.match_rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	var checked_turns: int = 0
	for match_index: int in range(MATCHES):
		var state: MatchState = MatchRules.create_match("m%d" % match_index, CpuPlanner.choose_setup(catalog, rng),
				CpuPlanner.choose_setup(catalog, rng), GameEnums.TeamSide.HOME, catalog, "")
		for step: int in range(MAX_STEPS):
			if MatchRules.is_play_complete(state, rules):
				break
			match state.stage:
				GameEnums.MatchStage.STYLE_CHANGE:
					state = MatchRules.apply_style_change(state, CpuPlanner.choose_styles(rng), CpuPlanner.choose_styles(rng))
				GameEnums.MatchStage.HALFTIME:
					state = MatchRules.apply_halftime(state, CpuPlanner.choose_setup(catalog, rng),
							CpuPlanner.choose_setup(catalog, rng), catalog)
				_:
					var label: String = "match %d step %d" % [match_index, step]
					var before: LayoutPair = MatchRules.current_layouts(state).pair
					var resolution: TurnResolution = MatchRules.resolve_turn(state,
							CpuPlanner.choose_turn(state, GameEnums.TeamSide.HOME, config.cpu(), rng),
							CpuPlanner.choose_turn(state, GameEnums.TeamSide.AWAY, config.cpu(), rng), rules)
					_assert_within_one(before, resolution.record.pair_at_judgement,
							label + " judgement " + _reasons(resolution.record))
					state = resolution.next_state
					# キックオフ（得点の後・ハーフタイム）は仕切り直しなので確かめない
					if resolution.record.outcome != GameEnums.TurnOutcome.GOAL \
							and state.stage == GameEnums.MatchStage.TURN and not MatchRules.is_play_complete(state, rules):
						_assert_within_one(before, MatchRules.current_layouts(state).pair, label + " next turn")
						checked_turns += 1
		assert_bool(MatchRules.is_play_complete(state, rules)).override_failure_message("match %d" % match_index).is_true()
	# 1試合 24 ターンのうち、得点とハーフの終わりを除いてもその大半を確かめているはず
	assert_int(checked_turns).is_greater_equal(MATCHES * rules.turns_per_half)


## 失敗したときに、どの動きで離れたかを読めるようにする「選手:移動元>移動先:理由」の並び
func _reasons(record: TurnRecord) -> String:
	var parts: Array[String] = []
	for movement: Movement in record.movements:
		parts.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return str(parts)


## before と after の両チームの各選手が1マス以内か。配置はチーム自身の視点なので、チームごとに比べる。
func _assert_within_one(before: LayoutPair, after: LayoutPair, label: String) -> void:
	for side: GameEnums.TeamSide in [GameEnums.TeamSide.HOME, GameEnums.TeamSide.AWAY]:
		var from: TeamLayout = before.attacker if before.attacker_side == side else before.defender
		var to: TeamLayout = after.attacker if after.attacker_side == side else after.defender
		for player: PlayerState in from.players:
			var a: PitchArea = from.current_area_of(player.player_id)
			var b: PitchArea = to.current_area_of(player.player_id)
			assert_bool(a.is_within_one(b)).override_failure_message("%s: %s %s>%s" % [
				label, player.player_id, a.to_key(), b.to_key()]).is_true()

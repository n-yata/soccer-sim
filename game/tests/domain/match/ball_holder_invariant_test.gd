## ボールのあるエリアに保持側の選手がいること（実測の性質）のテスト。
## CPU 同士の試合（固定シード）を最後まで回し、どの時点でもターン開始時の配置で破れていないことを確かめる。
## 1ターン1マス（2026-10-24）では、1マス以内に味方がいなければ誰も置かないので、規則の上ではボールのエリアが空になりうる。
## ただし計測では起きていない（CPU 同士 50試合・1200ターンで0回）。このテストが落ちたら、空になる場面が増えたので、
## 判定の扱いと見せ方を見直す（.steering/20261024-one-step-movement/design.md）。
extends GdUnitTestSuite

const MATCHES: int = 20
const MAX_STEPS: int = 200


func test_the_ball_always_has_a_holder_in_cpu_matches() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var config := ConfigRepository.new()
	var rules: MatchRuleConfig = config.match_rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var checked: int = 0
	for match_index: int in range(MATCHES):
		var state: MatchState = MatchRules.create_match("m%d" % match_index, CpuPlanner.choose_setup(catalog, rng),
				CpuPlanner.choose_setup(catalog, rng), GameEnums.TeamSide.HOME, catalog, "")
		for step: int in range(MAX_STEPS):
			if MatchRules.is_play_complete(state, rules):
				break
			# ハーフタイムには次のターンが無い（後半のキックオフで置き直す）ので確かめない
			if state.stage != GameEnums.MatchStage.HALFTIME:
				_assert_holder_on_the_ball(state, "match %d step %d" % [match_index, step])
				checked += 1
			match state.stage:
				GameEnums.MatchStage.STYLE_CHANGE:
					state = MatchRules.apply_style_change(state, CpuPlanner.choose_styles(rng), CpuPlanner.choose_styles(rng))
				GameEnums.MatchStage.HALFTIME:
					state = MatchRules.apply_halftime(state, CpuPlanner.choose_setup(catalog, rng),
							CpuPlanner.choose_setup(catalog, rng), catalog)
				_:
					state = MatchRules.resolve_turn(state,
							CpuPlanner.choose_turn(state, GameEnums.TeamSide.HOME, config.cpu(), rng),
							CpuPlanner.choose_turn(state, GameEnums.TeamSide.AWAY, config.cpu(), rng), rules).next_state
		assert_bool(MatchRules.is_play_complete(state, rules)).override_failure_message("match %d" % match_index).is_true()
	# 1試合は 24 ターン以上なので、確かめた回数がそれより少なければ試合が回っていない
	assert_int(checked).is_greater_equal(MATCHES * rules.turns_per_half * 2)


func _assert_holder_on_the_ball(state: MatchState, label: String) -> void:
	var holders: int = MatchRules.current_layouts(state).pair.attacker.count_at(state.ball_area)
	assert_int(holders).override_failure_message("%s: %s にボール保持側がいない" % [label, state.ball_area.to_key()]) \
			.is_greater_equal(1)

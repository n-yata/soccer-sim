## 1ターンに動けるのは1マス（斜めを含む周り8エリア）までであること（不変条件。2026-10-24）のテスト。
## 試合（固定シード）を最後まで回し、キックオフを除くすべてのターンで、
## ターン開始の位置 S から判定時の位置 J、S から次のターン開始の位置 S' が、どの選手も1マス以内であることを確かめる。
## 手は CPU の選び方と、選べる手からの一様な選び方の2通りで回す（CPU の癖で通らない経路も確かめるため）。
extends GdUnitTestSuite

## 全体テストを3分以内に収めるため 20 から絞った（2026-11-03）。一様な選び方で全種類の手を通ることは下のテストで確かめる
const MATCHES: int = 4
const MAX_STEPS: int = 200

var _catalog: ContentCatalog
var _config: ConfigRepository
var _rules: MatchRuleConfig


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	_config = ConfigRepository.new()
	_rules = _config.match_rules()


func test_every_player_moves_at_most_one_area_per_turn_in_cpu_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	_check_matches(rng, func(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
		return CpuPlanner.choose_turn(state, side, _config.cpu(), rng))


func test_every_player_moves_at_most_one_area_per_turn_with_uniformly_random_moves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var picked: Dictionary[String, int] = {}
	_check_matches(rng, func(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
		var choice: TurnChoice = _uniform_choice(state, side, rng)
		if choice != null:
			picked[_choice_key(choice)] = picked.get(_choice_key(choice), 0) + 1
		return choice)
	# 一様に選んでいれば、攻撃・守備・トランジションの手のすべての種類を通るはず（CPU の選び方に偏っていないこと）。
	# 2026-10-24 の実測では、いちばん少ない種類（LONG_BEHIND）でも 13 回選ばれた
	var all_kinds: int = GameEnums.PlayType.size() + GameEnums.DefenseAction.size() \
			+ GameEnums.NegTransAction.size() + GameEnums.PosTransAction.size()
	assert_int(picked.size()).override_failure_message("picked kinds %s" % picked).is_equal(all_kinds)


## 選べる手（運ぶ先ごとに1つ）から一様に1つ選ぶ。選べる手が無ければ null（resolve_turn が拒否し、テストが落ちる）。
func _uniform_choice(state: MatchState, side: GameEnums.TeamSide, rng: RandomNumberGenerator) -> TurnChoice:
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, side, MoveRules.options_for(state, side))
	if hints.is_empty():
		return null
	var hint: ChoiceHint = hints[rng.randi_range(0, hints.size() - 1)]
	return TurnChoice.new(hint.family, hint.action, null if hint.target == null else hint.target.duplicate_deep())


func _choice_key(choice: TurnChoice) -> String:
	return "%d:%d" % [choice.family, choice.action]


## MATCHES 試合を最後まで回して、各ターンの1マスを確かめる。choose は (状態, 陣営) から手を返す。
## 方式・陣形の選び直しは、どちらの回し方でも CPU の選び方にする（確かめたいのはターン中の動きのため）。
func _check_matches(rng: RandomNumberGenerator, choose: Callable) -> void:
	var checked_turns: int = 0
	for match_index: int in range(MATCHES):
		var state: MatchState = MatchRules.create_match("m%d" % match_index, CpuPlanner.choose_setup(_catalog, rng),
				CpuPlanner.choose_setup(_catalog, rng), GameEnums.TeamSide.HOME, _catalog, "")
		for step: int in range(MAX_STEPS):
			if MatchRules.is_play_complete(state, _rules):
				break
			match state.stage:
				GameEnums.MatchStage.STYLE_CHANGE:
					state = MatchRules.apply_style_change(state, CpuPlanner.choose_styles(rng), CpuPlanner.choose_styles(rng))
				GameEnums.MatchStage.HALFTIME:
					state = MatchRules.apply_halftime(state, CpuPlanner.choose_setup(_catalog, rng),
							CpuPlanner.choose_setup(_catalog, rng), _catalog)
				_:
					var label: String = "match %d step %d" % [match_index, step]
					var before_layouts: LayoutPair = MatchRules.current_layouts(state).pair
					var resolution: TurnResolution = MatchRules.resolve_turn(state,
							choose.call(state, GameEnums.TeamSide.HOME), choose.call(state, GameEnums.TeamSide.AWAY), _rules)
					assert_object(resolution).override_failure_message(label + " rejected").is_not_null()
					if resolution == null:
						return
					_assert_within_one(before_layouts, resolution.record.pair_at_judgement,
							label + " judgement " + _reasons(resolution.record))
					state = resolution.next_state
					# キックオフ（得点の後・ハーフタイム）は仕切り直しなので確かめない
					if resolution.record.outcome != GameEnums.TurnOutcome.GOAL \
							and state.stage == GameEnums.MatchStage.TURN and not MatchRules.is_play_complete(state, _rules):
						_assert_within_one(before_layouts, MatchRules.current_layouts(state).pair, label + " next turn")
						checked_turns += 1
		assert_bool(MatchRules.is_play_complete(state, _rules)).override_failure_message("match %d" % match_index).is_true()
	# 1試合 30 ターン以上のうち、得点とハーフの終わりを除いてもその大半を確かめているはず
	assert_int(checked_turns).is_greater_equal(MATCHES * _rules.turns_per_half)


## 失敗したときに、どの動きで離れたかを読めるようにする「選手:移動元>移動先:理由」の並び
func _reasons(record: TurnRecord) -> String:
	var parts: Array[String] = []
	for movement: Movement in record.movements:
		parts.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return str(parts)


## before と after の両チームの各選手が1マス以内か。配置はチーム自身の視点なので、チームごとに比べる。
func _assert_within_one(before_layouts: LayoutPair, after: LayoutPair, label: String) -> void:
	for side: GameEnums.TeamSide in [GameEnums.TeamSide.HOME, GameEnums.TeamSide.AWAY]:
		var from: TeamLayout = before_layouts.attacker if before_layouts.attacker_side == side else before_layouts.defender
		var to: TeamLayout = after.attacker if after.attacker_side == side else after.defender
		for player: PlayerState in from.players:
			var a: PitchArea = from.current_area_of(player.player_id)
			var b: PitchArea = to.current_area_of(player.player_id)
			assert_bool(a.is_within_one(b)).override_failure_message("%s: %s %s>%s" % [
				label, player.player_id, a.to_key(), b.to_key()]).is_true()

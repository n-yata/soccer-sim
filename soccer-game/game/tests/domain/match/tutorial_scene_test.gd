## MatchRules.create_scene（チュートリアルの段階の盤面）と MoveOptions.restricted_to のテスト。
## 期待値は .steering/20261029-tutorial/design.md「盤面の作り方」と、陣形の基本配置（アルゴリズム1）から導いた。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func _setup(formation_id: String) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION))


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _scene(turn_kind: GameEnums.TurnKind, possession: GameEnums.TeamSide, ball: String) -> MatchState:
	return MatchRules.create_scene(_setup("4-3-3"), _setup("4-4-2"), turn_kind, possession, _area(ball), _catalog)


func test_players_stand_on_their_base_areas_except_the_ball_holder() -> void:
	var state: MatchState = _scene(GameEnums.TurnKind.OPEN_PLAY, HOME, "M2-C")
	var base: TeamLayout = BaseLayoutDeriver.derive(_catalog.formation("4-4-2"))
	for player: PlayerState in state.away_players:
		assert_bool(player.current_area.equals(base.current_area_of(player.player_id))) \
				.override_failure_message(player.player_id).is_true()
		assert_object(player.fixed_area).is_null()
	# ボールのエリアに、ボールを持つ側の選手が固定されて立つ
	assert_int(_fixed_count_at(state.home_players, _area("M2-C"))).is_equal(1)


func _fixed_count_at(players: Array[PlayerState], area: PitchArea) -> int:
	var count: int = 0
	for player: PlayerState in players:
		if player.fixed_area != null and player.fixed_area.equals(area) and player.current_area.equals(area):
			count += 1
	return count


func test_the_scene_keeps_the_given_phase_and_ball() -> void:
	var state: MatchState = _scene(GameEnums.TurnKind.OPEN_PLAY, AWAY, "M1-L1")
	assert_int(state.possession).is_equal(AWAY)
	assert_int(state.turn_kind).is_equal(GameEnums.TurnKind.OPEN_PLAY)
	assert_str(state.ball_area.to_key()).is_equal("M1-L1")
	assert_object(state.transition_origin).is_null()
	assert_int(state.status).is_equal(GameEnums.MatchStatus.IN_PROGRESS)
	assert_array(state.turn_records).is_empty()
	assert_bool(MatchRules.current_layouts(state).pair.attacker.count_at(state.ball_area) > 0).is_true()


func test_a_transition_scene_starts_from_its_own_layout_with_the_holder_on_the_ball() -> void:
	var state: MatchState = _scene(GameEnums.TurnKind.TRANSITION, HOME, "M2-L1")
	assert_object(state.transition_origin).is_not_null()
	assert_int(state.transition_origin.attacker_side).is_equal(HOME)
	assert_int(state.transition_origin.attacker.count_at(_area("M2-L1"))).is_greater(0)
	# 起点の守備側は基本配置のまま
	assert_int(state.transition_origin.defender.counts()["M2-L1"] as int) \
			.is_equal(TeamLayout.from_players(state.away_players).counts()["M2-L1"] as int)
	# 選べる手はトランジションの手（奪った側）
	var options: MoveOptions = MoveRules.options_for(state, HOME)
	assert_bool(options.is_available(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


func test_an_unknown_formation_makes_no_scene() -> void:
	assert_object(MatchRules.create_scene(_setup("9-9-9"), _setup("4-4-2"), GameEnums.TurnKind.OPEN_PLAY, HOME,
			_area("M1-C"), _catalog)).is_null()


## 局面の手の種類（functional-overview.md の手の種類の表: 攻守ターンは攻撃側／守備側、トランジションは奪取側／喪失側）
func test_family_for_follows_the_turn_kind_and_the_ball() -> void:
	assert_int(TurnChoice.family_for(GameEnums.TurnKind.OPEN_PLAY, true)).is_equal(GameEnums.ChoiceFamily.ATTACK)
	assert_int(TurnChoice.family_for(GameEnums.TurnKind.OPEN_PLAY, false)).is_equal(GameEnums.ChoiceFamily.DEFENSE)
	assert_int(TurnChoice.family_for(GameEnums.TurnKind.TRANSITION, true)).is_equal(GameEnums.ChoiceFamily.POS_TRANS)
	assert_int(TurnChoice.family_for(GameEnums.TurnKind.TRANSITION, false)).is_equal(GameEnums.ChoiceFamily.NEG_TRANS)


## 何も残さない絞り込み・ほかの種類の手は、写しに入らない
func test_restricting_to_nothing_or_another_family_leaves_nothing() -> void:
	var options := MoveOptions.new()
	options.add_target(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS, _area("M2-C"))
	options.allow(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	var none: Array[int] = []
	var empty: MoveOptions = options.restricted_to(GameEnums.ChoiceFamily.ATTACK, none)
	assert_bool(empty.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS)).is_false()
	var attack_only: Array[int] = [GameEnums.PlayType.SHORT_PASS]
	var restricted: MoveOptions = options.restricted_to(GameEnums.ChoiceFamily.ATTACK, attack_only)
	assert_bool(restricted.is_available(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)).is_false()


func test_restricted_options_keep_only_the_given_actions_with_their_targets() -> void:
	var options := MoveOptions.new()
	options.add_target(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS, _area("M2-C"))
	options.add_target(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.DRIBBLE, _area("M2-L1"))
	options.allow(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)
	var only: Array[int] = [GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.SHOT, GameEnums.PlayType.SWITCH]
	var restricted: MoveOptions = options.restricted_to(GameEnums.ChoiceFamily.ATTACK, only)
	assert_bool(restricted.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS)).is_true()
	assert_str(restricted.targets(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS)[0].to_key()).is_equal("M2-C")
	assert_bool(restricted.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)).is_true()
	assert_bool(restricted.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.DRIBBLE)).is_false()
	# 元に無い手は足さない
	assert_bool(restricted.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SWITCH)).is_false()

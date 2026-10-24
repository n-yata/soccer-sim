## アルゴリズム7: キックオフと試合進行（MatchRules）のテスト。
## 期待値は functional-overview.md アルゴリズム5の手順7・アルゴリズム6の結果の反映・アルゴリズム7から手で書いた。
## 選択の運ぶ先は判定時の攻撃側（トランジションは奪取側）の視点、選手のエリアは各チーム自身の視点（component-design.md §1.2）。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const OPEN_PLAY := GameEnums.TurnKind.OPEN_PLAY
const TRANSITION := GameEnums.TurnKind.TRANSITION
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG_TRANS := GameEnums.ChoiceFamily.NEG_TRANS
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _styles(attack: GameEnums.AttackStyle = GameEnums.AttackStyle.COUNTER) -> TeamStyles:
	return TeamStyles.new(GameEnums.DefenseStyle.ZONE, attack)


## additional はアディショナルタイムの最大ターン数。既存のテストは 0（ハーフの最終ターンで終わる）で確かめる
func _rules(turns: int, additional: int = 0) -> MatchRuleConfig:
	var rules := MatchRuleConfig.new()
	rules.turns_per_half = turns
	rules.max_additional_turns = additional
	return rules


## spec は [選手 ID, 基本エリア, 固定先（無ければ ""）]
func _players(spec: Array) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String),
				null if fixed_key == "" else _area(fixed_key)))
	return players


## 選手の現在エリアを、固定先（無ければ基本エリア）にした配置
func _layout_of(players: Array[PlayerState]) -> TeamLayout:
	var current: Dictionary = {}
	for player: PlayerState in players:
		current[player.player_id] = player.fixed_area if player.is_fixed() else player.base_area
	return TeamLayout.new(players, current)


## 攻守ターンの状態。holder_spec は保持側、other_spec は相手（どちらもそのチーム自身の視点）
func _open_state(holder: GameEnums.TeamSide, holder_spec: Array, other_spec: Array, ball_key: String) -> MatchState:
	var state := MatchState.new()
	state.match_id = "20261018-120000-0001"
	state.possession = holder
	state.first_half_kickoff = HOME
	state.ball_area = _area(ball_key)
	state.home_setup = TeamSetup.new("4-4-2", _styles())
	state.away_setup = TeamSetup.new("4-3-3", _styles())
	if holder == HOME:
		state.home_players = _players(holder_spec)
		state.away_players = _players(other_spec)
	else:
		state.away_players = _players(holder_spec)
		state.home_players = _players(other_spec)
	return state


## トランジションの状態。保持側（奪取側）は HOME、ボールは HOME から見て D-C
func _transition_state(winner_spec: Array, loser_spec: Array) -> MatchState:
	var state: MatchState = _open_state(HOME, winner_spec, loser_spec, "D-C")
	state.turn_kind = TRANSITION
	state.transition_origin = LayoutPair.new(_layout_of(state.home_players), _layout_of(state.away_players), HOME)
	return state


func _choice(family: GameEnums.ChoiceFamily, action: int, target_key: String = "") -> TurnChoice:
	return TurnChoice.new(family, action, null if target_key == "" else _area(target_key))


## holder の手と相手の手を、HOME/AWAY の枠に入れて解決する
func _resolve(state: MatchState, holder_choice: TurnChoice, other_choice: TurnChoice, turns: int = 12,
		additional: int = 0) -> TurnResolution:
	var home_choice: TurnChoice = holder_choice if state.possession == HOME else other_choice
	var away_choice: TurnChoice = other_choice if state.possession == HOME else holder_choice
	return MatchRules.resolve_turn(state, home_choice, away_choice, _rules(turns, additional))


## 攻守ターンの共通の場面（保持側の視点）: h1 がボールの M-C、h2 が A-C、h3 は基本 D-C で D-L1 に固定。
## 相手の a1 は A-L2 にいて、攻撃側の視点の D-R1 へのプレスで動く（判定に関わらない位置）
func _holder_spec() -> Array:
	return [["h1", "M-C", ""], ["h2", "A-C", ""], ["h3", "D-C", "D-L1"]]


func _press_far() -> TurnChoice:
	return _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "D-R1")


func _pass_to_a_c() -> TurnChoice:
	return _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "A-C")


func _shot() -> TurnChoice:
	return _choice(ATTACK, GameEnums.PlayType.SHOT)


## 決まった手を選ぶ（通しの試合のテスト用）。攻撃はシュート → パス → ドリブル、守備はプレス → カバー、
## トランジションは保持 × リトリート
func _auto_choices(state: MatchState) -> Array[TurnChoice]:
	var holder: GameEnums.TeamSide = state.possession
	var other: GameEnums.TeamSide = MatchState.other(holder)
	var holder_options: MoveOptions = MoveRules.options_for(state, holder)
	var other_options: MoveOptions = MoveRules.options_for(state, other)
	var holder_choice: TurnChoice
	var other_choice: TurnChoice
	if state.turn_kind == TRANSITION:
		holder_choice = _choice(POS_TRANS, GameEnums.PosTransAction.SECURE)
		other_choice = _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT)
	else:
		if holder_options.is_available(ATTACK, GameEnums.PlayType.SHOT):
			holder_choice = _shot()
		else:
			for play: GameEnums.PlayType in [GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.DRIBBLE]:
				# 運ぶ先は D→M→A の順に並ぶので、最後（いちばん前）を選んで前進する
				if holder_choice == null and holder_options.is_available(ATTACK, play):
					holder_choice = TurnChoice.new(ATTACK, play, holder_options.targets(ATTACK, play).back())
		for action: GameEnums.DefenseAction in [GameEnums.DefenseAction.PRESS, GameEnums.DefenseAction.COVER]:
			if other_choice == null and other_options.is_available(DEFENSE, action):
				other_choice = TurnChoice.new(DEFENSE, action, other_options.targets(DEFENSE, action)[0])
	var result: Array[TurnChoice] = [holder_choice, holder_choice]
	result[0 if holder == HOME else 1] = holder_choice
	result[1 if holder == HOME else 0] = other_choice
	return result


# --- キックオフ ---

func test_create_match_kicks_off_from_the_center_with_base_layouts() -> void:
	var home := TeamSetup.new("4-4-2", _styles())
	var away := TeamSetup.new("4-3-3", _styles(GameEnums.AttackStyle.POSSESSION))
	var state: MatchState = MatchRules.create_match("20261018-120000-0001", home, away, AWAY, _catalog, "2026-10-18T12:00:00")
	assert_str(state.match_id).is_equal("20261018-120000-0001")
	assert_int(state.status).is_equal(GameEnums.MatchStatus.IN_PROGRESS)
	assert_int(state.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(state.half).is_equal(1)
	assert_int(state.turn_number).is_equal(1)
	assert_int(state.turn_kind).is_equal(OPEN_PLAY)
	assert_int(state.possession).is_equal(AWAY)
	assert_int(state.first_half_kickoff).is_equal(AWAY)
	assert_str(state.ball_area.to_key()).is_equal("M-C")
	assert_int(state.home_score).is_equal(0)
	assert_int(state.away_score).is_equal(0)
	assert_str(state.started_at).is_equal("2026-10-18T12:00:00")
	assert_object(state.transition_origin).is_null()
	assert_array(state.turn_records).is_empty()
	assert_int(state.home_players.size()).is_equal(10)
	assert_int(state.away_players.size()).is_equal(10)
	# 基本配置（アルゴリズム1）で、固定は無い
	assert_dict(TeamLayout.at_base(state.home_players).counts()) \
			.is_equal(BaseLayoutDeriver.derive(_catalog.formation("4-4-2")).counts())
	for player: PlayerState in state.home_players + state.away_players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()
	# 渡した陣形と方式を写して持つ
	home.formation_id = "3-5-2"
	assert_str(state.home_setup.formation_id).is_equal("4-4-2")
	assert_int(state.away_setup.styles.attack).is_equal(GameEnums.AttackStyle.POSSESSION)


func test_create_match_with_an_unknown_formation_returns_null() -> void:
	var state: MatchState = MatchRules.create_match("20261018-120000-0001", TeamSetup.new("9-9-9", _styles()),
			TeamSetup.new("4-3-3", _styles()), HOME, _catalog, "")
	assert_object(state).is_null()


func test_current_layouts_is_the_turn_start_layout_of_the_state() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-L1")
	var step: LayoutStep = MatchRules.current_layouts(state)
	# 守備側（ゾーン）はボールの M-L1（守備側から見て M-R1）へ1レーンずれる
	assert_str(step.pair.defender.current_area_of("a1").to_key()).is_equal("A-L1")
	assert_str(step.pair.attacker.current_area_of("h3").to_key()).is_equal("D-L1")


# --- 攻守ターンの結果の反映 ---

func test_open_play_advance_moves_the_ball_and_keeps_fixes() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	var resolution: TurnResolution = _resolve(state, _pass_to_a_c(), _press_far())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
	assert_int(next.possession).is_equal(HOME)
	assert_str(next.ball_area.to_key()).is_equal("A-C")
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_int(next.turn_number).is_equal(2)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.TURN)
	# 固定は維持（h3 は元の固定、a1 はプレスで A-L1 に固定）
	assert_str(next.home_players[2].fixed_area.to_key()).is_equal("D-L1")
	assert_str(next.away_players[0].fixed_area.to_key()).is_equal("A-L1")


func test_open_play_stall_keeps_the_ball_in_place() -> void:
	# M-L1 へのパスは h2 と相手の a2 で1対1。背後の A-L1 に相手の a3 がいて（攻撃側は0人）守備のカバーがあり膠着
	var holder_spec: Array = [["h1", "M-C", ""], ["h2", "M-L1", ""], ["h3", "D-C", "D-L1"]]
	var other_spec: Array = [["a1", "A-L2", ""], ["a2", "M-R1", ""], ["a3", "D-R1", ""]]
	var state: MatchState = _open_state(HOME, holder_spec, other_spec, "M-C")
	var resolution: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-L1"), _press_far())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.STALL)
	assert_int(resolution.next_state.possession).is_equal(HOME)
	assert_str(resolution.next_state.ball_area.to_key()).is_equal("M-C")
	assert_int(resolution.next_state.turn_kind).is_equal(OPEN_PLAY)
	# 攻守ターンの続きなので固定は維持
	assert_str(resolution.next_state.home_players[2].fixed_area.to_key()).is_equal("D-L1")
	assert_str(resolution.next_state.away_players[0].fixed_area.to_key()).is_equal("A-L1")


func test_open_play_loss_hands_the_ball_over_and_starts_a_transition() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(),
			[["a1", "A-L2", ""], ["a2", "D-C", ""], ["a3", "D-C", ""]], "M-C")
	var resolution: TurnResolution = _resolve(state, _pass_to_a_c(), _press_far())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.LOSS)
	# 相手が A-C（相手から見て D-C）で奪う
	assert_int(next.possession).is_equal(AWAY)
	assert_str(next.ball_area.to_key()).is_equal("D-C")
	assert_int(next.turn_kind).is_equal(TRANSITION)
	# 起点は判定時の配置で、奪取側（AWAY）を attacker に持つ
	assert_int(next.transition_origin.attacker_side).is_equal(AWAY)
	assert_str(next.transition_origin.attacker.current_area_of("a1").to_key()).is_equal("A-L1")
	assert_str(next.transition_origin.defender.current_area_of("h3").to_key()).is_equal("D-L1")
	# トランジションの間は配置区間が続き、固定は維持
	assert_str(next.away_players[0].fixed_area.to_key()).is_equal("A-L1")
	assert_str(next.home_players[2].fixed_area.to_key()).is_equal("D-L1")


func test_open_play_goal_scores_and_goes_to_the_style_change_with_the_conceding_side_to_kick_off() -> void:
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""]], "A-C")
	var resolution: TurnResolution = _resolve(state, _shot(), _press_far())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.GOAL)
	assert_int(next.home_score).is_equal(1)
	assert_int(next.away_score).is_equal(0)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.STYLE_CHANGE)
	assert_int(next.possession).is_equal(AWAY)
	assert_int(next.turn_number).is_equal(2)
	# 失点側のキックオフを得点の時点で済ませる（選び直しの間も、ボール位置は保持側の視点の M-C）
	assert_str(next.ball_area.to_key()).is_equal("M-C")
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_object(next.transition_origin).is_null()
	# キックオフで全員が基本エリアに戻る。キックオフの M-C に AWAY の選手がいないので、いちばん近い a1 を置いて固定する（距離は問わない）
	assert_bool(next.home_players[0].is_fixed()).is_false()
	assert_str(next.away_players[0].fixed_area.to_key()).is_equal("M-C")
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_equal(["a1:A-L2>M-C"])
	# 判定後のボール位置（攻撃側の視点）はシュートしたエリア
	assert_str(resolution.record.ball_after.to_key()).is_equal("A-C")


func test_open_play_save_gives_the_defender_the_ball_in_their_own_d_c() -> void:
	# 守備がボールのエリア（A-C。相手から見て D-C）へプレスしてシュートを読み、隣の a2 が寄せて1対1で阻止。
	# 守備側が自陣 D-C で持ち、トランジションへ
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""], ["a2", "D-L1", ""]], "A-C")
	var resolution: TurnResolution = _resolve(state, _shot(), _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "A-C"))
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.SAVE)
	assert_int(next.possession).is_equal(AWAY)
	assert_str(next.ball_area.to_key()).is_equal("D-C")
	assert_int(next.turn_kind).is_equal(TRANSITION)
	assert_int(next.transition_origin.attacker_side).is_equal(AWAY)
	# 判定後のボール位置（攻撃側の視点）は守備側の自陣 D-C = A-C
	assert_str(resolution.record.ball_after.to_key()).is_equal("A-C")


# --- トランジションの結果の反映 ---

func _secure() -> TurnChoice:
	return _choice(POS_TRANS, GameEnums.PosTransAction.SECURE)


func _counter(target_key: String) -> TurnChoice:
	return _choice(POS_TRANS, GameEnums.PosTransAction.COUNTER, target_key)


func _counter_press() -> TurnChoice:
	return _choice(NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)


func _retreat() -> TurnChoice:
	return _choice(NEG_TRANS, GameEnums.NegTransAction.RETREAT)


func _assert_fixes_released(next: MatchState) -> void:
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_object(next.transition_origin).is_null()
	for player: PlayerState in next.home_players + next.away_players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()


func test_transition_regain_gives_the_ball_back_to_the_loser_and_releases_the_fixes() -> void:
	# X の周り: 奪取側 1（D-C）、喪失側 2（A-C と、A-L1 に固定された a3）
	var state: MatchState = _transition_state([["h1", "D-C", ""]], [["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _secure(), _counter_press())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.REGAIN)
	assert_int(next.possession).is_equal(AWAY)
	assert_str(next.ball_area.to_key()).is_equal("A-C")
	_assert_fixes_released(next)


func test_transition_regain_failed_keeps_the_ball_with_the_winner() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _secure(), _counter_press())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.REGAIN_FAILED)
	assert_int(resolution.next_state.possession).is_equal(HOME)
	assert_str(resolution.next_state.ball_area.to_key()).is_equal("D-C")
	_assert_fixes_released(resolution.next_state)


func test_transition_no_contest_keeps_the_ball_with_the_winner_without_a_judgement() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""]], [["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _secure(), _retreat())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	assert_object(resolution.record.judge).is_null()
	assert_int(resolution.next_state.possession).is_equal(HOME)
	assert_str(resolution.next_state.ball_area.to_key()).is_equal("D-C")
	_assert_fixes_released(resolution.next_state)


func test_transition_counter_advance_moves_the_ball_to_the_target() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "A-L2", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _counter("M-C"), _counter_press())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
	assert_int(resolution.next_state.possession).is_equal(HOME)
	assert_str(resolution.next_state.ball_area.to_key()).is_equal("M-C")
	_assert_fixes_released(resolution.next_state)


func test_transition_counter_stall_keeps_the_ball_where_it_was_won() -> void:
	# M-C は1対1。背後（奪取側から見て A-C = 喪失側の D-C）に喪失側が1人いてカバー
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "M-C", ""], ["a2", "D-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _counter("M-C"), _counter_press())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.STALL)
	assert_int(resolution.next_state.possession).is_equal(HOME)
	assert_str(resolution.next_state.ball_area.to_key()).is_equal("D-C")
	_assert_fixes_released(resolution.next_state)


func test_after_a_transition_players_keep_their_positions_and_lose_their_fixes() -> void:
	# a3（基本 M-L2）は A-L1 に固定されていた。攻守ターンが始まると固定は解けるが、基本エリアへ一気には戻らない
	# （2026-10-24。1ターン1マス）。次のターン開始で、基本エリアへ1マスずつ戻る
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "A-L2", ""], ["a3", "M-L2", "A-L1"]])
	var next: MatchState = _resolve(state, _counter("M-C"), _counter_press()).next_state
	assert_bool(next.away_players[1].is_fixed()).is_false()
	assert_str(next.away_players[1].current_area.to_key()).is_equal("A-L1")
	var start: LayoutPair = MatchRules.current_layouts(next).pair
	assert_str(start.defender.current_area_of("a3").to_key()).is_equal("M-L2")


func test_players_who_moved_during_the_turn_are_flagged() -> void:
	# a1 がプレスで寄せた（相手から見て A-L2 → A-L1）。動いた選手だけ moved_in_turn が立ち、次のターン開始では動かない
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""], ["a2", "D-C", ""]], "M-C")
	var next: MatchState = _resolve(state, _pass_to_a_c(), _press_far()).next_state
	assert_bool(next.away_players[0].moved_in_turn).is_true()
	assert_bool(next.away_players[1].moved_in_turn).is_false()
	assert_bool(next.home_players[0].moved_in_turn).is_false()


func test_the_kickoff_after_a_goal_puts_everyone_on_the_base_area() -> void:
	# 得点の後のキックオフだけは、全員が基本エリアに戻り、固定も解ける（試合の仕切り直し）。
	# h2 は基本 D-C で M-C にいた。a2 は基本 D-L2 で D-L1 に固定されていた
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""], ["h2", "D-C", ""]],
			[["a1", "A-L2", ""], ["a2", "D-L2", "D-L1"]], "A-C")
	state.home_players[1].current_area = _area("M-C")
	# h2 は前のターンに動いた（印が立っている）。キックオフで印も消える
	state.home_players[1].moved_in_turn = true
	var resolution: TurnResolution = _resolve(state, _shot(), _press_far())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.GOAL)
	var next: MatchState = resolution.next_state
	assert_str(next.home_players[1].current_area.to_key()).is_equal("D-C")
	assert_str(next.away_players[1].current_area.to_key()).is_equal("D-L2")
	assert_bool(next.away_players[1].is_fixed()).is_false()
	# キックオフの保持者は、今と同じく最寄りの選手（距離の上限なし。仕切り直しの一部）
	assert_str(next.away_players[0].current_area.to_key()).is_equal("M-C")
	for player: PlayerState in next.home_players:
		assert_bool(player.moved_in_turn).override_failure_message(player.player_id).is_false()


func test_transition_counter_loss_starts_another_transition_for_the_loser() -> void:
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "M-C", ""], ["a2", "M-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _counter("M-C"), _counter_press())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.LOSS)
	assert_int(next.possession).is_equal(AWAY)
	assert_str(next.ball_area.to_key()).is_equal("M-C")
	assert_int(next.turn_kind).is_equal(TRANSITION)
	assert_int(next.transition_origin.attacker_side).is_equal(AWAY)
	# トランジションが続くので、固定は維持
	assert_str(next.away_players[2].fixed_area.to_key()).is_equal("A-L1")


# --- ボールのあるエリアの保持者 ---

## record の動きのうち、reason のものを「選手 ID:移動元>移動先」で並べる
func _moves_of(record: TurnRecord, reason: GameEnums.MovementReason) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in record.movements:
		if movement.reason == reason:
			result.append("%s:%s>%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key()])
	return result


func _dribble(target_key: String) -> TurnChoice:
	return _choice(ATTACK, GameEnums.PlayType.DRIBBLE, target_key)


## ドリブルの運ぶ先 M-L1（相手から見て M-R1）に相手が1人、その背後（相手から見て D-R1）にも1人いて、同数でカバーあり
func _dribble_blocked_spec() -> Array:
	return [["a1", "A-L2", ""], ["a2", "M-R1", ""], ["a3", "D-R1", ""]]


func test_dribble_stall_returns_the_carrier_to_the_ball() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), _dribble_blocked_spec(), "M-C")
	var resolution: TurnResolution = _resolve(state, _dribble("M-L1"), _press_far())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.STALL)
	# 判定は運んだ後の配置のまま（M-L1 で 1対1）
	assert_int(resolution.record.judge.attacker_count).is_equal(1)
	assert_int(resolution.record.judge.defender_count).is_equal(1)
	assert_str(resolution.record.pair_at_judgement.attacker.current_area_of("h1").to_key()).is_equal("M-L1")
	# 次のターンへ持ち越す配置では、運んだ選手がボールの M-C に戻り、固定も判定前（固定なし）に戻る
	assert_str(next.ball_area.to_key()).is_equal("M-C")
	assert_bool(next.home_players[0].is_fixed()).is_false()
	assert_str(MatchRules.current_layouts(next).pair.attacker.current_area_of("h1").to_key()).is_equal("M-C")
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.DRIBBLE)).is_equal(["h1:M-C>M-L1"])
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.DRIBBLE_STOPPED)).is_equal(["h1:M-L1>M-C"])
	# 戻したので、保持者を置き直す必要は無い
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()


func test_dribble_stall_keeps_the_carriers_previous_fix() -> void:
	# 前のドリブルで M-C に来て固定されていた選手は、膠着しても M-C の固定のまま。
	# h2（A-C。M-C から距離1）を配置の先頭に置く。固定が消えると M-C が空になり、保持者として h2 が置かれるので区別できる
	var state: MatchState = _open_state(HOME, [["h2", "A-C", ""], ["h1", "D-C", "M-C"]], _dribble_blocked_spec(), "M-C")
	var resolution: TurnResolution = _resolve(state, _dribble("M-L1"), _press_far())
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.STALL)
	assert_str(resolution.next_state.home_players[1].fixed_area.to_key()).is_equal("M-C")
	assert_bool(resolution.next_state.home_players[0].is_fixed()).is_false()
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()


func test_dribble_advance_keeps_the_carrier_on_the_target() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	var resolution: TurnResolution = _resolve(state, _dribble("M-L1"), _press_far())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
	assert_str(next.ball_area.to_key()).is_equal("M-L1")
	assert_str(next.home_players[0].fixed_area.to_key()).is_equal("M-L1")
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.DRIBBLE_STOPPED)).is_empty()
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()


func test_the_nearest_player_within_one_area_is_placed_on_the_ball() -> void:
	# 保持 × リトリートで、奪取側が X（D-C）から攻守ターンを始める。D-C には誰もいない。
	# 1マス以内のいちばん近い h1（M-C）を D-C に置いて固定する（h2 は M-L2。2マス離れていて届かない）
	var state: MatchState = _transition_state([["h1", "M-C", ""], ["h2", "M-L2", ""]],
			[["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _secure(), _retreat())
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	assert_str(next.ball_area.to_key()).is_equal("D-C")
	assert_str(next.home_players[0].fixed_area.to_key()).is_equal("D-C")
	assert_bool(next.home_players[1].is_fixed()).is_false()
	assert_int(MatchRules.current_layouts(next).pair.attacker.count_at(_area("D-C"))).is_equal(1)
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_equal(["h1:M-C>D-C"])


func test_players_at_the_same_distance_are_placed_in_layout_order() -> void:
	# D-L1 と D-R1 は、どちらも D-C から距離1。配置の選手の順で先の選手を置く
	for order: Array in [["h1", "h2"], ["h2", "h1"]]:
		var areas: Dictionary = {"h1": "D-L1", "h2": "D-R1"}
		var spec: Array = [[order[0], areas[order[0]], ""], [order[1], areas[order[1]], ""]]
		var state: MatchState = _transition_state(spec, [["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
		var resolution: TurnResolution = _resolve(state, _secure(), _retreat())
		var placed: Array[String] = _moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)
		assert_array(placed).override_failure_message(str(order)) \
				.is_equal(["%s:%s>D-C" % [order[0], areas[order[0]]]])


func test_no_one_is_placed_when_no_player_is_within_one_area_of_the_ball() -> void:
	# 奪取側は M-L2 の h1 だけ。X（D-C）まで2マスあり、1ターンでは届かないので、誰も置かない
	# （ボールのエリアに保持側がいないまま進む。2026-10-24。1ターン1マス）
	var state: MatchState = _transition_state([["h1", "M-L2", ""]], [["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]])
	var resolution: TurnResolution = _resolve(state, _secure(), _retreat())
	var next: MatchState = resolution.next_state
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()
	assert_bool(next.home_players[0].is_fixed()).is_false()
	assert_int(MatchRules.current_layouts(next).pair.attacker.count_at(_area("D-C"))).is_equal(0)


func test_a_player_two_areas_from_the_ball_at_the_turn_start_is_not_placed() -> void:
	# 置ける選手は、ターン開始の位置からも判定時の位置からも、ボールのエリアが1マス以内（ターン開始から1マス以内に保つ）。
	# 守備側 AWAY はマンツーマン（AWAY 自身の視点）:
	# - lag は M-L2 にいて、ターン開始で h2（M-R1）へ1マス近づき M-L1。カバーの後の付け直しで、さらに M-C まで近づく
	# - cov は D-R1 に固定されていて、M-R1 のカバーでその場に固定し直す（動かない）
	# - m1 は h1（M-C）をマークしている
	# M-R1 へのパスは読まれて（1対0）ロスト。AWAY が M-R1 で持つが、誰もいない。lag は判定時に M-C（M-R1 まで1マス）だが、
	# ターン開始の M-L1 からは2マスなので置かない。どちらからも1マス以内の cov を置く（m1 も1マス以内だが、配置の順で cov が先）
	var state: MatchState = _open_state(HOME, [["h1", "M-C", ""], ["h2", "M-L1", ""]],
			[["lag", "M-L2", ""], ["cov", "A-R1", "D-R1"], ["m1", "D-C", ""]], "M-C")
	state.away_players[2].current_area = _area("M-C")
	state.away_setup = TeamSetup.new("4-3-3", TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER))
	var resolution: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-L1"),
			_choice(DEFENSE, GameEnums.DefenseAction.COVER, "M-L1"))
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.LOSS)
	assert_str(resolution.record.pair_before.defender.current_area_of("lag").to_key()).is_equal("M-L1")
	assert_str(resolution.record.pair_at_judgement.defender.current_area_of("lag").to_key()).is_equal("M-C")
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_equal(["cov:D-R1>M-R1"])


func test_a_holder_is_placed_on_the_ball_at_the_start_of_a_transition() -> void:
	# 守備が M-L1（相手から見て M-R1）をカバーで読み、隣の a2（M-C）が背後の D-R1 へ下がる。M-L1 へのパスは1対0だが、
	# 読まれたので2人以上多くないと通らずロスト。相手は M-R1 で持つが、M-R1 に相手はいない（壊れた状態からでも、次のターンには保持者がいる）。
	# いちばん近い a2（D-R1）を起点の配置で M-R1 に置く
	var state: MatchState = _open_state(HOME, [["h1", "M-C", ""], ["h2", "M-L1", ""]], [["a1", "A-L2", ""], ["a2", "M-C", ""]], "M-C")
	var resolution: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-L1"),
			_choice(DEFENSE, GameEnums.DefenseAction.COVER, "M-L1"))
	var next: MatchState = resolution.next_state
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.LOSS)
	assert_int(resolution.record.judge.read).is_equal(GameEnums.ReadKind.EXACT)
	assert_int(next.turn_kind).is_equal(TRANSITION)
	assert_str(next.transition_origin.attacker.current_area_of("a2").to_key()).is_equal("M-R1")
	assert_str(next.away_players[1].fixed_area.to_key()).is_equal("M-R1")
	assert_int(MatchRules.current_layouts(next).pair.attacker.count_at(_area("M-R1"))).is_equal(1)
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_equal(["a2:D-R1>M-R1"])


func test_no_one_is_placed_when_a_holder_is_already_on_the_ball() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	var resolution: TurnResolution = _resolve(state, _pass_to_a_c(), _press_far())
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()
	assert_bool(resolution.next_state.home_players[1].is_fixed()).is_false()


# --- ターン記録 ---

func test_turn_record_keeps_what_happened_in_the_turn() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-L1")
	# M-L1 のボールで守備側はスライドする（方式の動き）。h1 は M-C で、ボールの M-L1 には h4 がいる
	state.home_players.append(PlayerState.new("h4", _area("M-L1")))
	var resolution: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-C"),
			_choice(DEFENSE, GameEnums.DefenseAction.PRESS, "D-R2"))
	var record: TurnRecord = resolution.record
	assert_int(record.seq).is_equal(1)
	assert_int(record.half).is_equal(1)
	assert_int(record.turn_number).is_equal(1)
	assert_int(record.turn_kind).is_equal(OPEN_PLAY)
	assert_int(record.attacker).is_equal(HOME)
	assert_str(record.home_setup.formation_id).is_equal("4-4-2")
	assert_int(record.home_choice.action).is_equal(GameEnums.PlayType.SHORT_PASS)
	assert_int(record.away_choice.family).is_equal(DEFENSE)
	assert_str(record.ball_before.to_key()).is_equal("M-L1")
	assert_str(record.ball_after.to_key()).is_equal("M-C")
	# 判定前は方式の動きの後、判定時はプレスの後の配置
	assert_str(record.pair_before.defender.current_area_of("a1").to_key()).is_equal("A-L1")
	assert_str(record.pair_at_judgement.defender.current_area_of("a1").to_key()).is_equal("A-L2")
	var reasons: Array[int] = []
	for movement: Movement in record.movements:
		reasons.append(movement.reason)
	assert_array(reasons).is_equal([GameEnums.MovementReason.SLIDE, GameEnums.MovementReason.PRESS])
	assert_str(record.judge.compare_area.to_key()).is_equal("M-C")
	assert_int(resolution.next_state.turn_records.size()).is_equal(1)
	assert_int(resolution.next_state.turn_records[0].seq).is_equal(1)


# --- ハーフ・試合終了 ---

func test_last_turn_of_the_first_half_goes_to_halftime() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	state.turn_number = 2
	var next: MatchState = _resolve(state, _pass_to_a_c(), _press_far(), 2).next_state
	assert_int(next.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_int(next.turn_number).is_equal(3)
	assert_int(next.half).is_equal(1)


func test_loss_on_the_last_turn_ends_the_half_without_a_transition() -> void:
	var spec_other: Array = [["a1", "A-L2", ""], ["a2", "D-C", ""], ["a3", "D-C", ""]]
	# 前半: ハーフタイムへ。トランジションには入らない
	var first: MatchState = _open_state(HOME, _holder_spec(), spec_other, "M-C")
	first.turn_number = 2
	var halftime: MatchState = _resolve(first, _pass_to_a_c(), _press_far(), 2).next_state
	assert_int(halftime.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_int(halftime.turn_kind).is_equal(OPEN_PLAY)
	assert_object(halftime.transition_origin).is_null()
	# 後半: 試合終了。最後の状態もトランジションにしない
	var second: MatchState = _open_state(HOME, _holder_spec(), spec_other, "M-C")
	second.half = 2
	second.turn_number = 2
	var end: MatchState = _resolve(second, _pass_to_a_c(), _press_far(), 2).next_state
	assert_bool(MatchRules.is_play_complete(end, _rules(2))).is_true()
	assert_int(end.turn_kind).is_equal(OPEN_PLAY)
	assert_object(end.transition_origin).is_null()


func test_save_on_the_last_turn_of_the_first_half_goes_to_halftime() -> void:
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""], ["a2", "D-C", ""]], "A-C")
	state.turn_number = 2
	var next: MatchState = _resolve(state, _shot(), _press_far(), 2).next_state
	assert_int(next.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_object(next.transition_origin).is_null()


func test_goal_on_the_last_turn_of_the_first_half_skips_the_style_change() -> void:
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""]], "A-C")
	state.turn_number = 2
	var resolution: TurnResolution = _resolve(state, _shot(), _press_far(), 2)
	var next: MatchState = resolution.next_state
	assert_int(next.home_score).is_equal(1)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	# キックオフの M-C に AWAY がいなくても、次のターンが無いので保持者を置かない（起きなかった動きを記録に残さない）
	assert_array(_moves_of(resolution.record, GameEnums.MovementReason.BALL_HOLDER)).is_empty()
	assert_bool(next.away_players[0].is_fixed()).is_false()


func test_goal_on_the_last_turn_of_the_second_half_ends_play_without_a_style_change() -> void:
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""]], "A-C")
	state.half = 2
	state.turn_number = 2
	var next: MatchState = _resolve(state, _shot(), _press_far(), 2).next_state
	assert_int(next.home_score).is_equal(1)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_bool(MatchRules.is_play_complete(next, _rules(2))).is_true()
	assert_bool(MatchRules.is_play_complete(state, _rules(2))).is_false()
	# 終えた後は、もうターンを解決しない
	assert_object(_resolve(next, _shot(), _press_far(), 2)).is_null()


# --- アディショナルタイム（2026-10-24。ハーフの最終ターンで続いている攻撃を、シュート・ボールを失うまで続ける） ---

## 1ハーフ1ターンの最終ターンを、攻撃が続く結果（ADVANCE）で終える。ボールは A-C の h2
func _advance_on_the_last_turn(additional: int, half: int = 1) -> MatchState:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	state.half = half
	var resolution: TurnResolution = _resolve(state, _pass_to_a_c(), _press_far(), 1, additional)
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
	return resolution.next_state


## 選べる守備の手の先頭（判定に関わらない手を選びたいとき）
func _any_defense(state: MatchState) -> TurnChoice:
	var options: MoveOptions = MoveRules.options_for(state, MatchState.other(state.possession))
	for action: GameEnums.DefenseAction in [GameEnums.DefenseAction.PRESS, GameEnums.DefenseAction.COVER]:
		if options.is_available(DEFENSE, action):
			return TurnChoice.new(DEFENSE, action, options.targets(DEFENSE, action)[0])
	return null


func test_an_attack_going_on_at_the_end_of_the_half_continues_into_additional_time() -> void:
	var next: MatchState = _advance_on_the_last_turn(5)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(next.half).is_equal(1)
	assert_int(next.turn_number).is_equal(2)
	assert_int(next.possession).is_equal(HOME)
	assert_str(next.ball_area.to_key()).is_equal("A-C")
	assert_bool(MatchRules.is_additional_time(next, _rules(1, 5))).is_true()
	# 後半でも同じ。アディショナルタイムの間は、まだ試合を終えていない
	var second: MatchState = _advance_on_the_last_turn(5, 2)
	assert_bool(MatchRules.is_additional_time(second, _rules(1, 5))).is_true()
	assert_bool(MatchRules.is_play_complete(second, _rules(1, 5))).is_false()


func test_a_regular_turn_is_not_additional_time() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	assert_bool(MatchRules.is_additional_time(state, _rules(1, 5))).is_false()
	var next: MatchState = _resolve(state, _pass_to_a_c(), _press_far(), 2, 5).next_state
	assert_bool(MatchRules.is_additional_time(next, _rules(2, 5))).is_false()


func test_a_goal_in_additional_time_ends_the_half_without_a_style_change() -> void:
	# A-C に相手がいないので、シュートは決まる
	var at: MatchState = _advance_on_the_last_turn(5)
	var resolution: TurnResolution = _resolve(at, _shot(), _any_defense(at), 1, 5)
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.GOAL)
	assert_int(resolution.next_state.home_score).is_equal(1)
	assert_int(resolution.next_state.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_bool(MatchRules.is_additional_time(resolution.next_state, _rules(1, 5))).is_false()
	# 後半なら、試合を終える（もうターンを解決しない）
	var second_at: MatchState = _advance_on_the_last_turn(5, 2)
	var end: MatchState = _resolve(second_at, _shot(), _any_defense(second_at), 1, 5).next_state
	assert_bool(MatchRules.is_play_complete(end, _rules(1, 5))).is_true()
	assert_object(_resolve(end, _shot(), _any_defense(end), 1, 5)).is_null()


func test_a_saved_shot_in_additional_time_ends_the_half_without_a_transition() -> void:
	# 最終ターン: A-C の h1 から、相手のいない A-L1 の h2 へのパスで前進。
	# アディショナルタイム: ゾーンの a2・a3 がボールの A-L1 へ1レーンずれ、h2 の1人に対して2人。シュートは止められる
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""], ["h2", "A-L1", ""]],
			[["a1", "A-L2", ""], ["a2", "D-C", ""], ["a3", "D-C", ""]], "A-C")
	var first: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "A-L1"), _press_far(), 1, 5)
	assert_int(first.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
	var at: MatchState = first.next_state
	var resolution: TurnResolution = _resolve(at, _shot(), _any_defense(at), 1, 5)
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.SAVE)
	var next: MatchState = resolution.next_state
	assert_int(next.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_object(next.transition_origin).is_null()


func test_a_regain_on_the_last_turn_ends_the_half_and_a_failed_regain_goes_into_additional_time() -> void:
	# 規定の最終ターンがトランジション。奪い返されたらハーフを終える（アディショナルタイムに入らない）
	var regained: TurnResolution = _resolve(_transition_state([["h1", "D-C", ""]],
			[["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]]), _secure(), _counter_press(), 1, 5)
	assert_int(regained.record.outcome).is_equal(GameEnums.TurnOutcome.REGAIN)
	assert_int(regained.next_state.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	# 奪い返しに失敗したら、奪った HOME の攻撃としてアディショナルタイムに入る
	var kept: TurnResolution = _resolve(_transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "A-C", ""], ["a3", "M-L2", "A-L1"]]), _secure(), _counter_press(), 1, 5)
	assert_int(kept.record.outcome).is_equal(GameEnums.TurnOutcome.REGAIN_FAILED)
	assert_int(kept.next_state.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(kept.next_state.possession).is_equal(HOME)
	assert_bool(MatchRules.is_additional_time(kept.next_state, _rules(1, 5))).is_true()


func test_losing_the_ball_in_additional_time_ends_the_half_without_a_transition() -> void:
	# 最終ターン（トランジション）は保持 × リトリートで、奪った HOME が持ったまま（NO_CONTEST）→ アディショナルタイム。
	# 次の M-C へのパスは、h2 の1人に対して相手の a2・a3 の2人（守備は M-C を読んでカバー）で、ボールを失う
	var state: MatchState = _transition_state([["h1", "D-C", ""], ["h2", "M-C", ""]],
			[["a1", "D-L2", ""], ["a2", "M-C", ""], ["a3", "M-C", ""]])
	var first: TurnResolution = _resolve(state, _secure(), _retreat(), 1, 5)
	assert_int(first.record.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	var at: MatchState = first.next_state
	assert_bool(MatchRules.is_additional_time(at, _rules(1, 5))).is_true()
	var resolution: TurnResolution = _resolve(at, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-C"),
			_choice(DEFENSE, GameEnums.DefenseAction.COVER, "M-C"), 1, 5)
	assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.LOSS)
	var next: MatchState = resolution.next_state
	assert_int(next.stage).is_equal(GameEnums.MatchStage.HALFTIME)
	assert_int(next.turn_kind).is_equal(OPEN_PLAY)
	assert_object(next.transition_origin).is_null()


func test_additional_time_lasts_at_most_the_configured_number_of_turns() -> void:
	# アディショナルタイムでは、攻撃が続く手（M-C の h1 へ戻すパス → A-C の h2 へのパス。相手のいないエリア）を繰り返す。
	# 上限 n なら、n ターン目を終えたところで、攻撃が続いていてもハーフを終える
	for additional: int in [1, 2]:
		var state: MatchState = _advance_on_the_last_turn(additional)
		var passes: Array[String] = ["M-C", "A-C"]
		for index: int in range(additional):
			assert_bool(MatchRules.is_additional_time(state, _rules(1, additional))) \
					.override_failure_message("上限 %d の %d ターン目" % [additional, index + 1]).is_true()
			var resolution: TurnResolution = _resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, passes[index]),
					_any_defense(state), 1, additional)
			assert_int(resolution.record.outcome).is_equal(GameEnums.TurnOutcome.ADVANCE)
			state = resolution.next_state
		assert_int(state.stage).override_failure_message("上限 %d" % additional).is_equal(GameEnums.MatchStage.HALFTIME)
		assert_int(state.turn_number).is_equal(1 + additional + 1)


func test_halftime_kicks_off_the_second_half_from_the_other_side_of_the_first_half() -> void:
	# 前半のキックオフは AWAY。前半最後に HOME が得点しても、後半のキックオフは失点側の AWAY ではなく HOME
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""]], "A-C")
	state.first_half_kickoff = AWAY
	state.turn_number = 2
	var halftime: MatchState = _resolve(state, _shot(), _press_far(), 2).next_state
	var second: MatchState = MatchRules.apply_halftime(halftime, TeamSetup.new("3-5-2", _styles()),
			TeamSetup.new("4-3-3", _styles(GameEnums.AttackStyle.POSSESSION)), _catalog)
	assert_int(second.half).is_equal(2)
	assert_int(second.turn_number).is_equal(1)
	assert_int(second.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(second.possession).is_equal(HOME)
	assert_str(second.ball_area.to_key()).is_equal("M-C")
	assert_int(second.home_score).is_equal(1)
	# 陣形を変えた後の基本配置
	assert_str(second.home_setup.formation_id).is_equal("3-5-2")
	assert_dict(TeamLayout.at_base(second.home_players).counts()) \
			.is_equal(BaseLayoutDeriver.derive(_catalog.formation("3-5-2")).counts())
	assert_int(second.away_setup.styles.attack).is_equal(GameEnums.AttackStyle.POSSESSION)


func test_halftime_rejects_an_unknown_formation_or_the_wrong_stage() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	assert_object(MatchRules.apply_halftime(state, TeamSetup.new("4-4-2", _styles()),
			TeamSetup.new("4-3-3", _styles()), _catalog)).is_null()
	state.stage = GameEnums.MatchStage.HALFTIME
	assert_object(MatchRules.apply_halftime(state, TeamSetup.new("9-9-9", _styles()),
			TeamSetup.new("4-3-3", _styles()), _catalog)).is_null()


func test_style_change_kicks_off_for_the_conceding_side_with_the_new_styles() -> void:
	# a2 がキックオフの M-C にいるので、保持者を置く固定は起きない（キックオフで固定が解けることだけを見る）
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""], ["h3", "D-C", "D-L1"]],
			[["a1", "A-L2", ""], ["a2", "M-C", ""]], "A-C")
	var after_goal: MatchState = _resolve(state, _shot(), _press_far()).next_state
	var man := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION)
	var next: MatchState = MatchRules.apply_style_change(after_goal, _styles(), man)
	assert_int(next.stage).is_equal(GameEnums.MatchStage.TURN)
	assert_int(next.possession).is_equal(AWAY)
	assert_str(next.ball_area.to_key()).is_equal("M-C")
	assert_int(next.away_setup.styles.defense).is_equal(GameEnums.DefenseStyle.MAN)
	assert_int(next.turn_number).is_equal(2)
	_assert_fixes_released(next)


func test_style_change_and_turns_are_rejected_in_the_wrong_stage() -> void:
	var state: MatchState = _open_state(HOME, [["h1", "A-C", ""]], [["a1", "A-L2", ""]], "A-C")
	assert_object(MatchRules.apply_style_change(state, _styles(), _styles())).is_null()
	var after_goal: MatchState = _resolve(state, _shot(), _press_far()).next_state
	assert_object(_resolve(after_goal, _shot(), _press_far())).is_null()


func test_finish_marks_the_match_finished_and_stops_turns() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	var finished: MatchState = MatchRules.finish(state)
	assert_int(finished.status).is_equal(GameEnums.MatchStatus.FINISHED)
	assert_int(state.status).is_equal(GameEnums.MatchStatus.IN_PROGRESS)
	assert_object(_resolve(finished, _pass_to_a_c(), _press_far())).is_null()


# --- 選択不可の手 ---

func test_unavailable_choices_are_rejected() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	# 味方のいない M-L1 へのパス
	assert_object(_resolve(state, _choice(ATTACK, GameEnums.PlayType.SHORT_PASS, "M-L1"), _press_far())).is_null()
	# 手の種類の取り違え（攻撃側が守備の手）
	assert_object(_resolve(state, _press_far(), _press_far())).is_null()
	# 隣接に守備側のいないプレス
	assert_object(_resolve(state, _pass_to_a_c(), _choice(DEFENSE, GameEnums.DefenseAction.PRESS, "M-C"))).is_null()


func test_out_of_range_transition_actions_are_rejected() -> void:
	# 前の作業からの申し送り: 範囲外の手の値を保持・即時奪回として扱わず、is_allowed で拒否する
	var state: MatchState = _transition_state([["h1", "D-C", ""]], [["a1", "A-C", ""]])
	assert_object(_resolve(state, _choice(POS_TRANS, 99), _counter_press())).is_null()
	assert_object(_resolve(state, _secure(), _choice(NEG_TRANS, 99))).is_null()


# --- 通しの試合・対称性・不変の性質 ---

func test_a_full_match_runs_both_halves_to_the_end() -> void:
	var rules: MatchRuleConfig = MatchRuleConfig.new()
	var state: MatchState = MatchRules.create_match("20261018-120000-0001", TeamSetup.new("4-4-2", _styles()),
			TeamSetup.new("4-3-3", _styles()), HOME, _catalog, "")
	var steps: int = 0
	var halftimes: int = 0
	while not MatchRules.is_play_complete(state, rules) and steps < 200:
		steps += 1
		if state.stage == GameEnums.MatchStage.STYLE_CHANGE:
			state = MatchRules.apply_style_change(state, state.home_setup.styles, state.away_setup.styles)
		elif state.stage == GameEnums.MatchStage.HALFTIME:
			halftimes += 1
			state = MatchRules.apply_halftime(state, state.home_setup, state.away_setup, _catalog)
		else:
			var choices: Array[TurnChoice] = _auto_choices(state)
			var resolution: TurnResolution = MatchRules.resolve_turn(state, choices[0], choices[1], rules)
			assert_object(resolution).override_failure_message("turn %d-%d" % [state.half, state.turn_number]).is_not_null()
			if resolution == null:
				return
			state = resolution.next_state
		assert_int(state.home_players.size()).is_equal(10)
		assert_int(state.away_players.size()).is_equal(10)
	assert_bool(MatchRules.is_play_complete(state, rules)).is_true()
	# 各ハーフは規定のターン数＋アディショナルタイム（0〜上限）。ターン番号はハーフごとに1から続く
	var per_half: Dictionary = {1: 0, 2: 0}
	var goals: int = 0
	for index: int in range(state.turn_records.size()):
		var record: TurnRecord = state.turn_records[index]
		assert_int(record.seq).is_equal(index + 1)
		per_half[record.half] = (per_half[record.half] as int) + 1
		assert_int(record.turn_number).is_equal(per_half[record.half] as int)
		if record.outcome == GameEnums.TurnOutcome.GOAL:
			goals += 1
	for half: int in [1, 2]:
		assert_int(per_half[half] as int).is_between(rules.turns_per_half, rules.turns_per_half + rules.max_additional_turns)
	assert_int(state.home_score + state.away_score).is_equal(goals)
	# ハーフタイムをちょうど1回通る。得点の経路（方式の選び直し・最終ターンの得点）は個別のテストで確かめている
	# （決まった手では得点が入るとは限らないため、ここでは得点の有無を前提にしない）
	assert_int(halftimes).is_equal(1)
	assert_object(MatchRules.resolve_turn(state, _shot(), _press_far(), rules)).is_null()


func test_swapping_home_and_away_mirrors_the_result() -> void:
	var as_home: TurnResolution = _resolve(_open_state(HOME, _holder_spec(),
			[["a1", "A-L2", ""], ["a2", "D-C", ""], ["a3", "D-C", ""]], "M-C"), _pass_to_a_c(), _press_far())
	var as_away: TurnResolution = _resolve(_open_state(AWAY, _holder_spec(),
			[["a1", "A-L2", ""], ["a2", "D-C", ""], ["a3", "D-C", ""]], "M-C"), _pass_to_a_c(), _press_far())
	assert_int(as_away.record.outcome).is_equal(as_home.record.outcome)
	assert_int(as_home.next_state.possession).is_equal(AWAY)
	assert_int(as_away.next_state.possession).is_equal(HOME)
	assert_str(as_away.next_state.ball_area.to_key()).is_equal(as_home.next_state.ball_area.to_key())
	assert_int(as_away.record.attacker).is_equal(AWAY)
	assert_dict(TeamLayout.at_base(as_away.next_state.home_players).counts()) \
			.is_equal(TeamLayout.at_base(as_home.next_state.away_players).counts())


func test_resolve_turn_does_not_modify_its_input() -> void:
	var state: MatchState = _open_state(HOME, _holder_spec(), [["a1", "A-L2", ""]], "M-C")
	var next: MatchState = _resolve(state, _pass_to_a_c(), _press_far()).next_state
	assert_object(next).is_not_same(state)
	assert_int(state.turn_number).is_equal(1)
	assert_str(state.ball_area.to_key()).is_equal("M-C")
	assert_array(state.turn_records).is_empty()
	assert_bool(state.away_players[0].is_fixed()).is_false()

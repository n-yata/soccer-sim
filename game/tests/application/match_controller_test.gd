## MatchController（component-design.md §3.2。今回作る範囲）のテスト。
## 利用者 = HOME、CPU = AWAY。乱数はシードを固定した生成器、相手は決まった手を返すテスト用の相手か、
## 本物の CpuOpponent（固定シード）を使う。画面の要求は、記録用の関数で受け取る。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE


## 選べる手の先頭（invalid が真なら選べない手）を返す相手。陣形は最初が 4-3-3・ゾーン・カウンター、
## 2回目以降（ハーフタイム）は 3-5-2・マンツーマン・ポゼッション
class FixedOpponent extends OpponentPolicy:
	var invalid: bool = false
	var setup_calls: int = 0

	func choose_turn(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
		if invalid:
			# 保持していない側が攻撃の手を出す（選べない手）
			return TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)
		return MatchControllerTestHelper.first_choice(MoveRules.options_for(state, side))

	func choose_setup() -> TeamSetup:
		setup_calls += 1
		if setup_calls == 1:
			return TeamSetup.new("4-3-3", choose_styles())
		return TeamSetup.new("3-5-2", TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION))

	func choose_styles() -> TeamStyles:
		return TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)


## 手と陣形は本物の CpuOpponent に任せ、方式は呼ばれるたびに2通りを交互に返す相手
## （得点後の選び直しで、CPU の方式が実際に入れ替わることを確かめる）
class AlternatingStylesOpponent extends OpponentPolicy:
	var inner: CpuOpponent
	var last_styles: TeamStyles
	var style_calls: int = 0

	func _init(p_inner: CpuOpponent) -> void:
		inner = p_inner

	func choose_turn(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
		return inner.choose_turn(state, side)

	func choose_setup() -> TeamSetup:
		return inner.choose_setup()

	func choose_styles() -> TeamStyles:
		style_calls += 1
		if style_calls % 2 == 1:
			last_styles = TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION)
		else:
			last_styles = TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
		return last_styles


var _catalog: ContentCatalog
var _requests: Array[int] = []


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func before_test() -> void:
	_requests.clear()


func _record_request(screen: AppScreens.Id, _params: Dictionary = {}) -> void:
	_requests.append(screen)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _user_setup() -> TeamSetup:
	return TeamSetup.new("4-4-2", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER))


## 1ハーフのターン数を turns にした ConfigRepository（一時ディレクトリに .tres を書く）
func _config(turns: int) -> ConfigRepository:
	var dir: String = create_temp_dir("match_controller/turns_%d" % turns)
	var rules := MatchRuleConfig.new()
	rules.turns_per_half = turns
	ResourceSaver.save(rules, dir.path_join("match_rule_config.tres"))
	ResourceSaver.save(CpuConfig.new(), dir.path_join("cpu_config.tres"))
	return ConfigRepository.new(dir)


func _controller(seed_value: int, opponent: OpponentPolicy = FixedOpponent.new(), turns: int = 12,
		assert_on_invalid_cpu: bool = true) -> MatchController:
	return MatchController.new(_catalog, _config(turns), _rng(seed_value), opponent, _record_request, assert_on_invalid_cpu)


## 前半のキックオフが side になるシード（0 から順に探す）。探すために作った試合の画面の要求は消しておく
func _seed_for_kickoff(side: GameEnums.TeamSide) -> int:
	var found: int = -1
	for seed_value: int in range(100):
		var controller: MatchController = _controller(seed_value)
		controller.start_match(_user_setup())
		if controller.state().possession == side:
			found = seed_value
			break
	_requests.clear()
	return found


func _keys(areas: Array[PitchArea]) -> Array[String]:
	var result: Array[String] = []
	for area: PitchArea in areas:
		result.append(area.to_key())
	return result


# --- 試合の開始 ---

func test_start_match_creates_the_match_with_the_cpu_setup_and_emits_the_state() -> void:
	var controller: MatchController = _controller(1)
	var monitor := monitor_signals(controller, false)
	assert_bool(controller.start_match(_user_setup())).is_true()
	await assert_signal(monitor).is_emitted("state_changed", [any()])
	# 試合画面への切り替えはコントローラーが頼む（screen-02-match-setup.md）
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH])
	var snapshot: BoardSnapshot = controller.snapshot()
	assert_int(snapshot.half).is_equal(1)
	assert_int(snapshot.turn_number).is_equal(1)
	assert_int(snapshot.turns_per_half).is_equal(12)
	assert_str(snapshot.user_setup.formation_id).is_equal("4-4-2")
	assert_str(snapshot.opponent_setup.formation_id).is_equal("4-3-3")
	assert_str(controller.opponent_setup().formation_id).is_equal("4-3-3")
	assert_str(snapshot.ball_area).is_equal("M-C")
	# 試合 ID は YYYYMMDD-HHMMSS-NNNN（data-definition.md §2.1）
	var pattern := RegEx.create_from_string("^\\d{8}-\\d{6}-\\d{4}$")
	assert_object(pattern.search(controller.state().match_id)).is_not_null()
	assert_str(controller.state().started_at).is_not_empty()


func test_kickoff_side_comes_from_the_injected_rng() -> void:
	# 同じシードなら同じキックオフ側。シードを変えると両方の側が出る
	var first: MatchController = _controller(7)
	first.start_match(_user_setup())
	var second: MatchController = _controller(7)
	second.start_match(_user_setup())
	assert_int(second.state().possession).is_equal(first.state().possession)
	assert_int(_seed_for_kickoff(HOME)).is_not_equal(-1)
	assert_int(_seed_for_kickoff(AWAY)).is_not_equal(-1)


func test_start_match_with_an_unknown_formation_fails() -> void:
	var controller: MatchController = _controller(1)
	var unknown := TeamSetup.new("9-9-9", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER))
	await assert_error(func() -> void: controller.start_match(unknown)) \
			.is_push_error("MatchController: 試合を作れない（陣形が無い）: 9-9-9")
	assert_bool(controller.is_match_started()).is_false()
	assert_array(_requests).is_empty()


func test_queries_before_the_match_starts_report_an_error_and_return_nothing() -> void:
	var controller: MatchController = _controller(1)
	await assert_error(func() -> void: controller.snapshot()) \
			.is_push_error("MatchController: 試合が始まる前に snapshot は呼べない")
	await assert_error(func() -> void: controller.user_options()) \
			.is_push_error("MatchController: 試合が始まる前に user_options は呼べない")
	await assert_error(func() -> void: controller.user_hints()) \
			.is_push_error("MatchController: 試合が始まる前に user_hints は呼べない")
	await assert_error(func() -> void: controller.opponent_setup()) \
			.is_push_error("MatchController: 試合が始まる前に opponent_setup は呼べない")
	assert_object(controller.snapshot()).is_null()
	assert_object(controller.user_options()).is_null()
	assert_array(controller.user_hints()).is_empty()
	assert_object(controller.opponent_setup()).is_null()
	assert_object(controller.state()).is_null()


# --- 選べる手・ヒント（利用者の視点） ---

func test_user_options_are_mirrored_when_the_user_defends() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(AWAY))
	controller.start_match(_user_setup())
	var user_options: MoveOptions = controller.user_options()
	var domain_options: MoveOptions = MoveRules.options_for(controller.state(), HOME)
	var expected: Array[String] = []
	for target: PitchArea in domain_options.targets(DEFENSE, GameEnums.DefenseAction.PRESS):
		expected.append(target.mirrored().to_key())
	assert_array(_keys(user_options.targets(DEFENSE, GameEnums.DefenseAction.PRESS))).is_equal(expected)
	assert_bool(user_options.is_available(ATTACK, GameEnums.PlayType.DRIBBLE)).is_false()


func test_user_hints_match_the_user_options() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(AWAY))
	controller.start_match(_user_setup())
	var options: MoveOptions = controller.user_options()
	for hint: ChoiceHint in controller.user_hints():
		assert_bool(MoveRules.is_allowed(options, TurnChoice.new(hint.family, hint.action, hint.target))) \
				.override_failure_message(str(hint.target)).is_true()


# --- 1ターンの確定 ---

func test_submit_turn_converts_the_user_choice_and_reveals_in_the_user_view() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(AWAY))
	controller.start_match(_user_setup())
	var target: PitchArea = controller.user_options().targets(DEFENSE, GameEnums.DefenseAction.PRESS)[0]
	var choice := TurnChoice.new(DEFENSE, GameEnums.DefenseAction.PRESS, target)
	var monitor := monitor_signals(controller, false)
	assert_bool(controller.submit_turn(choice)).is_true()
	await assert_signal(monitor).is_emitted("turn_resolved", [any(), any()])
	var reveal: RevealView = controller.last_reveal()
	assert_int(reveal.user_role).is_equal(GameEnums.Phase.DEFENSE)
	assert_str(reveal.user_choice.target.to_key()).is_equal(target.to_key())
	# 判定は攻撃側（CPU = AWAY）の視点で行われ、記録された利用者の手の運ぶ先は鏡像
	var record: TurnRecord = controller.state().turn_records[0]
	assert_str(record.home_choice.target.to_key()).is_equal(target.mirrored().to_key())
	assert_int(controller.state().turn_number).is_equal(2)


func test_submit_turn_rejects_an_unavailable_choice_without_changing_anything() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(AWAY))
	controller.start_match(_user_setup())
	var monitor := monitor_signals(controller, false)
	# 守備側の利用者が攻撃の手を出す
	var wrong := TurnChoice.new(ATTACK, GameEnums.PlayType.SHOT)
	await assert_error(func() -> void: controller.submit_turn(wrong)) \
			.is_push_error("MatchController: 選べない手は受け付けない")
	assert_bool(controller.submit_turn(wrong)).is_false()
	await assert_signal(monitor).is_not_emitted("turn_resolved")
	assert_int(controller.state().turn_number).is_equal(1)
	assert_array(controller.state().turn_records).is_empty()


func test_invalid_cpu_choice_is_replaced_by_the_first_selectable_move() -> void:
	# 書き出し版の経路（開発時は assert で止めるため、テストでは止めない設定にする）
	var opponent := FixedOpponent.new()
	opponent.invalid = true
	var controller: MatchController = _controller(_seed_for_kickoff(HOME), opponent, 12, false)
	controller.start_match(_user_setup())
	var choice: TurnChoice = MatchControllerTestHelper.first_choice(controller.user_options())
	await assert_error(func() -> void: controller.submit_turn(choice)) \
			.is_push_error("MatchController: CPU の手が選べないため、選べる手の先頭に置き換える")
	# CPU（4-3-3・ゾーン）はキックオフで守備側。選べる手の先頭は手の enum の順で PRESS、運ぶ先は
	# PitchArea.all() の順で最初に選べるエリア。攻撃側から見た D-L2 は守備側の視点で A-R2 で、その上下左右
	# （A-R1・M-R2）に選手がいないので選べない。D-L1（守備側の視点で A-R1）は隣の A-R2 に RW がいるので選べる
	var record: TurnRecord = controller.state().turn_records[0]
	assert_int(record.away_choice.family).is_equal(DEFENSE)
	assert_int(record.away_choice.action).is_equal(GameEnums.DefenseAction.PRESS)
	assert_str(record.away_choice.target.to_key()).is_equal("D-L1")


func test_snapshot_after_a_turn_has_the_movements_of_that_turn() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(HOME))
	controller.start_match(_user_setup())
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	var record: TurnRecord = controller.state().turn_records[0]
	assert_int(controller.snapshot().movements.size()).is_equal(record.movements.size())


# --- 次への進み方 ---

func test_a_second_turn_is_rejected_until_the_reveal_is_confirmed() -> void:
	# 確定ボタンの二度押しで、1ターン目の開示を飛ばして2ターン目が解決されないこと
	var controller: MatchController = _controller(_seed_for_kickoff(HOME))
	controller.start_match(_user_setup())
	assert_bool(controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))).is_true()
	assert_bool(controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))).is_false()
	assert_int(controller.state().turn_records.size()).is_equal(1)
	controller.continue_after_reveal()
	assert_bool(controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))).is_true()
	assert_int(controller.state().turn_records.size()).is_equal(2)


func test_continue_without_a_pending_reveal_does_nothing() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(HOME))
	controller.start_match(_user_setup())
	var monitor := monitor_signals(controller, false)
	controller.continue_after_reveal()
	await assert_signal(monitor).is_not_emitted("state_changed")
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH])

func test_continue_in_the_middle_of_a_half_emits_the_state() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(HOME))
	controller.start_match(_user_setup())
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	# キックオフ（M-C）の1ターン目はシュートを選べないので得点は無く、前半の途中のまま
	assert_int(controller.state().stage).is_equal(GameEnums.MatchStage.TURN)
	var monitor := monitor_signals(controller, false)
	controller.continue_after_reveal()
	await assert_signal(monitor).is_emitted("state_changed", [any()])
	await assert_signal(monitor).is_not_emitted("stage_changed")
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH])


func test_halftime_and_the_end_request_their_screens() -> void:
	# 1ハーフ1ターン: 前半の1ターンでハーフタイム、後半の1ターンで試合終了
	var controller: MatchController = _controller(_seed_for_kickoff(HOME), FixedOpponent.new(), 1)
	controller.start_match(_user_setup())
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	# 開示を確認する前は、ハーフタイムの画面を経ずに後半へ進めない
	assert_bool(controller.submit_halftime(_user_setup())).is_false()
	assert_array(controller.snapshot().movements).is_not_empty()
	var monitor := monitor_signals(controller, false)
	controller.continue_after_reveal()
	await assert_signal(monitor).is_emitted("stage_changed", [GameEnums.MatchStage.HALFTIME])
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH, AppScreens.Id.S05_HALFTIME])
	monitor = monitor_signals(controller, false)
	assert_bool(controller.submit_halftime(_user_setup())).is_true()
	await assert_signal(monitor).is_emitted("state_changed", [any()])
	assert_int(controller.snapshot().half).is_equal(2)
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH, AppScreens.Id.S05_HALFTIME, AppScreens.Id.S03_MATCH])
	# 後半は配置を作り直すので、前半の最後のターンの動きは盤面に出さない
	assert_array(controller.snapshot().movements).is_empty()
	# CPU の陣形・方式もハーフタイムで選び直される
	assert_str(controller.opponent_setup().formation_id).is_equal("3-5-2")
	assert_int(controller.opponent_setup().styles.defense).is_equal(GameEnums.DefenseStyle.MAN)
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	controller.continue_after_reveal()
	assert_bool(controller.is_match_over()).is_true()
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH, AppScreens.Id.S05_HALFTIME, AppScreens.Id.S03_MATCH, AppScreens.Id.S06_RESULT])
	# 結果の画面は1回だけ頼む
	controller.continue_after_reveal()
	assert_array(_requests).is_equal([AppScreens.Id.S03_MATCH, AppScreens.Id.S05_HALFTIME, AppScreens.Id.S03_MATCH, AppScreens.Id.S06_RESULT])
	# 終わった試合ではターンを受け付けない
	assert_bool(controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))).is_false()


func test_style_change_and_halftime_are_rejected_in_the_wrong_stage() -> void:
	var controller: MatchController = _controller(1)
	controller.start_match(_user_setup())
	assert_bool(controller.submit_style_change(TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION))).is_false()
	assert_bool(controller.submit_halftime(_user_setup())).is_false()


func test_a_full_match_against_the_cpu_runs_to_the_result() -> void:
	# 本物の CpuOpponent（方式だけ2通りを交互に返す）。利用者はシュートを選べればシュート、そうでなければ
	# 選べる手の先頭。得点のたびに、方式の選び直しの画面を頼み、選び直しで CPU の方式が入れ替わることを確かめる
	var style_changes: int = 0
	var cpu_styles_changed: bool = false
	for seed_value: int in range(20):
		var rng: RandomNumberGenerator = _rng(seed_value)
		var opponent := AlternatingStylesOpponent.new(CpuOpponent.new(_catalog, CpuConfig.new(), rng))
		var controller := MatchController.new(_catalog, ConfigRepository.new(), rng, opponent, _record_request, true)
		var stages: Array[int] = []
		var states_emitted: Array[int] = [0]
		controller.stage_changed.connect(func(stage: GameEnums.MatchStage) -> void: stages.append(stage))
		controller.state_changed.connect(func(_snapshot: BoardSnapshot) -> void: states_emitted[0] += 1)
		_requests.clear()
		controller.start_match(_user_setup())
		var steps: int = 0
		while not controller.is_match_over() and steps < 100:
			steps += 1
			var stage: GameEnums.MatchStage = controller.state().stage
			if stage == GameEnums.MatchStage.STYLE_CHANGE:
				style_changes += 1
				# 得点の後の continue_after_reveal が、段階の変化を知らせて方式の選び直しの画面を頼んでいる
				assert_int(_requests.back() as int).is_equal(AppScreens.Id.S04_STYLE_CHANGE)
				assert_int(stages.back() as int).is_equal(GameEnums.MatchStage.STYLE_CHANGE)
				var before: TeamStyles = controller.opponent_setup().styles
				var emitted_before: int = states_emitted[0]
				assert_bool(controller.submit_style_change(controller.snapshot().user_setup.styles)).is_true()
				assert_int(states_emitted[0]).is_equal(emitted_before + 1)
				assert_int(_requests.back() as int).is_equal(AppScreens.Id.S03_MATCH)
				# キックオフの配置に戻るので、得点のターンの動きは盤面に出さない
				assert_array(controller.snapshot().movements).is_empty()
				var after: TeamStyles = controller.opponent_setup().styles
				assert_int(after.defense).is_equal(opponent.last_styles.defense)
				assert_int(after.attack).is_equal(opponent.last_styles.attack)
				if after.defense != before.defense or after.attack != before.attack:
					cpu_styles_changed = true
			elif stage == GameEnums.MatchStage.HALFTIME:
				assert_bool(controller.submit_halftime(controller.snapshot().user_setup)).is_true()
			else:
				assert_bool(controller.submit_turn(MatchControllerTestHelper.shot_or_first(controller.user_options()))).is_true()
				if controller.state().stage == GameEnums.MatchStage.STYLE_CHANGE:
					# 得点の開示を確認する前は、方式の選び直しの画面を経ずに再開できない
					assert_bool(controller.submit_style_change(controller.snapshot().user_setup.styles)).is_false()
				controller.continue_after_reveal()
		assert_bool(controller.is_match_over()).override_failure_message("seed %d" % seed_value).is_true()
		assert_int(_requests.back() as int).is_equal(AppScreens.Id.S06_RESULT)
		assert_int(controller.state().turn_records.size()).is_equal(24)
		assert_int(_requests.count(AppScreens.Id.S04_STYLE_CHANGE)).is_equal(stages.count(GameEnums.MatchStage.STYLE_CHANGE))
	# 20試合のどこかで得点（方式の選び直し）が起き、CPU の方式が入れ替わる経路も通っていることを確かめる
	assert_int(style_changes).is_greater(0)
	assert_bool(cpu_styles_changed).is_true()


# --- 結果の画面から出る ---

func test_leave_result_before_the_end_is_rejected() -> void:
	var controller: MatchController = _controller(1)
	controller.start_match(_user_setup())
	_requests.clear()
	await assert_error(func() -> void: controller.leave_result()) \
			.is_push_error("MatchController: 試合が終わる前に結果の画面からは出られない")
	assert_bool(controller.leave_result()).is_false()
	assert_array(_requests).is_empty()


func test_leave_result_after_the_end_requests_the_title() -> void:
	var controller: MatchController = _controller(_seed_for_kickoff(HOME), FixedOpponent.new(), 1)
	controller.start_match(_user_setup())
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	controller.continue_after_reveal()
	controller.submit_halftime(_user_setup())
	controller.submit_turn(MatchControllerTestHelper.first_choice(controller.user_options()))
	controller.continue_after_reveal()
	_requests.clear()
	assert_bool(controller.leave_result()).is_true()
	assert_array(_requests).is_equal([AppScreens.Id.S01_TITLE])

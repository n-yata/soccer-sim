## 中断データの書き出し（SuspendedMatchEncoder）と読み込み（SuspendedMatchDecoder）のテスト（data-definition.md §2.1）。
## 往復: 固定シードの試合を最後まで進め、各段階の状態を JSON の文字列にして戻すと、書き出しが元と一致する。さらに、
## 戻した状態から同じ手で1ターン進めた結果が、元の状態から進めた結果と一致する（書き出しに出ない値の取りこぼしも捕まえる）。
## 範囲外: 正しい中断データを1か所ずつ壊して、読み込みが null になる。
extends GdUnitTestSuite

## 1試合で約40の状態（ハーフタイム・得点後の選び直しを含む）を往復させる。全体テストを3分以内に収めるため1試合に絞った（2026-11-03）
const SEEDS: Array[int] = [0]

var _catalog: ContentCatalog
var _rules: MatchRuleConfig
## シード → その試合の各段階の状態。試合を回すのに時間がかかるので、スイートの最初に1回だけ作る（各テストは読むだけ）
var _states_by_seed: Dictionary = {}


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()
	_rules = ConfigRepository.new().match_rules()
	for seed_value: int in SEEDS:
		_states_by_seed[seed_value] = _play_a_match(seed_value)


func _decoder() -> SuspendedMatchDecoder:
	return SuspendedMatchDecoder.new(_catalog, _rules)


## 保存と同じ経路（JSON の文字列）を通して戻す
func _round_trip(state: MatchState) -> MatchState:
	return _decoder().decode(JSON.parse_string(SuspendedMatchEncoder.to_json(state)))


## before で作った seed の試合の各段階の状態（読むだけにする）
func _states_of_a_match(seed_value: int) -> Array[MatchState]:
	return _states_by_seed[seed_value]


## seed の試合を最後まで進め、各段階の状態の写しを集める（ターン中・方式の選び直し・ハーフタイム・試合の後）
func _play_a_match(seed_value: int) -> Array[MatchState]:
	var controller: MatchController = ScreenTestHelper.new_controller(seed_value,
			func(_s: AppScreens.Id, _p: Dictionary) -> void: pass)
	controller.start_match(ScreenTestHelper.user_setup())
	var states: Array[MatchState] = [controller.state()]
	for step: int in range(ScreenTestHelper.MAX_STEPS):
		if controller.is_match_over():
			break
		var stage: GameEnums.MatchStage = controller.state().stage
		if stage == GameEnums.MatchStage.STYLE_CHANGE:
			controller.submit_style_change(controller.snapshot().user_setup.styles)
		elif stage == GameEnums.MatchStage.HALFTIME:
			controller.submit_halftime(controller.snapshot().user_setup)
		else:
			controller.submit_turn(ScreenTestHelper.forward_choice(controller.user_options()))
			controller.continue_after_reveal()
		states.append(controller.state())
	return states


func _first_choice(state: MatchState, side: GameEnums.TeamSide) -> TurnChoice:
	return MatchControllerTestHelper.first_choice(MoveRules.options_for(state, side))


func test_every_state_of_whole_matches_survives_the_round_trip() -> void:
	var kinds_seen: Dictionary = {}
	for seed_value: int in SEEDS:
		for state: MatchState in _states_of_a_match(seed_value):
			var label: String = "seed %d seq %d" % [seed_value, state.turn_records.size()]
			var decoder: SuspendedMatchDecoder = _decoder()
			var restored: MatchState = decoder.decode(JSON.parse_string(SuspendedMatchEncoder.to_json(state)))
			assert_object(restored).override_failure_message("%s %s" % [label, str(decoder.errors())]).is_not_null()
			if restored == null:
				return
			assert_str(SuspendedMatchEncoder.to_json(restored)).override_failure_message(label) \
					.is_equal(SuspendedMatchEncoder.to_json(state))
			kinds_seen[state.stage] = true
			kinds_seen[state.turn_kind + 10] = true
			if state.status == GameEnums.MatchStatus.FINISHED or MatchRules.is_play_complete(state, _rules):
				kinds_seen["over"] = true
	# 中断しうる段階（ターン中の攻守・トランジション、方式の選び直し、ハーフタイム）と試合の後を、どれも通っている
	for kind: Variant in [GameEnums.MatchStage.TURN, GameEnums.MatchStage.STYLE_CHANGE, GameEnums.MatchStage.HALFTIME,
			GameEnums.TurnKind.OPEN_PLAY + 10, GameEnums.TurnKind.TRANSITION + 10, "over"]:
		assert_bool(kinds_seen.has(kind)).override_failure_message(str(kind)).is_true()


func test_a_restored_state_plays_the_next_turn_exactly_like_the_original() -> void:
	var checked: int = 0
	for seed_value: int in SEEDS:
		for state: MatchState in _states_of_a_match(seed_value):
			if state.stage != GameEnums.MatchStage.TURN or MatchRules.is_play_complete(state, _rules):
				continue
			var restored: MatchState = _round_trip(state)
			var holder: GameEnums.TeamSide = state.possession
			var other: GameEnums.TeamSide = MatchState.other(holder)
			var home_choice: TurnChoice = _first_choice(state, GameEnums.TeamSide.HOME)
			var away_choice: TurnChoice = _first_choice(state, GameEnums.TeamSide.AWAY)
			var original: TurnResolution = MatchRules.resolve_turn(state, home_choice, away_choice, _rules)
			var again: TurnResolution = MatchRules.resolve_turn(restored, home_choice.duplicate_deep(),
					away_choice.duplicate_deep(), _rules)
			assert_str(SuspendedMatchEncoder.to_json(again.next_state)) \
					.override_failure_message("seed %d seq %d (holder %d other %d)" % [seed_value,
					state.turn_records.size(), holder, other]) \
					.is_equal(SuspendedMatchEncoder.to_json(original.next_state))
			checked += 1
	assert_int(checked).is_greater(30)


func test_the_written_shape_follows_the_data_definition() -> void:
	var state: MatchState = _states_of_a_match(0)[3]
	var root: Dictionary = SuspendedMatchEncoder.encode(state)
	assert_int(root["format_version"] as int).is_equal(1)
	var match_data: Dictionary = root["match"]
	for key: String in ["match_id", "status", "stage", "half", "turn_number", "turn_kind", "possession", "ball_area",
			"first_half_kickoff", "score", "setups", "players", "transition_origin", "started_at", "turn_records"]:
		assert_bool(match_data.has(key)).override_failure_message(key).is_true()
	assert_str(match_data["status"] as String).is_equal("IN_PROGRESS")
	assert_int((match_data["players"]["HOME"] as Array).size()).is_equal(10)
	var player: Dictionary = (match_data["players"]["HOME"] as Array)[0]
	assert_array(player.keys()).contains_exactly_in_any_order(
			["player_id", "base_area", "fixed_area", "current_area", "moved_in_turn"])
	var record: Dictionary = (match_data["turn_records"] as Array)[0]
	assert_str(record["choices"]["HOME"]["family"] as String).is_not_empty()
	assert_bool(PitchArea.from_key(record["ball_before"] as String) != null).is_true()


# --- 範囲外 ---


## 正しい中断データ（ターン記録とトランジションの起点を含む）の写し
func _valid_root() -> Dictionary:
	for state: MatchState in _states_of_a_match(0):
		if state.turn_kind == GameEnums.TurnKind.TRANSITION and state.turn_records.size() >= 2:
			return JSON.parse_string(SuspendedMatchEncoder.to_json(state))
	return {}


## path（キーと添字の並び）の場所の値を value にした写し。value が REMOVE ならキーを消す
const REMOVE: String = "__remove__"


func _with(root: Dictionary, path: Array, value: Variant) -> Dictionary:
	var copied: Dictionary = root.duplicate(true)
	var node: Variant = copied
	for index: int in range(path.size() - 1):
		node = node[path[index]]
	if typeof(value) == TYPE_STRING and value == REMOVE:
		(node as Dictionary).erase(path.back())
	else:
		node[path.back()] = value
	return copied


func _assert_corrupted(root: Dictionary, label: String) -> void:
	var decoder: SuspendedMatchDecoder = _decoder()
	assert_object(decoder.decode(root)).override_failure_message(label).is_null()
	assert_array(decoder.errors()).override_failure_message(label).is_not_empty()


func test_the_valid_root_itself_is_read() -> void:
	var root: Dictionary = _valid_root()
	assert_dict(root).is_not_empty()
	var decoder: SuspendedMatchDecoder = _decoder()
	assert_object(decoder.decode(root)).override_failure_message(str(decoder.errors())).is_not_null()


func test_values_outside_the_data_definition_are_corrupted() -> void:
	var root: Dictionary = _valid_root()
	var first_player: Array = ["match", "players", "HOME", 0]
	var first_record: Array = ["match", "turn_records", 0]
	var cases: Array = [
		[["format_version"], 2, "新しい版"],
		[["format_version"], REMOVE, "版が無い"],
		[["format_version"], "1", "版が文字列"],
		[["match"], REMOVE, "試合が無い"],
		[["match", "match_id"], "2026-1", "試合 ID の形"],
		[["match", "status"], "SUSPENDED", "存在しない状態"],
		[["match", "stage"], 0, "進行段階が数"],
		[["match", "half"], 3, "ハーフが 3"],
		[["match", "half"], 1.5, "ハーフが小数"],
		[["match", "half"], 1e300, "ハーフがとても大きな数"],
		[["match", "turn_number"], 0, "ターン 0"],
		[["match", "turn_number"], _rules.turns_per_half + _rules.max_additional_turns + 2, "ターンの上限超え"],
		[["match", "ball_area"], "Z9-C", "存在しないエリア"],
		[["match", "ball_area"], "M-L1", "3列の頃のエリア名"],
		[["match", "score", "AWAY"], -1, "負の得点"],
		[["match", "score", "HOME"], 100, "得点の上限超え"],
		[["match", "setups", "HOME", "formation_id"], "5-3-2", "陣形が無い"],
		[["match", "setups", "AWAY", "defense"], "PRESS", "守備方式でない"],
		[["match", "players", "HOME"], (root["match"]["players"]["HOME"] as Array).slice(0, 9), "9人"],
		[first_player + ["player_id"], "nobody", "陣形に無い選手"],
		[first_player + ["player_id"], root["match"]["players"]["HOME"][1]["player_id"], "選手の重なり"],
		[first_player + ["base_area"], "A2-C", "陣形と違う基本エリア"],
		[first_player + ["fixed_area"], REMOVE, "固定先のキーが無い"],
		[first_player + ["current_area"], null, "今いるエリアが null"],
		[first_player + ["moved_in_turn"], 1, "動いたかが数"],
		[["match", "transition_origin"], null, "トランジションなのに起点が無い"],
		[["match", "transition_origin", "attacker_side"], "BOTH", "起点の攻撃側"],
		[["match", "started_at"], "2026/10/29 10:00", "日時の形"],
		[["match", "turn_records"], {}, "ターン記録が配列でない"],
		[first_record + ["seq"], 5, "連番でない"],
		[first_record + ["choices", "HOME", "action"], "FLY", "存在しない手"],
		[first_record + ["choices", "HOME", "family"], REMOVE, "手の種類が無い"],
		[first_record + ["movements"], [{"side": "HOME", "player_id": "nobody", "from": "M1-C", "to": "M2-C",
				"reason": "PRESS"}], "動いた選手が陣形に無い"],
		[first_record + ["outcome"], "WIN", "存在しない結果"],
		[first_record + ["players_before", "AWAY"], [], "記録の配置が空"],
	]
	for case: Array in cases:
		_assert_corrupted(_with(root, case[0] as Array, case[1]), case[2] as String)


func test_a_halftime_in_the_second_half_is_corrupted() -> void:
	var root: Dictionary = _valid_root()
	var halftime: Dictionary = _with(root, ["match", "stage"], "HALFTIME")
	assert_object(_decoder().decode(halftime)).override_failure_message("前半のハーフタイムは読める").is_not_null()
	_assert_corrupted(_with(halftime, ["match", "half"], 2), "後半のハーフタイム")


func test_turn_records_over_the_limit_are_corrupted() -> void:
	var root: Dictionary = _valid_root()
	var records: Array = root["match"]["turn_records"]
	var many: Array = []
	for index: int in range((_rules.turns_per_half + _rules.max_additional_turns) * 2 + 1):
		var copied: Dictionary = (records[0] as Dictionary).duplicate(true)
		copied["seq"] = index + 1
		many.append(copied)
	_assert_corrupted(_with(root, ["match", "turn_records"], many), "ターン記録の上限超え")


func test_judge_must_be_null_exactly_when_there_was_no_contest() -> void:
	var root: Dictionary = _valid_root()
	var record: Dictionary = root["match"]["turn_records"][0]
	if record["judge"] == null:
		_assert_corrupted(_with(root, ["match", "turn_records", 0, "outcome"], "ADVANCE"), "判定なし以外で内訳が null")
	else:
		_assert_corrupted(_with(root, ["match", "turn_records", 0, "judge"], null), "判定ありなのに内訳が null")
		_assert_corrupted(_with(root, ["match", "turn_records", 0, "outcome"], "NO_CONTEST"), "判定なしなのに内訳がある")


func test_a_choice_target_must_match_whether_the_move_needs_one() -> void:
	var root: Dictionary = _valid_root()
	var choice: Array = ["match", "turn_records", 0, "choices", "HOME"]
	var shot: Dictionary = _with(root, choice + ["family"], "ATTACK")
	shot = _with(shot, choice + ["action"], "SHOT")
	_assert_corrupted(_with(shot, choice + ["target"], "M2-C"), "シュートに運ぶ先がある")
	var pass_choice: Dictionary = _with(root, choice + ["family"], "ATTACK")
	pass_choice = _with(pass_choice, choice + ["action"], "SHORT_PASS")
	_assert_corrupted(_with(pass_choice, choice + ["target"], null), "パスに運ぶ先が無い")


func test_not_an_object_at_the_top_is_corrupted() -> void:
	for value: Variant in [null, [], "text", 1]:
		var decoder: SuspendedMatchDecoder = _decoder()
		assert_object(decoder.decode(value)).override_failure_message(str(value)).is_null()

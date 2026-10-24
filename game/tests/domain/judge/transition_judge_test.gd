## アルゴリズム6: トランジションターンの判定（TransitionJudge）のテスト。
## 判定例 JE-07 は functional-overview.md「判定例」から、それ以外の期待値はアルゴリズム6の規則から手で書いた。
## 直前の配置 origin は奪取側を attacker として持つ。ボール位置 X・運ぶ先・比較エリアは奪取側の視点、
## 各チームの配置と動きはそのチーム自身から見た座標（component-design.md §1.2）。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _styles(defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamStyles:
	return TeamStyles.new(defense, attack)


func _counter(target_key: String) -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.COUNTER, _area(target_key))


func _secure() -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)


func _counter_press() -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)


func _retreat() -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.RETREAT)


## spec は [選手 ID, 基本エリア, 現在エリア（基本と同じなら ""）, 固定先（無ければ ""）]
func _team(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for row: Array in spec:
		var current_key: String = row[2] as String
		var fixed_key: String = row[3] as String
		var fixed: PitchArea = null if fixed_key == "" else _area(fixed_key)
		var player := PlayerState.new(row[0] as String, _area(row[1] as String), fixed)
		players.append(player)
		current[player.player_id] = player.base_area if current_key == "" else _area(current_key)
	return TeamLayout.new(players, current)


## そのチーム自身から見た行 "A l2 l1 c r1 r2 / M ... / D ..."
func _rows(layout: TeamLayout) -> String:
	var rows: Array[String] = []
	for zone: GameEnums.Zone in [GameEnums.Zone.A, GameEnums.Zone.M, GameEnums.Zone.D]:
		var counts: Array[String] = []
		for lane: GameEnums.Lane in [GameEnums.Lane.L2, GameEnums.Lane.L1, GameEnums.Lane.C,
				GameEnums.Lane.R1, GameEnums.Lane.R2]:
			counts.append(str(layout.count_at(PitchArea.new(lane, zone))))
		rows.append("%s %s" % [["D", "M", "A"][zone], " ".join(counts)])
	return " / ".join(rows)


func _moves(output: JudgeOutput) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in output.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## "結果 比較エリア 奪取側人数-喪失側人数 カバー"
func _summary(output: JudgeOutput) -> String:
	return "%s %s %d-%d %s" % [GameEnums.TurnOutcome.keys()[output.outcome], output.detail.compare_area.to_key(),
			output.detail.attacker_count, output.detail.defender_count,
			GameEnums.CoverKind.keys()[output.detail.cover]]


## JE-07 の直前の配置: 喪失側 4-3-3 保持型が攻撃中に A-C でロスト。奪取側 4-4-2 はゾーン（C レーンなのでスライドなし）
func _je07_origin(winner_side: GameEnums.TeamSide = HOME) -> LayoutPair:
	var loser_side: GameEnums.TeamSide = AWAY if winner_side == HOME else HOME
	var before: LayoutStep = StyleLayoutCalculator.compute(
			BaseLayoutDeriver.derive(_catalog.formation("4-3-3")), _styles(ZONE, POSSESSION),
			BaseLayoutDeriver.derive(_catalog.formation("4-4-2")), _styles(ZONE, COUNTER),
			_area("A-C"), loser_side)
	return LayoutPair.new(before.pair.defender, before.pair.attacker, winner_side)


func _je07(winner_choice: TurnChoice, winner_side: GameEnums.TeamSide = HOME) -> JudgeOutput:
	# 奪取側から見て、ボールは D-C
	return TransitionJudge.judge(_je07_origin(winner_side), _styles(ZONE, COUNTER), _styles(ZONE, POSSESSION),
			_area("D-C"), winner_choice, _counter_press())


# --- 判定例 JE-07 ---

func test_je07_counter_into_the_space_behind_the_possession_side() -> void:
	var origin: LayoutPair = _je07_origin()
	assert_str(_rows(origin.defender)).is_equal("A 1 0 1 0 1 / M 1 1 1 1 1 / D 0 0 2 0 0")
	var output: JudgeOutput = _je07(_counter("A-L2"))
	# カウンター型の飛び出しで、奪取側の大外が1ゾーン前へ
	assert_str(_rows(output.pair.attacker)).is_equal("A 1 0 2 0 1 / M 1 0 2 0 1 / D 0 0 2 0 0")
	assert_int(output.movements.size()).is_equal(4)
	for movement: Movement in output.movements:
		assert_int(movement.reason).is_equal(GameEnums.MovementReason.COUNTER_BREAKOUT)
		assert_int(movement.side).is_equal(HOME)
	# 喪失側のその地点（自陣の大外）は SB が上がったまま 0 人
	assert_str(_summary(output)).is_equal("ADVANCE A-L2 1-0 NONE")


func test_je07_secure_against_counter_press_fails_to_regain() -> void:
	var output: JudgeOutput = _je07(_secure())
	# X = D-C と隣接の合計: 奪取側 4（D-C 2・M-C 2）、喪失側 2（A-C 1・M-C 1）
	assert_str(_summary(output)).is_equal("REGAIN_FAILED D-C 4-2 NONE")
	assert_array(_moves(output)).is_empty()


# --- 即時奪回×保持 ---

func test_counter_press_with_more_players_around_the_ball_regains() -> void:
	var winner: TeamLayout = _team([["w1", "D-C", "", ""]])
	# 喪失側から見て X は A-C。A-C に1人、隣接の A-L1 に1人
	var loser: TeamLayout = _team([["l1", "A-C", "", ""], ["l2", "A-L1", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D-C"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN D-C 1-2 NONE")


func test_counter_press_with_level_numbers_fails_to_regain() -> void:
	var winner: TeamLayout = _team([["w1", "D-C", "", ""], ["w2", "D-L1", "", ""]])
	# 喪失側の M-L1 は X の隣接ではない（斜め）
	var loser: TeamLayout = _team([["l1", "A-C", "", ""], ["l2", "M-C", "", ""], ["l3", "M-L1", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D-C"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN_FAILED D-C 2-2 NONE")


func test_counter_press_on_the_wing_counts_the_mirrored_side_only() -> void:
	# X は奪取側の視点で D-L2（盤の端。隣接は D-L1 と M-L2 だけ）。喪失側の視点では A-R2（隣接は A-R1 と M-R2）
	var winner: TeamLayout = _team([["w1", "D-L2", "", ""], ["w2", "D-L1", "", ""]])
	# decoy は喪失側の A-L2。レーンを鏡写しにし損ねたときだけ数えに入る
	var loser: TeamLayout = _team([
		["l1", "A-R2", "", ""], ["l2", "A-R1", "", ""], ["l3", "M-R2", "", ""], ["decoy", "A-L2", "", ""],
	])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D-L2"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN D-L2 2-3 NONE")


func test_counter_into_more_defenders_is_lost() -> void:
	# 喪失側から見ても M-C に2人。カウンターの運ぶ先で上回られて奪い返される
	var winner: TeamLayout = _team([["w1", "D-C", "", ""], ["w2", "M-C", "", ""]])
	var loser: TeamLayout = _team([["l1", "M-C", "", ""], ["l2", "M-C", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D-C"), _counter("M-C"), _counter_press())
	assert_str(_summary(output)).is_equal("LOSS M-C 1-2 NONE")


func test_counter_targets_come_from_the_layout_after_the_breakout() -> void:
	# アルゴリズム3: カウンターの運ぶ先は「アルゴリズム6の配置」で味方がいるエリア。JE-07 の A-L2 は飛び出す前は0人
	var origin: LayoutPair = _je07_origin()
	var counter_action := GameEnums.PosTransAction.COUNTER
	var after: MoveOptions = MoveRules.pos_transition_options(
			TransitionJudge.counter_layout(origin.attacker, _styles(ZONE, COUNTER)), _area("D-C"))
	var before: MoveOptions = MoveRules.pos_transition_options(origin.attacker, _area("D-C"))
	assert_bool(MoveRules.is_allowed(after, _counter("A-L2"))).is_true()
	assert_bool(MoveRules.is_allowed(before, _counter("A-L2"))).is_false()
	assert_int(after.targets(GameEnums.ChoiceFamily.POS_TRANS, counter_action).size()) \
			.is_greater(before.targets(GameEnums.ChoiceFamily.POS_TRANS, counter_action).size())


# --- カウンターの同数（カバー判定） ---

func _level_counter(target_key: String) -> JudgeOutput:
	# 奪取側は保持型（飛び出さない）。運ぶ先に奪取側1人、同じ地点に喪失側1人
	var winner: TeamLayout = _team([["w1", "D-C", "", ""], ["w2", target_key, "", ""]])
	var loser: TeamLayout = _team([["l1", _area(target_key).mirrored().to_key(), "", ""]])
	return TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D-C"), _counter(target_key), _counter_press())


func test_level_counter_in_the_final_third_advances_without_a_keeper_cover() -> void:
	# GK はカバーに数えない（2026-10-24）。カウンターに読みは無いので、敵陣の同数はどのレーンでも前進
	assert_str(_summary(_level_counter("A-L2"))).is_equal("ADVANCE A-L2 1-1 NONE")
	assert_str(_summary(_level_counter("A-C"))).is_equal("ADVANCE A-C 1-1 NONE")
	assert_str(_summary(_level_counter("A-R1"))).is_equal("ADVANCE A-R1 1-1 NONE")
	assert_int(_level_counter("A-C").detail.read).is_equal(GameEnums.ReadKind.NONE)


# --- リトリート ---

func test_retreat_against_secure_is_no_contest_and_resets_the_loser() -> void:
	var winner: TeamLayout = _team([["w1", "D-C", "", ""]])
	# l1 は基本 D-C で、前のプレスで M-C に固定されている
	var loser: TeamLayout = _team([["l1", "D-C", "M-C", "M-C"], ["l2", "M-L2", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D-C"), _secure(), _retreat())
	assert_int(output.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	assert_object(output.detail).is_null()
	assert_array(_moves(output)).is_equal(["l1:M-C>D-C:RETREAT_RESET"])
	assert_bool(output.pair.defender.players[0].is_fixed()).is_false()


## 奪取側は D-C（ボール）と M-C に1人ずつ（保持型）。喪失側の l1（基本 M-C）は A-L2 に、l2（基本 D-C）は M-L2 に上がっている
func _counter_to_center(loser_choice: TurnChoice) -> JudgeOutput:
	var winner: TeamLayout = _team([["w1", "D-C", "", ""], ["w2", "M-C", "", ""]])
	var loser: TeamLayout = _team([["l1", "M-C", "A-L2", ""], ["l2", "D-C", "M-L2", ""]])
	return TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D-C"), _counter("M-C"), loser_choice)


func test_counter_against_counter_press_compares_the_layout_left_as_it_was() -> void:
	# 喪失側は上がったままで、M-C（喪失側から見ても M-C）に誰もいない
	assert_str(_summary(_counter_to_center(_counter_press()))).is_equal("ADVANCE M-C 1-0 NONE")


func test_counter_against_retreat_compares_after_the_loser_gets_back() -> void:
	# リトリートで l1 は M-C、l2 は D-C（奪取側から見て背後の A-C）へ戻りたいが、1ターンに1マスしか動けない
	# （2026-10-24）。l1 は M-L1、l2 は D-L1 までで、M-C は空いたまま。戻りきれない守備をカウンターが突いて前進する
	var output: JudgeOutput = _counter_to_center(_retreat())
	assert_array(_moves(output)).is_equal(["l1:A-L2>M-L1:RETREAT_RESET", "l2:M-L2>D-L1:RETREAT_RESET"])
	assert_str(_summary(output)).is_equal("ADVANCE M-C 1-0 NONE")


func test_retreat_with_man_marks_the_winner_after_the_breakout() -> void:
	# 奪取側（カウンター型）の w2 は M-L2 から A-L2 へ飛び出す。喪失側のマーカー m1 は、飛び出した後の位置（喪失側から見て D-R2）を
	# 追うが、1ターンでは A-C から1マスの M-R1 まで。A-L2 は空いたまま前進される（2026-10-24。1ターン1マス）
	var winner: TeamLayout = _team([["w1", "D-C", "", ""], ["w2", "M-L2", "", ""]])
	var loser: TeamLayout = _team([["m1", "M-C", "A-C", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(MAN, COUNTER), _area("D-C"), _counter("A-L2"), _retreat())
	assert_array(_moves(output)).is_equal(["w2:M-L2>A-L2:COUNTER_BREAKOUT", "m1:A-C>M-R1:RETREAT_RESET"])
	assert_str(_summary(output)).is_equal("ADVANCE A-L2 1-0 NONE")


# --- カウンター型の飛び出し ---

func test_counter_layout_moves_only_unfixed_wide_players_of_the_counter_style() -> void:
	# w1 は大外で固定、w2 は大外、w3 は中央、w4 は敵陣の大外（前が無い）
	var winner: TeamLayout = _team([
		["w1", "D-L2", "", "D-L2"], ["w2", "M-R2", "", ""], ["w3", "M-C", "", ""], ["w4", "A-L2", "", ""],
	])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, COUNTER))
	assert_str(counter.current_area_of("w1").to_key()).is_equal("D-L2")
	assert_str(counter.current_area_of("w2").to_key()).is_equal("A-R2")
	assert_str(counter.current_area_of("w3").to_key()).is_equal("M-C")
	assert_str(counter.current_area_of("w4").to_key()).is_equal("A-L2")
	# 飛び出しは方式の動きで、固定しない
	assert_bool(counter.players[1].is_fixed()).is_false()


func test_counter_layout_keeps_a_possession_side_as_it_was() -> void:
	var winner: TeamLayout = _team([["w2", "M-R2", "", ""]])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, POSSESSION))
	assert_str(counter.current_area_of("w2").to_key()).is_equal("M-R2")
	assert_object(counter).is_not_same(winner)


func test_counter_layout_starts_from_the_current_area_not_the_base_area() -> void:
	# 基本は M-C だが、直前の配置で M-L2 にいる（大外）ので飛び出す
	var winner: TeamLayout = _team([["w1", "M-C", "M-L2", ""]])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, COUNTER))
	assert_str(counter.current_area_of("w1").to_key()).is_equal("A-L2")


# --- 対称性・不正な入力・不変の性質 ---

func test_swapping_the_winning_team_only_swaps_the_movement_sides() -> void:
	var as_home: JudgeOutput = _je07(_counter("A-L2"), HOME)
	var as_away: JudgeOutput = _je07(_counter("A-L2"), AWAY)
	assert_str(_summary(as_away)).is_equal(_summary(as_home))
	assert_array(_moves(as_away)).is_equal(_moves(as_home))
	assert_dict(as_away.pair.attacker.counts()).is_equal(as_home.pair.attacker.counts())
	assert_dict(as_away.pair.defender.counts()).is_equal(as_home.pair.defender.counts())
	for index: int in range(as_home.movements.size()):
		assert_int(as_home.movements[index].side).is_equal(HOME)
		assert_int(as_away.movements[index].side).is_equal(AWAY)


func test_mismatched_or_incomplete_choices_return_null() -> void:
	var origin: LayoutPair = _je07_origin()
	var winner_styles: TeamStyles = _styles(ZONE, COUNTER)
	var loser_styles: TeamStyles = _styles(ZONE, POSSESSION)
	var ball: PitchArea = _area("D-C")
	# 奪取側と喪失側の手の取り違え
	assert_object(TransitionJudge.judge(origin, winner_styles, loser_styles, ball, _counter_press(), _secure())).is_null()
	# カウンターの運ぶ先が無い
	var no_target := TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.COUNTER)
	assert_object(TransitionJudge.judge(origin, winner_styles, loser_styles, ball, no_target, _retreat())).is_null()
	# ボール位置が無い
	assert_object(TransitionJudge.judge(origin, winner_styles, loser_styles, null, _secure(), _retreat())).is_null()


func test_judge_does_not_modify_its_inputs() -> void:
	var origin: LayoutPair = _je07_origin()
	var winner_before: Dictionary = origin.attacker.counts()
	var loser_before: Dictionary = origin.defender.counts()
	var output: JudgeOutput = TransitionJudge.judge(origin, _styles(ZONE, COUNTER), _styles(MAN, POSSESSION),
			_area("D-C"), _counter("A-L2"), _retreat())
	assert_object(output.pair).is_not_same(origin)
	assert_object(output.pair.attacker).is_not_same(origin.attacker)
	assert_object(output.pair.defender).is_not_same(origin.defender)
	assert_dict(origin.attacker.counts()).is_equal(winner_before)
	assert_dict(origin.defender.counts()).is_equal(loser_before)

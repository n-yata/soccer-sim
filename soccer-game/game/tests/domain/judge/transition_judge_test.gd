## アルゴリズム6: トランジションターンの判定（TransitionJudge）のテスト。
## 判定例 JE-07 は functional-overview.md「判定例」から、それ以外の期待値はアルゴリズム6の規則から手で書いた。
## 直前の配置 origin は奪取側を attacker として持つ。ボール位置 X・運ぶ先・比較エリアは奪取側の視点、
## 各チームの配置と動きはそのチーム自身から見た座標（component-design.md §1.2）。盤面は6列（2026-10-25）。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


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


func _areas_of(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


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


## JE-07 の直前の配置。喪失側（保持型）は攻撃中に、奪取側から見て D2-C（喪失側から見て A1-C）でロストした。
## 喪失側の右サイドバック l1（基本 D2-R2。奪取側から見て A1-L2）は M1-R2 まで上がっている。奪取側（カウンター型）は D2-C に2人、
## M1-C に1人、大外の M1-L2 と M2-L2 に1人ずつ
func _je07_origin(winner_side: GameEnums.TeamSide = HOME) -> LayoutPair:
	var winner: TeamLayout = _team([
		["w1", "D2-C", "", ""], ["w2", "D2-C", "", ""], ["w3", "M1-L2", "", ""], ["w4", "M1-C", "", ""],
		["w5", "M2-L2", "", ""],
	])
	var loser: TeamLayout = _team([["l1", "D2-R2", "M1-R2", ""], ["l2", "A1-C", "", ""], ["l3", "M2-C", "", ""]])
	return LayoutPair.new(winner, loser, winner_side)


func _je07(winner_choice: TurnChoice, winner_side: GameEnums.TeamSide = HOME) -> JudgeOutput:
	# 奪取側から見て、ボールは D2-C
	return TransitionJudge.judge(_je07_origin(winner_side), _styles(ZONE, COUNTER), _styles(ZONE, POSSESSION),
			_area("D2-C"), winner_choice, _counter_press())


# --- 自分で運ぶカウンター（2026-11-05） ---

func test_a_counter_into_an_empty_area_is_carried_by_the_ball_winner() -> void:
	# 奪取側（保持型。飛び出しなし）は M2-C の w1（ボール）と M1-C の w2。前の A1-C に味方はいないので、w1 が運ぶ。
	# 喪失側は奪取側から見て A2-R2 に l1 だけ（喪失側から見て D1-L2）。A1-C は 1対0 で前進
	var origin := LayoutPair.new(_team([["w1", "M2-C", "", ""], ["w2", "M1-C", "", ""]]),
			_team([["l1", "D1-L2", "", ""]]), HOME)
	var output: JudgeOutput = TransitionJudge.judge(origin, _styles(ZONE, POSSESSION), _styles(ZONE, POSSESSION),
			_area("M2-C"), _counter("A1-C"), _counter_press())
	assert_array(_moves(output)).is_equal(["w1:M2-C>A1-C:DRIBBLE"])
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-0 NONE")


func test_a_counter_to_a_teammate_does_not_move_the_ball_winner() -> void:
	# 運ぶ先に味方がいれば、ボールだけが渡る（自分で運ぶ動きは出ない）
	var origin := LayoutPair.new(_team([["w1", "M2-C", "", ""], ["w2", "A1-C", "", ""]]),
			_team([["l1", "D1-L2", "", ""]]), HOME)
	var output: JudgeOutput = TransitionJudge.judge(origin, _styles(ZONE, POSSESSION), _styles(ZONE, POSSESSION),
			_area("M2-C"), _counter("A1-C"), _counter_press())
	assert_array(_moves(output)).is_empty()
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-0 NONE")


# --- カウンターのオフサイド（2026-11-06） ---

## 奪取側（保持型。飛び出しなし）は M1-C の w1（ボール）と A1-C の w2。喪失側の最終ラインは、基本 D2-C から M1-C へ
## 上がっている l1（奪取側から見て M2-C = 3）。A1-C（4）の w2 はラインより前
func _offside_counter(loser_choice: TurnChoice) -> JudgeOutput:
	var origin := LayoutPair.new(_team([["w1", "M1-C", "", ""], ["w2", "A1-C", "", ""]]),
			_team([["l1", "D2-C", "M1-C", ""], ["l2", "M2-L1", "", ""]]), HOME)
	return TransitionJudge.judge(origin, _styles(ZONE, POSSESSION), _styles(ZONE, POSSESSION),
			_area("M1-C"), _counter("A1-C"), loser_choice)


func test_a_counter_pass_to_a_receiver_beyond_the_line_is_offside() -> void:
	# 人数（1対0）に関係なく、受け手のいたエリアで守備側のボールになる
	assert_str(_summary(_offside_counter(_counter_press()))).is_equal("OFFSIDE A1-C 1-0 NONE")


func test_a_counter_pass_stays_offside_when_the_loser_retreats() -> void:
	# リトリートで l1 が基本の D2-C（奪取側から見て A1-C = 4）へ戻ると、その後のラインでは w2 はラインと同じ列になる。
	# ラインは奪った時点の配置で決まり（パスが出た時点）、喪失側が後から下がってもオンサイドにならない
	var output: JudgeOutput = _offside_counter(_retreat())
	assert_array(_moves(output)).contains(["l1:M1-C>D2-C:RETREAT_RESET"])
	assert_int(output.outcome).is_equal(GameEnums.TurnOutcome.OFFSIDE)
	assert_str(output.detail.compare_area.to_key()).is_equal("A1-C")


func test_a_counter_receiver_judged_where_they_were_before_breaking_out() -> void:
	# 奪取側（カウンター型）の w2 は M2-L2 から A1-L2 へ飛び出す。喪失側の最終ラインは M2（l1 の M1-R2）。
	# 飛び出しはパスと同時の走り込みなので、走り込む前の M2-L2（ラインと同じ列）でオンサイド
	var origin := LayoutPair.new(_team([["w1", "D2-C", "", ""], ["w2", "M2-L2", "", ""]]),
			_team([["l1", "M1-R2", "", ""]]), HOME)
	var output: JudgeOutput = TransitionJudge.judge(origin, _styles(ZONE, COUNTER), _styles(ZONE, POSSESSION),
			_area("D2-C"), _counter("A1-L2"), _counter_press())
	assert_str(_summary(output)).is_equal("ADVANCE A1-L2 1-0 NONE")


func test_a_counter_carried_by_the_ball_winner_is_never_offside() -> void:
	# 前に味方がいないので w1 が自分で A2-C へ運ぶ（ドリブル）。喪失側の最終ラインは A1（l1 の D2-C）で、A2 はラインより前だが対象外
	var origin := LayoutPair.new(_team([["w1", "A1-C", "", ""]]), _team([["l1", "D2-C", "", ""]]), HOME)
	var output: JudgeOutput = TransitionJudge.judge(origin, _styles(ZONE, POSSESSION), _styles(ZONE, POSSESSION),
			_area("A1-C"), _counter("A2-C"), _counter_press())
	assert_array(_moves(output)).is_equal(["w1:A1-C>A2-C:DRIBBLE"])
	assert_str(_summary(output)).is_equal("ADVANCE A2-C 1-0 NONE")


# --- 判定例 JE-07 ---

func test_je07_counter_into_the_space_behind_the_possession_side() -> void:
	var output: JudgeOutput = _je07(_counter("A1-L2"))
	# カウンター型の飛び出しで、奪取側の大外（w3・w5）が1列前へ
	assert_array(_moves(output)).is_equal(["w3:M1-L2>M2-L2:COUNTER_BREAKOUT", "w5:M2-L2>A1-L2:COUNTER_BREAKOUT"])
	for movement: Movement in output.movements:
		assert_int(movement.side).is_equal(HOME)
	# 喪失側のその地点（喪失側から見て D2-R2）は、SB が上がったまま 0 人
	assert_str(_summary(output)).is_equal("ADVANCE A1-L2 1-0 NONE")


func test_je07_secure_against_counter_press_fails_to_regain() -> void:
	var output: JudgeOutput = _je07(_secure())
	# X = D2-C と隣（D1-C・D2-L1・D2-R1・M1-C）の合計: 奪取側 3（D2-C 2・M1-C 1）、喪失側 2（A1-C 1・M2-C 1）
	assert_str(_summary(output)).is_equal("REGAIN_FAILED D2-C 3-2 NONE")
	assert_array(_moves(output)).is_empty()


# --- 即時奪回×保持 ---

func test_counter_press_with_more_players_around_the_ball_regains() -> void:
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""]])
	# 喪失側から見て X は A1-C。A1-C に1人、隣の A1-L1 に1人
	var loser: TeamLayout = _team([["l1", "A1-C", "", ""], ["l2", "A1-L1", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D2-C"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN D2-C 1-2 NONE")


func test_counter_press_with_level_numbers_fails_to_regain() -> void:
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""], ["w2", "D2-L1", "", ""]])
	# 喪失側の M2-L1 は X の隣ではない（斜め）
	var loser: TeamLayout = _team([["l1", "A1-C", "", ""], ["l2", "M2-C", "", ""], ["l3", "M2-L1", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D2-C"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN_FAILED D2-C 2-2 NONE")


func test_counter_press_on_the_wing_counts_the_mirrored_side_only() -> void:
	# X は奪取側の視点で D1-L2（盤の隅。隣は D1-L1 と D2-L2 だけ）。喪失側の視点では A2-R2（隣は A2-R1 と A1-R2）
	var winner: TeamLayout = _team([["w1", "D1-L2", "", ""], ["w2", "D1-L1", "", ""]])
	# decoy は喪失側の A2-L2。レーンを鏡写しにし損ねたときだけ数えに入る
	var loser: TeamLayout = _team([
		["l1", "A2-R2", "", ""], ["l2", "A2-R1", "", ""], ["l3", "A1-R2", "", ""], ["decoy", "A2-L2", "", ""],
	])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D1-L2"), _secure(), _counter_press())
	assert_str(_summary(output)).is_equal("REGAIN D1-L2 2-3 NONE")


func test_counter_into_more_defenders_is_lost() -> void:
	# 喪失側から見て M2-C（奪取側から見て M1-C）に2人。カウンターの運ぶ先で上回られて奪い返される
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""], ["w2", "M1-C", "", ""]])
	var loser: TeamLayout = _team([["l1", "M2-C", "", ""], ["l2", "M2-C", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D2-C"), _counter("M1-C"), _counter_press())
	assert_str(_summary(output)).is_equal("LOSS M1-C 1-2 NONE")


func test_counter_targets_come_from_the_layout_after_the_breakout() -> void:
	# アルゴリズム3: カウンターの運ぶ先は「アルゴリズム6の配置」で味方がいるエリア。JE-07 の A1-L2 は飛び出す前は0人
	var origin: LayoutPair = _je07_origin()
	var counter_action := GameEnums.PosTransAction.COUNTER
	var after: MoveOptions = MoveRules.pos_transition_options(
			TransitionJudge.counter_layout(origin.attacker, _styles(ZONE, COUNTER)), _area("D2-C"))
	var before: MoveOptions = MoveRules.pos_transition_options(origin.attacker, _area("D2-C"))
	assert_bool(MoveRules.is_allowed(after, _counter("A1-L2"))).is_true()
	assert_bool(MoveRules.is_allowed(before, _counter("A1-L2"))).is_false()
	assert_int(after.targets(GameEnums.ChoiceFamily.POS_TRANS, counter_action).size()) \
			.is_greater_equal(before.targets(GameEnums.ChoiceFamily.POS_TRANS, counter_action).size())


# --- カウンターの同数（カバー判定） ---

func _level_counter(target_key: String) -> JudgeOutput:
	# 奪取側は保持型（飛び出さない）。運ぶ先に奪取側1人、同じ地点に喪失側1人
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""], ["w2", target_key, "", ""]])
	var loser: TeamLayout = _team([["l1", _area(target_key).mirrored().to_key(), "", ""]])
	return TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D2-C"), _counter(target_key), _counter_press())


func test_level_counter_into_the_last_row_advances_without_a_keeper_cover() -> void:
	# GK はカバーに数えない（2026-10-24）。カウンターに読みは無いので、敵陣ゴール前（背後が盤外）の同数はどのレーンでも前進
	assert_str(_summary(_level_counter("A2-L2"))).is_equal("ADVANCE A2-L2 1-1 NONE")
	assert_str(_summary(_level_counter("A2-C"))).is_equal("ADVANCE A2-C 1-1 NONE")
	assert_str(_summary(_level_counter("A2-R1"))).is_equal("ADVANCE A2-R1 1-1 NONE")
	assert_int(_level_counter("A2-C").detail.read).is_equal(GameEnums.ReadKind.NONE)


# --- リトリート ---

func test_retreat_against_secure_is_no_contest_and_resets_the_loser() -> void:
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""]])
	# l1 は基本 M1-C で、前のプレスで M2-C に固定されている
	var loser: TeamLayout = _team([["l1", "M1-C", "M2-C", "M2-C"], ["l2", "M2-L2", "", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(ZONE, COUNTER), _area("D2-C"), _secure(), _retreat())
	assert_int(output.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	assert_object(output.detail).is_null()
	assert_array(_moves(output)).is_equal(["l1:M2-C>M1-C:RETREAT_RESET"])
	assert_bool(output.pair.defender.players[0].is_fixed()).is_false()


## 奪取側は D2-C（ボール）と M1-C に1人ずつ（保持型）。喪失側の l1（基本 M2-C）は A1-L2 に、l2（基本 M1-C）は M2-L2 に上がっている
func _counter_to_center(loser_choice: TurnChoice) -> JudgeOutput:
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""], ["w2", "M1-C", "", ""]])
	var loser: TeamLayout = _team([["l1", "M2-C", "A1-L2", ""], ["l2", "M1-C", "M2-L2", ""]])
	return TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, POSSESSION),
			_styles(ZONE, COUNTER), _area("D2-C"), _counter("M1-C"), loser_choice)


func test_counter_against_counter_press_compares_the_layout_left_as_it_was() -> void:
	# 喪失側は上がったままで、M2-C（奪取側から見て M1-C）に誰もいない
	assert_str(_summary(_counter_to_center(_counter_press()))).is_equal("ADVANCE M1-C 1-0 NONE")


func test_counter_against_retreat_compares_after_the_loser_gets_back() -> void:
	# リトリートで l1 は M2-C、l2 は M1-C へ戻りたいが、1ターンに1マスしか動けない（2026-10-24）。
	# l1 は M2-L1、l2 は M1-L1 までで、M2-C は空いたまま。戻りきれない守備をカウンターが突いて前進する
	var output: JudgeOutput = _counter_to_center(_retreat())
	assert_array(_moves(output)).is_equal(["l1:A1-L2>M2-L1:RETREAT_RESET", "l2:M2-L2>M1-L1:RETREAT_RESET"])
	assert_str(_summary(output)).is_equal("ADVANCE M1-C 1-0 NONE")


func test_retreat_with_man_marks_the_winner_after_the_breakout() -> void:
	# 奪取側（カウンター型）の w2 は M1-L2 から M2-L2 へ飛び出す。喪失側のマーカー m1 は、飛び出した後の位置（喪失側から見て
	# M1-R2）を追うが、1ターンでは A1-C から1マスの M2-R1 まで。M2-L2 は空いたまま前進される（2026-10-24。1ターン1マス）
	var winner: TeamLayout = _team([["w1", "D2-C", "", ""], ["w2", "M1-L2", "", ""]])
	var loser: TeamLayout = _team([["m1", "M2-C", "A1-C", ""]])
	var output: JudgeOutput = TransitionJudge.judge(LayoutPair.new(winner, loser, HOME), _styles(ZONE, COUNTER),
			_styles(MAN, COUNTER), _area("D2-C"), _counter("M2-L2"), _retreat())
	assert_array(_moves(output)).is_equal(["w2:M1-L2>M2-L2:COUNTER_BREAKOUT", "m1:A1-C>M2-R1:RETREAT_RESET"])
	assert_str(_summary(output)).is_equal("ADVANCE M2-L2 1-0 NONE")


# --- カウンター型の飛び出し ---

func test_counter_layout_moves_only_unfixed_wide_players_of_the_counter_style() -> void:
	# w1 は大外で固定、w2 は大外、w3 は中央、w4 は敵陣ゴール前の大外（前が無い）
	var winner: TeamLayout = _team([
		["w1", "D2-L2", "", "D2-L2"], ["w2", "M1-R2", "", ""], ["w3", "M1-C", "", ""], ["w4", "A2-L2", "", ""],
	])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, COUNTER))
	assert_dict(_areas_of(counter)).is_equal({"w1": "D2-L2", "w2": "M2-R2", "w3": "M1-C", "w4": "A2-L2"})
	# 飛び出しは方式の動きで、固定しない
	assert_bool(counter.players[1].is_fixed()).is_false()


func test_counter_layout_keeps_a_possession_side_as_it_was() -> void:
	var winner: TeamLayout = _team([["w2", "M1-R2", "", ""]])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, POSSESSION))
	assert_str(counter.current_area_of("w2").to_key()).is_equal("M1-R2")
	assert_object(counter).is_not_same(winner)


func test_counter_layout_starts_from_the_current_area_not_the_base_area() -> void:
	# 基本は M1-C だが、直前の配置で M1-L2 にいる（大外）ので飛び出す
	var winner: TeamLayout = _team([["w1", "M1-C", "M1-L2", ""]])
	var counter: TeamLayout = TransitionJudge.counter_layout(winner, _styles(ZONE, COUNTER))
	assert_str(counter.current_area_of("w1").to_key()).is_equal("M2-L2")


# --- 対称性・不正な入力・不変の性質 ---

func test_swapping_the_winning_team_only_swaps_the_movement_sides() -> void:
	var as_home: JudgeOutput = _je07(_counter("A1-L2"), HOME)
	var as_away: JudgeOutput = _je07(_counter("A1-L2"), AWAY)
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
	var ball: PitchArea = _area("D2-C")
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
			_area("D2-C"), _counter("A1-L2"), _retreat())
	assert_object(output.pair).is_not_same(origin)
	assert_object(output.pair.attacker).is_not_same(origin.attacker)
	assert_object(output.pair.defender).is_not_same(origin.defender)
	assert_dict(origin.attacker.counts()).is_equal(winner_before)
	assert_dict(origin.defender.counts()).is_equal(loser_before)

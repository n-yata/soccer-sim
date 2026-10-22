## アルゴリズム5: 攻守ターンの判定（OpenPlayJudge）のテスト。
## 判定例 JE-01〜06 は functional-overview.md「判定例」から、それ以外の期待値はアルゴリズム5の規則から手で書いた。
## ボール位置・運ぶ先・比較エリアは攻撃側から見た座標、守備側の配置と動きは守備側から見た座標（component-design.md §1.2）。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ADVANCE := GameEnums.TurnOutcome.ADVANCE
const STALL := GameEnums.TurnOutcome.STALL
const LOSS := GameEnums.TurnOutcome.LOSS
const GOAL := GameEnums.TurnOutcome.GOAL
const SAVE := GameEnums.TurnOutcome.SAVE

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _styles(defense: GameEnums.DefenseStyle) -> TeamStyles:
	return TeamStyles.new(defense, COUNTER)


func _attack(play: GameEnums.PlayType, target_key: String = "") -> TurnChoice:
	var target: PitchArea = null if target_key == "" else _area(target_key)
	return TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, play, target)


func _defense(action: GameEnums.DefenseAction, target_key: String) -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, action, _area(target_key))


## 判定例の場面: 実際の陣形データから基本配置を作り、アルゴリズム2を適用した配置（どちらもカウンター型）
func _scene(attacker_id: String, defender_id: String, defense: GameEnums.DefenseStyle, ball_key: String,
		attacker_side: GameEnums.TeamSide = HOME) -> LayoutPair:
	var step: LayoutStep = StyleLayoutCalculator.compute(
			BaseLayoutDeriver.derive(_catalog.formation(attacker_id)), _styles(ZONE),
			BaseLayoutDeriver.derive(_catalog.formation(defender_id)), _styles(defense),
			_area(ball_key), attacker_side)
	return step.pair


## 守備側の人数を攻撃側の視点の行で表す（判定例の書き方。"A l2 l1 c r1 r2 / M ... / D ..."）
func _defender_rows(pair: LayoutPair) -> String:
	var rows: Array[String] = []
	for zone: GameEnums.Zone in [GameEnums.Zone.A, GameEnums.Zone.M, GameEnums.Zone.D]:
		var counts: Array[String] = []
		for lane: GameEnums.Lane in [GameEnums.Lane.L2, GameEnums.Lane.L1, GameEnums.Lane.C,
				GameEnums.Lane.R1, GameEnums.Lane.R2]:
			counts.append(str(pair.defender.count_at(PitchArea.new(lane, zone).mirrored())))
		rows.append("%s %s" % [["D", "M", "A"][zone], " ".join(counts)])
	return " / ".join(rows)


## "選手 ID:移動元>移動先:理由"（座標は動いた選手のチーム自身から見た値）
func _moves(output: JudgeOutput) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in output.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## 判定の要約 "結果 比較エリア 攻撃側人数-守備側人数 カバー"
func _summary(output: JudgeOutput) -> String:
	return "%s %s %d-%d %s" % [GameEnums.TurnOutcome.keys()[output.outcome], output.detail.compare_area.to_key(),
			output.detail.attacker_count, output.detail.defender_count,
			GameEnums.CoverKind.keys()[output.detail.cover]]


## spec は [選手 ID, エリア, 固定先（無ければ ""）]。現在エリアは固定先、無ければエリア
func _team(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		var fixed: PitchArea = null if fixed_key == "" else _area(fixed_key)
		var player := PlayerState.new(row[0] as String, _area(row[1] as String), fixed)
		players.append(player)
		current[player.player_id] = fixed if fixed != null else player.base_area
	return TeamLayout.new(players, current)


func _judge(pair: LayoutPair, defense_style: GameEnums.DefenseStyle, ball_key: String,
		attack: TurnChoice, defense: TurnChoice) -> JudgeOutput:
	return OpenPlayJudge.judge(pair, _styles(ZONE), _styles(defense_style), _area(ball_key), attack, defense)


# --- 判定例 ---

func test_je01_pass_into_the_center_left_open_by_the_zone_slide() -> void:
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", ZONE, "M-L1")
	assert_str(_defender_rows(pair)).is_equal("A 1 2 0 1 0 / M 1 2 0 1 0 / D 0 2 0 0 0")
	var output: JudgeOutput = _judge(pair, ZONE, "M-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-C"), _defense(GameEnums.DefenseAction.PRESS, "M-L1"))
	# 同率（+2）は前方優先で、攻撃側の視点の D-L1（守備側の A-R1。守備側の FW）が寄せる
	assert_int(output.movements.size()).is_equal(1)
	assert_str(output.movements[0].from.mirrored().to_key()).is_equal("D-L1")
	assert_str(output.movements[0].to.mirrored().to_key()).is_equal("M-L1")
	assert_str(_summary(output)).is_equal("ADVANCE M-C 1-0 NONE")


func test_je02_man_marking_without_cover_behind_the_wide_pass() -> void:
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", MAN, "M-C")
	assert_str(_defender_rows(pair)).is_equal("A 1 0 3 0 1 / M 0 1 1 1 0 / D 0 0 2 0 0")
	var output: JudgeOutput = _judge(pair, MAN, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-L1"), _defense(GameEnums.DefenseAction.PRESS, "M-C"))
	# 余り +2 の攻撃側の視点の A-C（守備側の D-C）から1人が寄せて固定。付け直した後、A-C は2人
	assert_str(output.movements[0].from.to_key()).is_equal("D-C")
	assert_str(output.movements[0].to.to_key()).is_equal("M-C")
	assert_int(output.movements[0].reason).is_equal(GameEnums.MovementReason.PRESS)
	assert_int(output.pair.defender.count_at(_area("A-C").mirrored())).is_equal(2)
	# 背後の A-L1 は守備0・攻撃0でカバーなし
	assert_str(_summary(output)).is_equal("ADVANCE M-L1 1-1 NONE")


func test_je02_variant_pass_into_the_covered_center_is_lost() -> void:
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", MAN, "M-C")
	var output: JudgeOutput = _judge(pair, MAN, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A-C"), _defense(GameEnums.DefenseAction.PRESS, "M-C"))
	assert_str(_summary(output)).is_equal("LOSS A-C 1-2 NONE")


func test_je03_reading_the_pass_with_cover_stalls_it() -> void:
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", MAN, "M-C")
	var output: JudgeOutput = _judge(pair, MAN, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-L1"), _defense(GameEnums.DefenseAction.COVER, "M-L1"))
	# M-L1 のマーカー（守備側の M-R1）が背後の A-L1（守備側の D-R1）へ下がり、余りの1人が M-L1 の相手につく
	assert_str(output.movements[0].from.to_key()).is_equal("M-R1")
	assert_str(output.movements[0].to.to_key()).is_equal("D-R1")
	assert_int(output.movements[0].reason).is_equal(GameEnums.MovementReason.COVER)
	assert_int(output.pair.defender.count_at(_area("A-C").mirrored())).is_equal(2)
	assert_str(_summary(output)).is_equal("STALL M-L1 1-1 DEFENDER")


func test_je04_level_numbers_in_the_final_third_center_are_covered_by_the_keeper() -> void:
	var pair: LayoutPair = _scene("4-4-2", "4-4-2", ZONE, "M-C")
	assert_str(_defender_rows(pair)).is_equal("A 1 0 2 0 1 / M 1 0 2 0 1 / D 0 0 2 0 0")
	var output: JudgeOutput = _judge(pair, ZONE, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A-C"), _defense(GameEnums.DefenseAction.COVER, "M-R2"))
	# M-R2 の1人（守備側の M-L2）が背後の A-R2（守備側の D-L2）へ
	assert_array(_moves(output)).has_size(1)
	assert_str(output.movements[0].from.to_key()).is_equal("M-L2")
	assert_str(output.movements[0].to.to_key()).is_equal("D-L2")
	assert_str(_summary(output)).is_equal("STALL A-C 2-2 GOALKEEPER")


func test_je05_shot_with_a_numerical_advantage_scores() -> void:
	var pair: LayoutPair = _scene("4-4-2", "3-5-2", ZONE, "A-C")
	assert_str(_defender_rows(pair)).is_equal("A 0 1 1 1 0 / M 1 0 3 0 1 / D 0 0 2 0 0")
	var output: JudgeOutput = _judge(pair, ZONE, "A-C",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "M-C"))
	# 隣接で守備者がいるのは攻撃側の視点の A-C（-1）と D-C（0）。D-C（守備側の A-C）の FW が寄せる
	assert_str(output.movements[0].from.to_key()).is_equal("A-C")
	assert_str(output.movements[0].to.to_key()).is_equal("M-C")
	assert_str(_summary(output)).is_equal("GOAL A-C 2-1 NONE")


func test_je06_shot_read_by_the_defense_is_saved() -> void:
	var pair: LayoutPair = _scene("4-4-2", "3-5-2", ZONE, "A-C")
	var output: JudgeOutput = _judge(pair, ZONE, "A-C",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "A-C"))
	# 隣接の余りはどれも +1。前方優先で M-C（守備側の M-C）の MF が戻る
	assert_str(output.movements[0].from.to_key()).is_equal("M-C")
	assert_str(output.movements[0].to.to_key()).is_equal("D-C")
	assert_str(_summary(output)).is_equal("SAVE A-C 2-2 NONE")


# --- 同数のカバー判定（エッジケース） ---

## 攻撃側は ball と target に1人ずつ、守備側は target（攻撃側の視点）に1人と、遠くでプレスに出る1人
func _level_at(target_key: String, ball_key: String) -> JudgeOutput:
	var attacker: TeamLayout = _team([["a1", ball_key, ""], ["a2", target_key, ""]])
	var defender: TeamLayout = _team([["d1", _area(target_key).mirrored().to_key(), ""], ["far", "A-L2", ""]])
	# 攻撃側の視点の D-R1（守備側の A-L1）へのプレス。隣接の A-L2 の far だけが動く
	return _judge(LayoutPair.new(attacker, defender, HOME), ZONE, ball_key,
			_attack(GameEnums.PlayType.SHORT_PASS, target_key), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))


func test_level_numbers_on_the_final_third_wings_advance_out_of_keeper_reach() -> void:
	assert_str(_summary(_level_at("A-L2", "A-L1"))).is_equal("ADVANCE A-L2 1-1 OUT_OF_GK_REACH")
	assert_str(_summary(_level_at("A-R2", "A-R1"))).is_equal("ADVANCE A-R2 1-1 OUT_OF_GK_REACH")


func test_level_numbers_in_the_final_third_center_or_half_spaces_stall_by_the_keeper() -> void:
	assert_str(_summary(_level_at("A-C", "A-L1"))).is_equal("STALL A-C 1-1 GOALKEEPER")
	assert_str(_summary(_level_at("A-L1", "A-C"))).is_equal("STALL A-L1 1-1 GOALKEEPER")
	assert_str(_summary(_level_at("A-R1", "A-C"))).is_equal("STALL A-R1 1-1 GOALKEEPER")


func test_level_numbers_behind_are_not_a_cover() -> void:
	# 比較エリア M-C は1対1。背後の A-C は攻撃1・守備1で、上回らないのでカバーなし
	var attacker: TeamLayout = _team([["a1", "M-L1", ""], ["a2", "M-C", ""], ["a3", "A-C", ""]])
	var defender: TeamLayout = _team([["d1", "M-C", ""], ["d2", "D-C", ""], ["far", "A-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-C"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_str(_summary(output)).is_equal("ADVANCE M-C 1-1 NONE")


func test_more_defenders_behind_make_a_cover() -> void:
	var attacker: TeamLayout = _team([["a1", "M-L1", ""], ["a2", "M-C", ""], ["a3", "A-C", ""]])
	var defender: TeamLayout = _team([
		["d1", "M-C", ""], ["d2", "D-C", ""], ["d3", "D-C", ""], ["far", "A-L2", ""],
	])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-C"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_str(_summary(output)).is_equal("STALL M-C 1-1 DEFENDER")


func test_shot_with_level_numbers_is_saved_without_a_cover_check() -> void:
	# シュートは同数で阻止（カバー判定をしない）
	var attacker: TeamLayout = _team([["a1", "A-L1", ""]])
	var defender: TeamLayout = _team([["d1", "D-R1", ""], ["far", "A-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "A-L1",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_str(_summary(output)).is_equal("SAVE A-L1 1-1 NONE")


# --- ドリブル ---

func test_dribble_keeps_the_player_who_carried_the_ball_here() -> void:
	# ボールの M-C に、前のドリブルで M-C に固定された a1（基本は D-C）と、固定されていない a2。a1 が運び続ける
	var attacker: TeamLayout = _team([["a2", "M-C", ""], ["a1", "D-C", "M-C"]])
	var defender: TeamLayout = _team([["far", "A-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A-C"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_array(_moves(output)).is_equal(["far:A-L2>A-L1:PRESS", "a1:M-C>A-C:DRIBBLE"])
	assert_int(output.movements[1].side).is_equal(HOME)
	# 固定先が A-C に更新され、a2 は固定されないまま M-C に残る
	assert_str(output.pair.attacker.players[1].fixed_area.to_key()).is_equal("A-C")
	assert_bool(output.pair.attacker.players[0].is_fixed()).is_false()
	assert_str(output.pair.attacker.current_area_of("a2").to_key()).is_equal("M-C")
	# A-C は攻撃1・守備0
	assert_str(_summary(output)).is_equal("ADVANCE A-C 1-0 NONE")


func test_dribble_among_unfixed_players_takes_the_first_in_layout_order() -> void:
	var attacker: TeamLayout = _team([["a1", "M-C", ""], ["a2", "M-C", ""]])
	var defender: TeamLayout = _team([["far", "A-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M-L1"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_array(_moves(output)).is_equal(["far:A-L2>A-L1:PRESS", "a1:M-C>M-L1:DRIBBLE"])
	assert_str(output.pair.attacker.players[0].fixed_area.to_key()).is_equal("M-L1")
	assert_bool(output.pair.attacker.players[1].is_fixed()).is_false()


func test_man_marker_follows_the_dribbler() -> void:
	# a1 は守備側から見て M-C。マーカー m1 がつく。far は基本エリアが A なのでマーカーにならない
	var attacker: TeamLayout = _team([["a1", "M-C", ""]])
	var defender: TeamLayout = _team([["m1", "M-L1", ""], ["far", "A-L2", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE), defender, _styles(MAN),
			_area("M-C"), HOME)
	assert_str(start.pair.defender.current_area_of("m1").to_key()).is_equal("M-C")
	var output: JudgeOutput = _judge(start.pair, MAN, "M-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A-C"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_array(_moves(output)).is_equal(["far:A-L2>A-L1:PRESS", "a1:M-C>A-C:DRIBBLE", "m1:M-C>D-C:MARK"])
	assert_str(_summary(output)).is_equal("STALL A-C 1-1 GOALKEEPER")


func test_dribble_without_a_player_on_the_ball_moves_nobody() -> void:
	var attacker: TeamLayout = _team([["a1", "D-C", ""]])
	var defender: TeamLayout = _team([["far", "A-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A-C"), _defense(GameEnums.DefenseAction.PRESS, "D-R1"))
	assert_array(_moves(output)).is_equal(["far:A-L2>A-L1:PRESS"])
	assert_str(_summary(output)).is_equal("STALL A-C 0-0 GOALKEEPER")


# --- 対称性・不正な入力・不変の性質 ---

func test_swapping_the_attacking_team_only_swaps_the_movement_sides() -> void:
	var as_home: JudgeOutput = _judge(_scene("4-3-3", "4-4-2", MAN, "M-C", HOME), MAN, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-L1"), _defense(GameEnums.DefenseAction.COVER, "M-L1"))
	var as_away: JudgeOutput = _judge(_scene("4-3-3", "4-4-2", MAN, "M-C", AWAY), MAN, "M-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M-L1"), _defense(GameEnums.DefenseAction.COVER, "M-L1"))
	assert_str(_summary(as_away)).is_equal(_summary(as_home))
	assert_array(_moves(as_away)).is_equal(_moves(as_home))
	assert_dict(as_away.pair.defender.counts()).is_equal(as_home.pair.defender.counts())
	assert_dict(as_away.pair.attacker.counts()).is_equal(as_home.pair.attacker.counts())
	assert_int(as_away.pair.attacker_side).is_equal(AWAY)
	for index: int in range(as_home.movements.size()):
		assert_int(as_home.movements[index].side).is_equal(AWAY)
		assert_int(as_away.movements[index].side).is_equal(HOME)


func test_unavailable_or_mismatched_choices_return_null() -> void:
	var pair: LayoutPair = _scene("4-4-2", "4-4-2", ZONE, "M-C")
	var pass_choice: TurnChoice = _attack(GameEnums.PlayType.SHORT_PASS, "A-C")
	var press_choice: TurnChoice = _defense(GameEnums.DefenseAction.PRESS, "M-C")
	# 守備側の D ゾーン（攻撃側の視点の A-C）へのカバーは、背後が無く適用できない
	assert_object(_judge(pair, ZONE, "M-C", pass_choice, _defense(GameEnums.DefenseAction.COVER, "A-C"))).is_null()
	# 手の種類の取り違え
	assert_object(_judge(pair, ZONE, "M-C", press_choice, press_choice)).is_null()
	assert_object(_judge(pair, ZONE, "M-C", pass_choice, pass_choice)).is_null()
	# 運ぶ先が要る手で運ぶ先が無い
	assert_object(_judge(pair, ZONE, "M-C", _attack(GameEnums.PlayType.SHORT_PASS), press_choice)).is_null()
	# ボール位置が無い
	assert_object(OpenPlayJudge.judge(pair, _styles(ZONE), _styles(ZONE), null, pass_choice, press_choice)).is_null()


func test_judge_does_not_modify_its_inputs() -> void:
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", MAN, "M-C")
	var before_defender: Dictionary = pair.defender.counts()
	var before_attacker: Dictionary = pair.attacker.counts()
	var output: JudgeOutput = _judge(pair, MAN, "M-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M-L1"), _defense(GameEnums.DefenseAction.COVER, "M-L1"))
	assert_object(output.pair).is_not_same(pair)
	assert_object(output.pair.attacker).is_not_same(pair.attacker)
	assert_object(output.pair.defender).is_not_same(pair.defender)
	assert_dict(pair.defender.counts()).is_equal(before_defender)
	assert_dict(pair.attacker.counts()).is_equal(before_attacker)
	for player: PlayerState in pair.attacker.players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()
	for player: PlayerState in pair.defender.players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()


func test_apply_defense_gives_the_defense_part_of_the_judgement() -> void:
	# マンツーマン。プレスで寄せた後のマークの付け直しまでが守備の手の動き。シュートは選手を動かさないので、
	# 判定の動きは守備の手の動きと同じになる
	var pair: LayoutPair = _scene("4-3-3", "4-4-2", MAN, "M-C")
	var press_choice: TurnChoice = _defense(GameEnums.DefenseAction.PRESS, "M-L1")
	var step: LayoutStep = OpenPlayJudge.apply_defense(pair, _styles(MAN), press_choice)
	var output: JudgeOutput = _judge(pair, MAN, "M-C", _attack(GameEnums.PlayType.SHOT), press_choice)
	assert_int(step.movements.size()).is_equal(output.movements.size())
	assert_int(step.movements[0].reason).is_equal(GameEnums.MovementReason.PRESS)
	for index: int in range(step.movements.size()):
		assert_str(step.movements[index].player_id).is_equal(output.movements[index].player_id)
		assert_str(step.movements[index].to.to_key()).is_equal(output.movements[index].to.to_key())
		assert_int(step.movements[index].reason).is_equal(output.movements[index].reason)
	assert_dict(step.pair.defender.counts()).is_equal(output.pair.defender.counts())


func test_apply_defense_returns_null_for_an_inapplicable_move() -> void:
	var pair: LayoutPair = _scene("4-4-2", "4-4-2", ZONE, "M-C")
	assert_object(OpenPlayJudge.apply_defense(pair, _styles(ZONE), _defense(GameEnums.DefenseAction.COVER, "A-C"))).is_null()


func test_apply_defense_of_a_zone_press_moves_the_neighbor_in() -> void:
	# 手で書いた場面: 攻撃側 h1 が M-C、守備側（ゾーン）の a1 が守備側から見て D-C。M-C へのプレスで a1 が寄せる
	var h1 := PlayerState.new("h1", _area("M-C"), null)
	var a1 := PlayerState.new("a1", _area("D-C"), null)
	var pair := LayoutPair.new(TeamLayout.new([h1], {"h1": _area("M-C")}), TeamLayout.new([a1], {"a1": _area("D-C")}), HOME)
	var step: LayoutStep = OpenPlayJudge.apply_defense(pair, _styles(ZONE), _defense(GameEnums.DefenseAction.PRESS, "M-C"))
	assert_int(step.movements.size()).is_equal(1)
	assert_str("%s %s>%s" % [step.movements[0].player_id, step.movements[0].from.to_key(), step.movements[0].to.to_key()]) \
			.is_equal("a1 D-C>M-C")
	assert_int(step.movements[0].reason).is_equal(GameEnums.MovementReason.PRESS)
	assert_str(step.pair.defender.current_area_of("a1").to_key()).is_equal("M-C")

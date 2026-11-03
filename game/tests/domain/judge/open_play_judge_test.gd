## アルゴリズム5: 攻守ターンの判定（OpenPlayJudge）のテスト。
## 判定例 JE-01〜06・JE-08〜10 は functional-overview.md「判定例」から、それ以外の期待値はアルゴリズム5の規則から手で書いた。
## ボール位置・運ぶ先・比較エリアは攻撃側から見た座標、守備側の配置と動きは守備側から見た座標（component-design.md §1.2）。
## 盤面は6列（2026-10-25）。判定例は陣形の名前を使わず、場面の配置で示す。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


func _styles(defense: GameEnums.DefenseStyle) -> TeamStyles:
	return TeamStyles.new(defense, COUNTER)


func _attack(play: GameEnums.PlayType, target_key: String = "") -> TurnChoice:
	var target: PitchArea = null if target_key == "" else _area(target_key)
	return TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, play, target)


func _defense(action: GameEnums.DefenseAction, target_key: String) -> TurnChoice:
	return TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, action, _area(target_key))


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


## 判定例の場面: attacker_spec・defender_spec の配置（基本エリアに立つ）に、同じボール位置で方式の動きが落ち着くまで
## ターン開始（アルゴリズム2）を繰り返した配置。攻撃側はカウンター型・ゾーン
func _scene(attacker_spec: Array, defender_spec: Array, defense: GameEnums.DefenseStyle, ball_key: String,
		attacker_side: GameEnums.TeamSide = HOME) -> LayoutPair:
	var pair := LayoutPair.new(_team(attacker_spec), _team(defender_spec), attacker_side)
	for _turn: int in range(6):
		var step: LayoutStep = StyleLayoutCalculator.compute(pair.attacker, _styles(ZONE), pair.defender,
				_styles(defense), _area(ball_key), attacker_side)
		pair = step.pair
		if step.movements.is_empty():
			return pair
	fail("方式の動きが6ターンで落ち着かない")
	return pair


func _areas_of(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


## "選手 ID:移動元>移動先:理由"（座標は動いた選手のチーム自身から見た値）
func _moves(output: JudgeOutput) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in output.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## 判定の要約 "結果 比較エリア 攻撃側人数-守備側人数 カバー"。守備の読みが外れでなければ、末尾に段階（" EXACT"・" NEAR"）
func _summary(output: JudgeOutput) -> String:
	return "%s %s %d-%d %s%s" % [GameEnums.TurnOutcome.keys()[output.outcome], output.detail.compare_area.to_key(),
			output.detail.attacker_count, output.detail.defender_count,
			GameEnums.CoverKind.keys()[output.detail.cover],
			"" if output.detail.read == GameEnums.ReadKind.NONE else " " + GameEnums.ReadKind.keys()[output.detail.read]]


func _judge(pair: LayoutPair, defense_style: GameEnums.DefenseStyle, ball_key: String,
		attack: TurnChoice, defense: TurnChoice) -> JudgeOutput:
	return OpenPlayJudge.judge(pair, _styles(ZONE), _styles(defense_style), _area(ball_key), attack, defense)


# --- 判定例の場面 ---

## JE-01: 攻撃側はボールの M2-L1 に a1、中央の M2-C に a2。守備側（ゾーン。守備側の視点）は中央 M1-C に d1、
## 右の大外 M1-R2 に d2、2列目の中央 D2-C に d3
func _je01() -> LayoutPair:
	return _scene([["a1", "M2-L1", ""], ["a2", "M2-C", ""]],
			[["d1", "M1-C", ""], ["d2", "M1-R2", ""], ["d3", "D2-C", ""]], ZONE, "M2-L1")


## JE-02・JE-03: 攻撃側はボールの M2-C に a1、左のハーフスペース M2-L1 に a2、敵陣の A1-C に a3。
## 守備側（マンツーマン）は M1-C に m1、M1-R1 に m2、D2-C に m3、D2-L1 に m4、D2-R1 に m5
func _je02(attacker_side: GameEnums.TeamSide = HOME) -> LayoutPair:
	return _scene([["a1", "M2-C", ""], ["a2", "M2-L1", ""], ["a3", "A1-C", ""]],
			[["m1", "M1-C", ""], ["m2", "M1-R1", ""], ["m3", "D2-C", ""], ["m4", "D2-L1", ""], ["m5", "D2-R1", ""]],
			MAN, "M2-C", attacker_side)


## JE-04: 攻撃側はボールの A1-C に a1、敵陣ゴール前の A2-C に a2・a3。守備側（ゾーン）はゴール前の D1-C に d1・d2、
## 左の大外 D2-L2 に d3
func _je04() -> LayoutPair:
	return _scene([["a1", "A1-C", ""], ["a2", "A2-C", ""], ["a3", "A2-C", ""]],
			[["d1", "D1-C", ""], ["d2", "D1-C", ""], ["d3", "D2-L2", ""]], ZONE, "A1-C")


## JE-05・JE-06: 攻撃側はボールの A1-C に a1・a2。守備側（ゾーン）は D2-C（攻撃側の視点で A1-C）に d1、
## ゴール前の D1-C に d2、その前の M1-C に d3
func _je05() -> LayoutPair:
	return _scene([["a1", "A1-C", ""], ["a2", "A1-C", ""]],
			[["d1", "D2-C", ""], ["d2", "D1-C", ""], ["d3", "M1-C", ""]], ZONE, "A1-C")


# --- 判定例 ---

func test_je01_pass_into_the_center_left_open_by_the_zone_slide() -> void:
	var pair: LayoutPair = _je01()
	# ボールは守備側から見て右のハーフスペース（M1-R1）。全員が右へ1レーンずれ（大外の d2 はそのまま）、中央の M1-C が空く
	assert_dict(_areas_of(pair.defender)).is_equal({"d1": "M1-R1", "d2": "M1-R2", "d3": "D2-R1"})
	var output: JudgeOutput = _judge(pair, ZONE, "M2-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"), _defense(GameEnums.DefenseAction.PRESS, "M2-L1"))
	# ボールのエリア（守備側の M1-R1）へのプレス。横の d2（+1）と背後の d3（+1）が同率で、横を先に（d2 が寄せる）
	assert_array(_moves(output)).is_equal(["d2:M1-R2>M1-R1:PRESS"])
	# 寄せた M2-L1 はボールのエリア（持っている選手への寄せ）なので、隣の M2-C への読みにはならない
	assert_str(_summary(output)).is_equal("ADVANCE M2-C 1-0 NONE")


func test_je02_man_marking_without_cover_behind_the_wide_pass() -> void:
	var pair: LayoutPair = _je02()
	# マーク: m1 が a1（M1-C）、m2 が a2（M1-R1）、m3 が a3（D2-C）。余りの m4・m5 は D2-C
	assert_dict(_areas_of(pair.defender)).is_equal(
			{"m1": "M1-C", "m2": "M1-R1", "m3": "D2-C", "m4": "D2-C", "m5": "D2-C"})
	var output: JudgeOutput = _judge(pair, MAN, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-L1"), _defense(GameEnums.DefenseAction.PRESS, "M2-C"))
	# 余り +2 の背後 D2-C（守備側の視点）から m3 が寄せて固定。付け直しでは誰も動かず、D2-C は2人
	assert_array(_moves(output)).is_equal(["m3:D2-C>M1-C:PRESS"])
	assert_int(output.pair.defender.count_at(_area("D2-C"))).is_equal(2)
	# 背後の A1-L1 は守備0・攻撃0でカバーなし。M2-C へのプレスはボールのエリアへの寄せなので、隣の読みにも数えない
	assert_str(_summary(output)).is_equal("ADVANCE M2-L1 1-1 NONE")


func test_je02_variant_pass_into_the_covered_center_is_lost() -> void:
	var output: JudgeOutput = _judge(_je02(), MAN, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "M2-C"))
	assert_str(_summary(output)).is_equal("LOSS A1-C 1-2 NONE")


func test_je03_reading_the_pass_wins_the_ball_at_level_numbers() -> void:
	var output: JudgeOutput = _judge(_je02(), MAN, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-L1"), _defense(GameEnums.DefenseAction.COVER, "M2-L1"))
	# M2-L1 のマーカー m2（守備側の M1-R1）が背後の D2-R1 へ下がって固定。付け直しで、余りの m4 が M1-R1 の相手につく
	assert_array(_moves(output)).is_equal(["m2:M1-R1>D2-R1:COVER", "m4:D2-C>M1-R1:MARK"])
	# 制限したエリアにパスが来た（読みを当てた）。同数なので、攻撃側は2人以上多くないと通らずロスト
	assert_str(_summary(output)).is_equal("LOSS M2-L1 1-1 DEFENDER EXACT")


func test_je04_level_numbers_in_the_last_row_center_advance_without_a_keeper_cover() -> void:
	var pair: LayoutPair = _je04()
	var output: JudgeOutput = _judge(pair, ZONE, "A1-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A2-C"), _defense(GameEnums.DefenseAction.COVER, "A1-R2"))
	# A1-R2 の1人（守備側の D2-L2）が背後の D1-L2 へ。A2-C には影響しない
	assert_array(_moves(output)).is_equal(["d3:D2-L2>D1-L2:COVER"])
	# 背後は盤外で、GK はカバーに数えない（2026-10-24）。読まれていない同数で前進
	assert_str(_summary(output)).is_equal("ADVANCE A2-C 2-2 NONE")


func test_je05_shot_after_a_misread_press_scores() -> void:
	var output: JudgeOutput = _judge(_je05(), ZONE, "A1-C",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "M2-C"))
	# 読み違いのプレス（攻撃側の視点の M2-C = 守備側の M1-C）。M1-C の隣で守備者がいるのは背後の D2-C の d1 だけ（余り −1）で、
	# d1 がシュートのエリアを離れる
	assert_array(_moves(output)).is_equal(["d1:D2-C>M1-C:PRESS"])
	assert_str(_summary(output)).is_equal("GOAL A1-C 2-0 NONE")


func test_je06_shot_read_by_the_defense_is_saved() -> void:
	# シュートを読むのは「シュートコースを塞ぐ」（2026-11-03）。動きはボールのエリアへのプレスと同じ
	var output: JudgeOutput = _judge(_je05(), ZONE, "A1-C",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.BLOCK_SHOT, "A1-C"))
	# 隣の余りは前方 M1-C（d3）と背後 D1-C（d2）がどちらも +1。前方優先で d3 が戻る
	assert_array(_moves(output)).is_equal(["d3:M1-C>D2-C:PRESS"])
	assert_str(_summary(output)).is_equal("SAVE A1-C 2-2 NONE EXACT")


func test_shot_is_not_read_by_a_plain_press_or_closing_down_the_ball() -> void:
	# 同じボールのエリアへの寄せでも、パスコースを切る（PRESS）・ボールに寄せる（CLOSE_DOWN）はシュートを読んだことにならず、
	# 同数のシュートは得点（2026-11-03）
	for action: int in [GameEnums.DefenseAction.PRESS, GameEnums.DefenseAction.CLOSE_DOWN]:
		var output: JudgeOutput = _judge(_je05(), ZONE, "A1-C",
				_attack(GameEnums.PlayType.SHOT), _defense(action as GameEnums.DefenseAction, "A1-C"))
		assert_str(_summary(output)).override_failure_message(str(action)).is_equal("GOAL A1-C 2-2 NONE")


# --- スルーパス（2026-10-25。読まれたら人数に関係なく奪われ、読まれなければ人数に関係なく通る） ---

## JE-09: 攻撃側はボールの M2-C に a1、A1-L1 に a2。守備側（ゾーン）は運ぶ先 A1-C（守備側の視点で D2-C）に d1・d2、
## 遠くの A2-L2（攻撃側の視点で D1-R2）に far
func _je09() -> LayoutPair:
	return LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-L1", ""]]),
			_team([["d1", "D2-C", ""], ["d2", "D2-C", ""], ["far", "A2-L2", ""]]), HOME)


func test_je09_through_pass_unread_gets_through_even_against_more_defenders() -> void:
	var output: JudgeOutput = _judge(_je09(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	# 守備は遠くへ寄せた（外れ）。a2 が A1-C へ走り込んで固定される。1対2 でも読まれていないので前進
	assert_array(_moves(output)).is_equal(["far:A2-L2>A2-L1:PRESS", "a2:A1-L1>A1-C:THROUGH_RUN"])
	assert_str(output.pair.attacker.players[1].fixed_area.to_key()).is_equal("A1-C")
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-2 NONE")


func test_through_pass_read_next_door_still_gets_through() -> void:
	# 隣の A1-R1（守備側の D2-L1）へプレス。D2-C の d1 が寄せて、運ぶ先は1対1。ほかの手なら隣の読みで奪われるが、スルーパスは前進
	var output: JudgeOutput = _judge(_je09(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "A1-R1"))
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-1 NONE NEAR")


func test_through_pass_read_exactly_is_lost_even_with_more_attackers() -> void:
	# 運ぶ先 A1-C に a2・a3 の2人（a2 が受け手。もういるので動かない）。守備は A1-C を読み、隣の D2-L1 の d1 が寄せて1人。
	# 2対1 でも、読まれたのでロスト
	var pair := LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-C", ""], ["a3", "A1-C", ""]]),
			_team([["d1", "D2-L1", ""]]), HOME)
	var output: JudgeOutput = _judge(pair, ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "A1-C"))
	assert_array(_moves(output)).is_equal(["d1:D2-L1>D2-C:PRESS"])
	assert_str(output.pair.attacker.players[1].fixed_area.to_key()).is_equal("A1-C")
	assert_str(_summary(output)).is_equal("LOSS A1-C 2-1 NONE EXACT")


func test_through_pass_runner_is_the_nearest_teammate_outside_the_ball_area() -> void:
	var target: PitchArea = _area("A1-C")
	var ball: PitchArea = _area("M2-C")
	# 運ぶ先にいる a3（0マス）が、1マスの a2 より先。ボールのエリアの a1 は、運ぶ先から1マスでも受け手にならない
	var nearest: TeamLayout = _team([["a1", "M2-C", ""], ["a2", "A2-L1", ""], ["a3", "A1-C", ""]])
	assert_str(OpenPlayJudge.through_pass_runner(nearest, ball, target).player_id).is_equal("a3")
	# 同じ近さなら配置の選手の順で先
	for order: Array in [["a2", "a3"], ["a3", "a2"]]:
		var areas: Dictionary = {"a2": "A1-L1", "a3": "A1-R1"}
		var layout: TeamLayout = _team([["a1", "M2-C", ""], [order[0], areas[order[0]], ""], [order[1], areas[order[1]], ""]])
		assert_str(OpenPlayJudge.through_pass_runner(layout, ball, target).player_id).override_failure_message(str(order)) \
				.is_equal(order[0] as String)
	# 1マス以内にボールのエリアの選手しかいなければ、受け手はいない
	assert_object(OpenPlayJudge.through_pass_runner(_team([["a1", "M2-C", ""], ["a2", "M2-C", ""]]), ball, target)).is_null()


func test_through_pass_runner_followed_in_by_the_man_marker_is_lost() -> void:
	# 守備側はマンツーマン。m1 は a2（A1-L1 = 守備側の D2-R1）につく。a2 が A1-C へ走り込むと、m1 も D2-C へついていく。
	# 運ぶ先へ守備が入ってきたので、読まれていなくても奪われる（2026-10-28。シャビの判断）
	var pair: LayoutPair = _scene([["a1", "M2-C", ""], ["a2", "A1-L1", ""]],
			[["m1", "D2-R1", ""], ["m2", "M1-C", ""], ["far", "A2-L2", ""]], MAN, "M2-C")
	var output: JudgeOutput = _judge(pair, MAN, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_array(_moves(output)).contains(["a2:A1-L1>A1-C:THROUGH_RUN", "m1:D2-R1>D2-C:MARK"])
	assert_str(_summary(output)).is_equal("LOSS A1-C 1-1 NONE")


func test_through_pass_into_an_area_a_cover_drops_into_is_lost() -> void:
	# ボールのエリア M2-C（守備側の M1-C）のカバーで、d1 が背後の D2-C（攻撃側の視点で運ぶ先の A1-C）へ下がる。
	# 制限したのはボールのエリアで読みは外れだが、運ぶ先へ守備が入ってきたので奪われる（2026-10-28）。
	# d1 が下がるのでラインも A1 になり、A1-L1 の受け手はオフサイドではない
	var pair := LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-L1", ""]]), _team([["d1", "M1-C", ""]]), HOME)
	var output: JudgeOutput = _judge(pair, ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.COVER, "M2-C"))
	assert_array(_moves(output)).is_equal(["d1:M1-C>D2-C:COVER", "a2:A1-L1>A1-C:THROUGH_RUN"])
	assert_str(_summary(output)).is_equal("LOSS A1-C 1-1 NONE")
	# 守備が運ぶ先へ入らなければ（遠くへのプレス）、同じ場面でも通る
	var far := LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-L1", ""]]),
			_team([["d1", "D2-L2", ""], ["far", "A2-L2", ""]]), HOME)
	var through: JudgeOutput = _judge(far, ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(through)).is_equal("ADVANCE A1-C 1-0 NONE")


# --- オフサイド（2026-10-25。守備の手を適用した後のラインで、人数・読みより先に判定する） ---

## JE-10: 攻撃側はボールの M2-C に a1、A1-C に a2。守備側（ゾーン）は最終ラインの d1 が D2-L1（攻撃側の視点で A1-R1）、
## d2 が M1-C（M2-C）、遠くの A2-L2（D1-R2）に far。ラインは A1（4）で、A1-C の a2 はラインと同じ列でオンサイド
func _je10() -> LayoutPair:
	return LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-C", ""]]),
			_team([["d1", "D2-L1", ""], ["d2", "M1-C", ""], ["far", "A2-L2", ""]]), HOME)


func test_je10_the_last_defender_stepping_up_catches_the_receiver_offside() -> void:
	# M2-R1（守備側の M1-L1）へのプレスで、余りの大きい最終ラインの d1 が前へ出る。ラインが M2（3）へ上がり、
	# A1-C の a2 はラインより前でオフサイド。人数（1対0）に関係なく、守備側のボールになる
	var output: JudgeOutput = _judge(_je10(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "M2-R1"))
	assert_array(_moves(output)).is_equal(["d1:D2-L1>M1-L1:PRESS"])
	assert_str(_summary(output)).is_equal("OFFSIDE A1-C 1-0 NONE")


func test_je10_without_the_step_up_the_level_receiver_is_onside() -> void:
	# 遠くへのプレス（外れ）ではラインが A1 のまま。a2 はラインと同じ列でオンサイドで、ふつうに人数で判定する
	var output: JudgeOutput = _judge(_je10(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-0 NONE")


func test_a_cover_dropping_behind_the_line_keeps_the_receiver_onside() -> void:
	# 守備側の最終ラインは M1（攻撃側の視点で M2 = 3）で、A1-C の a2 はオフサイドの位置。
	# M2-L1（守備側の M1-R1）のカバーで d2 が背後の D2-R1（A1-L1 = 4）へ下がると、ラインが下がって a2 はオンサイド
	var pair := LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A1-C", ""]]),
			_team([["d1", "M1-C", ""], ["d2", "M1-R1", ""], ["far", "A2-L2", ""]]), HOME)
	var covered: JudgeOutput = _judge(pair, ZONE, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"), _defense(GameEnums.DefenseAction.COVER, "M2-L1"))
	assert_array(_moves(covered)).is_equal(["d2:M1-R1>D2-R1:COVER"])
	assert_str(_summary(covered)).is_equal("ADVANCE A1-C 1-0 NONE")
	var pressed: JudgeOutput = _judge(pair, ZONE, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(pressed)).is_equal("OFFSIDE A1-C 1-0 NONE")


func test_an_offside_through_pass_stops_play_before_the_run_and_the_read() -> void:
	# 受け手 a2 は A2-L1（5）から A1-C へ走り込むが、ラインは A1（守備側の D2-C = 4）で、走り込む前の位置でオフサイド。
	# 守備がぴったり読んでいても（ロストではなく）オフサイド。プレーが止まるので、a2 は走り込まない
	var pair := LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "A2-L1", ""]]),
			_team([["d1", "D2-C", ""], ["d2", "D2-L1", ""]]), HOME)
	var output: JudgeOutput = _judge(pair, ZONE, "M2-C",
			_attack(GameEnums.PlayType.THROUGH_PASS, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "A1-C"))
	assert_array(_moves(output)).is_equal(["d2:D2-L1>D2-C:PRESS"])
	assert_str(_summary(output)).is_equal("OFFSIDE A2-L1 1-0 NONE")


# --- 同数のカバー判定（エッジケース） ---

## 攻撃側は ball と target に1人ずつ、守備側は target（攻撃側の視点）に1人と、遠くでプレスに出る1人
func _level_at(target_key: String, ball_key: String) -> JudgeOutput:
	var attacker: TeamLayout = _team([["a1", ball_key, ""], ["a2", target_key, ""]])
	var defender: TeamLayout = _team([["d1", _area(target_key).mirrored().to_key(), ""], ["far", "A2-L2", ""]])
	# 攻撃側の視点の D1-R1（守備側の A2-L1）へのプレス。隣の A2-L2 の far だけが動く
	return _judge(LayoutPair.new(attacker, defender, HOME), ZONE, ball_key,
			_attack(GameEnums.PlayType.SHORT_PASS, target_key), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))


func test_level_numbers_in_the_last_row_advance_on_every_lane() -> void:
	# 敵陣ゴール前の背後は盤外。GK はカバーに数えないので、読まれていない同数はどのレーンでも前進
	assert_str(_summary(_level_at("A2-L2", "A2-L1"))).is_equal("ADVANCE A2-L2 1-1 NONE")
	assert_str(_summary(_level_at("A2-R2", "A2-R1"))).is_equal("ADVANCE A2-R2 1-1 NONE")
	assert_str(_summary(_level_at("A2-C", "A2-L1"))).is_equal("ADVANCE A2-C 1-1 NONE")
	assert_str(_summary(_level_at("A2-L1", "A2-C"))).is_equal("ADVANCE A2-L1 1-1 NONE")
	assert_str(_summary(_level_at("A2-R1", "A2-C"))).is_equal("ADVANCE A2-R1 1-1 NONE")


func test_level_numbers_behind_are_not_a_cover() -> void:
	# 比較エリア M2-C は1対1。背後の A1-C は攻撃1・守備1で、上回らないのでカバーなし
	var attacker: TeamLayout = _team([["a1", "M2-L1", ""], ["a2", "M2-C", ""], ["a3", "A1-C", ""]])
	var defender: TeamLayout = _team([["d1", "M1-C", ""], ["d2", "D2-C", ""], ["far", "A2-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M2-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(output)).is_equal("ADVANCE M2-C 1-1 NONE")


func test_more_defenders_behind_make_a_cover() -> void:
	var attacker: TeamLayout = _team([["a1", "M2-L1", ""], ["a2", "M2-C", ""], ["a3", "A1-C", ""]])
	var defender: TeamLayout = _team([
		["d1", "M1-C", ""], ["d2", "D2-C", ""], ["d3", "D2-C", ""], ["far", "A2-L2", ""],
	])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M2-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(output)).is_equal("STALL M2-C 1-1 DEFENDER")


func test_shot_with_level_numbers_scores_when_the_defense_did_not_read_it() -> void:
	# 守備はボールのエリア（A2-L1）ではなく D1-R1 を制限した。同数のシュートは、読まれていなければ得点（カバー判定はしない）
	var attacker: TeamLayout = _team([["a1", "A2-L1", ""]])
	var defender: TeamLayout = _team([["d1", "D1-R1", ""], ["far", "A2-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "A2-L1",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_str(_summary(output)).is_equal("GOAL A2-L1 1-1 NONE")


# --- ドリブル ---

func test_dribble_keeps_the_player_who_carried_the_ball_here() -> void:
	# ボールの M2-C に、前のドリブルで M2-C に固定された a1（基本は M1-C）と、固定されていない a2。a1 が運び続ける
	var attacker: TeamLayout = _team([["a2", "M2-C", ""], ["a1", "M1-C", "M2-C"]])
	var defender: TeamLayout = _team([["far", "A2-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_array(_moves(output)).is_equal(["far:A2-L2>A2-L1:PRESS", "a1:M2-C>A1-C:DRIBBLE"])
	assert_int(output.movements[1].side).is_equal(HOME)
	# 固定先が A1-C に更新され、a2 は固定されないまま M2-C に残る
	assert_str(output.pair.attacker.players[1].fixed_area.to_key()).is_equal("A1-C")
	assert_bool(output.pair.attacker.players[0].is_fixed()).is_false()
	assert_str(output.pair.attacker.current_area_of("a2").to_key()).is_equal("M2-C")
	# A1-C は攻撃1・守備0
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-0 NONE")


func test_dribble_among_unfixed_players_takes_the_first_in_layout_order() -> void:
	var attacker: TeamLayout = _team([["a1", "M2-C", ""], ["a2", "M2-C", ""]])
	var defender: TeamLayout = _team([["far", "A2-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M2-L1"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_array(_moves(output)).is_equal(["far:A2-L2>A2-L1:PRESS", "a1:M2-C>M2-L1:DRIBBLE"])
	assert_str(output.pair.attacker.players[0].fixed_area.to_key()).is_equal("M2-L1")
	assert_bool(output.pair.attacker.players[1].is_fixed()).is_false()


func test_man_marker_follows_the_dribbler() -> void:
	# a1 は守備側から見て M1-C。マーカー m1 がつく。far は基本エリアが6列目なのでマーカーにならない
	var attacker: TeamLayout = _team([["a1", "M2-C", ""]])
	var defender: TeamLayout = _team([["m1", "M1-L1", ""], ["far", "A2-L2", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE), defender, _styles(MAN),
			_area("M2-C"), HOME)
	assert_str(start.pair.defender.current_area_of("m1").to_key()).is_equal("M1-C")
	var output: JudgeOutput = _judge(start.pair, MAN, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_array(_moves(output)).is_equal(["far:A2-L2>A2-L1:PRESS", "a1:M2-C>A1-C:DRIBBLE", "m1:M1-C>D2-C:MARK"])
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 1-1 NONE")


func test_dribble_without_a_player_on_the_ball_moves_nobody() -> void:
	var attacker: TeamLayout = _team([["a1", "M1-C", ""]])
	var defender: TeamLayout = _team([["far", "A2-L2", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "A1-C"), _defense(GameEnums.DefenseAction.PRESS, "D1-R1"))
	assert_array(_moves(output)).is_equal(["far:A2-L2>A2-L1:PRESS"])
	assert_str(_summary(output)).is_equal("ADVANCE A1-C 0-0 NONE")


# --- ボールに寄せる・バックパス（2026-11-03。手の選択の簡素化） ---

## 攻撃側はボールの M2-C に a1、M1-C に a2。守備側（ゾーン）は D2-C（攻撃側の視点で A1-C）に d1。
## d1 はボールのエリア（守備側の視点 M1-C）の上下左右にいるので、ボールへ寄せられる
func _close_down_pair() -> LayoutPair:
	return LayoutPair.new(_team([["a1", "M2-C", ""], ["a2", "M1-C", ""]]), _team([["d1", "D2-C", ""]]), HOME)


func test_closing_down_the_ball_reads_a_dribble_and_wins_it_before_the_carry() -> void:
	# ボールに寄せる（CLOSE_DOWN）はドリブルをぴったり読んだ扱いで、運ばれる前にボールのエリア M2-C で奪う（人数に関係なくロスト）。
	# ドリブルの選手は動かない
	var output: JudgeOutput = _judge(_close_down_pair(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M2-L1"), _defense(GameEnums.DefenseAction.CLOSE_DOWN, "M2-C"))
	assert_array(_moves(output)).is_equal(["d1:D2-C>M1-C:PRESS"])
	assert_str(_summary(output)).is_equal("LOSS M2-C 1-1 NONE EXACT")


func test_pressing_the_ball_area_does_not_read_a_dribble_or_a_pass() -> void:
	# 同じボールのエリアへの寄せでも、パスコースを切る（PRESS）はドリブルを読んだことにならず、1対0 のドリブルは前進
	var dribble: JudgeOutput = _judge(_close_down_pair(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M2-L1"), _defense(GameEnums.DefenseAction.PRESS, "M2-C"))
	assert_str(_summary(dribble)).is_equal("ADVANCE M2-L1 1-0 NONE")
	# ボールに寄せても、パスの読みにはならない（M1-C へのショートパスは 1対0 で前進）
	var short_pass: JudgeOutput = _judge(_close_down_pair(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M1-C"), _defense(GameEnums.DefenseAction.CLOSE_DOWN, "M2-C"))
	assert_str(_summary(short_pass)).is_equal("ADVANCE M1-C 1-0 NONE")


func test_back_pass_is_not_judged_but_the_defense_still_moves() -> void:
	var output: JudgeOutput = _judge(_close_down_pair(), ZONE, "M2-C",
			_attack(GameEnums.PlayType.BACK_PASS, "M1-C"), _defense(GameEnums.DefenseAction.CLOSE_DOWN, "M2-C"))
	assert_int(output.outcome).is_equal(GameEnums.TurnOutcome.NO_CONTEST)
	assert_object(output.detail).is_null()
	assert_array(_moves(output)).is_equal(["d1:D2-C>M1-C:PRESS"])


# --- 対称性・不正な入力・不変の性質 ---

func test_swapping_the_attacking_team_only_swaps_the_movement_sides() -> void:
	var as_home: JudgeOutput = _judge(_je02(HOME), MAN, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-L1"), _defense(GameEnums.DefenseAction.COVER, "M2-L1"))
	var as_away: JudgeOutput = _judge(_je02(AWAY), MAN, "M2-C",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-L1"), _defense(GameEnums.DefenseAction.COVER, "M2-L1"))
	assert_str(_summary(as_away)).is_equal(_summary(as_home))
	assert_array(_moves(as_away)).is_equal(_moves(as_home))
	assert_dict(as_away.pair.defender.counts()).is_equal(as_home.pair.defender.counts())
	assert_dict(as_away.pair.attacker.counts()).is_equal(as_home.pair.attacker.counts())
	assert_int(as_away.pair.attacker_side).is_equal(AWAY)
	for index: int in range(as_home.movements.size()):
		assert_int(as_home.movements[index].side).is_equal(AWAY)
		assert_int(as_away.movements[index].side).is_equal(HOME)


func test_unavailable_or_mismatched_choices_return_null() -> void:
	var pair: LayoutPair = _je04()
	var pass_choice: TurnChoice = _attack(GameEnums.PlayType.SHORT_PASS, "A2-C")
	var press_choice: TurnChoice = _defense(GameEnums.DefenseAction.PRESS, "A2-C")
	# 守備側の1列目（攻撃側の視点の A2-C）へのカバーは、背後が無く適用できない
	assert_object(_judge(pair, ZONE, "A1-C", pass_choice, _defense(GameEnums.DefenseAction.COVER, "A2-C"))).is_null()
	# 手の種類の取り違え
	assert_object(_judge(pair, ZONE, "A1-C", press_choice, press_choice)).is_null()
	assert_object(_judge(pair, ZONE, "A1-C", pass_choice, pass_choice)).is_null()
	# 運ぶ先が要る手で運ぶ先が無い
	assert_object(_judge(pair, ZONE, "A1-C", _attack(GameEnums.PlayType.SHORT_PASS), press_choice)).is_null()
	# ボール位置が無い
	assert_object(OpenPlayJudge.judge(pair, _styles(ZONE), _styles(ZONE), null, pass_choice, press_choice)).is_null()


func test_judge_does_not_modify_its_inputs() -> void:
	var pair: LayoutPair = _je02()
	var before_defender: Dictionary = pair.defender.counts()
	var before_attacker: Dictionary = pair.attacker.counts()
	var output: JudgeOutput = _judge(pair, MAN, "M2-C",
			_attack(GameEnums.PlayType.DRIBBLE, "M2-L1"), _defense(GameEnums.DefenseAction.COVER, "M2-L1"))
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
	var pair: LayoutPair = _je02()
	var press_choice: TurnChoice = _defense(GameEnums.DefenseAction.PRESS, "M2-L1")
	var step: LayoutStep = OpenPlayJudge.apply_defense(pair, _styles(MAN), press_choice)
	var output: JudgeOutput = _judge(pair, MAN, "M2-C", _attack(GameEnums.PlayType.SHOT), press_choice)
	assert_int(step.movements.size()).is_equal(output.movements.size())
	assert_int(step.movements[0].reason).is_equal(GameEnums.MovementReason.PRESS)
	for index: int in range(step.movements.size()):
		assert_str(step.movements[index].player_id).is_equal(output.movements[index].player_id)
		assert_str(step.movements[index].to.to_key()).is_equal(output.movements[index].to.to_key())
		assert_int(step.movements[index].reason).is_equal(output.movements[index].reason)
	assert_dict(step.pair.defender.counts()).is_equal(output.pair.defender.counts())


func test_apply_defense_returns_null_for_an_inapplicable_move() -> void:
	assert_object(OpenPlayJudge.apply_defense(_je04(), _styles(ZONE), _defense(GameEnums.DefenseAction.COVER, "A2-C"))).is_null()


func test_apply_defense_of_a_zone_press_moves_the_neighbor_in() -> void:
	# 手で書いた場面: 攻撃側 h1 が M2-C、守備側（ゾーン）の a1 が守備側から見て D2-C。M2-C へのプレスで a1 が M1-C へ寄せる
	var h1 := PlayerState.new("h1", _area("M2-C"), null)
	var a1 := PlayerState.new("a1", _area("D2-C"), null)
	var pair := LayoutPair.new(TeamLayout.new([h1], {"h1": _area("M2-C")}), TeamLayout.new([a1], {"a1": _area("D2-C")}), HOME)
	var step: LayoutStep = OpenPlayJudge.apply_defense(pair, _styles(ZONE), _defense(GameEnums.DefenseAction.PRESS, "M2-C"))
	assert_int(step.movements.size()).is_equal(1)
	assert_str("%s %s>%s" % [step.movements[0].player_id, step.movements[0].from.to_key(), step.movements[0].to.to_key()]) \
			.is_equal("a1 D2-C>M1-C")
	assert_int(step.movements[0].reason).is_equal(GameEnums.MovementReason.PRESS)
	assert_str(step.pair.defender.current_area_of("a1").to_key()).is_equal("M1-C")


# --- 読みを当てた守備（2026-10-24） ---

## 攻撃側はボールの M2-L1 に a1、運ぶ先の M2-C に extra 人。守備側は M2-C（攻撃側の視点）の隣 M2-R1 に near が1人。
## defense_key へプレスする（M2-C なら near が寄せて M2-C は extra 対 1）
func _read_scene(extra: int, defense_key: String) -> JudgeOutput:
	var attacker_spec: Array = [["a1", "M2-L1", ""]]
	for index: int in range(extra):
		attacker_spec.append(["m%d" % index, "M2-C", ""])
	var defender: TeamLayout = _team([["near", _area("M2-R1").mirrored().to_key(), ""], ["far", "A2-L2", ""]])
	return _judge(LayoutPair.new(_team(attacker_spec), defender, HOME), ZONE, "M2-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"), _defense(GameEnums.DefenseAction.PRESS, defense_key))


func test_a_read_pass_needs_two_more_attackers_to_get_through() -> void:
	# 読まれた（制限したエリアに来た）パスは、攻撃側が2人以上多くないと通らない
	assert_str(_summary(_read_scene(2, "M2-C"))).is_equal("LOSS M2-C 2-1 NONE EXACT")
	assert_str(_summary(_read_scene(3, "M2-C"))).is_equal("ADVANCE M2-C 3-1 NONE EXACT")


func test_an_unread_pass_with_one_more_attacker_gets_through() -> void:
	# 守備が別のエリア（D1-R1）を制限した。1人多ければ前進
	var output: JudgeOutput = _read_scene(1, "D1-R1")
	assert_str(_summary(output)).is_equal("ADVANCE M2-C 1-0 NONE")
	assert_int(output.detail.read).is_equal(GameEnums.ReadKind.NONE)


func test_a_level_shot_read_by_the_defense_is_saved() -> void:
	# シュートで、守備がシュートコースを塞いだ（ボールのエリア A2-L1 への寄せ。読みを当てた）。隣の near が寄せて 2対2。同数なら阻止
	var attacker: TeamLayout = _team([["a1", "A2-L1", ""], ["a2", "A2-L1", ""]])
	var defender: TeamLayout = _team([["d1", "D1-R1", ""], ["near", "D1-C", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "A2-L1",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.BLOCK_SHOT, "A2-L1"))
	assert_str(_summary(output)).is_equal("SAVE A2-L1 2-2 NONE EXACT")


func test_a_read_shot_with_one_more_attacker_still_scores() -> void:
	# シュートは、読まれても1人多ければ得点（シュート以外の手と違い、+2 は要らない）
	var attacker: TeamLayout = _team([["a1", "A2-L1", ""], ["a2", "A2-L1", ""], ["a3", "A2-L1", ""]])
	var defender: TeamLayout = _team([["d1", "D1-R1", ""], ["near", "D1-C", ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "A2-L1",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.BLOCK_SHOT, "A2-L1"))
	assert_str(_summary(output)).is_equal("GOAL A2-L1 3-2 NONE EXACT")


# --- 読みの段階（2026-10-24。隣の読み） ---

func test_read_kind_follows_the_distance_between_the_restricted_and_compared_areas() -> void:
	# [制限したエリア, 比較エリア, ボール, 段階]。隣は同じ列でレーンが1つ隣だけ。
	# ボールのエリアへの寄せは、持っている選手への寄せで、運ぶ先の読みではない（ぴったり＝シュートだけ）
	var cases: Array = [
		["M2-C", "M2-C", "M1-C", GameEnums.ReadKind.EXACT],
		["M2-R1", "M2-C", "M1-C", GameEnums.ReadKind.NEAR],
		["M2-L1", "M2-C", "M1-C", GameEnums.ReadKind.NEAR],
		["A1-L2", "A1-L1", "M2-C", GameEnums.ReadKind.NEAR],
		["M2-R2", "M2-C", "M1-C", GameEnums.ReadKind.NONE],
		["A1-C", "M2-C", "M1-C", GameEnums.ReadKind.NONE],
		["M1-L1", "M2-C", "M1-C", GameEnums.ReadKind.NONE],
		["M2-L1", "M2-C", "M2-L1", GameEnums.ReadKind.NONE],
		["A1-C", "A1-C", "A1-C", GameEnums.ReadKind.EXACT],
	]
	for case: Array in cases:
		assert_int(OpenPlayJudge.read_of(_area(case[0] as String), _area(case[1] as String), _area(case[2] as String))) \
				.override_failure_message(str(case)).is_equal(case[3] as int)


## 攻撃側はボールの M2-L1 に a1、運ぶ先の M2-C に extra 人。守備側は M2-C（攻撃側の視点）に d1 が1人と、
## presser_key（攻撃側の視点）に寄せ役が1人。defense_key へプレスする
func _near_scene(extra: int, presser_key: String, defense_key: String) -> JudgeOutput:
	var attacker_spec: Array = [["a1", "M2-L1", ""]]
	for index: int in range(extra):
		attacker_spec.append(["m%d" % index, "M2-C", ""])
	var defender: TeamLayout = _team([["d1", _area("M2-C").mirrored().to_key(), ""],
			["presser", _area(presser_key).mirrored().to_key(), ""]])
	return _judge(LayoutPair.new(_team(attacker_spec), defender, HOME), ZONE, "M2-L1",
			_attack(GameEnums.PlayType.SHORT_PASS, "M2-C"), _defense(GameEnums.DefenseAction.PRESS, defense_key))


func test_je08_pass_read_next_door_is_won_at_level_numbers() -> void:
	# 隣の M2-R1 へ寄せた。M2-C は 1対1 で、背後にカバーはいない。外れなら前進だが、隣を読まれていればロスト
	assert_str(_summary(_near_scene(1, "M2-R2", "M2-R1"))).is_equal("LOSS M2-C 1-1 NONE NEAR")


func test_je08_pass_read_next_door_gets_through_with_one_more_attacker() -> void:
	assert_str(_summary(_near_scene(2, "M2-R2", "M2-R1"))).is_equal("ADVANCE M2-C 2-1 NONE NEAR")


func test_je08_press_two_lanes_away_is_not_a_read() -> void:
	# 2つ離れた M2-R2 へ寄せた。外れなので、カバーのいない同数は前進
	assert_str(_summary(_near_scene(1, "A1-R2", "M2-R2"))).is_equal("ADVANCE M2-C 1-1 NONE")


func test_a_press_on_the_area_behind_is_a_cover_not_a_read() -> void:
	# 列が違う A1-C（M2-C の背後）へ寄せた。隣の読みではなく、背後のカバーとして同数を膠着にする
	assert_str(_summary(_near_scene(1, "A1-R1", "A1-C"))).is_equal("STALL M2-C 1-1 DEFENDER")


func test_a_near_read_does_not_stop_a_level_shot() -> void:
	# シュートは、シュートコースを塞がれた同数だけ阻止。隣の A2-R1 へ寄せても、読みに数えず（2026-11-03）同数のシュートは決まる
	var attacker: TeamLayout = _team([["a1", "A2-C", ""]])
	var defender: TeamLayout = _team([["d1", "D1-C", ""], ["presser", _area("A2-R2").mirrored().to_key(), ""]])
	var output: JudgeOutput = _judge(LayoutPair.new(attacker, defender, HOME), ZONE, "A2-C",
			_attack(GameEnums.PlayType.SHOT), _defense(GameEnums.DefenseAction.PRESS, "A2-R1"))
	assert_str(_summary(output)).is_equal("GOAL A2-C 1-1 NONE")

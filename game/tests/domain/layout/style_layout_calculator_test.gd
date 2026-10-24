## アルゴリズム2: 現在配置の算出（StyleLayoutCalculator）のテスト。
## 期待値は functional-overview.md アルゴリズム2の規則から手で書いた。
## ボール位置は攻撃側から見た座標、各チームの配置はそのチーム自身から見た座標（component-design.md §1.2）。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER
const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## spec は [選手 ID, 基本エリア, 固定先（無ければ ""）] の配列。今いるエリアは、固定先があれば固定先、なければ基本エリア
## （固定された選手は固定先にいる。試合の状態と同じ）。
func _layout(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		var fixed_key: String = row[2] as String
		var fixed: PitchArea = null if fixed_key == "" else _area(fixed_key)
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String), fixed))
	return TeamLayout.from_players(players)


## spec は [選手 ID, 基本エリア, 今いるエリア]（固定なし）の配列。ターンをまたいで持ち越した位置から始める配置
func _layout_now(spec: Array) -> TeamLayout:
	var players: Array[PlayerState] = []
	for row: Array in spec:
		players.append(PlayerState.new(row[0] as String, _area(row[1] as String), null, _area(row[2] as String)))
	return TeamLayout.from_players(players)


func _styles(defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamStyles:
	return TeamStyles.new(defense, attack)


## 選手 ID → 現在エリアのキー
func _areas_of(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id).to_key()
	return result


## "選手 ID:移動元>移動先:理由" の並び（理由は MovementReason の名前）
func _moves(step: LayoutStep) -> Array[String]:
	var result: Array[String] = []
	for movement: Movement in step.movements:
		result.append("%s:%s>%s:%s" % [movement.player_id, movement.from.to_key(), movement.to.to_key(),
				GameEnums.MovementReason.keys()[movement.reason]])
	return result


## 守備側の配置（ZONE 用）。左の大外から右の大外まで1人ずつと、敵陣の中央に1人
func _zone_defender() -> TeamLayout:
	return _layout([
		["d1", "D-L2", ""], ["d2", "D-L1", ""], ["d3", "D-C", ""],
		["d4", "M-R1", ""], ["d5", "M-R2", ""], ["d6", "A-C", ""],
	])


## 攻撃方式を COUNTER にした、動かない攻撃側
func _still_attacker() -> TeamLayout:
	return _layout([["a1", "M-C", ""]])


## MAN 用の攻撃側（攻撃側の視点）。守備側から見ると a1 は D-C、a2 は D-R1、a3 は M-L2、a4 は A-C（対象外）
func _man_attacker() -> TeamLayout:
	return _layout([
		["a1", "A-C", ""], ["a2", "A-L1", ""], ["a3", "M-R2", ""], ["a4", "D-C", ""],
	])


## layout の player_id を area_key へ動かして固定した配置（ドリブル・プレスの後の配置を作る）
func _moved(layout: TeamLayout, player_id: String, area_key: String) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for player: PlayerState in layout.players:
		var copied: PlayerState = player.duplicate_deep()
		current[copied.player_id] = layout.current_area_of(copied.player_id)
		if copied.player_id == player_id:
			copied.fixed_area = _area(area_key)
			current[copied.player_id] = _area(area_key)
		players.append(copied)
	return TeamLayout.new(players, current)


func _compute_zone_defense(ball_key: String) -> LayoutStep:
	return StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			_zone_defender(), _styles(ZONE, COUNTER), _area(ball_key), HOME)


# --- 1ターン1マス（2026-10-24。位置の持ち越し） ---

func test_zone_slide_reversal_takes_two_turns() -> void:
	# 前のターンはボールが攻撃側の右（守備側の左）で、全員が左へ1レーンずれていた。ボールが反対側（M-L2）へ移ると、
	# 目標は右へ1レーンずれた位置（2レーン先）。1ターンに1レーンずつしか動けないので、まず基本エリアまで
	var slid: TeamLayout = _layout_now([
		["d1", "D-L2", "D-L2"], ["d2", "D-L1", "D-L2"], ["d3", "D-C", "D-L1"], ["d4", "M-R1", "M-C"],
	])
	var first: LayoutStep = StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			slid, _styles(ZONE, COUNTER), _area("M-L2"), HOME)
	assert_dict(_areas_of(first.pair.defender)).is_equal({"d1": "D-L1", "d2": "D-L1", "d3": "D-C", "d4": "M-R1"})
	assert_array(_moves(first)).contains(["d3:D-L1>D-C:SLIDE"])
	# 次のターンで目標（右へ1レーン）に届く
	var second: LayoutStep = StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			first.pair.defender, _styles(ZONE, COUNTER), _area("M-L2"), HOME)
	assert_dict(_areas_of(second.pair.defender)).is_equal({"d1": "D-L1", "d2": "D-C", "d3": "D-R1", "d4": "M-R2"})


func test_a_player_away_from_the_base_area_returns_one_area_per_turn() -> void:
	# 固定を解かれた選手は、基本エリアへ一気に戻らず、1マスずつ戻る（方式の動きの理由が無いので RETURN）
	var attacker: TeamLayout = _layout_now([["a1", "D-C", "A-R2"], ["a2", "M-L2", "M-L2"]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-R1", "a2": "M-L2"})
	assert_array(_moves(step)).is_equal(["a1:A-R2>M-R1:RETURN"])


func test_a_marker_closes_in_one_area_per_turn() -> void:
	# 守備側から見て、a1 は M-L2。マーカー d1 は D-R1 にいて、1ターンでは M-C までしか近づけない
	var defender: TeamLayout = _layout_now([["d1", "D-C", "D-R1"]])
	var attacker: TeamLayout = _layout([["a1", "M-R2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_array(_moves(step)).is_equal(["d1:D-R1>M-C:MARK"])


func test_marker_assignment_follows_where_the_markers_are_now() -> void:
	# 対象は守備側から見て M-R2（攻撃側の M-L2）。基本エリアでは d1（M-R1）が近いが、今は d2 が M-R1 にいて、
	# d1 は D-L2 にいる。今近い d2 がマークにつき、d1 は余りとして D-C へ1マス近づく
	var defender: TeamLayout = _layout_now([["d1", "M-R1", "D-L2"], ["d2", "D-L2", "M-R1"]])
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-L1", "d2": "M-R2"})


func test_a_player_who_moved_in_the_last_turn_stays_where_it_is() -> void:
	var players: Array[PlayerState] = [PlayerState.new("a1", _area("D-C"), null, _area("M-C"))]
	players[0].moved_in_turn = true
	var step: LayoutStep = StyleLayoutCalculator.compute(TeamLayout.from_players(players), _styles(ZONE, COUNTER),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_str(step.pair.attacker.current_area_of("a1").to_key()).is_equal("M-C")
	assert_array(_moves(step)).is_empty()


func test_every_player_moves_at_most_one_area_from_where_it_is() -> void:
	# 全員が盤の反対側にいても、1ターンでは1マスまで
	var defender: TeamLayout = _layout_now([
		["d1", "D-L2", "A-R2"], ["d2", "D-C", "A-L2"], ["d3", "M-R2", "D-L2"], ["d4", "D-R1", "A-C"],
	])
	var attacker: TeamLayout = _layout_now([["a1", "A-C", "D-L2"], ["a2", "M-L2", "D-R2"]])
	for defense: GameEnums.DefenseStyle in [ZONE, MAN]:
		for ball_key: String in ["M-C", "A-R2", "D-L1"]:
			var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
					defender, _styles(defense, COUNTER), _area(ball_key), HOME)
			for layout_pair: Array in [[attacker, step.pair.attacker], [defender, step.pair.defender]]:
				var before: TeamLayout = layout_pair[0]
				var after: TeamLayout = layout_pair[1]
				for player: PlayerState in before.players:
					assert_bool(before.current_area_of(player.player_id).is_within_one(after.current_area_of(player.player_id))) \
							.override_failure_message("%s %s %s" % [defense, ball_key, player.player_id]).is_true()


# --- 攻撃方式（手順3） ---

func test_possession_moves_only_wide_players_one_zone_forward() -> void:
	var attacker: TeamLayout = _layout([
		["a1", "D-L2", ""], ["a2", "M-R2", ""], ["a3", "A-L2", ""], ["a4", "M-C", ""], ["a5", "D-R1", ""],
	])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), AWAY)
	assert_dict(_areas_of(step.pair.attacker)).is_equal(
			{"a1": "M-L2", "a2": "A-R2", "a3": "A-L2", "a4": "M-C", "a5": "D-R1"})
	assert_array(_moves(step)).is_equal(["a1:D-L2>M-L2:POSSESSION_ADVANCE", "a2:M-R2>A-R2:POSSESSION_ADVANCE"])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)


func test_counter_returns_last_turn_style_moves_to_the_base_area_one_area_at_a_time() -> void:
	# 前のターンの保持型の前進で、現在エリアが基本エリアから1ゾーン前にずれている。カウンター型は基本エリアへ戻る
	var attacker: TeamLayout = _layout_now([["a1", "M-L2", "A-L2"], ["a2", "M-C", "M-C"]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-L2", "a2": "M-C"})
	assert_array(_moves(step)).is_equal(["a1:A-L2>M-L2:RETURN"])


# --- ZONE（手順4） ---

func test_zone_does_not_slide_when_the_ball_is_in_the_center_lane() -> void:
	var step: LayoutStep = _compute_zone_defense("M-C")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L2", "d2": "D-L1", "d3": "D-C", "d4": "M-R1", "d5": "M-R2", "d6": "A-C"})
	assert_array(_moves(step)).is_empty()


func test_zone_slides_to_the_defender_left_when_the_ball_is_on_the_attacker_right() -> void:
	# 攻撃側から見た A-R1 は、守備側から見た D-L1（左のハーフスペース）
	var step: LayoutStep = _compute_zone_defense("A-R1")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L2", "d2": "D-L2", "d3": "D-L1", "d4": "M-C", "d5": "M-R1", "d6": "A-L1"})
	# ボールサイドの大外に、元の大外とずれてきた選手の2人が集まる
	assert_int(step.pair.defender.count_at(_area("D-L2"))).is_equal(2)
	assert_array(_moves(step)).is_equal([
		"d2:D-L1>D-L2:SLIDE", "d3:D-C>D-L1:SLIDE", "d4:M-R1>M-C:SLIDE", "d5:M-R2>M-R1:SLIDE", "d6:A-C>A-L1:SLIDE",
	])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)


func test_zone_slides_to_the_defender_right_when_the_ball_is_on_the_attacker_left_wing() -> void:
	# 攻撃側から見た M-L2 は、守備側から見た M-R2（右の大外）
	var step: LayoutStep = _compute_zone_defense("M-L2")
	assert_dict(_areas_of(step.pair.defender)).is_equal(
			{"d1": "D-L1", "d2": "D-C", "d3": "D-R1", "d4": "M-R2", "d5": "M-R2", "d6": "A-R1"})
	assert_int(step.pair.defender.count_at(_area("M-R2"))).is_equal(2)


func test_zone_slide_follows_the_ball_lane_not_its_zone() -> void:
	# 同じレーンなら、ボールのゾーンが違ってもずれ方は同じ（A-R2 と D-R2 は守備側から見てどちらも左の大外）
	var near: LayoutStep = _compute_zone_defense("A-R2")
	var far: LayoutStep = _compute_zone_defense("D-R2")
	assert_dict(_areas_of(near.pair.defender)).is_equal(_areas_of(far.pair.defender))
	assert_str(near.pair.defender.current_area_of("d3").to_key()).is_equal("D-L1")


# --- MAN（手順4） ---

## マンツーマンで、ターン開始を繰り返してマーカーが目標に落ち着いた守備側の配置（1ターン1マスなので、
## 盤の端から端まで4ターン）。誰がどの対象につくか（割り当ての規則）を確かめるのに使う
func _settled(attacker: TeamLayout, attacker_styles: TeamStyles, defender: TeamLayout) -> TeamLayout:
	var current_attacker: TeamLayout = attacker
	var current_defender: TeamLayout = defender
	for _turn: int in range(4):
		var step: LayoutStep = StyleLayoutCalculator.compute(current_attacker, attacker_styles,
				current_defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
		current_attacker = step.pair.attacker
		current_defender = step.pair.defender
	# 落ち着いた（もう誰も動かない）ことを確かめる。途中の配置がたまたま期待値と一致して通るのを防ぐ
	var settled: LayoutStep = StyleLayoutCalculator.compute(current_attacker, attacker_styles,
			current_defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_array(settled.movements).override_failure_message("4ターンで落ち着いていない").is_empty()
	return current_defender


func test_man_with_spare_markers_sends_the_rest_to_d_c() -> void:
	var defender: TeamLayout = _layout([
		["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""], ["d4", "M-C", ""], ["d5", "A-C", ""],
	])
	var step: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# 対象は D-C・D-R1・M-L2 の3人。マーカー4人のうち1人が余り、D-C へ。基本エリアが A の d5 は残る。
	# d2 は D-R1 まで2レーンあるので、1ターン目は D-C まで
	assert_array(_moves(step)).is_equal(["d2:D-L1>D-C:MARK", "d4:M-C>D-C:MARK"])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)
	assert_dict(_areas_of(_settled(_man_attacker(), _styles(ZONE, COUNTER), defender))).is_equal(
			{"d1": "D-C", "d2": "D-R1", "d3": "M-L2", "d4": "D-C", "d5": "A-C"})


func test_man_with_exactly_enough_markers_marks_every_target() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	assert_dict(_areas_of(_settled(_man_attacker(), _styles(ZONE, COUNTER), defender))).is_equal(
			{"d1": "D-C", "d2": "D-R1", "d3": "M-L2"})


func test_man_without_enough_markers_marks_targets_nearest_the_own_goal_first() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d3", "M-L2", ""], ["d5", "A-C", ""]])
	var settled: TeamLayout = _settled(_man_attacker(), _styles(ZONE, COUNTER), defender)
	# D-C と D-R1 を先にマークし、M-L2 の対象は空く
	assert_dict(_areas_of(settled)).is_equal({"d1": "D-C", "d3": "D-R1", "d5": "A-C"})
	assert_int(settled.count_at(_area("M-L2"))).is_equal(0)


func test_man_priority_is_zone_then_center_then_half_space_then_wide_then_left() -> void:
	# 守備側から見ると M-C・D-R2・D-R1・D-L1・D-C の5人。選手の並びは優先順とわざと違えてある
	var attacker: TeamLayout = _layout([
		["a1", "M-C", ""], ["a2", "A-L2", ""], ["a3", "A-L1", ""], ["a4", "A-R1", ""], ["a5", "A-C", ""],
	])
	var defender: TeamLayout = _layout([
		["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""], ["m4", "M-C", ""],
	])
	var counts: Dictionary = _settled(attacker, _styles(ZONE, COUNTER), defender).counts()
	# 4人なら D-C → D-L1 → D-R1 → D-R2。M-C の対象（D より遠い）は空く
	assert_int(counts["D-C"] as int).is_equal(1)
	assert_int(counts["D-L1"] as int).is_equal(1)
	assert_int(counts["D-R1"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(1)
	assert_int(counts["M-C"] as int).is_equal(0)


func test_man_priority_with_three_markers_leaves_the_wide_target() -> void:
	var attacker: TeamLayout = _layout([
		["a1", "M-C", ""], ["a2", "A-L2", ""], ["a3", "A-L1", ""], ["a4", "A-R1", ""], ["a5", "A-C", ""],
	])
	var defender: TeamLayout = _layout([["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""]])
	var counts: Dictionary = _settled(attacker, _styles(ZONE, COUNTER), defender).counts()
	assert_int(counts["D-C"] as int).is_equal(1)
	assert_int(counts["D-L1"] as int).is_equal(1)
	assert_int(counts["D-R1"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(0)


func test_man_priority_marks_the_defender_left_first_on_a_tie() -> void:
	# 守備側から見ると D-R1・D-L1・D-R2・D-L2 の4人。マーカー2人ならハーフスペースの左右、1人なら左だけ
	var attacker: TeamLayout = _layout([
		["a1", "A-L1", ""], ["a2", "A-R1", ""], ["a3", "A-L2", ""], ["a4", "A-R2", ""],
	])
	var one: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "M-C", ""]]), _styles(MAN, COUNTER), _area("M-C"), HOME)
	assert_str(one.pair.defender.current_area_of("m1").to_key()).is_equal("D-L1")
	var counts: Dictionary = _settled(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "M-C", ""], ["m2", "M-C", ""], ["m3", "M-C", ""]])).counts()
	assert_int(counts["D-L2"] as int).is_equal(1)
	assert_int(counts["D-R2"] as int).is_equal(0)


func test_man_short_of_markers_does_not_keep_a_marker_on_a_lower_priority_target() -> void:
	# 対象は D-C と M-L2（守備側の視点）。マーカーは M-L2 にいる1人だけ。その場に残らず、優先の D-C へ
	var attacker: TeamLayout = _layout([["a1", "A-C", ""], ["a2", "M-R2", ""]])
	var settled: TeamLayout = _settled(attacker, _styles(ZONE, COUNTER), _layout([["d1", "M-L2", ""]]))
	assert_str(settled.current_area_of("d1").to_key()).is_equal("D-C")


func test_man_targets_the_attacker_position_after_the_possession_advance() -> void:
	# 攻撃側の M-L2 の大外は保持型で A-L2 へ出る。守備側から見て D-R2
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""]])
	var defender: TeamLayout = _layout([["d1", "D-C", ""]])
	assert_str(_settled(attacker, _styles(ZONE, POSSESSION), defender).current_area_of("d1").to_key()).is_equal("D-R2")


func test_man_with_no_targets_sends_every_marker_to_d_c() -> void:
	# 攻撃側が全員自陣（守備側から見て A）にいると、マークの対象がいない
	var attacker: TeamLayout = _layout([["a1", "D-C", ""], ["a2", "D-L2", ""]])
	var defender: TeamLayout = _layout([["d1", "D-L2", ""], ["d2", "M-R1", ""], ["d3", "A-C", ""]])
	assert_dict(_areas_of(_settled(attacker, _styles(ZONE, COUNTER), defender))).is_equal(
			{"d1": "D-C", "d2": "D-C", "d3": "A-C"})


func test_movements_list_the_attacker_first_with_each_team_side() -> void:
	var step: LayoutStep = StyleLayoutCalculator.compute(_layout([["a1", "D-L2", ""], ["a2", "M-C", ""]]),
			_styles(ZONE, POSSESSION), _zone_defender(), _styles(ZONE, COUNTER), _area("A-R1"), HOME)
	assert_array(_moves(step)).is_equal([
		"a1:D-L2>M-L2:POSSESSION_ADVANCE",
		"d2:D-L1>D-L2:SLIDE", "d3:D-C>D-L1:SLIDE", "d4:M-R1>M-C:SLIDE", "d5:M-R2>M-R1:SLIDE", "d6:A-C>A-L1:SLIDE",
	])
	assert_int(step.movements[0].side).is_equal(HOME)
	for index: int in range(1, step.movements.size()):
		assert_int(step.movements[index].side).is_equal(AWAY)
	assert_int(step.pair.attacker_side).is_equal(HOME)


# --- 固定された選手（手順2） ---

func test_fixed_attacker_is_not_moved_by_possession_and_stays_fixed() -> void:
	# 固定先も大外（M-L2）。固定されていなければ A-L2 へ出るところ
	var attacker: TeamLayout = _layout([["a1", "D-L2", "M-L2"], ["a2", "D-R2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION),
			_layout([["d1", "D-C", ""]]), _styles(ZONE, COUNTER), _area("M-C"), HOME)
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-L2", "a2": "M-R2"})
	assert_str(step.pair.attacker.players[0].fixed_area.to_key()).is_equal("M-L2")
	assert_array(_moves(step)).is_equal(["a2:D-R2>M-R2:POSSESSION_ADVANCE"])


func test_fixed_defender_is_not_moved_by_zone_slide() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", "D-C"]])
	var step: LayoutStep = StyleLayoutCalculator.compute(_still_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(ZONE, COUNTER), _area("A-R1"), HOME)
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-L1", "d2": "D-C"})
	assert_bool(step.pair.defender.players[1].is_fixed()).is_true()
	assert_array(_moves(step)).is_equal(["d1:D-C>D-L1:SLIDE"])


func test_fixed_defender_is_not_a_man_marker() -> void:
	# d1 は M-R1 に固定されている。対象は D-C・D-R1・M-L2 の3人で、マーカーは d2・d3 の2人
	var defender: TeamLayout = _layout([["d1", "D-C", "M-R1"], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	assert_dict(_areas_of(_settled(_man_attacker(), _styles(ZONE, COUNTER), defender))).is_equal(
			{"d1": "M-R1", "d2": "D-C", "d3": "D-R1"})


# --- remark（マークの付け直し） ---

func test_remark_moves_the_marker_after_its_target_dribbles() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(_man_attacker(), _styles(ZONE, COUNTER),
			defender, _styles(MAN, COUNTER), _area("M-C"), HOME)
	# a3 が M-R2 から A-R2 へドリブルして固定された（守備側から見て M-L2 → D-L2）
	var attacker_players: Array[PlayerState] = []
	var attacker_current: Dictionary = {}
	for player: PlayerState in start.pair.attacker.players:
		var moved: PlayerState = player.duplicate_deep()
		if moved.player_id == "a3":
			moved.fixed_area = _area("A-R2")
		attacker_players.append(moved)
		attacker_current[moved.player_id] = start.pair.attacker.current_area_of(moved.player_id)
	attacker_current["a3"] = _area("A-R2")
	var pair := LayoutPair.new(TeamLayout.new(attacker_players, attacker_current), start.pair.defender, HOME)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d2": "D-R1", "d3": "D-L2"})
	# d3 がついていく。ターン開始で追いつけていなかった d2（D-R1 まで2レーン）も、付け直しで1マス近づく
	assert_array(_moves(step)).is_equal(["d2:D-C>D-R1:MARK", "d3:M-L2>D-L2:MARK"])
	assert_str(step.pair.attacker.current_area_of("a3").to_key()).is_equal("A-R2")


func test_remark_measures_the_step_from_the_turn_start_position() -> void:
	# 1ターンの中で付け直しが2回（プレスの後とドリブルの後）あっても、マーカーはターン開始の位置から1マスまで。
	# d1 はターン開始で D-C にいて、1回目の付け直しで D-R1 へ動いた。対象がさらに M-R2（守備側の視点）へ動いても、
	# ターン開始の D-C から1マスの M-R1 まで
	var start: TeamLayout = _layout_now([["d1", "D-C", "D-C"]])
	var after_first: TeamLayout = _layout_now([["d1", "D-C", "D-R1"]])
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""]])
	var step: LayoutStep = StyleLayoutCalculator.remark(LayoutPair.new(attacker, after_first, HOME),
			_styles(MAN, COUNTER), start)
	assert_str(step.pair.defender.current_area_of("d1").to_key()).is_equal("M-R1")
	assert_array(_moves(step)).is_equal(["d1:D-R1>M-R1:MARK"])


func test_remark_keeps_a_marker_on_its_unmoved_target_instead_of_swapping() -> void:
	# m1 は D-L1、m2 は M-C の対象をマークしている（守備側の視点）。M-C の対象が D-C へドリブルした
	var attacker: TeamLayout = _layout([["a1", "A-R1", ""], ["a2", "M-C", ""]])
	var start: LayoutStep = StyleLayoutCalculator.compute(attacker, _styles(ZONE, COUNTER),
			_layout([["m1", "D-L1", ""], ["m2", "M-C", ""]]), _styles(MAN, COUNTER), _area("M-C"), AWAY)
	assert_dict(_areas_of(start.pair.defender)).is_equal({"m1": "D-L1", "m2": "M-C"})
	var pair := LayoutPair.new(_moved(start.pair.attacker, "a2", "A-C"), start.pair.defender, AWAY)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	# m2 だけが対象についていく。m1 と m2 を入れ替えて矢印を交差させない
	assert_dict(_areas_of(step.pair.defender)).is_equal({"m1": "D-L1", "m2": "D-C"})
	assert_array(_moves(step)).is_equal(["m2:M-C>D-C:MARK"])
	assert_int(step.movements[0].side).is_equal(HOME)


func test_remark_skips_a_marker_fixed_by_press_and_keeps_inputs() -> void:
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""]])
	var marking: TeamLayout = _settled(_man_attacker(), _styles(ZONE, COUNTER), defender)
	# d1 がプレスで M-C へ動いて固定された。マーカーは d2・d3 の2人で、対象は D-C・D-R1 の2人を先にマークする。
	# d3 は D-C へ1マス（D-L1）だけ近づく
	var pair := LayoutPair.new(_man_attacker(), _moved(marking, "d1", "M-C"), HOME)
	var step: LayoutStep = StyleLayoutCalculator.remark(pair, _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "M-C", "d2": "D-R1", "d3": "D-L1"})
	assert_array(_moves(step)).is_equal(["d3:M-L2>D-L1:MARK"])
	# 入力は書き換えない
	assert_dict(_areas_of(pair.defender)).is_equal({"d1": "M-C", "d2": "D-R1", "d3": "M-L2"})


func test_remark_without_changes_moves_nobody() -> void:
	var defender: TeamLayout = _layout([
		["d1", "D-C", ""], ["d2", "D-L1", ""], ["d3", "M-L2", ""], ["d4", "M-C", ""], ["d5", "A-C", ""],
	])
	var marking: TeamLayout = _settled(_man_attacker(), _styles(ZONE, COUNTER), defender)
	var step: LayoutStep = StyleLayoutCalculator.remark(LayoutPair.new(_man_attacker(), marking, HOME), _styles(MAN, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal(_areas_of(marking))
	assert_array(_moves(step)).is_empty()


func test_remark_does_nothing_for_zone() -> void:
	var start: LayoutStep = _compute_zone_defense("A-R1")
	var step: LayoutStep = StyleLayoutCalculator.remark(start.pair, _styles(ZONE, COUNTER))
	assert_dict(_areas_of(step.pair.defender)).is_equal(_areas_of(start.pair.defender))
	assert_array(_moves(step)).is_empty()
	assert_object(step.pair).is_not_same(start.pair)


# --- 不変の性質 ---

func test_compute_does_not_modify_its_inputs() -> void:
	var attacker: TeamLayout = _layout([["a1", "M-L2", ""], ["a2", "A-C", "A-L1"]])
	var defender: TeamLayout = _layout([["d1", "D-C", ""], ["d2", "M-R2", "M-C"]])
	StyleLayoutCalculator.compute(attacker, _styles(ZONE, POSSESSION), defender, _styles(MAN, COUNTER),
			_area("A-R1"), HOME)
	assert_dict(_areas_of(attacker)).is_equal({"a1": "M-L2", "a2": "A-L1"})
	assert_dict(_areas_of(defender)).is_equal({"d1": "D-C", "d2": "M-C"})
	assert_str(defender.players[1].fixed_area.to_key()).is_equal("M-C")


func test_both_teams_keep_ten_players_for_every_formation_style_and_ball() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	assert_int(catalog.formations.size()).is_equal(4)
	var checked: int = 0
	for own: FormationDef in catalog.formations:
		for opponent: FormationDef in catalog.formations:
			for defense: GameEnums.DefenseStyle in [ZONE, MAN]:
				for attack: GameEnums.AttackStyle in [POSSESSION, COUNTER]:
					for ball: PitchArea in PitchArea.all():
						var step: LayoutStep = StyleLayoutCalculator.compute(
								BaseLayoutDeriver.derive(own), _styles(ZONE, attack),
								BaseLayoutDeriver.derive(opponent), _styles(defense, COUNTER), ball, HOME)
						var label: String = "%s vs %s %d/%d %s" % [own.id, opponent.id, defense, attack, ball.to_key()]
						assert_int(_total(step.pair.attacker)).override_failure_message(label).is_equal(10)
						assert_int(_total(step.pair.defender)).override_failure_message(label).is_equal(10)
						# MAN では基本エリアが A の選手はマーカーにならず、基本エリアに残る
						if defense == MAN:
							for player: PlayerState in step.pair.defender.players:
								if player.base_area.zone == GameEnums.Zone.A:
									assert_bool(player.base_area.equals(
											step.pair.defender.current_area_of(player.player_id))) \
											.override_failure_message(label).is_true()
						checked += 1
	assert_int(checked).is_equal(4 * 4 * 2 * 2 * 15)


func _total(layout: TeamLayout) -> int:
	var total: int = 0
	for count: int in layout.counts().values():
		total += count
	return total


# --- retreat（アルゴリズム6のリトリート） ---

## 直前の配置: d1 は D-C が基本で M-C に固定、d2 は D-L1 が基本で前のスライドで D-L2 に、d3 は M-R2 のまま
func _retreating_defender() -> TeamLayout:
	var players: Array[PlayerState] = [
		PlayerState.new("d1", _area("D-C"), _area("M-C")),
		PlayerState.new("d2", _area("D-L1")),
		PlayerState.new("d3", _area("M-R2")),
	]
	return TeamLayout.new(players, {"d1": _area("M-C"), "d2": _area("D-L2"), "d3": _area("M-R2")})


func test_retreat_resets_fixes_and_slides_from_the_base_layout() -> void:
	var pair := LayoutPair.new(_layout([["a1", "M-C", ""]]), _retreating_defender(), HOME)
	# 奪われたエリア X は奪取側（攻撃側）の視点で A-R1。守備側から見て D-L1 なので左へ1レーン
	var step: LayoutStep = StyleLayoutCalculator.retreat(pair, _styles(ZONE, COUNTER), _area("A-R1"))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-L1", "d2": "D-L2", "d3": "M-R1"})
	for player: PlayerState in step.pair.defender.players:
		assert_bool(player.is_fixed()).override_failure_message(player.player_id).is_false()
	# 直前の位置から変わった選手だけ（d2 は D-L2 のまま）
	assert_array(_moves(step)).is_equal(["d1:M-C>D-L1:RETREAT_RESET", "d3:M-R2>M-R1:RETREAT_RESET"])
	for movement: Movement in step.movements:
		assert_int(movement.side).is_equal(AWAY)
	# 攻撃側は変わらず、入力も書き換えない
	assert_dict(_areas_of(step.pair.attacker)).is_equal({"a1": "M-C"})
	assert_dict(_areas_of(pair.defender)).is_equal({"d1": "M-C", "d2": "D-L2", "d3": "M-R2"})
	assert_bool(pair.defender.players[0].is_fixed()).is_true()


func test_retreat_with_the_ball_in_the_center_lane_returns_to_the_base_layout() -> void:
	var pair := LayoutPair.new(_layout([["a1", "M-C", ""]]), _retreating_defender(), HOME)
	var step: LayoutStep = StyleLayoutCalculator.retreat(pair, _styles(ZONE, COUNTER), _area("D-C"))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"d1": "D-C", "d2": "D-L1", "d3": "M-R2"})


func test_retreat_with_man_marks_the_attackers_where_they_are_now() -> void:
	# 攻撃側 a1 は A-C（守備側から見て D-C）。m1（基本 M-L1、A-L2 に固定）は固定が解けてマーカーになる。f は基本が A で残る。
	# m1 は D-C へ一気に戻らず、1マス（M-L1）だけ近づく（2026-10-24。1ターン1マス）
	var players: Array[PlayerState] = [
		PlayerState.new("m1", _area("M-L1"), _area("A-L2")),
		PlayerState.new("f", _area("A-C")),
	]
	var defender := TeamLayout.new(players, {"m1": _area("A-L2"), "f": _area("A-C")})
	var pair := LayoutPair.new(_layout([["a1", "A-C", ""]]), defender, AWAY)
	var step: LayoutStep = StyleLayoutCalculator.retreat(pair, _styles(MAN, COUNTER), _area("M-C"))
	assert_dict(_areas_of(step.pair.defender)).is_equal({"m1": "M-L1", "f": "A-C"})
	assert_array(_moves(step)).is_equal(["m1:A-L2>M-L1:RETREAT_RESET"])
	assert_int(step.movements[0].side).is_equal(HOME)

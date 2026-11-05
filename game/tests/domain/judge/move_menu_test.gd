## 画面に出す手（MoveMenu。2026-11-03 の手の選択の簡素化）のテスト。
## 期待値は design.md「ゲームが行き先を選ぶ規則」と functional-overview.md アルゴリズム3〜5の規則から手で数えた。
## 運ぶ先は判定時の攻撃側（HOME）の視点、選手のエリアは各チーム自身の視点。方式の動きで位置がずれないよう、選手はすべて固定する。
extends GdUnitTestSuite

const HOME := GameEnums.TeamSide.HOME
const AWAY := GameEnums.TeamSide.AWAY
const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const POS_TRANS := GameEnums.ChoiceFamily.POS_TRANS
const ZONE := GameEnums.DefenseStyle.ZONE
const POSSESSION := GameEnums.AttackStyle.POSSESSION


func _area(key: String) -> PitchArea:
	return PitchArea.from_key(key)


## keys は各選手のエリア（固定）。ID は prefix と並びの番号
func _players(prefix: String, keys: Array) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for index: int in range(keys.size()):
		var area: PitchArea = _area(keys[index] as String)
		players.append(PlayerState.new("%s%d" % [prefix, index], area, area.duplicate_deep()))
	return players


## HOME が保持する攻守ターン。away_keys は AWAY 自身の視点
func _open_state(home_keys: Array, away_keys: Array, ball_key: String) -> MatchState:
	var state := MatchState.new()
	state.possession = HOME
	state.ball_area = _area(ball_key)
	state.home_setup = TeamSetup.new("x", TeamStyles.new(ZONE, POSSESSION))
	state.away_setup = TeamSetup.new("y", TeamStyles.new(ZONE, POSSESSION))
	state.home_players = _players("h", home_keys)
	state.away_players = _players("a", away_keys)
	return state


func _keys(areas: Array[PitchArea]) -> Array[String]:
	var keys: Array[String] = []
	for area: PitchArea in areas:
		keys.append(area.to_key())
	return keys


## ボール M1-C。味方 M2-L1・M2-R1・D2-C、相手は HOME の視点で M2-R1・M2-C・A2-C（AWAY の視点で M1-L1・M1-C・D1-C）
func _midfield_state() -> MatchState:
	return _open_state(["M1-C", "M2-L1", "M2-R1", "D2-C"], ["M1-L1", "M1-C", "D1-C"], "M1-C")


func test_attack_menu_keeps_one_move_per_slot_with_the_best_destination() -> void:
	var menu: MoveOptions = MoveMenu.options_for(_midfield_state(), HOME)
	# ショートパスの枠: 普通のショートパス（M2-L1 は +1・1列前）より、スルーパス（走り込んだ後 +1・2列前）が有利。
	# 2列前の A1-L1・A1-C・A1-R1 は並ぶので、候補の順で先の A1-L1
	assert_bool(menu.is_available(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_false()
	assert_array(_keys(menu.targets(ATTACK, GameEnums.PlayType.THROUGH_PASS))).is_equal(["A1-L1"])
	# ドリブル: M2-L1（味方と2対0・1列前）が、D2-C（2対0・1列後ろ）と M2-R1（2対1）より有利
	assert_array(_keys(menu.targets(ATTACK, GameEnums.PlayType.DRIBBLE))).is_equal(["M2-L1"])
	# 4つ目の枠: ペナルティエリアの外なのでバックパス（1列後ろの味方 D2-C）
	assert_array(_keys(menu.targets(ATTACK, GameEnums.PlayType.BACK_PASS))).is_equal(["D2-C"])
	assert_bool(menu.is_available(ATTACK, GameEnums.PlayType.SHOT)).is_false()
	# ロングパスの枠: 敵陣の奥にも、同じ列の3レーン以上横にも味方がいないので出ない
	assert_bool(menu.is_available(ATTACK, GameEnums.PlayType.LONG_BEHIND)).is_false()
	assert_bool(menu.is_available(ATTACK, GameEnums.PlayType.SWITCH)).is_false()


func test_defense_menu_cuts_the_predicted_short_pass_and_the_predicted_dribble() -> void:
	var menu: MoveOptions = MoveMenu.options_for(_midfield_state(), AWAY)
	# パスコースを切る: 予測先は攻撃のショートパスの枠の A1-L1。そこへはプレスできない（守備側の視点 D2-R1 の上下左右に味方がいない）ので、
	# プレスできるエリアのうち A1-L1 にいちばん近い（1マス）もので、候補の順で先の M2-L1
	assert_array(_keys(menu.targets(DEFENSE, GameEnums.DefenseAction.PRESS))).is_equal(["M2-L1"])
	# ドリブルのコースを切る（2026-11-05）: 予測先は攻撃のドリブルの枠の M2-L1。そこへ寄せられる（守備側の視点 M1-R1 の隣の M1-C に味方）
	assert_array(_keys(menu.targets(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN))).is_equal(["M2-L1"])
	# 背後を埋める: 攻撃にロングパスの枠が無いので出ない。シュートコースを塞ぐ: ペナルティエリアの外なので出ない
	assert_bool(menu.is_available(DEFENSE, GameEnums.DefenseAction.COVER)).is_false()
	assert_bool(menu.is_available(DEFENSE, GameEnums.DefenseAction.BLOCK_SHOT)).is_false()


func test_cutting_the_passing_lane_follows_the_dribble_when_there_is_no_short_pass() -> void:
	# ボール M1-C に1人だけ（パスの受け手がいない）。相手は HOME の視点で M2-C（AWAY の視点で M1-C）。
	# 攻撃はドリブルだけ: M2-C は 1対1、ほかは 1対0。前へ1列で 1対0 の M2-L1・M2-R1 のうち、候補の順で先の M2-L1
	var state: MatchState = _open_state(["M1-C"], ["M1-C"], "M1-C")
	var attack: MoveOptions = MoveMenu.options_for(state, HOME)
	assert_array(_keys(attack.targets(ATTACK, GameEnums.PlayType.DRIBBLE))).is_equal(["M2-L1"])
	assert_bool(attack.is_available(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_false()
	assert_bool(attack.is_available(ATTACK, GameEnums.PlayType.THROUGH_PASS)).is_false()
	# パスコースを切るは、ショートパスの枠が無いのでドリブルの行き先 M2-L1 を予測先にする（AWAY の視点 M1-R1 の隣の M1-C に味方がいて寄せられる）。
	# 守備の手が1つも無くならない
	var defense: MoveOptions = MoveMenu.options_for(state, AWAY)
	assert_array(_keys(defense.targets(DEFENSE, GameEnums.DefenseAction.PRESS))).is_equal(["M2-L1"])


func test_long_pass_slot_prefers_the_better_numbers_and_cover_takes_the_nearest_area() -> void:
	# ボール M1-L1。味方 M1-R2（サイドチェンジ: 1対0）と A1-L1（ロングボール: 相手が1人いて 1対1）。
	# 相手は HOME の視点で A1-L1（AWAY の視点で D2-R1）
	var state: MatchState = _open_state(["M1-L1", "M1-R2", "A1-L1"], ["D2-R1"], "M1-L1")
	var attack: MoveOptions = MoveMenu.options_for(state, HOME)
	# 人数差（+1 と ±0）が、前進の列数（0 列と 3 列）より先に効く
	assert_array(_keys(attack.targets(ATTACK, GameEnums.PlayType.SWITCH))).is_equal(["M1-R2"])
	assert_bool(attack.is_available(ATTACK, GameEnums.PlayType.LONG_BEHIND)).is_false()
	var defense: MoveOptions = MoveMenu.options_for(state, AWAY)
	# 背後を埋める: 予測先 M1-R2 へはカバーできない。カバーできるエリア（AWAY の視点 D2-C・D2-R1・D2-R2・M1-R1 = HOME の視点
	# A1-C・A1-L1・A1-L2・M2-L1）のうち、M1-R2 にいちばん近い（2マス）A1-C
	assert_array(_keys(defense.targets(DEFENSE, GameEnums.DefenseAction.COVER))).is_equal(["A1-C"])
	# ドリブルのコースを切る: 攻撃のドリブルの枠は M2-L2（どこへ運んでも 1対0。前へ1列で、候補の順で先）。そこへは寄せられないので、
	# 寄せられるエリア（HOME の視点 M2-L1・A1-L2・A1-C・A2-L1）のうち M2-L2 にいちばん近い（1マス）もので、候補の順で先の M2-L1
	assert_array(_keys(defense.targets(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN))).is_equal(["M2-L1"])


func test_penalty_area_offers_shot_instead_of_back_pass_and_the_defense_can_block_it() -> void:
	# ボール A2-C（ペナルティエリア）。1列後ろの A1-C に味方がいても、バックパスは出さない。相手は AWAY の視点 D2-C（HOME の視点 A1-C）
	var state: MatchState = _open_state(["A2-C", "A1-C"], ["D2-C"], "A2-C")
	var attack: MoveOptions = MoveMenu.options_for(state, HOME)
	assert_bool(attack.is_available(ATTACK, GameEnums.PlayType.SHOT)).is_true()
	assert_bool(attack.is_available(ATTACK, GameEnums.PlayType.BACK_PASS)).is_false()
	var defense: MoveOptions = MoveMenu.options_for(state, AWAY)
	assert_array(_keys(defense.targets(DEFENSE, GameEnums.DefenseAction.BLOCK_SHOT))).is_equal(["A2-C"])
	# ドリブルのコースを切る: 攻撃のドリブルの枠は A2-L1（1対0・同じ列。A1-C は 2対1 で同じ +1 だが後ろ）。寄せられるエリア
	# （M2-C・A1-L1・A1-R1・A2-C）のうち A2-L1 にいちばん近い（1マス）もので、候補の順で先の A1-L1
	assert_array(_keys(defense.targets(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN))).is_equal(["A1-L1"])


func test_counter_takes_the_best_destination_and_secure_stays() -> void:
	# HOME が奪取側。ボール D2-C。味方 M1-C（相手と 1対1）と A1-C（1対0・3列前）。相手は AWAY の視点 M2-C（HOME の視点 M1-C）
	var state: MatchState = _open_state(["D2-C", "M1-C", "A1-C"], ["M2-C"], "D2-C")
	state.turn_kind = GameEnums.TurnKind.TRANSITION
	state.transition_origin = LayoutPair.new(TeamLayout.from_players(state.home_players),
			TeamLayout.from_players(state.away_players), HOME)
	var menu: MoveOptions = MoveMenu.options_for(state, HOME)
	assert_array(_keys(menu.targets(POS_TRANS, GameEnums.PosTransAction.COUNTER))).is_equal(["A1-C"])
	assert_bool(menu.is_available(POS_TRANS, GameEnums.PosTransAction.SECURE)).is_true()


func test_slots_group_the_moves_by_button() -> void:
	assert_array(MoveMenu.slot_actions(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_equal(
			[GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.THROUGH_PASS])
	assert_array(MoveMenu.slot_actions(ATTACK, GameEnums.PlayType.SWITCH)).is_equal(
			[GameEnums.PlayType.LONG_BEHIND, GameEnums.PlayType.SWITCH])
	assert_array(MoveMenu.slot_actions(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN)).is_equal(
			[GameEnums.DefenseAction.CLOSE_DOWN])
	# 攻撃と守備で、読みが対応する手を同じ位置にそろえる
	assert_int(MoveMenu.slot_index(ATTACK, GameEnums.PlayType.THROUGH_PASS)).is_equal(
			MoveMenu.slot_index(DEFENSE, GameEnums.DefenseAction.PRESS))
	assert_int(MoveMenu.slot_index(ATTACK, GameEnums.PlayType.DRIBBLE)).is_equal(
			MoveMenu.slot_index(DEFENSE, GameEnums.DefenseAction.CLOSE_DOWN))
	assert_int(MoveMenu.slot_index(ATTACK, GameEnums.PlayType.SHOT)).is_equal(
			MoveMenu.slot_index(DEFENSE, GameEnums.DefenseAction.BLOCK_SHOT))

## MatchTexts（試合の画面の文言。.steering/20261019-match-screen/design.md §2）のテスト。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG := GameEnums.ChoiceFamily.NEG_TRANS
const POS := GameEnums.ChoiceFamily.POS_TRANS


func test_area_names_use_zone_and_lane_from_the_user_view() -> void:
	assert_str(MatchTexts.area_name("M1-C")).is_equal("中盤（自陣）・中央")
	assert_str(MatchTexts.area_name("M2-L1")).is_equal("中盤（敵陣）・左HS")
	assert_str(MatchTexts.area_name("D2-L2")).is_equal("自陣・左大外")
	assert_str(MatchTexts.area_name("A1-R1")).is_equal("敵陣・右HS")
	assert_str(MatchTexts.area_name("A2-R2")).is_equal("敵陣ゴール前・右大外")
	assert_str(MatchTexts.area_name("D1-C")).is_equal("自陣ゴール前・中央")


func test_area_names_are_unique_over_the_thirty_areas() -> void:
	var names: Dictionary = {}
	for area: PitchArea in PitchArea.all():
		names[MatchTexts.area_name(area.to_key())] = true
	assert_int(names.size()).is_equal(30)


func test_an_unknown_area_key_is_shown_as_is() -> void:
	assert_str(MatchTexts.area_name("X-9")).is_equal("X-9")


func test_lane_names_go_from_left_wide_to_right_wide() -> void:
	var expected: Array[String] = ["左大外", "左HS", "中央", "右HS", "右大外"]
	for lane: int in GameEnums.Lane.values():
		assert_str(MatchTexts.lane_name(lane as GameEnums.Lane)).is_equal(expected[lane])


func test_action_names_cover_every_family() -> void:
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.SHORT_PASS)).is_equal("ショートパス")
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.DRIBBLE)).is_equal("ドリブル")
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.LONG_BEHIND)).is_equal("背後へのロングボール")
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.SWITCH)).is_equal("サイドチェンジ")
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.SHOT)).is_equal("シュート")
	assert_str(MatchTexts.action_name(DEFENSE, GameEnums.DefenseAction.PRESS)).is_equal("プレス")
	assert_str(MatchTexts.action_name(DEFENSE, GameEnums.DefenseAction.COVER)).is_equal("カバー")
	assert_str(MatchTexts.action_name(NEG, GameEnums.NegTransAction.COUNTER_PRESS)).is_equal("即時奪回")
	assert_str(MatchTexts.action_name(NEG, GameEnums.NegTransAction.RETREAT)).is_equal("リトリート")
	assert_str(MatchTexts.action_name(POS, GameEnums.PosTransAction.COUNTER)).is_equal("カウンター")
	assert_str(MatchTexts.action_name(POS, GameEnums.PosTransAction.SECURE)).is_equal("保持")


func test_choice_summary_has_the_target_only_when_the_move_has_one() -> void:
	var pass_choice := TurnChoice.new(ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("M1-C"))
	assert_str(MatchTexts.choice_summary(pass_choice)).is_equal("ショートパス → 中盤（自陣）・中央")
	var shot := TurnChoice.new(ATTACK, GameEnums.PlayType.SHOT)
	assert_str(MatchTexts.choice_summary(shot)).is_equal("シュート")


func test_phase_tags_follow_the_turn_kind_and_possession() -> void:
	assert_str(MatchTexts.phase_tag(GameEnums.TurnKind.OPEN_PLAY, true)).is_equal("ATTACK 攻撃")
	assert_str(MatchTexts.phase_tag(GameEnums.TurnKind.OPEN_PLAY, false)).is_equal("DEFENSE 守備")
	assert_str(MatchTexts.phase_tag(GameEnums.TurnKind.TRANSITION, true)).is_equal("POS.TRANSITION ポジティブトランジション")
	assert_str(MatchTexts.phase_tag(GameEnums.TurnKind.TRANSITION, false)).is_equal("NEG.TRANSITION ネガティブトランジション")


func test_outcome_labels_pair_the_code_and_the_japanese_name() -> void:
	var expected: Dictionary = {
		GameEnums.TurnOutcome.ADVANCE: "ADVANCE 前進",
		GameEnums.TurnOutcome.STALL: "STALL 膠着",
		GameEnums.TurnOutcome.LOSS: "LOSS ロスト",
		GameEnums.TurnOutcome.GOAL: "GOAL 得点",
		GameEnums.TurnOutcome.SAVE: "SAVE シュート阻止",
		GameEnums.TurnOutcome.REGAIN: "REGAIN 奪回成功",
		GameEnums.TurnOutcome.REGAIN_FAILED: "REGAIN_FAILED 奪回失敗",
		GameEnums.TurnOutcome.NO_CONTEST: "NO_CONTEST 判定なし",
	}
	assert_int(expected.size()).is_equal(GameEnums.TurnOutcome.size())
	for outcome: int in expected:
		assert_str(MatchTexts.outcome_label(outcome as GameEnums.TurnOutcome)).is_equal(expected[outcome] as String)


func test_setup_text_names_the_formation_and_both_styles() -> void:
	var setup := TeamSetup.new("4-3-3", TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER))
	assert_str(MatchTexts.setup_text(setup)).is_equal("4-3-3 ゾーン・カウンター型")
	setup = TeamSetup.new("3-5-2", TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION))
	assert_str(MatchTexts.setup_text(setup)).is_equal("3-5-2 マンツーマン・保持型")


func test_hint_tag_shows_the_difference_and_the_cover_only_when_even() -> void:
	var hint := ChoiceHint.new(ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("M2-C"), true, 2, 1,
			GameEnums.CoverKind.NONE)
	assert_str(MatchTexts.hint_tag(hint)).is_equal("+1")
	hint.own_count = 1
	hint.opponent_count = 3
	assert_str(MatchTexts.hint_tag(hint)).is_equal("−2")
	hint.opponent_count = 1
	assert_str(MatchTexts.hint_tag(hint)).is_equal("±0")
	hint.cover = GameEnums.CoverKind.DEFENDER
	assert_str(MatchTexts.hint_tag(hint)).is_equal("±0 カバーあり")
	assert_str(MatchTexts.hint_counts(hint)).is_equal("1対1")


func test_hint_of_an_uncompared_move_has_no_tag() -> void:
	var retreat := ChoiceHint.new(NEG, GameEnums.NegTransAction.RETREAT, null, false, 0, 0, GameEnums.CoverKind.NONE)
	assert_str(MatchTexts.hint_tag(retreat)).is_empty()
	assert_str(MatchTexts.hint_counts(retreat)).is_empty()


func _reveal_of(role: GameEnums.Phase, outcome: GameEnums.TurnOutcome) -> RevealView:
	var reveal := RevealView.new()
	reveal.user_role = role
	reveal.outcome = outcome
	return reveal


func test_turn_winner_is_the_side_whose_action_succeeded() -> void:
	# [利用者の役割, 結果, 成功した側]。攻撃側（トランジションは奪った側）の成功は前進・得点・奪い返しの失敗、
	# 守備側の成功は膠着・奪取・セーブ・奪い返し。奪い合いの無い NO_CONTEST はどちらでもない
	var you := MatchTexts.TurnWinner.USER
	var cpu := MatchTexts.TurnWinner.OPPONENT
	var none := MatchTexts.TurnWinner.NONE
	var cases: Array = [
		[GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, you],
		[GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.GOAL, you],
		[GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.STALL, cpu],
		[GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, cpu],
		[GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.SAVE, cpu],
		[GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.ADVANCE, cpu],
		[GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.GOAL, cpu],
		[GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.STALL, you],
		[GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.LOSS, you],
		[GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.SAVE, you],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.ADVANCE, you],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.REGAIN_FAILED, you],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.REGAIN, cpu],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.STALL, cpu],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.LOSS, cpu],
		[GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.NO_CONTEST, none],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.REGAIN, you],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.REGAIN_FAILED, cpu],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.ADVANCE, cpu],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.STALL, you],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.LOSS, you],
		[GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.NO_CONTEST, none],
	]
	for case: Array in cases:
		var reveal: RevealView = _reveal_of(case[0] as GameEnums.Phase, case[1] as GameEnums.TurnOutcome)
		assert_int(MatchTexts.turn_winner(reveal)).override_failure_message("%s %s" % [
			GameEnums.Phase.find_key(case[0]), GameEnums.TurnOutcome.find_key(case[1])]).is_equal(case[2] as int)


func test_outcome_tag_marks_the_successful_side_with_its_piece_symbol() -> void:
	# 色だけに頼らず、駒と同じ記号（自分 ●・相手 ◆）でも示す
	assert_str(MatchTexts.outcome_tag(_reveal_of(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE))) \
			.is_equal("● ADVANCE 前進")
	assert_str(MatchTexts.outcome_tag(_reveal_of(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS))) \
			.is_equal("◆ LOSS ロスト")
	assert_str(MatchTexts.outcome_tag(_reveal_of(GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.NO_CONTEST))) \
			.is_equal(MatchTexts.outcome_label(GameEnums.TurnOutcome.NO_CONTEST))


func test_possession_text_names_the_side_with_the_ball_and_its_piece_symbol() -> void:
	assert_str(MatchTexts.possession_text(true)).is_equal("● 自分のボール")
	assert_str(MatchTexts.possession_text(false)).is_equal("◆ CPU のボール")


func test_clock_text_shows_the_half_and_the_turn() -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.half = 1
	snapshot.turn_number = 5
	snapshot.turns_per_half = 15
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("前半 5／15")
	snapshot.half = 2
	snapshot.turn_number = 15
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("後半 15／15")
	# ハーフを終えた後の盤面（turn_number は1つ先に進む）は、最後に行ったターンとして出す
	snapshot.turn_number = 16
	snapshot.is_half_over = true
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("後半 15／15")


func test_clock_text_shows_additional_time_as_plus_turns() -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.half = 1
	snapshot.turns_per_half = 15
	# アディショナルタイムの1ターン目・2ターン目
	snapshot.turn_number = 16
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("前半 15＋1")
	snapshot.turn_number = 17
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("前半 15＋2")
	# アディショナルタイムの2ターン目でハーフを終えた後も、そのターンを出す
	snapshot.turn_number = 18
	snapshot.is_half_over = true
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("前半 15＋2")


func test_target_rule_explains_who_moves_and_which_areas_can_be_chosen_for_press_and_cover() -> void:
	# シャビの「カバーで選べないマスがあるのはなぜ？」への一言（MoveRules.defense_options の条件と同じ内容）
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.PRESS)) \
			.is_equal("プレス: 隣のエリアの味方1人が、選んだエリアへ寄せる。隣に味方がいるエリアだけ選べる")
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.COVER)) \
			.is_equal("カバー: 味方1人が、選んだエリアの背後へ下がる。自陣ゴール前の列と、その場にも横にも背後にも味方がいないエリアは選べない（前にいる味方は届かない）")
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.DRIBBLE)).is_empty()
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.COUNTER)).is_empty()


func test_target_rule_explains_the_through_pass() -> void:
	# スルーパス（2026-10-25）は、出せる先と、人数に関係なく読みで決まることを一言で（MoveRules・OpenPlayJudge と同じ内容）
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.THROUGH_PASS)) \
			.is_equal("スルーパス: 1〜2列前の、味方が走り込めるエリアへ出す（空いていてもよい）。人数に関係なく、読まれたら奪われ、読まれなければ通る")


func test_through_pass_hint_tag_says_it_depends_on_the_read() -> void:
	# 人数を比べない手だが、スルーパスは通るかが読み次第であることを札で示す。人数の表記は出さない
	var hint := ChoiceHint.new(ATTACK, GameEnums.PlayType.THROUGH_PASS, PitchArea.from_key("A1-C"), false, 1, 2,
			GameEnums.CoverKind.NONE)
	assert_str(MatchTexts.hint_tag(hint)).is_equal("読み次第")
	assert_str(MatchTexts.hint_counts(hint)).is_empty()
	assert_str(MatchTexts.action_name(ATTACK, GameEnums.PlayType.THROUGH_PASS)).is_equal("スルーパス")

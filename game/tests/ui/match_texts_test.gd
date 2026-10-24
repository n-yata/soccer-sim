## MatchTexts（試合の画面の文言。.steering/20261019-match-screen/design.md §2）のテスト。
extends GdUnitTestSuite

const ATTACK := GameEnums.ChoiceFamily.ATTACK
const DEFENSE := GameEnums.ChoiceFamily.DEFENSE
const NEG := GameEnums.ChoiceFamily.NEG_TRANS
const POS := GameEnums.ChoiceFamily.POS_TRANS


func test_area_names_use_zone_and_lane_from_the_user_view() -> void:
	assert_str(MatchTexts.area_name("M-C")).is_equal("中盤・中央")
	assert_str(MatchTexts.area_name("M-L1")).is_equal("中盤・左HS")
	assert_str(MatchTexts.area_name("D-L2")).is_equal("自陣・左大外")
	assert_str(MatchTexts.area_name("A-R1")).is_equal("敵陣・右HS")
	assert_str(MatchTexts.area_name("A-R2")).is_equal("敵陣・右大外")


func test_area_names_are_unique_over_the_fifteen_areas() -> void:
	var names: Dictionary = {}
	for area: PitchArea in PitchArea.all():
		names[MatchTexts.area_name(area.to_key())] = true
	assert_int(names.size()).is_equal(15)


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
	var pass_choice := TurnChoice.new(ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("M-C"))
	assert_str(MatchTexts.choice_summary(pass_choice)).is_equal("ショートパス → 中盤・中央")
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
	var hint := ChoiceHint.new(ATTACK, GameEnums.PlayType.SHORT_PASS, PitchArea.from_key("M-C"), true, 2, 1,
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


func test_clock_text_shows_the_half_and_the_turn() -> void:
	var snapshot := BoardSnapshot.new()
	snapshot.half = 1
	snapshot.turn_number = 5
	snapshot.turns_per_half = 12
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("前半 5／12")
	snapshot.half = 2
	snapshot.turn_number = 12
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("後半 12／12")
	# ハーフの最終ターンを終えた後の盤面（turn_number は1つ先に進む）も、最終ターンとして出す
	snapshot.turn_number = 13
	assert_str(MatchTexts.clock_text(snapshot)).is_equal("後半 12／12")


func test_target_rule_explains_who_moves_and_which_areas_can_be_chosen_for_press_and_cover() -> void:
	# シャビの「カバーで選べないマスがあるのはなぜ？」への一言（MoveRules.defense_options の条件と同じ内容）
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.PRESS)) \
			.is_equal("プレス: 隣のエリアの味方1人が、選んだエリアへ寄せる。隣に味方がいるエリアだけ選べる")
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.COVER)) \
			.is_equal("カバー: 味方1人が、選んだエリアの背後へ下がる。自陣の列と、その場にも横にも背後にも味方がいないエリアは選べない（前にいる味方は届かない）")
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.DRIBBLE)).is_empty()
	assert_str(MatchTexts.target_rule(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.COUNTER)).is_empty()

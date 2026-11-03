## ReviewTexts（振り返り S-07 の文言）のテスト。期待値は screen-07-review.md・screen-design.md「S-07」の表示の形から手で書いた。
extends GdUnitTestSuite


func _setup(formation_id: String, defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(defense, attack))


func test_tally_text_lists_only_nonzero_counts() -> void:
	assert_str(ReviewTexts.tally_text([3, 1, 1])).is_equal("勝3 負1 膠1")
	assert_str(ReviewTexts.tally_text([0, 2, 0])).is_equal("負2")
	assert_str(ReviewTexts.tally_text([1, 0, 4])).is_equal("勝1 膠4")
	assert_str(ReviewTexts.tally_text([0, 0, 0])).is_empty()


func test_phase_counts_text_says_when_the_phase_did_not_happen() -> void:
	assert_str(ReviewTexts.phase_counts_text([3, 1, 0])).is_equal("勝 3　負 1　膠着 0")
	assert_str(ReviewTexts.phase_counts_text([0, 0, 1])).is_equal("勝 0　負 0　膠着 1")
	assert_str(ReviewTexts.phase_counts_text([0, 0, 0])).is_equal("この試合では起きなかった")


func test_phase_names_follow_the_enum_order() -> void:
	assert_str(ReviewTexts.phase_name(GameEnums.Phase.ATTACK)).is_equal("攻撃")
	assert_str(ReviewTexts.phase_name(GameEnums.Phase.NEG_TRANSITION)).is_equal("ネガティブトランジション")
	assert_str(ReviewTexts.phase_name(GameEnums.Phase.DEFENSE)).is_equal("守備")
	assert_str(ReviewTexts.phase_name(GameEnums.Phase.POS_TRANSITION)).is_equal("ポジティブトランジション")


func test_turn_text_shows_additional_time_after_the_regular_turns() -> void:
	assert_str(ReviewTexts.turn_text(1, 6, 15)).is_equal("前半 6")
	assert_str(ReviewTexts.turn_text(2, 15, 15)).is_equal("後半 15")
	assert_str(ReviewTexts.turn_text(2, 17, 15)).is_equal("後半 15＋2")


func test_goal_title_marks_goals_and_conceded_goals_with_a_symbol_and_a_word() -> void:
	var scored: Dictionary = {"is_user": true, "half": 1, "turn_number": 6, "score_user": 1, "score_opponent": 0}
	var conceded: Dictionary = {"is_user": false, "half": 2, "turn_number": 16, "score_user": 1, "score_opponent": 1}
	assert_str(ReviewTexts.goal_title(scored, 15)).is_equal("▲ 得点 前半 6ターン目（1 − 0）")
	assert_str(ReviewTexts.goal_title(conceded, 15)).is_equal("▼ 失点 後半 15＋1ターン目（1 − 1）")


func test_segment_text_names_both_setups_and_the_span() -> void:
	var segment: Dictionary = {"half": 1, "from_turn": 1, "to_turn": 6,
			"user_setup": _setup("4-3-3", GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.POSSESSION),
			"opponent_setup": _setup("4-4-2", GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)}
	assert_str(ReviewTexts.segment_text(segment, 15)) \
			.is_equal("前半 1〜6ターン: ● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型")
	segment["half"] = 2
	segment["from_turn"] = 14
	segment["to_turn"] = 17
	assert_str(ReviewTexts.segment_text(segment, 15)) \
			.is_equal("後半 14〜15＋2ターン: ● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型")
	segment["to_turn"] = 14
	assert_str(ReviewTexts.segment_text(segment, 15)).starts_with("後半 14ターン: ")


func test_turn_heading_and_choices_name_the_turn_the_phase_and_both_moves() -> void:
	var reveal := RevealView.new()
	reveal.half = 1
	reveal.turn_number = 5
	reveal.user_role = GameEnums.Phase.DEFENSE
	reveal.user_choice = TurnChoice.new(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.PRESS,
			PitchArea.from_key("M1-C"))
	reveal.opponent_choice = TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS,
			PitchArea.from_key("M1-C"))
	assert_str(ReviewTexts.turn_heading(reveal, 15)).is_equal("前半 5ターン目　守備")
	assert_str(ReviewTexts.choices_text(reveal)) \
			.is_equal("● 自分: パスコースを切る → 中盤（自陣）・中央\n◆ 相手: ショートパス → 中盤（自陣）・中央")


func test_no_goals_text_uses_the_minus_sign() -> void:
	assert_str(ReviewTexts.no_goals_text()).starts_with("この試合は 0 − 0 でした。")

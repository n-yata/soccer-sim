## ヒントの値オブジェクト（ChoiceHint）と CPU の調整値（CpuConfig）のテスト。
extends GdUnitTestSuite


func test_choice_hint_diff_is_own_minus_opponent() -> void:
	var hint := ChoiceHint.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS,
			PitchArea.from_key("M1-C"), true, 1, 2, GameEnums.CoverKind.NONE)
	assert_int(hint.diff()).is_equal(-1)
	assert_bool(hint.is_compared).is_true()


func test_choice_hint_duplicate_deep_copies_the_target() -> void:
	var hint := ChoiceHint.new(GameEnums.ChoiceFamily.DEFENSE, GameEnums.DefenseAction.COVER,
			PitchArea.from_key("A1-C"), true, 2, 2, GameEnums.CoverKind.DEFENDER)
	var copy: ChoiceHint = hint.duplicate_deep()
	assert_object(copy.target).is_not_same(hint.target)
	assert_str(copy.target.to_key()).is_equal("A1-C")
	assert_int(copy.cover).is_equal(GameEnums.CoverKind.DEFENDER)
	assert_int(copy.own_count).is_equal(2)


func test_choice_hint_without_target_copies_null() -> void:
	var hint := ChoiceHint.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE,
			null, false, 0, 0, GameEnums.CoverKind.NONE)
	assert_object(hint.duplicate_deep().target).is_null()
	assert_bool(hint.is_compared).is_false()


func test_cpu_config_defaults_match_the_external_settings_table() -> void:
	# functional-overview.md「設定値として外部化する値」の初期値
	var cpu := CpuConfig.new()
	assert_float(cpu.temperature).is_equal(0.5)
	assert_float(cpu.floor_probability).is_equal(0.05)
	assert_float(cpu.style_bonus).is_equal(1.0)

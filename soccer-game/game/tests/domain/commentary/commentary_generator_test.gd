## CommentaryGenerator（アルゴリズム9: 解説の導出。component-design.md §2.7）のテスト。
## ルールは手で組んだ小さなカタログで確かめる（本物のデータの組み合わせは tests/content/commentary_content_test.gd）。
extends GdUnitTestSuite


func _slot(slot_id: String, position_type: String, x: float, y: float) -> PlayerSlotDef:
	return PlayerSlotDef.new(slot_id, position_type, position_type, 1, x, y)


## 2トップ（FW 2人）の陣形。extra_tags でタグを足す
func _two_top(formation_id: String, extra_tags: Array[String] = []) -> FormationDef:
	var slots: Array[PlayerSlotDef] = [_slot(formation_id + "-gk", "GK", 50.0, 5.0),
			_slot(formation_id + "-f1", "FW", 40.0, 70.0), _slot(formation_id + "-f2", "FW", 60.0, 70.0)]
	return FormationDef.new(formation_id, formation_id, "テスト用", extra_tags, slots)


## 1トップ（FW 1人）の陣形
func _one_top(formation_id: String) -> FormationDef:
	var slots: Array[PlayerSlotDef] = [_slot(formation_id + "-gk", "GK", 50.0, 5.0),
			_slot(formation_id + "-f1", "FW", 50.0, 70.0)]
	return FormationDef.new(formation_id, formation_id, "テスト用", [] as Array[String], slots)


func _formation_rule(rule_id: String, theme: String, viewer_tags: Array[String],
		opponent_tags: Array[String]) -> MatchupRuleDef:
	var rule := MatchupRuleDef.new()
	rule.id = rule_id
	rule.kind = MatchupRuleDef.KIND_FORMATION
	rule.viewer_tags = viewer_tags
	rule.opponent_tags = opponent_tags
	rule.text = "文" + rule_id
	rule.theme = theme
	rule.principle_ids = ["TP-10"] as Array[String]
	rule.simplification_ids = ["SIM-0" + rule_id.right(1)] as Array[String]
	return rule


func _style_rule(rule_id: String, viewer_style: String, opponent_style: String) -> MatchupRuleDef:
	var rule := MatchupRuleDef.new()
	rule.id = rule_id
	rule.kind = MatchupRuleDef.KIND_STYLE
	rule.viewer_style = viewer_style
	rule.opponent_style = opponent_style
	rule.text = "文" + rule_id
	rule.theme = rule_id
	rule.principle_ids = ["TP-04"] as Array[String]
	return rule


func _style(style_id: String, kind: String) -> StyleDef:
	var style := StyleDef.new()
	style.id = style_id
	style.kind = kind
	style.name = "名前" + style_id
	style.summary = "特徴" + style_id
	style.strengths = "強み" + style_id
	style.weaknesses = "弱み" + style_id
	style.principle_ids = ["TP-0" + str(style_id.length() % 9 + 1)] as Array[String]
	style.simplification_ids = ["SIM-07"] as Array[String]
	return style


func _catalog(rules: Array[MatchupRuleDef], fallback: MatchupNote = null) -> ContentCatalog:
	var styles: Array[StyleDef] = [_style("ZONE", StyleDef.KIND_DEFENSE), _style("MAN", StyleDef.KIND_DEFENSE),
			_style("POSSESSION", StyleDef.KIND_ATTACK), _style("COUNTER", StyleDef.KIND_ATTACK)]
	return ContentCatalog.new([] as Array[FormationDef], [] as Array[SimplificationDef], [] as Array[TutorialStepDef],
			[] as Array[PrincipleDef], [] as Array[QuizQuestionDef], styles, rules, fallback)


func _texts(notes: Array[MatchupNote]) -> Array[String]:
	var result: Array[String] = []
	for note: MatchupNote in notes:
		result.append(note.text)
	return result


func test_formation_rule_needs_all_viewer_and_opponent_tags() -> void:
	var rules: Array[MatchupRuleDef] = [
		_formation_rule("R1", "テーマ1", ["2トップ"] as Array[String], ["1トップ"] as Array[String]),
		_formation_rule("R2", "テーマ2", ["2トップ", "ライン間が空く"] as Array[String], [] as Array[String]),
		_formation_rule("R3", "テーマ3", ["1トップ"] as Array[String], ["2トップ"] as Array[String]),
	]
	var catalog := _catalog(rules)
	var notes: Array[MatchupNote] = CommentaryGenerator.formation_matchup(_two_top("a"), _one_top("b"), catalog)
	assert_array(_texts(notes)).is_equal(["文R1"])
	var with_extra: Array[MatchupNote] = CommentaryGenerator.formation_matchup(
			_two_top("a", ["ライン間が空く"] as Array[String]), _one_top("b"), catalog)
	assert_array(_texts(with_extra)).is_equal(["文R1", "文R2"])
	assert_array(_texts(CommentaryGenerator.formation_matchup(_one_top("b"), _two_top("a"), catalog))).is_equal(["文R3"])


func test_only_the_first_rule_of_a_theme_is_used() -> void:
	var rules: Array[MatchupRuleDef] = [
		_formation_rule("R1", "同じ", ["2トップ"] as Array[String], [] as Array[String]),
		_formation_rule("R2", "別", ["2トップ"] as Array[String], [] as Array[String]),
		_formation_rule("R3", "同じ", ["2トップ"] as Array[String], [] as Array[String]),
	]
	var notes: Array[MatchupNote] = CommentaryGenerator.formation_matchup(_two_top("a"), _two_top("b"), _catalog(rules))
	assert_array(_texts(notes)).is_equal(["文R1", "文R2"])


func test_note_keeps_principles_and_simplifications_of_the_rule() -> void:
	var rules: Array[MatchupRuleDef] = [_formation_rule("R5", "t", ["2トップ"] as Array[String], [] as Array[String])]
	var note: MatchupNote = CommentaryGenerator.formation_matchup(_two_top("a"), _two_top("b"), _catalog(rules))[0]
	assert_array(note.principle_ids).is_equal(["TP-10"])
	assert_array(note.simplification_ids).is_equal(["SIM-05"])
	assert_str(note.label).is_empty()


func test_fallback_is_used_when_no_formation_rule_matches() -> void:
	var rules: Array[MatchupRuleDef] = [_formation_rule("R1", "t", ["3トップ"] as Array[String], [] as Array[String])]
	var fallback := MatchupNote.new("目立ったズレは無い", ["TP-10"] as Array[String])
	var notes: Array[MatchupNote] = CommentaryGenerator.formation_matchup(_two_top("a"), _two_top("b"),
			_catalog(rules, fallback))
	assert_array(_texts(notes)).is_equal(["目立ったズレは無い"])
	assert_array(CommentaryGenerator.formation_matchup(_two_top("a"), _two_top("b"), _catalog(rules))).is_empty()


func test_style_rules_are_ignored_for_formations_and_formation_rules_for_styles() -> void:
	var rules: Array[MatchupRuleDef] = [_style_rule("S1", "ZONE", "POSSESSION"),
			_formation_rule("R1", "t", ["2トップ"] as Array[String], [] as Array[String])]
	var catalog := _catalog(rules)
	assert_array(_texts(CommentaryGenerator.formation_matchup(_two_top("a"), _two_top("b"), catalog))).is_equal(["文R1"])
	var viewer := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var opponent := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION)
	assert_array(_texts(CommentaryGenerator.style_matchup(viewer, opponent, catalog))).is_equal(["文S1"])


## 守備方式 × 相手の攻撃方式、攻撃方式 × 相手の守備方式の順（配列の順ではない）
func test_style_matchup_puts_defense_before_attack() -> void:
	var rules: Array[MatchupRuleDef] = [
		_style_rule("S5", "COUNTER", "MAN"),
		_style_rule("S2", "MAN", "COUNTER"),
		_style_rule("S9", "ZONE", "COUNTER"),
		_style_rule("S7", "POSSESSION", "MAN"),
	]
	var viewer := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	var opponent := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER)
	assert_array(_texts(CommentaryGenerator.style_matchup(viewer, opponent, _catalog(rules)))).is_equal(["文S2", "文S5"])


func test_formation_profile_is_feature_strengths_and_weaknesses() -> void:
	var formation := _two_top("a")
	formation.strengths = "強いところ"
	formation.weaknesses = "弱いところ"
	formation.principle_ids = ["TP-01"] as Array[String]
	var notes: Array[MatchupNote] = CommentaryGenerator.formation_profile(formation)
	assert_array(_texts(notes)).is_equal(["特徴: テスト用", "強み: 強いところ", "弱み: 弱いところ"])
	for note: MatchupNote in notes:
		assert_array(note.principle_ids).is_equal(["TP-01"])
		assert_array(note.simplification_ids).is_empty()


func test_style_profile_lists_one_style_with_its_simplifications() -> void:
	var catalog := _catalog([] as Array[MatchupRuleDef])
	var notes: Array[MatchupNote] = CommentaryGenerator.style_profile("MAN", catalog)
	assert_array(_texts(notes)).is_equal(["特徴: 特徴MAN", "強み: 強みMAN", "弱み: 弱みMAN"])
	assert_array(notes[0].simplification_ids).is_equal(["SIM-07"])
	assert_array(notes[0].principle_ids).is_equal(["TP-04"])


func test_style_profile_of_unknown_style_is_empty() -> void:
	assert_array(CommentaryGenerator.style_profile("NONE", _catalog([] as Array[MatchupRuleDef]))).is_empty()

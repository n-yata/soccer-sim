## CommentaryContentReader（data-definition.md §3.2・§3.3 の形と範囲）のテスト。
## 壊れたデータは、本物の styles.json・matchup_rules.json を1か所ずつ変えて作る（本物を写した fixture は古くなるため）。
extends GdUnitTestSuite

const CONTENT_DIR: String = "res://content"
const PRINCIPLE_IDS: Array[String] = ["TP-01", "TP-02", "TP-03", "TP-04", "TP-05", "TP-06", "TP-07", "TP-08", "TP-09",
		"TP-10"]
const SIMPLIFICATION_IDS: Array[String] = ["SIM-07"]


func _real(file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONTENT_DIR.path_join(file_name))) as Dictionary


func _style(root: Dictionary, index: int) -> Dictionary:
	return (root["styles"] as Array)[index] as Dictionary


func _rule(root: Dictionary, index: int) -> Dictionary:
	return (root["rules"] as Array)[index] as Dictionary


func _style_errors(root: Dictionary) -> Array[String]:
	var reader := CommentaryContentReader.new(PRINCIPLE_IDS, SIMPLIFICATION_IDS)
	var styles: Array[StyleDef] = reader.read_styles(root)
	if not reader.errors().is_empty():
		assert_array(styles).is_empty()
	return reader.errors()


func _rule_errors(root: Dictionary) -> Array[String]:
	var reader := CommentaryContentReader.new(PRINCIPLE_IDS, SIMPLIFICATION_IDS)
	var rules: Array[MatchupRuleDef] = reader.read_rules(root)
	if not reader.errors().is_empty():
		assert_array(rules).is_empty()
		assert_object(reader.fallback()).is_null()
	return reader.errors()


func _assert_one_error_at(errors: Array[String], location: String) -> void:
	assert_int(errors.size()).override_failure_message(str(errors)).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0]).starts_with(location)


func test_the_real_files_are_read_into_values() -> void:
	var reader := CommentaryContentReader.new(PRINCIPLE_IDS, SIMPLIFICATION_IDS)
	var styles: Array[StyleDef] = reader.read_styles(_real("styles.json"))
	assert_array(reader.errors()).is_empty()
	assert_int(styles.size()).is_equal(4)
	assert_str(styles[1].id).is_equal("MAN")
	assert_str(styles[1].kind).is_equal(StyleDef.KIND_DEFENSE)
	assert_str(styles[1].name).is_equal("マンツーマン")
	assert_str(styles[1].strengths).is_equal(_style(_real("styles.json"), 1)["strengths"] as String)
	assert_array(styles[1].simplification_ids).is_equal(["SIM-07"])
	var rules: Array[MatchupRuleDef] = reader.read_rules(_real("matchup_rules.json"))
	assert_array(reader.errors()).is_empty()
	assert_str(rules[0].id).is_equal("R08")
	assert_str(rules[0].kind).is_equal(MatchupRuleDef.KIND_FORMATION)
	assert_array(rules[0].viewer_tags).is_equal(["中盤実質5枚"])
	assert_array(rules[0].opponent_tags).is_equal(["中盤フラット4枚"])
	assert_str(rules[0].theme).is_equal("中盤の枚数")
	assert_array(rules[0].principle_ids).is_equal(["TP-02", "TP-10"])
	var style_rule: MatchupRuleDef = rules[rules.size() - 1]
	assert_str(style_rule.kind).is_equal(MatchupRuleDef.KIND_STYLE)
	assert_str(style_rule.viewer_style).is_equal("COUNTER")
	assert_str(style_rule.opponent_style).is_equal("MAN")
	assert_str(reader.fallback().text).is_equal(_real("matchup_rules.json")["fallback"]["text"] as String)
	assert_array(reader.fallback().principle_ids).is_equal(["TP-10"])


func test_styles_must_be_the_four_styles() -> void:
	var root: Dictionary = _real("styles.json")
	(root["styles"] as Array).remove_at(3)
	_assert_one_error_at(_style_errors(root), "styles:")
	root = _real("styles.json")
	_style(root, 3)["id"] = "MAN"
	var errors: Array[String] = _style_errors(root)
	assert_str(str(errors)).contains("styles[3].id: 重複: MAN")
	assert_str(str(errors)).contains("styles: COUNTER が無い")


func test_style_id_must_be_a_style_name() -> void:
	var root: Dictionary = _real("styles.json")
	_style(root, 0)["id"] = "PRESS"
	var errors: Array[String] = _style_errors(root)
	assert_str(errors[0]).starts_with("styles[0].id:")


func test_style_kind_must_match_the_style() -> void:
	var root: Dictionary = _real("styles.json")
	_style(root, 0)["kind"] = "ATTACK"
	_assert_one_error_at(_style_errors(root), "styles[0].kind:")


func test_style_texts_have_length_limits() -> void:
	var root: Dictionary = _real("styles.json")
	_style(root, 2)["name"] = "あ".repeat(21)
	_assert_one_error_at(_style_errors(root), "styles[2].name:")
	root = _real("styles.json")
	_style(root, 2)["weaknesses"] = ""
	_assert_one_error_at(_style_errors(root), "styles[2].weaknesses:")
	root = _real("styles.json")
	_style(root, 2)["summary"] = "あ".repeat(301)
	_assert_one_error_at(_style_errors(root), "styles[2].summary:")


func test_style_principles_must_exist_and_not_be_empty() -> void:
	var root: Dictionary = _real("styles.json")
	_style(root, 0)["principle_ids"] = []
	_assert_one_error_at(_style_errors(root), "styles[0].principle_ids:")
	root = _real("styles.json")
	_style(root, 0)["principle_ids"] = ["TP-99"]
	_assert_one_error_at(_style_errors(root), "styles[0].principle_ids[0]:")


func test_style_simplifications_must_exist() -> void:
	var root: Dictionary = _real("styles.json")
	_style(root, 0)["simplification_ids"] = ["SIM-99"]
	_assert_one_error_at(_style_errors(root), "styles[0].simplification_ids[0]:")


func test_rule_id_must_be_unique() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	_rule(root, 1)["id"] = "R08"
	_assert_one_error_at(_rule_errors(root), "rules[1].id:")


func test_rule_kind_must_be_known() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	_rule(root, 0)["kind"] = "PHASE"
	_assert_one_error_at(_rule_errors(root), "rules[0].kind:")


func test_formation_rule_tags_must_be_known_and_not_both_empty() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	(_rule(root, 0)["condition"] as Dictionary)["viewer_tags"] = ["5バック"]
	_assert_one_error_at(_rule_errors(root), "rules[0].condition.viewer_tags[0]:")
	root = _real("matchup_rules.json")
	_rule(root, 0)["condition"] = {"viewer_tags": [], "opponent_tags": []}
	_assert_one_error_at(_rule_errors(root), "rules[0].condition:")


func test_style_rule_needs_one_defense_and_one_attack_style() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	var last: int = (root["rules"] as Array).size() - 1
	_rule(root, last)["condition"] = {"viewer_style": "COUNTER", "opponent_style": "POSSESSION"}
	_assert_one_error_at(_rule_errors(root), "rules[%d].condition:" % last)
	root = _real("matchup_rules.json")
	_rule(root, last)["condition"] = {"viewer_style": "COUNTER", "opponent_style": "PRESS"}
	_assert_one_error_at(_rule_errors(root), "rules[%d].condition.opponent_style:" % last)


## 条件が空のオブジェクトだと、陣形のルールはどの組み合わせにも当たり、方式のルールは一度も当たらない。どちらも誤りにする
func test_an_empty_condition_is_an_error_for_both_kinds() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	_rule(root, 0)["condition"] = {}
	var errors: Array[String] = _rule_errors(root)
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("rules[0].condition."))) \
			.override_failure_message(str(errors)).is_true()
	root = _real("matchup_rules.json")
	var last: int = (root["rules"] as Array).size() - 1
	_rule(root, last)["condition"] = {}
	errors = _rule_errors(root)
	assert_bool(errors.any(func(e: String) -> bool: return e.begins_with("rules[%d].condition." % last))) \
			.override_failure_message(str(errors)).is_true()


func test_rule_texts_have_length_limits() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	_rule(root, 0)["text"] = "あ".repeat(301)
	_assert_one_error_at(_rule_errors(root), "rules[0].text:")
	root = _real("matchup_rules.json")
	_rule(root, 0)["theme"] = "あ".repeat(41)
	_assert_one_error_at(_rule_errors(root), "rules[0].theme:")


func test_rule_principles_and_simplifications_must_exist() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	_rule(root, 0)["principle_ids"] = []
	_assert_one_error_at(_rule_errors(root), "rules[0].principle_ids:")
	root = _real("matchup_rules.json")
	_rule(root, 0)["simplification_ids"] = ["SIM-99"]
	_assert_one_error_at(_rule_errors(root), "rules[0].simplification_ids[0]:")


func test_fallback_is_required_with_a_text_and_principles() -> void:
	var root: Dictionary = _real("matchup_rules.json")
	root.erase("fallback")
	_assert_one_error_at(_rule_errors(root), "fallback:")
	root = _real("matchup_rules.json")
	(root["fallback"] as Dictionary)["principle_ids"] = ["TP-99"]
	_assert_one_error_at(_rule_errors(root), "fallback.principle_ids[0]:")


func test_top_level_must_be_an_object_with_the_format_version() -> void:
	var errors: Array[String] = _rule_errors({})
	assert_str(str(errors)).contains("format_version: 整数でない")
	assert_str(str(errors)).contains("rules: 配列でない")
	var reader := CommentaryContentReader.new(PRINCIPLE_IDS, SIMPLIFICATION_IDS)
	reader.read_styles(null)
	assert_array(reader.errors()).is_equal(["(最上位): オブジェクトでない"])

## LibraryService（component-design.md §3.4）のテスト。陣形の一覧・基本配置の人数・噛み合わせの人数・解説（アルゴリズム9）。
extends GdUnitTestSuite


func _library() -> LibraryService:
	return LibraryService.new(ContentRepository.new().load_catalog())


func test_formations_are_the_four_mvp_formations_in_data_order() -> void:
	var ids: Array[String] = []
	for formation: FormationDef in _library().formations():
		ids.append(formation.id)
	assert_array(ids).is_equal(["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"] as Array[String])


func test_formations_returns_a_copy_of_the_list() -> void:
	var library: LibraryService = _library()
	library.formations().clear()
	assert_int(library.formations().size()).is_equal(4)


func test_base_counts_of_4_4_2_match_the_algorithm_1_table() -> void:
	# functional-overview.md アルゴリズム1の表の 4-4-2（レーンは L2 / L1 / C / R1 / R2）
	# 6列（2026-10-25）。陣形の座標をそのまま6列に当て、重なりを1マス1人に散らした値。空き列は0人
	var expected: Dictionary = {
		"A2": [0, 1, 0, 1, 0],
		"A1": [0, 0, 0, 0, 0],
		"M2": [1, 1, 0, 1, 1],
		"M1": [0, 0, 0, 0, 0],
		"D2": [1, 1, 0, 1, 1],
		"D1": [0, 0, 0, 0, 0],
	}
	var lanes: Array[String] = ["L2", "L1", "C", "R1", "R2"]
	var counts: Dictionary = _library().base_counts("4-4-2")
	assert_int(counts.size()).is_equal(30)
	for zone: String in expected:
		var row: Array = expected[zone]
		for i: int in lanes.size():
			var key: String = "%s-%s" % [zone, lanes[i]]
			assert_int(counts[key] as int).override_failure_message(key).is_equal(row[i] as int)


func test_base_counts_of_unknown_formation_is_empty() -> void:
	assert_dict(_library().base_counts("5-3-2")).is_empty()


func test_base_counts_of_unknown_formation_reports_an_error() -> void:
	var library: LibraryService = _library()
	await assert_error(func() -> void: library.base_counts("5-3-2")) \
			.is_push_error("LibraryService: 陣形が無い: 5-3-2")


func _rule_text(rule_id: String) -> String:
	for rule: MatchupRuleDef in ContentRepository.new().load_catalog().matchup_rules:
		if rule.id == rule_id:
			return rule.text
	return ""


func _labels_and_texts(notes: Array[MatchupNote]) -> Array[String]:
	var result: Array[String] = []
	for note: MatchupNote in notes:
		result.append("%s|%s" % [note.label, note.text])
	return result


## 4-4-2（利用者）と 3-5-2（相手）。相手の基本配置は相手の視点なので、利用者の視点へ鏡像にする
## （3-5-2 の D1-C の CB は利用者から見て A2-C、M1-L2 のウイングバックは M2-R2）
func test_matchup_counts_puts_both_teams_in_the_user_view() -> void:
	var counts: Dictionary = _library().matchup_counts("4-4-2", "3-5-2")
	assert_int(counts.size()).is_equal(30)
	var expected: Dictionary = {
		"A2-C": [0, 1], "A2-L1": [1, 0], "A1-L1": [0, 1], "M2-L2": [1, 1], "M2-C": [0, 1], "M2-R2": [1, 1],
		"M1-L1": [0, 1], "M1-L2": [0, 0], "D2-L2": [1, 0], "D1-R1": [0, 1], "D1-C": [0, 0],
	}
	for key: String in expected:
		assert_array(counts[key] as Array).override_failure_message(key).is_equal(expected[key] as Array)
	var user_total: int = 0
	var opponent_total: int = 0
	for key: String in counts:
		user_total += (counts[key] as Array)[0] as int
		opponent_total += (counts[key] as Array)[1] as int
	assert_int(user_total).is_equal(10)
	assert_int(opponent_total).is_equal(10)


func test_matchup_counts_of_unknown_formation_is_empty() -> void:
	var library: LibraryService = _library()
	await assert_error(func() -> void: library.matchup_counts("4-4-2", "5-3-2")) \
			.is_push_error("LibraryService: 陣形が無い: 5-3-2")
	assert_dict(library.matchup_counts("4-4-2", "5-3-2")).is_empty()


func test_formation_notes_without_opponent_is_the_profile() -> void:
	var notes: Array[MatchupNote] = _library().formation_notes("4-3-3", "")
	var formation: FormationDef = _library().formations()[1]
	assert_array(_labels_and_texts(notes)).is_equal([
		"陣形 4-3-3|特徴: " + formation.description,
		"陣形 4-3-3|強み: " + formation.strengths,
		"陣形 4-3-3|弱み: " + formation.weaknesses,
	])


## 利用者の狙いどころ（viewer 側のルール）と、相手の狙いどころ（相手から見たルール。「相手」は利用者なので「こちら」に言い換える）
func test_formation_notes_against_an_opponent_shows_both_sides() -> void:
	var notes: Array[MatchupNote] = _library().formation_notes("4-2-3-1", "4-4-2")
	assert_array(_labels_and_texts(notes)).is_equal([
		"こちらの狙いどころ|" + _rule_text("R08"),
		"こちらの狙いどころ|" + _rule_text("R03"),
		"こちらの狙いどころ|" + _rule_text("R04"),
		"こちらの狙いどころ|" + _rule_text("R07"),
		"相手の狙いどころ|" + _rule_text("R20").replace("相手", "こちら"),
		"相手の狙いどころ|" + _rule_text("R10").replace("相手", "こちら"),
	])
	# 上の期待値は実装と同じ置き換えで作っているので、置き換えた後の語句と「相手」が残らないことを直接確かめる
	assert_str(notes[4].text).contains("こちらの攻撃的MF3枚")
	assert_str(notes[5].text).contains("こちらの守備的MF2枚")
	assert_str(notes[4].text).not_contains("相手")
	assert_str(notes[5].text).not_contains("相手")


## 同じ陣形どうしは両側の解説が同じになるので、相手側を出さない
func test_formation_notes_of_the_same_formation_shows_one_side() -> void:
	assert_array(_labels_and_texts(_library().formation_notes("4-3-3", "4-3-3"))) \
			.is_equal(["こちらの狙いどころ|" + _rule_text("R02")])
	var fallback: String = ContentRepository.new().load_catalog().matchup_fallback.text
	assert_array(_labels_and_texts(_library().formation_notes("4-4-2", "4-4-2"))) \
			.is_equal(["こちらの狙いどころ|" + fallback])


func test_formation_notes_of_unknown_formation_is_empty() -> void:
	var library: LibraryService = _library()
	await assert_error(func() -> void: library.formation_notes("5-3-2", "")) \
			.is_push_error("LibraryService: 陣形が無い: 5-3-2")
	assert_array(library.formation_notes("4-4-2", "5-3-2")).is_empty()


func test_style_notes_without_opponent_lists_defense_then_attack() -> void:
	var viewer := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	var notes: Array[MatchupNote] = _library().style_notes(viewer, null)
	assert_int(notes.size()).is_equal(6)
	for index: int in range(3):
		assert_str(notes[index].label).is_equal("守備方式 ゾーン")
		assert_str(notes[index + 3].label).is_equal("攻撃方式 カウンター型")
	assert_str(notes[0].text).starts_with("特徴: エリアを分担して守る")
	assert_str(notes[5].text).starts_with("弱み: ")
	assert_array(notes[0].simplification_ids).is_equal(["SIM-07"])


func test_style_notes_against_an_opponent_is_the_style_matchup() -> void:
	var viewer := TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.POSSESSION)
	var opponent := TeamStyles.new(GameEnums.DefenseStyle.ZONE, GameEnums.AttackStyle.COUNTER)
	assert_array(_labels_and_texts(_library().style_notes(viewer, opponent))).is_equal([
		"方式の噛み合わせ|" + _rule_text("S04"),
		"方式の噛み合わせ|" + _rule_text("S05"),
	])


func test_single_style_notes_have_the_style_name_as_label() -> void:
	var defense: Array[MatchupNote] = _library().defense_style_notes(GameEnums.DefenseStyle.MAN)
	assert_int(defense.size()).is_equal(3)
	assert_str(defense[1].label).is_equal("守備方式 マンツーマン")
	assert_str(defense[1].text).starts_with("強み: ")
	var attack: Array[MatchupNote] = _library().attack_style_notes(GameEnums.AttackStyle.POSSESSION)
	assert_str(attack[2].label).is_equal("攻撃方式 保持型")


func test_app_library_is_created_on_start_with_four_formations() -> void:
	assert_object(App.library).is_not_null()
	assert_int(App.library.formations().size()).is_equal(4)

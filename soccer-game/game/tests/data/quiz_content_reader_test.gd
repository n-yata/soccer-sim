## QuizContentReader（data-definition.md §3.4・§3.5 の形と範囲）のテスト。
## 壊れたデータは、本物の principles.json・quiz.json を1か所ずつ変えて作る（本物を写した fixture は古くなるため）。
extends GdUnitTestSuite

const CONTENT_DIR: String = "res://content"


func _real(file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONTENT_DIR.path_join(file_name))) as Dictionary


func _principle_ids() -> Array[String]:
	var ids: Array[String] = []
	for principle: PrincipleDef in QuizContentReader.new().read_principles(_real("principles.json")):
		ids.append(principle.id)
	return ids


func _question(root: Dictionary, index: int) -> Dictionary:
	return (root["questions"] as Array)[index] as Dictionary


## root の quiz.json を読み、誤りを返す。
func _quiz_errors(root: Dictionary) -> Array[String]:
	var reader := QuizContentReader.new()
	var questions: Array[QuizQuestionDef] = reader.read_quiz(root, _principle_ids())
	if not reader.errors().is_empty():
		assert_array(questions).is_empty()
	return reader.errors()


func _principle_errors(root: Dictionary) -> Array[String]:
	var reader := QuizContentReader.new()
	var principles: Array[PrincipleDef] = reader.read_principles(root)
	if not reader.errors().is_empty():
		assert_array(principles).is_empty()
	return reader.errors()


func _assert_one_error_at(errors: Array[String], location: String) -> void:
	assert_int(errors.size()).override_failure_message(str(errors)).is_equal(1)
	if errors.size() == 1:
		assert_str(errors[0]).starts_with(location)


func test_the_real_files_are_read_into_values() -> void:
	var reader := QuizContentReader.new()
	var principles: Array[PrincipleDef] = reader.read_principles(_real("principles.json"))
	assert_array(reader.errors()).is_empty()
	assert_str(principles[2].id).is_equal("TP-03")
	assert_str(principles[2].name).is_equal("チャレンジ＆カバー")
	assert_int(principles[4].status).is_equal(GameEnums.PrincipleStatus.NO_SOURCE)
	var questions: Array[QuizQuestionDef] = reader.read_quiz(_real("quiz.json"), _principle_ids())
	assert_array(reader.errors()).is_empty()
	var first: QuizQuestionDef = questions[0]
	var raw: Dictionary = _question(_real("quiz.json"), 0)
	assert_str(first.id).is_equal(raw["id"] as String)
	assert_str(first.goal_id).is_equal("LG-1")
	assert_bool(first.is_playtest_set).is_true()
	assert_str(first.ball_area.to_key()).is_equal("M2-L1")
	assert_int(first.user_counts["A1-R1"] as int).is_equal(2)
	assert_int(first.opponent_counts["A1-L1"] as int).is_equal(2)
	# 人数が0のエリアは持たない
	assert_bool(first.user_counts.has("M2-C")).is_false()
	assert_int(first.user_styles.attack).is_equal(GameEnums.AttackStyle.POSSESSION)
	assert_int(first.opponent_styles.attack).is_equal(GameEnums.AttackStyle.COUNTER)
	assert_array(first.choice_ids).is_equal(["a1-l1", "a1-c", "a1-r1"] as Array[String])
	assert_int(first.choice_texts.size()).is_equal(3)
	assert_bool(first.is_correct("a1-r1")).is_true()
	assert_bool(first.is_correct("a1-c")).is_false()
	assert_array(first.principle_ids).is_equal(["TP-01", "TP-02", "TP-04"] as Array[String])


func test_a_team_that_does_not_total_ten_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	((_question(root, 0)["scene"] as Dictionary)["counts"] as Dictionary)["D1-C"] = [1, 0]
	_assert_one_error_at(_quiz_errors(root), "questions[0].scene.counts")


func test_an_unknown_area_in_the_scene_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	var counts: Dictionary = (_question(root, 0)["scene"] as Dictionary)["counts"]
	counts["X9-Q"] = counts["M2-R2"]
	counts.erase("M2-R2")
	var errors: Array[String] = _quiz_errors(root)
	# エリアでないキーの人数は数えないので、合計も10に足りない
	assert_str(errors[0]).is_equal("questions[0].scene.counts.X9-Q: エリアでない")
	assert_int(errors.size()).is_equal(2)


func test_a_count_that_is_not_a_small_integer_is_an_error() -> void:
	for bad: Variant in [-1, 11, 1.5, "1"]:
		var root: Dictionary = _real("quiz.json")
		((_question(root, 0)["scene"] as Dictionary)["counts"] as Dictionary)["M2-R2"] = [bad, 0]
		var errors: Array[String] = _quiz_errors(root)
		assert_str(errors[0]).override_failure_message(str(bad)).starts_with("questions[0].scene.counts.M2-R2: 人数が")


func test_an_answer_that_is_not_a_choice_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	_question(root, 1)["answer"] = "nowhere"
	_assert_one_error_at(_quiz_errors(root), "questions[1].answer")


func test_a_duplicated_choice_id_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	var choices: Array = _question(root, 0)["choices"]
	(choices[1] as Dictionary)["id"] = (choices[0] as Dictionary)["id"]
	_assert_one_error_at(_quiz_errors(root), "questions[0].choices[1].id")


func test_choices_must_be_two_to_four() -> void:
	var root: Dictionary = _real("quiz.json")
	var choices: Array = _question(root, 4)["choices"]
	choices.resize(1)
	assert_str(_quiz_errors(root)[0]).starts_with("questions[4].choices")
	root = _real("quiz.json")
	choices = _question(root, 0)["choices"]
	for index: int in range(2):
		choices.append({"id": "extra-%d" % index, "text": "もう1つ"})
	# 件数が外れた選択肢は読まないので、正解も選択肢に無いことになる
	assert_array(_quiz_errors(root)).is_equal(["questions[0].choices: 件数が 2〜4 でない: 5",
			"questions[0].answer: 選択肢の ID のどれでもない: a1-r1"] as Array[String])


func test_an_unknown_or_repeated_principle_is_an_error() -> void:
	for bad: Array in [["TP-99"], ["TP-03", "TP-03"], []]:
		var root: Dictionary = _real("quiz.json")
		_question(root, 2)["principle_ids"] = bad
		_assert_one_error_at(_quiz_errors(root), "questions[2].principle_ids")


func test_a_duplicated_question_id_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	_question(root, 1)["id"] = _question(root, 0)["id"]
	_assert_one_error_at(_quiz_errors(root), "questions[1].id")


func test_an_unknown_goal_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	_question(root, 0)["goal_id"] = "LG-9"
	var errors: Array[String] = _quiz_errors(root)
	assert_str(errors[0]).starts_with("questions[0].goal_id")
	# LG-1 の問題が1問になり、問題の数とプレイテストの問題の数も足りない
	assert_array(errors).contains(["questions: LG-1 の問題が 2 件未満: 1 件",
			"questions: LG-1 のプレイテストの問題がちょうど 2 件でない: 1 件"])


func test_each_goal_needs_exactly_two_playtest_questions() -> void:
	var root: Dictionary = _real("quiz.json")
	_question(root, 6)["is_playtest_set"] = false
	_assert_one_error_at(_quiz_errors(root), "questions: LG-4 のプレイテストの問題")
	root = _real("quiz.json")
	var extra: Dictionary = (_question(root, 6) as Dictionary).duplicate(true)
	extra["id"] = "lg4-extra"
	(root["questions"] as Array).append(extra)
	_assert_one_error_at(_quiz_errors(root), "questions: LG-4 のプレイテストの問題がちょうど 2 件でない: 3 件")
	# プレイテストに使わない問題なら、3問目を足せる
	extra["is_playtest_set"] = false
	assert_array(_quiz_errors(root)).is_empty()


func test_texts_have_length_limits() -> void:
	var cases: Array = [["text", 201], ["explanation", 401]]
	for entry: Array in cases:
		var root: Dictionary = _real("quiz.json")
		_question(root, 0)[entry[0] as String] = "あ".repeat(entry[1] as int)
		_assert_one_error_at(_quiz_errors(root), "questions[0].%s" % entry[0])
	var empty: Dictionary = _real("quiz.json")
	_question(empty, 0)["text"] = ""
	_assert_one_error_at(_quiz_errors(empty), "questions[0].text")


func test_bad_styles_and_ball_are_errors() -> void:
	var root: Dictionary = _real("quiz.json")
	var scene: Dictionary = _question(root, 0)["scene"]
	scene["ball"] = "Z9"
	(scene["user_styles"] as Dictionary)["defense"] = "PRESSING"
	var errors: Array[String] = _quiz_errors(root)
	assert_array(errors).contains(["questions[0].scene.ball: エリアでない: Z9",
			"questions[0].scene.user_styles.defense: 区分値でない: PRESSING"])
	assert_int(errors.size()).is_equal(2)


func test_bad_principles_are_errors() -> void:
	var root: Dictionary = _real("principles.json")
	((root["principles"] as Array)[0] as Dictionary)["id"] = "P-1"
	_assert_one_error_at(_principle_errors(root), "principles[0].id")
	root = _real("principles.json")
	((root["principles"] as Array)[1] as Dictionary)["id"] = "TP-01"
	_assert_one_error_at(_principle_errors(root), "principles[1].id")
	root = _real("principles.json")
	((root["principles"] as Array)[0] as Dictionary)["status"] = "DONE"
	_assert_one_error_at(_principle_errors(root), "principles[0].status")
	root = _real("principles.json")
	((root["principles"] as Array)[0] as Dictionary)["name"] = ""
	_assert_one_error_at(_principle_errors(root), "principles[0].name")


func test_a_wrong_format_version_or_top_level_is_an_error() -> void:
	var root: Dictionary = _real("quiz.json")
	root["format_version"] = 2
	_assert_one_error_at(_quiz_errors(root), "format_version")
	var reader := QuizContentReader.new()
	assert_array(reader.read_principles([])).is_empty()
	assert_array(reader.errors()).is_equal(["(最上位): オブジェクトでない"] as Array[String])

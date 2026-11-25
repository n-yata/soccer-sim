## TutorialContentReader（data-definition.md §3.4・§3.6 の形と範囲）のテスト。
## 壊れたデータは、本物の tutorial.json・simplifications.json を1か所ずつ変えて作る（本物を写した fixture は古くなるため）。
extends GdUnitTestSuite

const CONTENT_DIR: String = "res://content"


func _real(file_name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONTENT_DIR.path_join(file_name))) as Dictionary


func _reader() -> TutorialContentReader:
	return TutorialContentReader.new(ContentRepository.FORMATION_IDS)


func _step(root: Dictionary, index: int) -> Dictionary:
	return (root["steps"] as Array)[index] as Dictionary


## 段階の種類ごとの最初の段階の位置
func _index_of_kind(root: Dictionary, kind: String) -> int:
	var steps: Array = root["steps"]
	for index: int in range(steps.size()):
		if (steps[index] as Dictionary)["kind"] == kind:
			return index
	return -1


func test_the_real_files_are_read() -> void:
	var reader: TutorialContentReader = _reader()
	assert_int(reader.read_simplifications(_real("simplifications.json")).size()).is_greater(0)
	assert_array(reader.errors()).is_empty()
	var steps: Array[TutorialStepDef] = reader.read_tutorial(_real("tutorial.json"))
	assert_array(reader.errors()).is_empty()
	var operate: TutorialStepDef = steps[_index_of_kind(_real("tutorial.json"), "OPERATE")]
	assert_object(operate.opponent_choice).is_not_null()
	assert_array(operate.allowed_actions).is_not_empty()
	assert_object(operate.home_setup).is_not_null()
	assert_object(operate.ball_area).is_not_null()


func test_broken_tutorial_fields_are_rejected() -> void:
	var operate: int = _index_of_kind(_real("tutorial.json"), "OPERATE")
	var explain: int = _index_of_kind(_real("tutorial.json"), "EXPLAIN")
	var cases: Dictionary = {
		"version": func(root: Dictionary) -> void: root["format_version"] = 2,
		"no steps": func(root: Dictionary) -> void: root["steps"] = [],
		"kind": func(root: Dictionary) -> void: _step(root, explain)["kind"] = "WATCH",
		"text empty": func(root: Dictionary) -> void: _step(root, explain)["text"] = "",
		"text long": func(root: Dictionary) -> void: _step(root, explain)["text"] = "あ".repeat(301),
		"duplicate id": func(root: Dictionary) -> void: _step(root, 1)["id"] = _step(root, 0)["id"],
		"cover name": func(root: Dictionary) -> void: _step(root, explain)["covers"] = ["PASSING"],
		"cover twice": func(root: Dictionary) -> void: _step(root, explain)["covers"] = ["PITCH", "PITCH"],
		"no setup": func(root: Dictionary) -> void: _step(root, explain).erase("setup"),
		"formation": func(root: Dictionary) -> void: _step(root, explain)["setup"]["home"]["formation_id"] = "9-9-9",
		"style": func(root: Dictionary) -> void: _step(root, explain)["setup"]["away"]["defense"] = "PRESSING",
		"ball area": func(root: Dictionary) -> void: _step(root, explain)["setup"]["ball_area"] = "Z9-C",
		"possession": func(root: Dictionary) -> void: _step(root, explain)["setup"]["possession"] = "BOTH",
		"no allowed": func(root: Dictionary) -> void: _step(root, operate)["allowed_actions"] = [],
		"other phase action": func(root: Dictionary) -> void: _step(root, operate)["allowed_actions"] = ["RETREAT"],
		"no opponent": func(root: Dictionary) -> void: _step(root, operate).erase("opponent_choice"),
		# 形としては正しい攻撃の手だが、利用者がボールを持つ段階の相手の手ではない（手の種類だけが違う）
		"opponent family": func(root: Dictionary) -> void: _step(root, operate)["opponent_choice"] = {
				"family": "ATTACK", "action": "SHORT_PASS", "target": "M2-C"},
		"opponent target": func(root: Dictionary) -> void: _step(root, operate)["opponent_choice"]["target"] = null,
		"scope not last": func(root: Dictionary) -> void: (root["steps"] as Array).reverse(),
		"two scopes": func(root: Dictionary) -> void: _step(root, explain)["kind"] = "SCOPE",
	}
	for case_name: String in cases:
		var root: Dictionary = _real("tutorial.json")
		(cases[case_name] as Callable).call(root)
		var reader: TutorialContentReader = _reader()
		assert_array(reader.read_tutorial(root)).override_failure_message("壊したのに読めた: " + case_name).is_empty()
		assert_array(reader.errors()).override_failure_message("誤りが無い: " + case_name).is_not_empty()


func test_broken_simplification_fields_are_rejected() -> void:
	var cases: Dictionary = {
		"id shape": func(root: Dictionary) -> void: root["simplifications"][0]["id"] = "SIMP-1",
		"duplicate id": func(root: Dictionary) -> void: root["simplifications"][1]["id"] = "SIM-01",
		"name empty": func(root: Dictionary) -> void: root["simplifications"][0]["name"] = "",
		"in_game long": func(root: Dictionary) -> void: root["simplifications"][0]["in_game"] = "あ".repeat(301),
		"in_real missing": func(root: Dictionary) -> void: (root["simplifications"][0] as Dictionary).erase("in_real"),
		"no entries": func(root: Dictionary) -> void: root["simplifications"] = [],
	}
	for case_name: String in cases:
		var root: Dictionary = _real("simplifications.json")
		(cases[case_name] as Callable).call(root)
		var reader: TutorialContentReader = _reader()
		assert_array(reader.read_simplifications(root)).override_failure_message("壊したのに読めた: " + case_name).is_empty()


func test_a_missing_file_reads_as_nothing_with_an_error() -> void:
	var reader: TutorialContentReader = _reader()
	assert_array(reader.read_tutorial(null)).is_empty()
	assert_array(reader.errors()).is_not_empty()

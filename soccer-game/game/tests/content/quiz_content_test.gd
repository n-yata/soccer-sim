## 同梱の静的データ（principles.json・quiz.json）の検証（data-definition.md §3.4・§3.5・FR-22・NFR-17 ②）。
## 形と範囲は読み込み（QuizContentReader）が確かめる。ここでは、戦術原則カタログ（functional-overview.md「戦術原則カタログ」）との
## 一致と、問題の文に書いた人数・陣形が場面の図（scene）やゲームの基本配置と食い違っていないかを確かめる。
extends GdUnitTestSuite

## functional-overview.md「戦術原則カタログ」の件数（TP-01〜TP-10）。カタログの行を増減したら、ここと principles.json を直す
const CATALOG_PRINCIPLE_COUNT: int = 10
## 選択肢の文の「{エリア}…（N対M）」
const CHOICE_COUNT_PATTERN: String = "^.*\\{([A-Z0-9-]+)\\}.*（(\\d+)対(\\d+)）$"
## 解説の文が書いている人数（問題 ID → [[エリア, 自分, 相手], ...]）。解説を書き換えたら、ここも合わせる
const EXPLANATION_COUNTS: Dictionary = {
	"lg1-half-space": [["A1-L1", 1, 2], ["A1-C", 1, 1], ["A1-R1", 2, 1]],
	"lg1-switch": [["A1-L1", 1, 2], ["M2-L1", 1, 2], ["M2-R2", 1, 0]],
	"lg2-cover": [["D1-L1", 0, 1]],
	"lg2-far-side": [["M1-L2", 1, 1], ["D2-C", 1, 1], ["D2-R2", 0, 1]],
	"lg3-counter": [["M2-R2", 1, 0]],
	"lg4-anchor": [["M2-C", 0, 1]],
}

var _repository: ContentRepository
var _catalog: ContentCatalog
var _library: LibraryService


func before() -> void:
	_repository = ContentRepository.new()
	_catalog = _repository.load_catalog()
	_library = LibraryService.new(_catalog)


func _question(question_id: String) -> QuizQuestionDef:
	for question: QuizQuestionDef in _catalog.quiz_questions:
		if question.id == question_id:
			return question
	return null


func _pair(question: QuizQuestionDef, key: String) -> Array[int]:
	return [question.user_counts.get(key, 0) as int, question.opponent_counts.get(key, 0) as int]


func test_the_bundled_content_has_no_validation_errors() -> void:
	assert_array(_repository.validation_errors()).is_empty()
	assert_int(_catalog.quiz_questions.size()).is_greater_equal(QuizQuestionDef.GOAL_IDS.size() * 2)


## principles.json は戦術原則カタログの書き写し（正本は functional-overview.md）。ID と件数がカタログと同じ
func test_principles_match_the_catalog_ids_and_count() -> void:
	var ids: Array[String] = []
	for principle: PrincipleDef in _catalog.principles:
		ids.append(principle.id)
	var expected: Array[String] = []
	for number: int in range(1, CATALOG_PRINCIPLE_COUNT + 1):
		expected.append("TP-%02d" % number)
	assert_array(ids).is_equal(expected)


## 図に出すエリアの呼び名に置き換えられる（{…} の中が30エリアのどれか）
func test_every_placeholder_is_an_area() -> void:
	for question: QuizQuestionDef in _catalog.quiz_questions:
		var texts: Array[String] = [question.text, question.explanation]
		texts.append_array(question.choice_texts)
		for text: String in texts:
			for key: String in QuizTexts.placeholder_keys(text):
				assert_object(PitchArea.from_key(key)).override_failure_message("%s: %s" % [question.id, key]).is_not_null()
			assert_bool(QuizTexts.fill(text).contains("{")).override_failure_message(question.id).is_false()


## 選択肢に書いた「（N対M）」が、場面の図のそのエリアの人数と同じ
func test_choice_counts_match_the_scene() -> void:
	var pattern := RegEx.create_from_string(CHOICE_COUNT_PATTERN)
	var checked: int = 0
	for question: QuizQuestionDef in _catalog.quiz_questions:
		for text: String in question.choice_texts:
			var found: RegExMatch = pattern.search(text)
			if found == null:
				continue
			var expected: Array[int] = [found.get_string(2).to_int(), found.get_string(3).to_int()]
			assert_array(_pair(question, found.get_string(1))).override_failure_message("%s: %s" % [question.id, text]) \
					.is_equal(expected)
			checked += 1
	assert_int(checked).is_greater(0)


## 解説に書いた人数が、場面の図と同じで、解説の文に「N対M」として出ている
func test_explanation_counts_match_the_scene() -> void:
	for question_id: String in EXPLANATION_COUNTS:
		var question: QuizQuestionDef = _question(question_id)
		assert_object(question).override_failure_message(question_id).is_not_null()
		for fact: Array in EXPLANATION_COUNTS[question_id] as Array:
			var key: String = fact[0]
			assert_array(_pair(question, key)).override_failure_message("%s: %s" % [question_id, key]) \
					.is_equal([fact[1] as int, fact[2] as int] as Array[int])
			assert_str(question.explanation).contains("{%s}" % key).contains("%d対%d" % [fact[1], fact[2]])


## 即時奪回の判断（アルゴリズム6）: ボールのエリアと上下左右の人数の合計が、解説の「自分1対相手3」と同じ
func test_the_counter_press_question_counts_the_ball_and_its_neighbors() -> void:
	var question: QuizQuestionDef = _question("lg3-retreat")
	var totals: Array[int] = _pair(question, question.ball_area.to_key())
	for area: PitchArea in question.ball_area.neighbors4():
		var pair: Array[int] = _pair(question, area.to_key())
		totals = [totals[0] + pair[0], totals[1] + pair[1]]
	assert_array(totals).is_equal([1, 3] as Array[int])
	assert_str(question.explanation).contains("自分1対相手3")
	# 周りの人数が上回らないので、即時奪回は失敗する（アルゴリズム6）。正解は撤退
	assert_str(question.answer).is_equal("retreat")


## 噛み合わせの2問の場面は、ゲームの基本配置（自分 4-4-2、相手 4-3-3 を自分の視点へ鏡像にしたもの）そのもの
func test_the_matchup_scenes_are_the_base_layouts() -> void:
	var user_counts: Dictionary = _library.base_counts("4-4-2")
	var opponent_counts: Dictionary = {}
	var own_view: Dictionary = _library.base_counts("4-3-3")
	for key: String in own_view:
		if own_view[key] as int > 0:
			opponent_counts[PitchArea.from_key(key).mirrored().to_key()] = own_view[key]
	for key: String in user_counts.keys():
		if user_counts[key] as int == 0:
			user_counts.erase(key)
	for question_id: String in ["lg4-anchor", "lg4-fix"]:
		var question: QuizQuestionDef = _question(question_id)
		assert_dict(question.user_counts).override_failure_message(question_id).is_equal(user_counts)
		assert_dict(question.opponent_counts).override_failure_message(question_id).is_equal(opponent_counts)


## 陣形を選ぶ問題: 基本配置で M2-C に味方がいるのは、正解の陣形だけ
func test_only_the_answer_formation_puts_a_player_in_the_middle() -> void:
	var question: QuizQuestionDef = _question("lg4-fix")
	for choice_id: String in question.choice_ids:
		assert_object(_catalog.formation(choice_id)).override_failure_message(choice_id).is_not_null()
		var has_player: bool = _library.base_counts(choice_id).get("M2-C", 0) as int > 0
		assert_bool(has_player).override_failure_message(choice_id).is_equal(question.is_correct(choice_id))


## principles.json は戦術原則カタログ（functional-overview.md）の書き写し。名前と照合状態がカタログの表と同じ
## （期待値は JSON からではなく、正本の Markdown の表から独立に読む。内容・出典の文面は確かめない）
func test_principle_names_and_statuses_match_the_catalog_table() -> void:
	var rows: Dictionary = _doc_table_rows("1_requirements/functional-overview.md",
			"^\\| (TP-\\d\\d) \\| ([^|]+?) \\|.*\\| `(\\w+)` \\|$")
	assert_int(rows.size()).is_equal(CATALOG_PRINCIPLE_COUNT)
	for principle: PrincipleDef in _catalog.principles:
		var row: Array = rows.get(principle.id, []) as Array
		assert_array(row).override_failure_message(principle.id).is_not_empty()
		if row.is_empty():
			continue
		assert_str(principle.name).override_failure_message(principle.id).is_equal(row[0] as String)
		assert_str(str(GameEnums.PrincipleStatus.find_key(principle.status))).override_failure_message(principle.id) \
				.is_equal(row[1] as String)


## 学習目標の名前（QuizTexts.GOAL_NAMES）は要件定義書 §1.4 の表の書き写し。ID と名前が表と同じ
func test_goal_names_match_the_requirements_table() -> void:
	var rows: Dictionary = _doc_table_rows("1_requirements/requirements-definition.md",
			"^\\| (LG-\\d) \\| ([^|]+?) \\| ([^|]+?) \\|$")
	assert_array(rows.keys()).is_equal(QuizQuestionDef.GOAL_IDS)
	assert_array(QuizTexts.GOAL_NAMES.keys()).is_equal(QuizQuestionDef.GOAL_IDS)
	for goal_id: String in QuizQuestionDef.GOAL_IDS:
		assert_str(QuizTexts.GOAL_NAMES[goal_id] as String).is_equal((rows[goal_id] as Array)[0] as String)


## docs/specs/<relative> の表の行（pattern の1つ目のグループ → 残りのグループ）。docs はプロジェクト（game/）の1つ上
func _doc_table_rows(relative: String, pattern: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../docs/specs").path_join(relative)
	assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_true()
	var regex := RegEx.create_from_string(pattern)
	var rows: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var found: RegExMatch = regex.search(line.strip_edges())
		if found == null:
			continue
		var values: Array = []
		for group: int in range(2, found.get_group_count() + 1):
			values.append(found.get_string(group).strip_edges())
		rows[found.get_string(1)] = values
	return rows

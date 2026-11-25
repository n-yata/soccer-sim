## 静的データの戦術原則カタログ（principles.json）と場面問題（quiz.json）を、形と範囲を確かめながら読む
## （data-definition.md §3.4・§3.5）。ContentRepository が JSON を読んで渡す。項目の読み出しは SaveDataReader。
## ここで確かめるのは形・型・範囲と、原則 ID が原則カタログにあること。場面の人数が問題文・選択肢・解説の数字と合うかは
## テストで確かめる（tests/content/quiz_content_test.gd）。
class_name QuizContentReader
extends RefCounted

const PRINCIPLE_ID_PATTERN: String = "^TP-[0-9]{2}$"
const PRINCIPLE_NAME_LENGTH_MAX: int = 40
const PRINCIPLE_TEXT_LENGTH_MAX: int = 300
const MAX_PRINCIPLES: int = 50
# 以下の値は data-definition.md §3.5 の範囲・制約の写し。正本を変えたらここも合わせる
const QUESTION_TEXT_LENGTH_MAX: int = 200
const CHOICE_COUNT_MIN: int = 2
const CHOICE_COUNT_MAX: int = 4
const CHOICE_TEXT_LENGTH_MAX: int = 100
const EXPLANATION_LENGTH_MAX: int = 400
## 各学習目標の問題の数の下限（FR-22）と、プレイテストの測定に使う問題の数（requirements-definition.md §1.5）
const QUESTIONS_PER_GOAL_MIN: int = 2
const PLAYTEST_QUESTIONS_PER_GOAL: int = 2
## 1チームの人数（GK を除く。場面の人数の合計）
const TEAM_PLAYER_COUNT: int = 10
## 問題の数の上限（多すぎる定義は誤り。読み込みの上限として足す）
const MAX_QUESTIONS: int = 200

var _reader: SaveDataReader
var _principle_id_regex: RegEx
var _id_regex: RegEx


func _init() -> void:
	_principle_id_regex = RegEx.create_from_string(PRINCIPLE_ID_PATTERN)
	_id_regex = RegEx.create_from_string(ContentRepository.ID_PATTERN)


## 誤りがあれば空。誤りは errors()。
func read_principles(root: Variant) -> Array[PrincipleDef]:
	_reader = SaveDataReader.new()
	var result: Array[PrincipleDef] = []
	var entries: Array = _entries(root, "principles", MAX_PRINCIPLES)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "principles[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var fields: Dictionary = entries[index]
		var id: String = _reader.text(fields, "id", location + ".id", _principle_id_regex)
		if seen.has(id):
			_reader.fail(location + ".id", "重複: %s" % id)
		seen[id] = true
		var status: int = _reader.enum_value(fields, "status", location + ".status", GameEnums.PrincipleStatus)
		result.append(PrincipleDef.new(id, _bounded_text(fields, "name", location, PRINCIPLE_NAME_LENGTH_MAX),
				_bounded_text(fields, "content", location, PRINCIPLE_TEXT_LENGTH_MAX),
				_bounded_text(fields, "source", location, PRINCIPLE_TEXT_LENGTH_MAX),
				maxi(0, status) as GameEnums.PrincipleStatus))
	if not _reader.is_ok():
		result.clear()
	return result


## principle_ids は根拠の原則として使える ID（読み込んだ原則）。誤りがあれば空。誤りは errors()。
func read_quiz(root: Variant, principle_ids: Array[String]) -> Array[QuizQuestionDef]:
	_reader = SaveDataReader.new()
	var result: Array[QuizQuestionDef] = []
	var entries: Array = _entries(root, "questions", MAX_QUESTIONS)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "questions[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var question: QuizQuestionDef = _question(entries[index] as Dictionary, location, principle_ids)
		if seen.has(question.id):
			_reader.fail(location + ".id", "重複: %s" % question.id)
		seen[question.id] = true
		result.append(question)
	_check_goals(result)
	if not _reader.is_ok():
		result.clear()
	return result


## 直前の読み込みで見つかった誤り（「場所: 理由」）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


func _entries(root: Variant, key: String, max_count: int) -> Array:
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return []
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", ContentRepository.FORMAT_VERSION,
			ContentRepository.FORMAT_VERSION)
	return _reader.array(fields, key, key, 1, max_count)


func _bounded_text(fields: Dictionary, key: String, location: String, max_length: int) -> String:
	var text: String = _reader.text(fields, key, location + "." + key)
	if text.is_empty() or text.length() > max_length:
		_reader.fail(location + "." + key, "1〜%d 文字でない: %d 文字" % [max_length, text.length()])
	return text


func _question(fields: Dictionary, location: String, principle_ids: Array[String]) -> QuizQuestionDef:
	var question := QuizQuestionDef.new()
	question.id = _reader.text(fields, "id", location + ".id", _id_regex)
	question.goal_id = _reader.text(fields, "goal_id", location + ".goal_id")
	if not QuizQuestionDef.GOAL_IDS.has(question.goal_id):
		_reader.fail(location + ".goal_id", "学習目標（%s）のどれでもない: %s" % [", ".join(QuizQuestionDef.GOAL_IDS),
				question.goal_id])
	question.is_playtest_set = _reader.boolean(fields, "is_playtest_set", location + ".is_playtest_set")
	_scene(question, _reader.object(fields, "scene", location + ".scene"), location + ".scene")
	question.text = _bounded_text(fields, "text", location, QUESTION_TEXT_LENGTH_MAX)
	_choices(question, fields, location)
	question.answer = _reader.text(fields, "answer", location + ".answer")
	if not question.choice_ids.has(question.answer):
		_reader.fail(location + ".answer", "選択肢の ID のどれでもない: %s" % question.answer)
	question.explanation = _bounded_text(fields, "explanation", location, EXPLANATION_LENGTH_MAX)
	var values: Array = _reader.array(fields, "principle_ids", location + ".principle_ids", 1, principle_ids.size())
	for value: Variant in values:
		if typeof(value) != TYPE_STRING or not principle_ids.has(value) or question.principle_ids.has(value):
			_reader.fail(location + ".principle_ids", "原則カタログに無いか重複: %s" % str(value))
			continue
		question.principle_ids.append(value as String)
	return question


## 場面の人数（30エリアのキー → [自分, 相手]。各チームの合計が10）・ボール・両者の方式。
func _scene(question: QuizQuestionDef, scene: Dictionary, location: String) -> void:
	var counts: Dictionary = _reader.object(scene, "counts", location + ".counts")
	var totals: Array[int] = [0, 0]
	for key: Variant in counts:
		var area_location: String = "%s.counts.%s" % [location, str(key)]
		if typeof(key) != TYPE_STRING or PitchArea.from_key(key as String) == null:
			_reader.fail(area_location, "エリアでない")
			continue
		var pair: Variant = counts[key]
		if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
			_reader.fail(area_location, "[自分, 相手] の形でない")
			continue
		for side: int in range(2):
			var value: Variant = (pair as Array)[side]
			if not SaveDataReader.is_integer(value) or float(value) < 0 or float(value) > TEAM_PLAYER_COUNT:
				_reader.fail(area_location, "人数が 0〜%d の整数でない: %s" % [TEAM_PLAYER_COUNT, str(value)])
				continue
			totals[side] += int(value)
			if int(value) > 0 and side == 0:
				question.user_counts[key] = int(value)
			elif int(value) > 0:
				question.opponent_counts[key] = int(value)
	if totals[0] != TEAM_PLAYER_COUNT or totals[1] != TEAM_PLAYER_COUNT:
		_reader.fail(location + ".counts", "各チームの合計が %d でない: %s" % [TEAM_PLAYER_COUNT, str(totals)])
	question.ball_area = _reader.area(scene, "ball", location + ".ball")
	question.user_styles = _styles(scene, "user_styles", location + ".user_styles")
	question.opponent_styles = _styles(scene, "opponent_styles", location + ".opponent_styles")


func _styles(fields: Dictionary, key: String, location: String) -> TeamStyles:
	var styles: Dictionary = _reader.object(fields, key, location)
	var defense: int = maxi(0, _reader.enum_value(styles, "defense", location + ".defense", GameEnums.DefenseStyle))
	var attack: int = maxi(0, _reader.enum_value(styles, "attack", location + ".attack", GameEnums.AttackStyle))
	return TeamStyles.new(defense as GameEnums.DefenseStyle, attack as GameEnums.AttackStyle)


## 選択肢（2〜4件。id は問題の中で一意）。
func _choices(question: QuizQuestionDef, fields: Dictionary, location: String) -> void:
	var entries: Array = _reader.array(fields, "choices", location + ".choices", CHOICE_COUNT_MIN, CHOICE_COUNT_MAX)
	for index: int in range(entries.size()):
		var choice_location: String = "%s.choices[%d]" % [location, index]
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(choice_location, "オブジェクトでない")
			continue
		var choice: Dictionary = entries[index]
		var id: String = _reader.text(choice, "id", choice_location + ".id", _id_regex)
		if question.choice_ids.has(id):
			_reader.fail(choice_location + ".id", "重複: %s" % id)
		question.choice_ids.append(id)
		question.choice_texts.append(_bounded_text(choice, "text", choice_location, CHOICE_TEXT_LENGTH_MAX))


## 各学習目標に2件以上、うちプレイテストの測定に使うものがちょうど2件（data-definition.md §3.5）。
func _check_goals(questions: Array[QuizQuestionDef]) -> void:
	for goal_id: String in QuizQuestionDef.GOAL_IDS:
		var count: int = 0
		var playtest_count: int = 0
		for question: QuizQuestionDef in questions:
			if question.goal_id == goal_id:
				count += 1
				if question.is_playtest_set:
					playtest_count += 1
		if count < QUESTIONS_PER_GOAL_MIN:
			_reader.fail("questions", "%s の問題が %d 件未満: %d 件" % [goal_id, QUESTIONS_PER_GOAL_MIN, count])
		if playtest_count != PLAYTEST_QUESTIONS_PER_GOAL:
			_reader.fail("questions", "%s のプレイテストの問題がちょうど %d 件でない: %d 件" % [goal_id,
					PLAYTEST_QUESTIONS_PER_GOAL, playtest_count])

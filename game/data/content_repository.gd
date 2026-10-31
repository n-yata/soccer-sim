## 静的データ（game/content/*.json）を読み、検証して ContentCatalog に変換する（component-design.md §4.1）。
## 陣形（formations.json）・単純化カタログ（simplifications.json）・チュートリアルの段階（tutorial.json）・
## 戦術原則カタログ（principles.json）・場面問題（quiz.json）を扱う。ほかの静的データは、それを使う機能の作業で足す。
## 単純化とチュートリアルの形・範囲は TutorialContentReader、原則と場面問題は QuizContentReader が確かめる。
##
## 静的データはアプリに同梱するため、誤りは開発時の誤りとして扱う（data-definition.md §4）。
## 誤りが1件でもあれば、何も持たない空の ContentCatalog を返す（一部だけ正しいデータで動き続けないため）。
class_name ContentRepository
extends RefCounted

const FORMATIONS_FILE: String = "formations.json"
const SIMPLIFICATIONS_FILE: String = "simplifications.json"
const TUTORIAL_FILE: String = "tutorial.json"
const PRINCIPLES_FILE: String = "principles.json"
const QUIZ_FILE: String = "quiz.json"

# 以下の値は data-definition.md §3・§3.1 の範囲・制約の写し。正本を変えたらここも合わせる
const FORMAT_VERSION: int = 1
const ID_PATTERN: String = "^[A-Za-z0-9_-]{1,40}$"
## MVP の4陣形（data-definition.md §3.1「4件（4-4-2・4-3-3・4-2-3-1・3-5-2）」）
const FORMATION_IDS: Array[String] = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"]
const NAME_LENGTH_MIN: int = 1
const NAME_LENGTH_MAX: int = 20
const DESCRIPTION_LENGTH_MIN: int = 1
const DESCRIPTION_LENGTH_MAX: int = 200
const PLAYER_COUNT: int = 11
const PLAYER_TYPES: Array[String] = ["GK", "DF", "MF", "FW"]
const LABEL_LENGTH_MIN: int = 1
const LABEL_LENGTH_MAX: int = 4
const NUMBER_MIN: int = 1
const NUMBER_MAX: int = 99
const COORDINATE_MIN: float = 0.0
const COORDINATE_MAX: float = 100.0

var _content_dir: String
var _errors: Array[String] = []
var _is_loaded: bool = false
var _id_regex: RegEx


## content_dir はテストで別の場所を読ませるための引数。アプリは既定値を使う。
func _init(content_dir: String = "res://content") -> void:
	_content_dir = content_dir
	_id_regex = RegEx.new()
	_id_regex.compile(ID_PATTERN)


func load_catalog() -> ContentCatalog:
	_errors.clear()
	_is_loaded = true
	var formations: Array[FormationDef] = _load_formations()
	# 段階の陣形は MVP の陣形の ID で確かめる（読み込んだ陣形で確かめると、陣形の誤り1件が段階の数だけ誤りを増やすため）
	var reader := TutorialContentReader.new(FORMATION_IDS)
	var simplifications: Array[SimplificationDef] = reader.read_simplifications(_read_json(SIMPLIFICATIONS_FILE))
	_add_reader_errors(SIMPLIFICATIONS_FILE, reader.errors())
	var steps: Array[TutorialStepDef] = reader.read_tutorial(_read_json(TUTORIAL_FILE))
	_add_reader_errors(TUTORIAL_FILE, reader.errors())
	var quiz_reader := QuizContentReader.new()
	var principles: Array[PrincipleDef] = quiz_reader.read_principles(_read_json(PRINCIPLES_FILE))
	_add_reader_errors(PRINCIPLES_FILE, quiz_reader.errors())
	var principle_ids: Array[String] = []
	for principle: PrincipleDef in principles:
		principle_ids.append(principle.id)
	var questions: Array[QuizQuestionDef] = quiz_reader.read_quiz(_read_json(QUIZ_FILE), principle_ids)
	_add_reader_errors(QUIZ_FILE, quiz_reader.errors())
	if not _errors.is_empty():
		for message: String in _errors:
			push_error(message)
		return ContentCatalog.new()
	return ContentCatalog.new(formations, simplifications, steps, principles, questions)


## 直前の load_catalog() で見つかった誤り。まだ読んでいなければ読む。空なら正常。
func validation_errors() -> Array[String]:
	if not _is_loaded:
		load_catalog()
	return _errors.duplicate()


func _load_formations() -> Array[FormationDef]:
	var result: Array[FormationDef] = []
	var path: String = _content_dir.path_join(FORMATIONS_FILE)
	if not FileAccess.file_exists(path):
		_error("(ファイル)", "ファイルが無い: %s" % path)
		return result
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_error("(ファイル)", "JSON として読めない（%d 行目: %s）" % [json.get_error_line(), json.get_error_message()])
		return result
	if typeof(json.data) != TYPE_DICTIONARY:
		_error("(最上位)", "オブジェクトでない")
		return result
	var root: Dictionary = json.data
	if not root.has("format_version"):
		_error("format_version", "無い")
	elif not _is_integer(root["format_version"]) or int(root["format_version"]) != FORMAT_VERSION:
		_error("format_version", "%d でない: %s" % [FORMAT_VERSION, str(root["format_version"])])
	if typeof(root.get("formations")) != TYPE_ARRAY:
		_error("formations", "配列でない")
		return result
	var entries: Array = root["formations"]
	if entries.size() != FORMATION_IDS.size():
		_error("formations", "%d 件でない: %d 件" % [FORMATION_IDS.size(), entries.size()])
	var formation_ids: Dictionary = {}
	var player_ids: Dictionary = {}
	for i: int in entries.size():
		var formation: FormationDef = _parse_formation(entries[i], "formations[%d]" % i, formation_ids, player_ids)
		if formation != null:
			result.append(formation)
	return result


## 誤りがあれば記録して null を返す。formation_ids・player_ids は一意性の確認に使う（見た ID を足していく）。
func _parse_formation(entry: Variant, location: String, formation_ids: Dictionary,
		player_ids: Dictionary) -> FormationDef:
	if typeof(entry) != TYPE_DICTIONARY:
		_error(location, "オブジェクトでない")
		return null
	var fields: Dictionary = entry
	var error_count: int = _errors.size()
	var formation_id: String = _require_id(fields, "id", location, formation_ids)
	if not formation_id.is_empty() and not FORMATION_IDS.has(formation_id):
		_error(location + ".id", "MVP の陣形（%s）のどれでもない: %s" % [", ".join(FORMATION_IDS), formation_id])
	var formation_name: String = _require_text(fields, "name", location, NAME_LENGTH_MIN, NAME_LENGTH_MAX)
	var description: String = _require_text(fields, "description", location,
			DESCRIPTION_LENGTH_MIN, DESCRIPTION_LENGTH_MAX)
	var tags: Array[String] = _require_string_array(fields, "extra_tags", location)
	var players: Array[PlayerSlotDef] = []
	if typeof(fields.get("players")) != TYPE_ARRAY:
		_error(location + ".players", "配列でない")
	else:
		players = _parse_players(fields["players"], location + ".players", player_ids)
	if _errors.size() != error_count:
		return null
	return FormationDef.new(formation_id, formation_name, description, tags, players)


func _parse_players(entries: Array, location: String, player_ids: Dictionary) -> Array[PlayerSlotDef]:
	var result: Array[PlayerSlotDef] = []
	if entries.size() != PLAYER_COUNT:
		_error(location, "%d 人でない: %d 人" % [PLAYER_COUNT, entries.size()])
	var numbers: Dictionary = {}
	var goalkeeper_count: int = 0
	for i: int in entries.size():
		var player_location: String = "%s[%d]" % [location, i]
		if typeof(entries[i]) != TYPE_DICTIONARY:
			_error(player_location, "オブジェクトでない")
			continue
		var fields: Dictionary = entries[i]
		var error_count: int = _errors.size()
		var player_id: String = _require_id(fields, "id", player_location, player_ids)
		var position_type: String = _require_player_type(fields, player_location)
		var label: String = _require_text(fields, "label", player_location, LABEL_LENGTH_MIN, LABEL_LENGTH_MAX)
		var number: int = _require_number(fields, player_location, numbers)
		var x: float = _require_coordinate(fields, "x", player_location)
		var y: float = _require_coordinate(fields, "y", player_location)
		if position_type == PlayerSlotDef.GOALKEEPER_TYPE:
			goalkeeper_count += 1
		if _errors.size() == error_count:
			result.append(PlayerSlotDef.new(player_id, position_type, label, number, x, y))
	if goalkeeper_count != 1:
		_error(location, "GK がちょうど1人でない: %d 人" % goalkeeper_count)
	return result


## ID の形式と一意性を確かめる。seen に見た ID を足す。誤りなら空文字を返す。
func _require_id(fields: Dictionary, key: String, location: String, seen: Dictionary) -> String:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_STRING or _id_regex.search(value as String) == null:
		_error(location + "." + key, "ID の形式（%s）でない: %s" % [ID_PATTERN, str(value)])
		return ""
	var id: String = value
	if seen.has(id):
		_error(location + "." + key, "重複: %s" % id)
		return ""
	seen[id] = true
	return id


func _require_text(fields: Dictionary, key: String, location: String, min_length: int, max_length: int) -> String:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_STRING:
		_error(location + "." + key, "文字列でない")
		return ""
	var text: String = value
	if text.length() < min_length or text.length() > max_length:
		_error(location + "." + key, "%d〜%d 文字でない: %d 文字" % [min_length, max_length, text.length()])
		return ""
	return text


func _require_string_array(fields: Dictionary, key: String, location: String) -> Array[String]:
	var result: Array[String] = []
	if typeof(fields.get(key)) != TYPE_ARRAY:
		_error(location + "." + key, "配列でない")
		return result
	var values: Array = fields[key]
	for i: int in values.size():
		if typeof(values[i]) != TYPE_STRING:
			_error("%s.%s[%d]" % [location, key, i], "文字列でない")
		else:
			result.append(values[i] as String)
	return result


func _require_player_type(fields: Dictionary, location: String) -> String:
	var value: Variant = fields.get("type")
	if typeof(value) != TYPE_STRING or not PLAYER_TYPES.has(value as String):
		_error(location + ".type", "GK・DF・MF・FW のどれでもない: %s" % str(value))
		return ""
	return value as String


## 背番号（1〜99 の整数。陣形の中で一意）。seen に見た番号を足す。
func _require_number(fields: Dictionary, location: String, seen: Dictionary) -> int:
	var value: Variant = fields.get("number")
	if not _is_integer(value) or int(value) < NUMBER_MIN or int(value) > NUMBER_MAX:
		_error(location + ".number", "%d〜%d の整数でない: %s" % [NUMBER_MIN, NUMBER_MAX, str(value)])
		return 0
	var number: int = int(value)
	if seen.has(number):
		_error(location + ".number", "陣形の中で重複: %d" % number)
		return 0
	seen[number] = true
	return number


func _require_coordinate(fields: Dictionary, key: String, location: String) -> float:
	var value: Variant = fields.get(key)
	var value_type: int = typeof(value)
	# 範囲の比較は NaN を止めないため、先に有限値かを確かめる（Godot の JSON は 1e999 を inf として読む）
	var is_number: bool = value_type == TYPE_FLOAT or value_type == TYPE_INT
	if not is_number or not is_finite(float(value)) \
			or float(value) < COORDINATE_MIN or float(value) > COORDINATE_MAX:
		_error(location + "." + key, "%s〜%s の数でない: %s" % [COORDINATE_MIN, COORDINATE_MAX, str(value)])
		return 0.0
	return float(value)


## JSON の数は float として読まれるので、小数部が無いことで整数かを判断する。
func _is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == roundf(float(value))


func _error(location: String, reason: String) -> void:
	_errors.append("%s: %s: %s" % [FORMATIONS_FILE, location, reason])


## file を JSON として読む。無い・読めなければ誤りを記録して null（読み手が「オブジェクトでない」として扱う）。
func _read_json(file: String) -> Variant:
	var path: String = _content_dir.path_join(file)
	if not FileAccess.file_exists(path):
		_errors.append("%s: (ファイル): ファイルが無い: %s" % [file, path])
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_errors.append("%s: (ファイル): JSON として読めない（%d 行目: %s）" % [file, json.get_error_line(),
				json.get_error_message()])
		return null
	return json.data


## messages は読み手（TutorialContentReader・QuizContentReader）の errors()。
func _add_reader_errors(file: String, messages: Array[String]) -> void:
	for message: String in messages:
		_errors.append("%s: %s" % [file, message])

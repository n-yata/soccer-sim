## 静的データの方式（styles.json）と噛み合わせルール（matchup_rules.json）を、形と範囲を確かめながら読む
## （data-definition.md §3.2・§3.3。アルゴリズム9）。ContentRepository が JSON を読んで渡す。項目の読み出しは SaveDataReader。
## 原則 ID・単純化 ID は、読み込んだカタログにあるものだけを受け付ける（NFR-17 ①）。
class_name CommentaryContentReader
extends RefCounted

# 以下の値は data-definition.md §3.2・§3.3 の範囲・制約の写し。正本を変えたらここも合わせる
const NAME_LENGTH_MAX: int = 20
const TEXT_LENGTH_MAX: int = 300
const THEME_LENGTH_MAX: int = 40
## 守備方式・攻撃方式の4件（区分値の名前 → 種類）
const STYLE_KINDS: Dictionary = {
	"ZONE": StyleDef.KIND_DEFENSE, "MAN": StyleDef.KIND_DEFENSE,
	"POSSESSION": StyleDef.KIND_ATTACK, "COUNTER": StyleDef.KIND_ATTACK,
}
const RULE_KINDS: Array[String] = [MatchupRuleDef.KIND_FORMATION, MatchupRuleDef.KIND_STYLE]
## 読み込みの上限（多すぎる定義は誤り）
const MAX_RULES: int = 200
const MAX_IDS: int = 20

var _principle_ids: Array[String]
var _simplification_ids: Array[String]
var _reader: SaveDataReader
var _id_regex: RegEx
var _fallback: MatchupNote


## principle_ids・simplification_ids は、根拠の原則・単純化として使える ID（読み込んだカタログ）。
func _init(principle_ids: Array[String], simplification_ids: Array[String]) -> void:
	_principle_ids = principle_ids.duplicate()
	_simplification_ids = simplification_ids.duplicate()
	_id_regex = RegEx.create_from_string(ContentRepository.ID_PATTERN)


## 4方式（静的データの順）。誤りがあれば空。誤りは errors()。
func read_styles(root: Variant) -> Array[StyleDef]:
	_reader = SaveDataReader.new()
	var result: Array[StyleDef] = []
	var entries: Array = _entries(root, "styles", STYLE_KINDS.size(), STYLE_KINDS.size())
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "styles[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var style: StyleDef = _style(entries[index] as Dictionary, location)
		if seen.has(style.id):
			_reader.fail(location + ".id", "重複: %s" % style.id)
		elif not style.id.is_empty():
			seen[style.id] = true
		result.append(style)
	if not entries.is_empty():
		for style_id: String in STYLE_KINDS:
			if not seen.has(style_id):
				_reader.fail("styles", "%s が無い" % style_id)
	if not _reader.is_ok():
		result.clear()
	return result


## ルール（配列の順のまま）。fallback() も読む。誤りがあれば空（fallback() も null）。誤りは errors()。
func read_rules(root: Variant) -> Array[MatchupRuleDef]:
	_reader = SaveDataReader.new()
	_fallback = null
	var result: Array[MatchupRuleDef] = []
	var entries: Array = _entries(root, "rules", 1, MAX_RULES)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "rules[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var rule: MatchupRuleDef = _rule(entries[index] as Dictionary, location)
		if seen.has(rule.id):
			_reader.fail(location + ".id", "重複: %s" % rule.id)
		seen[rule.id] = true
		result.append(rule)
	var fallback_note: MatchupNote = null
	if typeof(root) == TYPE_DICTIONARY:
		var fields: Dictionary = _reader.object(root as Dictionary, "fallback", "fallback")
		if not fields.is_empty():
			fallback_note = MatchupNote.new(_bounded_text(fields, "text", "fallback", TEXT_LENGTH_MAX),
					_ids(fields, "principle_ids", "fallback", _principle_ids, 1))
	if not _reader.is_ok():
		result.clear()
		return result
	_fallback = fallback_note
	return result


## 直前の read_rules で読んだ代わりの文（陣形どうしでルールが1件も当たらない側に出す）。誤りがあれば null。
func fallback() -> MatchupNote:
	return _fallback


## 直前の読み込みで見つかった誤り（「場所: 理由」）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


func _entries(root: Variant, key: String, min_count: int, max_count: int) -> Array:
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return []
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", ContentRepository.FORMAT_VERSION,
			ContentRepository.FORMAT_VERSION)
	return _reader.array(fields, key, key, min_count, max_count)


func _style(fields: Dictionary, location: String) -> StyleDef:
	var style := StyleDef.new()
	style.id = _reader.text(fields, "id", location + ".id")
	if not style.id.is_empty() and not STYLE_KINDS.has(style.id):
		_reader.fail(location + ".id", "方式（%s）のどれでもない: %s" % [", ".join(STYLE_KINDS.keys()), style.id])
		style.id = ""
	style.kind = _reader.text(fields, "kind", location + ".kind")
	if not style.id.is_empty() and style.kind != STYLE_KINDS[style.id]:
		_reader.fail(location + ".kind", "%s の種類（%s）でない: %s" % [style.id, STYLE_KINDS[style.id], style.kind])
	style.name = _bounded_text(fields, "name", location, NAME_LENGTH_MAX)
	style.summary = _bounded_text(fields, "summary", location, TEXT_LENGTH_MAX)
	style.strengths = _bounded_text(fields, "strengths", location, TEXT_LENGTH_MAX)
	style.weaknesses = _bounded_text(fields, "weaknesses", location, TEXT_LENGTH_MAX)
	style.principle_ids = _ids(fields, "principle_ids", location, _principle_ids, 1)
	style.simplification_ids = _ids(fields, "simplification_ids", location, _simplification_ids, 0)
	return style


func _rule(fields: Dictionary, location: String) -> MatchupRuleDef:
	var rule := MatchupRuleDef.new()
	rule.id = _reader.text(fields, "id", location + ".id", _id_regex)
	rule.kind = _reader.text(fields, "kind", location + ".kind")
	if not rule.kind.is_empty() and not RULE_KINDS.has(rule.kind):
		_reader.fail(location + ".kind", "%s のどれでもない: %s" % [", ".join(RULE_KINDS), rule.kind])
	var condition: Dictionary = _reader.object(fields, "condition", location + ".condition")
	if rule.kind == MatchupRuleDef.KIND_FORMATION:
		_formation_condition(rule, condition, location + ".condition")
	elif rule.kind == MatchupRuleDef.KIND_STYLE:
		_style_condition(rule, condition, location + ".condition")
	rule.text = _bounded_text(fields, "text", location, TEXT_LENGTH_MAX)
	rule.theme = _bounded_text(fields, "theme", location, THEME_LENGTH_MAX)
	rule.principle_ids = _ids(fields, "principle_ids", location, _principle_ids, 1)
	rule.simplification_ids = _ids(fields, "simplification_ids", location, _simplification_ids, 0)
	return rule


## 陣形どうしの条件: viewer_tags・opponent_tags は既知のタグの配列で、どちらかが1件以上。
## 条件が空（{}、またはオブジェクトでなかった）でも抜けない。キーが無い誤りを積む（空のまま通すと、どの組み合わせにも当たる）
func _formation_condition(rule: MatchupRuleDef, condition: Dictionary, location: String) -> void:
	rule.viewer_tags = _ids(condition, "viewer_tags", location, FormationTags.KNOWN, 0)
	rule.opponent_tags = _ids(condition, "opponent_tags", location, FormationTags.KNOWN, 0)
	if rule.viewer_tags.is_empty() and rule.opponent_tags.is_empty():
		_reader.fail(location, "viewer_tags・opponent_tags のどちらも空")


## 方式どうしの条件: viewer_style・opponent_style は方式の ID で、守備方式と攻撃方式の組。
## 条件が空でも抜けない（空のまま通すと、一度も当たらないルールが黙って残る）
func _style_condition(rule: MatchupRuleDef, condition: Dictionary, location: String) -> void:
	rule.viewer_style = _style_id(condition, "viewer_style", location)
	rule.opponent_style = _style_id(condition, "opponent_style", location)
	if rule.viewer_style.is_empty() or rule.opponent_style.is_empty():
		return
	if STYLE_KINDS[rule.viewer_style] == STYLE_KINDS[rule.opponent_style]:
		_reader.fail(location, "守備方式と攻撃方式の組でない: %s・%s" % [rule.viewer_style, rule.opponent_style])


func _style_id(fields: Dictionary, key: String, location: String) -> String:
	var value: String = _reader.text(fields, key, location + "." + key)
	if not value.is_empty() and not STYLE_KINDS.has(value):
		_reader.fail(location + "." + key, "方式でない: %s" % value)
		return ""
	return value


func _bounded_text(fields: Dictionary, key: String, location: String, max_length: int) -> String:
	var text: String = _reader.text(fields, key, location + "." + key)
	if text.is_empty() or text.length() > max_length:
		_reader.fail(location + "." + key, "1〜%d 文字でない: %d 文字" % [max_length, text.length()])
	return text


## known に含まれる文字列の配列（min_count 件以上）。外れた要素は誤りにする。
func _ids(fields: Dictionary, key: String, location: String, known: Array[String], min_count: int) -> Array[String]:
	var result: Array[String] = []
	var values: Array = _reader.array(fields, key, location + "." + key, min_count, MAX_IDS)
	for index: int in range(values.size()):
		var item_location: String = "%s.%s[%d]" % [location, key, index]
		if typeof(values[index]) != TYPE_STRING or not known.has(values[index] as String):
			_reader.fail(item_location, "既知の ID でない: %s" % str(values[index]))
			continue
		result.append(values[index] as String)
	return result

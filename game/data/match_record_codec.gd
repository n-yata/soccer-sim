## 戦績のファイル（data-definition.md §2.2）と MatchRecord の配列の変換。読み込みは型・必須・範囲を確かめ、1つでも外れたら
## 全体を使わない（null。破損として退避する。NFR-09）。陣形と方式の形は中断データと同じ（SuspendedMatchEncoder.setup_fields）。
## 陣形 ID は ID の形（data-definition.md §3）であることだけを確かめ、カタログにあるかは見ない（陣形を減らした後も、
## 過去の戦績を破損にしないため）。
class_name MatchRecordCodec
extends RefCounted

const FORMAT_VERSION: int = 1
## 件数の上限（data-definition.md §2.2）
const MAX_RECORDS: int = 3000
const MAX_SCORE: int = 99

var _max_turn: int
var _max_periods: int
var _reader: SaveDataReader
var _match_id_regex: RegEx
var _datetime_regex: RegEx
var _id_regex: RegEx


func _init(rules: MatchRuleConfig) -> void:
	_max_turn = rules.turns_per_half + rules.max_additional_turns
	# 推移の件数の上限: （1ハーフのターン数＋アディショナルタイムの最大ターン数）× 2 ＋ 2
	_max_periods = _max_turn * 2 + 2
	_match_id_regex = RegEx.create_from_string(SuspendedMatchDecoder.MATCH_ID_PATTERN)
	_datetime_regex = RegEx.create_from_string(SuspendedMatchDecoder.DATETIME_PATTERN)
	_id_regex = RegEx.create_from_string(ContentRepository.ID_PATTERN)


static func to_json(records: Array[MatchRecord]) -> String:
	var items: Array = []
	for record: MatchRecord in records:
		items.append(encode(record))
	return JSON.stringify({"format_version": FORMAT_VERSION, "records": items})


static func encode(record: MatchRecord) -> Dictionary:
	var timeline: Array = []
	for period: RecordPeriod in record.timeline:
		timeline.append({"half": period.half, "from_turn": period.from_turn,
				"user": SuspendedMatchEncoder.setup_fields(period.user_setup),
				"cpu": SuspendedMatchEncoder.setup_fields(period.cpu_setup)})
	return {"record_id": record.record_id, "match_id": record.match_id, "finished_at": record.finished_at,
			"score_user": record.score_user, "score_cpu": record.score_cpu,
			"result": GameEnums.MatchResult.find_key(record.result), "timeline": timeline}


## 最上位の format_version（整数でなければ -1）。新しい版かどうかを、中身を確かめる前に見分けるのに使う。
static func version_of(root: Variant) -> int:
	if typeof(root) != TYPE_DICTIONARY:
		return -1
	var value: Variant = (root as Dictionary).get("format_version")
	return int(value) if SaveDataReader.is_integer(value) and absf(float(value)) < 1e9 else -1


## 誤りがあれば null。ファイルの中の順（記録した順）のまま返す。
func decode(root: Variant) -> Variant:
	_reader = SaveDataReader.new()
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return null
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", FORMAT_VERSION, FORMAT_VERSION)
	var items: Array = _reader.array(fields, "records", "records", 0, MAX_RECORDS)
	var records: Array[MatchRecord] = []
	var seen_ids: Dictionary = {}
	for index: int in range(items.size()):
		var location: String = "records[%d]" % index
		if typeof(items[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var record: MatchRecord = _record(items[index] as Dictionary, location)
		if seen_ids.has(record.match_id):
			_reader.fail(location + ".match_id", "重複している: %s" % record.match_id)
		seen_ids[record.match_id] = true
		records.append(record)
	return records if _reader.is_ok() else null


## 直前の decode で見つかった誤り（「場所: 理由」）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


func _record(fields: Dictionary, location: String) -> MatchRecord:
	var record := MatchRecord.new()
	record.match_id = _reader.text(fields, "match_id", location + ".match_id", _match_id_regex)
	record.record_id = _reader.text(fields, "record_id", location + ".record_id")
	if record.record_id != record.match_id:
		_reader.fail(location + ".record_id", "match_id と違う")
	record.finished_at = _reader.text(fields, "finished_at", location + ".finished_at", _datetime_regex)
	record.score_user = _reader.integer(fields, "score_user", location + ".score_user", 0, MAX_SCORE)
	record.score_cpu = _reader.integer(fields, "score_cpu", location + ".score_cpu", 0, MAX_SCORE)
	var result: int = _reader.enum_value(fields, "result", location + ".result", GameEnums.MatchResult)
	if result >= 0:
		record.result = result as GameEnums.MatchResult
		if record.result != MatchRecord.result_of(record.score_user, record.score_cpu):
			_reader.fail(location + ".result", "スコアと合わない")
	var periods: Array = _reader.array(fields, "timeline", location + ".timeline", 1, _max_periods)
	for index: int in range(periods.size()):
		var period_location: String = "%s.timeline[%d]" % [location, index]
		if typeof(periods[index]) != TYPE_DICTIONARY:
			_reader.fail(period_location, "オブジェクトでない")
			continue
		var period: RecordPeriod = _period(periods[index] as Dictionary, period_location)
		if period != null:
			record.timeline.append(period)
	return record


func _period(fields: Dictionary, location: String) -> RecordPeriod:
	var half: int = _reader.integer(fields, "half", location + ".half", 1, 2)
	var from_turn: int = _reader.integer(fields, "from_turn", location + ".from_turn", 1, _max_turn)
	var user_setup: TeamSetup = _setup(fields, "user", location + ".user")
	var cpu_setup: TeamSetup = _setup(fields, "cpu", location + ".cpu")
	if user_setup == null or cpu_setup == null:
		return null
	return RecordPeriod.new(half, from_turn, user_setup, cpu_setup)


## 陣形と方式。誤りがあれば null。
func _setup(fields: Dictionary, key: String, location: String) -> TeamSetup:
	var setup: Dictionary = _reader.object(fields, key, location)
	var formation_id: String = _reader.text(setup, "formation_id", location + ".formation_id", _id_regex)
	var defense: int = _reader.enum_value(setup, "defense", location + ".defense", GameEnums.DefenseStyle)
	var attack: int = _reader.enum_value(setup, "attack", location + ".attack", GameEnums.AttackStyle)
	if formation_id.is_empty() or defense < 0 or attack < 0:
		return null
	return TeamSetup.new(formation_id, TeamStyles.new(defense as GameEnums.DefenseStyle, attack as GameEnums.AttackStyle))

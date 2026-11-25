## 保存データ（JSON から読んだ Dictionary）の項目を、型・必須・範囲を確かめながら読む（data-definition.md §1 の表の読み方）。
## 外れた項目は errors() に「場所: 理由」で積む。読み出しの関数は、外れたときに使える既定値（-1・空・null）を返すので、
## 呼び出し側は最後に is_ok() を見て、1つでも外れていればデータ全体を使わない。
## 保存データは利用者が改変しうる入力なので、型が違っても落ちないように Variant のまま確かめる（NFR-09）。
class_name SaveDataReader
extends RefCounted

## 文字列の長さの上限（data-definition.md §1「共通の制約」）
const MAX_STRING_LENGTH: int = 2000

var _errors: Array[String] = []


func is_ok() -> bool:
	return _errors.is_empty()


func errors() -> Array[String]:
	return _errors.duplicate()


func fail(location: String, reason: String) -> void:
	_errors.append("%s: %s" % [location, reason])


## オブジェクト。無い・オブジェクトでなければ空の Dictionary。
func object(fields: Dictionary, key: String, location: String) -> Dictionary:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_DICTIONARY:
		fail(location, "オブジェクトでない")
		return {}
	return value


## オブジェクトか null。null なら null、オブジェクトでなければ誤りにして null。
func object_or_null(fields: Dictionary, key: String, location: String) -> Variant:
	if not fields.has(key):
		fail(location, "無い")
		return null
	var value: Variant = fields[key]
	if value == null:
		return null
	if typeof(value) != TYPE_DICTIONARY:
		fail(location, "オブジェクトでも null でもない")
		return null
	return value


## 配列（件数が min_count〜max_count）。外れたら空。
func array(fields: Dictionary, key: String, location: String, min_count: int, max_count: int) -> Array:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_ARRAY:
		fail(location, "配列でない")
		return []
	var items: Array = value
	if items.size() < min_count or items.size() > max_count:
		fail(location, "件数が %d〜%d でない: %d" % [min_count, max_count, items.size()])
		return []
	return items


## 整数（JSON の数は float で来るので、整数の値であることを確かめる）。範囲外は -1。
func integer(fields: Dictionary, key: String, location: String, min_value: int, max_value: int) -> int:
	var value: Variant = fields.get(key)
	if not is_integer(value):
		fail(location, "整数でない")
		return -1
	# 整数にする前に範囲を見る（1e300 のような大きな数を int にすると、値が変わってしまうため）
	if float(value) < min_value or float(value) > max_value:
		fail(location, "%d〜%d でない: %s" % [min_value, max_value, str(value)])
		return -1
	return int(value)


func boolean(fields: Dictionary, key: String, location: String) -> bool:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_BOOL:
		fail(location, "真偽値でない")
		return false
	return value


## 文字列（pattern が空でなければ、それに一致すること）。外れたら空文字。
func text(fields: Dictionary, key: String, location: String, pattern: RegEx = null) -> String:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_STRING:
		fail(location, "文字列でない")
		return ""
	var string: String = value
	if string.length() > MAX_STRING_LENGTH:
		fail(location, "%d 文字を超える" % MAX_STRING_LENGTH)
		return ""
	if pattern != null and pattern.search(string) == null:
		fail(location, "形が違う: %s" % string)
		return ""
	return string


## 区分値の名前（enum_values は GameEnums の enum）。外れたら -1。
func enum_value(fields: Dictionary, key: String, location: String, enum_values: Dictionary) -> int:
	var value: Variant = fields.get(key)
	if typeof(value) != TYPE_STRING or not enum_values.has(value):
		fail(location, "区分値でない: %s" % str(value))
		return -1
	return enum_values[value] as int


## エリア（"M2-L1" の形）。外れたら null。
func area(fields: Dictionary, key: String, location: String) -> PitchArea:
	var value: Variant = fields.get(key)
	var parsed: PitchArea = PitchArea.from_key(value) if typeof(value) == TYPE_STRING else null
	if parsed == null:
		fail(location, "エリアでない: %s" % str(value))
	return parsed


## エリアか null。キーが無い・エリアでも null でもなければ誤り。
func area_or_null(fields: Dictionary, key: String, location: String) -> PitchArea:
	if not fields.has(key):
		fail(location, "無い")
		return null
	if fields[key] == null:
		return null
	return area(fields, key, location)


static func is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and float(value) == floorf(value)

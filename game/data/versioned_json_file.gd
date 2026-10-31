## 端末内保存の JSON ファイル1つ（戦績・回答結果）の読み込みと書き込み（component-design.md §4.3「破損・新しい版のときに
## 元のファイルを失わない」）。書き込みの手順は SaveFileIO。中身の形と検証は、呼び出し側が渡す decode
## （最上位の値 → 読めれば中身、駄目なら null）。同じ中身を何度も解析しないよう、直前に解析した（または書いた）文字列と
## その結果だけを覚えておく。
## ・破損: 本体（無ければ .bak）を <名前>.corrupt-<YYYYMMDD-HHMMSS> へ名前を変えて退避し、空として扱う。
##   退避できなければ、壊れたファイルを上書きしないよう書き込みを断る（can_write が偽）。
##   本体が壊れていて .bak が読めるとき（書き込みの途中で止まった後に本体が壊れたなど）は、.bak を使い、壊れた本体は退避する
##   （退避しないと、次の書き込みで本体が .bak へ回されて消える）
## ・新しい版（format_version が今の版より新しい）: 空として扱い、書き込まない（古い版のアプリで新しい版のデータを上書きしない）
class_name VersionedJsonFile
extends RefCounted

enum LoadState { OK, EMPTY, CORRUPTED, NEWER_VERSION }

var _path: String
var _format_version: int
var _decode: Callable
var _load_state: LoadState = LoadState.EMPTY
## 直前の読み込みで破損を見つけ、退避できなかったか
var _is_quarantine_failed: bool = false
## 直前に解析した（または書いた）文字列と、その結果（読めなければ null の中身・新しい版か）
var _parsed_text: String = ""
var _parsed_value: Variant = null
var _is_parsed_newer: bool = false


## decode は最上位の値（JSON.parse_string の結果）を受け、読めれば中身、駄目なら null を返す。
func _init(path: String, format_version: int, decode: Callable) -> void:
	_path = path
	_format_version = format_version
	_decode = decode


## 読めた中身（decode の結果）。無い・破損・新しい版なら null。結果は load_state() で読める。
## 中身は覚えている値そのものなので、呼び出し側は書き換えずに写して使う。
func load() -> Variant:
	_is_quarantine_failed = false
	if not SaveFileIO.exists(_path):
		# 本体も .bak も無い。書き込みの途中の .tmp だけが残っていれば消しておく
		SaveFileIO.read(_path, _is_usable)
		_load_state = LoadState.EMPTY
		return null
	var bak_path: String = _path + SaveFileIO.BAK_SUFFIX
	if FileAccess.file_exists(_path) and FileAccess.file_exists(bak_path) \
			and not _is_usable(SaveFileIO.read_limited(_path)):
		if not _quarantine(_path):
			_load_state = LoadState.CORRUPTED
			_is_quarantine_failed = true
			return null
	var text: String = SaveFileIO.read(_path, _is_usable)
	if text.is_empty():
		_load_state = LoadState.CORRUPTED
		var source: String = _path if FileAccess.file_exists(_path) else bak_path
		_is_quarantine_failed = not _quarantine(source)
		return null
	_parse(text)
	if _is_parsed_newer:
		_load_state = LoadState.NEWER_VERSION
		return null
	_load_state = LoadState.OK
	return _parsed_value


## 直前の load の結果。
func load_state() -> LoadState:
	return _load_state


## 直前の load の後に書いてよいか（新しい版・退避できなかった破損では書かない）。
func can_write() -> bool:
	return _load_state != LoadState.NEWER_VERSION and not _is_quarantine_failed


## text を書く。value は text を読んだときの中身（次の load で解析し直さないよう覚える）。失敗したら false。
func write(text: String, value: Variant) -> bool:
	if not SaveFileIO.write(_path, text):
		return false
	_parsed_text = text
	_parsed_value = value
	_is_parsed_newer = false
	return true


## 最上位の format_version（整数でなければ -1）。新しい版かどうかを、中身を確かめる前に見分けるのに使う。
static func version_of(root: Variant) -> int:
	if typeof(root) != TYPE_DICTIONARY:
		return -1
	var value: Variant = (root as Dictionary).get("format_version")
	return int(value) if SaveDataReader.is_integer(value) and absf(float(value)) < 1e9 else -1


## 本体を使うか .bak へ回るかを決める: 読めて検証が通るか、新しい版なら使う（新しい版は中身を確かめない）。
func _is_usable(text: String) -> bool:
	if text.is_empty():
		return false
	_parse(text)
	return _is_parsed_newer or _parsed_value != null


## text を解析して覚える。直前と同じ文字列なら解析し直さない。
func _parse(text: String) -> void:
	if text == _parsed_text and not text.is_empty():
		return
	_parsed_text = text
	var root: Variant = JSON.parse_string(text)
	_is_parsed_newer = root != null and version_of(root) > _format_version
	_parsed_value = null if root == null or _is_parsed_newer else _decode.call(root)


## 壊れたファイルを退避する。名前を変えられたら true。本体を退避したら、本体が無い間に古い .bak が使われないよう
## .bak も確かめ直す（読めない .bak は消す。読める .bak は残して、それを使う）。
func _quarantine(source: String) -> bool:
	if not SaveFileIO.move_aside(source, _path):
		return false
	var bak_path: String = _path + SaveFileIO.BAK_SUFFIX
	if source != bak_path and FileAccess.file_exists(bak_path) and not _is_usable(SaveFileIO.read_limited(bak_path)):
		DirAccess.remove_absolute(bak_path)
	return true

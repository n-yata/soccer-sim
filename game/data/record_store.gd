## 戦績（user://match_records.json）の読み込みと追記（component-design.md §4.3・data-definition.md §2.2）。
## 書き込みの手順は SaveFileIO、形と検証は MatchRecordCodec。追記のたびにファイルを読み直す（終わった試合ごとに1回だけ）。
## 同じ中身を何度も解析しないよう、直前に解析した（または書いた）文字列とその結果だけを覚えておく。
## ・破損: 本体（無ければ .bak）を <名前>.corrupt-<YYYYMMDD-HHMMSS> へ名前を変えて退避し、0件として扱う。
##   退避できなければ、壊れたファイルを上書きしないよう追記を断る。
##   本体が壊れていて .bak が読めるとき（書き込みの途中で止まった後に本体が壊れたなど）は、.bak を使い、壊れた本体は退避する
##   （退避しないと、次の書き込みで本体が .bak へ回されて消える）
## ・新しい版（format_version が今の版より新しい）: 0件として扱い、書き込まない（古い版のアプリで新しい版のデータを上書きしない）
class_name RecordStore
extends RefCounted

enum LoadState { OK, EMPTY, CORRUPTED, NEWER_VERSION }

const FILE_NAME: String = "match_records.json"
const CORRUPT_INFIX: String = ".corrupt-"
## 退避先の名前が既にあるとき（同じ秒に2回退避した）に試す、連番の数
const MAX_QUARANTINE_SUFFIX: int = 9
## 書き込み後のファイルの大きさの上限（読み込みの上限 SaveFileIO.MAX_READ_BYTES より小さくする）
const MAX_WRITE_BYTES: int = 4 * 1024 * 1024

var _path: String
var _codec: MatchRecordCodec
var _load_state: LoadState = LoadState.EMPTY
## 直前の読み込みで破損を見つけ、退避できなかったか
var _is_quarantine_failed: bool = false
## 直前に解析した（または書いた）文字列と、その結果（読めなければ null の戦績・新しい版か）
var _parsed_text: String = ""
var _parsed_records: Variant = null
var _is_parsed_newer: bool = false


## dir はテストで別の場所を使うための引数。アプリは既定値を使う。
func _init(rules: MatchRuleConfig, dir: String = "user://") -> void:
	_path = dir.path_join(FILE_NAME)
	_codec = MatchRecordCodec.new(rules)


## 記録した順（古いものが先）。破損・新しい版・無いときは空。結果は load_state() で読める。
func load_all() -> Array[MatchRecord]:
	_is_quarantine_failed = false
	if not SaveFileIO.exists(_path):
		# 本体も .bak も無い。書き込みの途中の .tmp だけが残っていれば消しておく
		SaveFileIO.read(_path, _is_usable)
		_load_state = LoadState.EMPTY
		return []
	var bak_path: String = _path + SaveFileIO.BAK_SUFFIX
	if FileAccess.file_exists(_path) and FileAccess.file_exists(bak_path) \
			and not _is_usable(SaveFileIO.read_limited(_path)):
		if not _quarantine(_path):
			_load_state = LoadState.CORRUPTED
			_is_quarantine_failed = true
			return []
	var text: String = SaveFileIO.read(_path, _is_usable)
	if text.is_empty():
		_load_state = LoadState.CORRUPTED
		var source: String = _path if FileAccess.file_exists(_path) else bak_path
		_is_quarantine_failed = not _quarantine(source)
		return []
	_parse(text)
	if _is_parsed_newer:
		_load_state = LoadState.NEWER_VERSION
		return []
	_load_state = LoadState.OK
	# 覚えている結果は書き換えさせない（append が足したり捨てたりする）
	return (_parsed_records as Array[MatchRecord]).duplicate()


## 直前の load_all（append の中の読み直しを含む）の結果。
func load_state() -> LoadState:
	return _load_state


## 1件足す。同じ match_id があれば書かずに true（終了処理をやり直しても二重に記録しない）。
## 新しい版・退避できなかった破損のときは書かずに false。件数か大きさの上限を超えるなら、超えなくなるまで古いものから捨てる。
func append(record: MatchRecord) -> bool:
	var records: Array[MatchRecord] = load_all()
	if _load_state == LoadState.NEWER_VERSION or _is_quarantine_failed:
		return false
	for existing: MatchRecord in records:
		if existing.match_id == record.match_id:
			return true
	records.append(record)
	if records.size() > MatchRecordCodec.MAX_RECORDS:
		records = records.slice(records.size() - MatchRecordCodec.MAX_RECORDS)
	var text: String = MatchRecordCodec.to_json(records)
	var size: int = text.to_utf8_buffer().size()
	while size > MAX_WRITE_BYTES and records.size() > 1:
		# 1件あたりの大きさから、超えた分に見合う件数をまとめて捨てる（1件ずつ書き出し直すと、改変された大きなファイルで重い）
		var drop: int = clampi(ceili(float(size - MAX_WRITE_BYTES) * records.size() / size), 1, records.size() - 1)
		records = records.slice(drop)
		text = MatchRecordCodec.to_json(records)
		size = text.to_utf8_buffer().size()
	if not SaveFileIO.write(_path, text):
		return false
	_parsed_text = text
	_parsed_records = records
	_is_parsed_newer = false
	return true


## 直前の読み込みで見つかった誤り（開発時の確認用）。
func errors() -> Array[String]:
	return _codec.errors()


## 本体を使うか .bak へ回るかを決める: 読めて検証が通るか、新しい版なら使う（新しい版は中身を確かめない）。
func _is_usable(text: String) -> bool:
	if text.is_empty():
		return false
	_parse(text)
	return _is_parsed_newer or _parsed_records != null


## text を解析して覚える。直前と同じ文字列なら解析し直さない。
func _parse(text: String) -> void:
	if text == _parsed_text and not text.is_empty():
		return
	_parsed_text = text
	var root: Variant = JSON.parse_string(text)
	_is_parsed_newer = root != null and MatchRecordCodec.version_of(root) > MatchRecordCodec.FORMAT_VERSION
	_parsed_records = null if root == null or _is_parsed_newer else _codec.decode(root)


## 壊れたファイルを退避する。名前を変えられたら true。本体を退避したら、本体が無い間に古い .bak が使われないよう
## .bak も確かめ直す（読めない .bak は消す。読める .bak は残して、それを使う）。
func _quarantine(source: String) -> bool:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var stamp: String = "%04d%02d%02d-%02d%02d%02d" % [now["year"], now["month"], now["day"],
			now["hour"], now["minute"], now["second"]]
	if not _rename_to_free_name(source, _path + CORRUPT_INFIX + stamp):
		return false
	var bak_path: String = _path + SaveFileIO.BAK_SUFFIX
	if source != bak_path and FileAccess.file_exists(bak_path) and not _is_usable(SaveFileIO.read_limited(bak_path)):
		DirAccess.remove_absolute(bak_path)
	return true


## 退避先の名前（無ければそのまま、あれば「-1」〜の連番を付けた名前）へ変える。どれも使えなければ false。
static func _rename_to_free_name(source: String, target: String) -> bool:
	for suffix: int in range(MAX_QUARANTINE_SUFFIX + 1):
		var candidate: String = target if suffix == 0 else "%s-%d" % [target, suffix]
		if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
			continue
		return DirAccess.rename_absolute(source, candidate) == OK
	return false

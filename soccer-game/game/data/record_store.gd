## 戦績（user://match_records.json）の読み込みと追記（component-design.md §4.3・data-definition.md §2.2）。
## 破損・新しい版の扱いと書き込みの手順は VersionedJsonFile、形と検証は MatchRecordCodec。
## 追記のたびにファイルを読み直す（終わった試合ごとに1回だけ）。破損・新しい版・無いときは0件として扱う。
class_name RecordStore
extends RefCounted

const FILE_NAME: String = "match_records.json"
## 書き込み後のファイルの大きさの上限（読み込みの上限 SaveFileIO.MAX_READ_BYTES より小さくする）
const MAX_WRITE_BYTES: int = 4 * 1024 * 1024

var _codec: MatchRecordCodec
var _file: VersionedJsonFile


## dir はテストで別の場所を使うための引数。アプリは既定値を使う。
func _init(rules: MatchRuleConfig, dir: String = "user://") -> void:
	_codec = MatchRecordCodec.new(rules)
	_file = VersionedJsonFile.new(dir.path_join(FILE_NAME), MatchRecordCodec.FORMAT_VERSION, _codec.decode)


## 記録した順（古いものが先）。破損・新しい版・無いときは空。結果は load_state() で読める。
func load_all() -> Array[MatchRecord]:
	var loaded: Variant = _file.load()
	if loaded == null:
		return []
	# 覚えている結果は書き換えさせない（append が足したり捨てたりする）
	return (loaded as Array[MatchRecord]).duplicate()


## 直前の load_all（append の中の読み直しを含む）の結果。
func load_state() -> VersionedJsonFile.LoadState:
	return _file.load_state()


## 1件足す。同じ match_id があれば書かずに true（終了処理をやり直しても二重に記録しない）。
## 新しい版・退避できなかった破損のときは書かずに false。件数か大きさの上限を超えるなら、超えなくなるまで古いものから捨てる。
func append(record: MatchRecord) -> bool:
	var records: Array[MatchRecord] = load_all()
	if not _file.can_write():
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
	return _file.write(text, records)


## 直前の読み込みで見つかった誤り（開発時の確認用）。
func errors() -> Array[String]:
	return _codec.errors()

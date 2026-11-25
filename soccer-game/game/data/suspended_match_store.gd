## 中断データ（進行中の1試合とターン記録。user://suspended_match.json）の保存・読み込み・削除（component-design.md §4.3）。
## 書き込みの手順は SaveFileIO、形と検証は SuspendedMatchEncoder・SuspendedMatchDecoder。
## 中断データは、破損も新しい版も CORRUPTED として扱う（戦績と違って退避しない。進行中の1試合だけで、積み重ねたデータではないため）。
class_name SuspendedMatchStore
extends RefCounted

const FILE_NAME: String = "suspended_match.json"

var _path: String
var _decoder: SuspendedMatchDecoder


## dir はテストで別の場所を使うための引数。アプリは既定値を使う。
func _init(catalog: ContentCatalog, rules: MatchRuleConfig, dir: String = "user://") -> void:
	_path = dir.path_join(FILE_NAME)
	_decoder = SuspendedMatchDecoder.new(catalog, rules)


func load() -> SuspendedLoad:
	if not SaveFileIO.exists(_path):
		# 本体も .bak も無い。書き込みの途中の .tmp だけが残っていれば消しておく
		SaveFileIO.read(_path, _is_decodable)
		return SuspendedLoad.new(SuspendedLoad.Status.NONE)
	var text: String = SaveFileIO.read(_path, _is_decodable)
	if text.is_empty():
		return SuspendedLoad.new(SuspendedLoad.Status.CORRUPTED)
	return SuspendedLoad.new(SuspendedLoad.Status.OK, _decoder.decode(JSON.parse_string(text)))


func save(state: MatchState) -> bool:
	return SaveFileIO.write(_path, SuspendedMatchEncoder.to_json(state))


func delete() -> bool:
	return SaveFileIO.delete(_path)


## 直前の読み込みで見つかった誤り（開発時の確認用）。
func errors() -> Array[String]:
	return _decoder.errors()


## 本体を使うか .bak へ回るかを決めるため、JSON として読めて検証も通るかを見る。
func _is_decodable(text: String) -> bool:
	return _decoder.decode(JSON.parse_string(text)) != null

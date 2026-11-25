## 設定（user://settings.cfg。ConfigFile の書式）の読み込みと保存（component-design.md §4.3・data-definition.md §2.4）。
## 書き込みは ConfigFile の文字列（encode_to_text）を SaveFileIO の手順（.tmp → .bak）で書く。
## 読み込みは ConfigFile.parse を使わず、この設定が使う形だけを受け付ける限定の読み方で読む
## （ConfigFile.parse は値の Object(...)・Resource(...) からオブジェクトを作り、リソースを読み込む。利用者が書き換えられる
## ファイルでそれを起こさないため。コミット前レビュー H-1。2026-10-29）。受け付ける行は「[節]」「キー=値」「;・# の注釈」「空行」だけで、
## 値は整数・小数・true・false（単純な文字列と英字だけの語は型違いとしてキーごとに直す）。組み立てる書き方（Vector2(...) など）を
## 含むファイルは破損として扱う。
## ・キーごと: 範囲外・型違い・無いキーは、そのキーだけを初期値にする（設定はキー単位で直せるため。通知しない）
## ・破損（上の形でない、[meta] format_version が無い・整数でない・1 未満）: 本体を退避して初期値。退避できなければ保存を断る。
##   本体が壊れていて .bak が読めるときは .bak を使い、壊れた本体は退避する（退避しないと、次の書き込みで本体が .bak へ回されて消える）
## ・新しい版（format_version が今の版より新しい）: 初期値で表示し、書き込まない
class_name SettingsStore
extends RefCounted

## 値は VersionedJsonFile.LoadState と同じ意味（クラスの内側なので名前は衝突しない）
enum LoadState { OK, EMPTY, CORRUPTED, NEWER_VERSION }

const FILE_NAME: String = "settings.cfg"
const FORMAT_VERSION: int = 1

static var _section_regex: RegEx = RegEx.create_from_string("^\\[([a-z_]+)\\]$")
static var _entry_regex: RegEx = RegEx.create_from_string("^([a-z_]+)\\s*=\\s*(.*)$")
static var _int_regex: RegEx = RegEx.create_from_string("^-?[0-9]+$")
static var _float_regex: RegEx = RegEx.create_from_string("^-?[0-9]+(\\.[0-9]+)?(e[-+]?[0-9]+)?$")
## 型違いとして読む値（キーごとに初期値にする）: 引用符で囲んだ単純な文字列と、英字だけの語（nan・inf・null など）
static var _mismatch_regex: RegEx = RegEx.create_from_string("^(\"[^\"\\\\]*\"|[A-Za-z_]+)$")
## 上の書式で読めないファイルから、版の行だけを拾う（新しい版は、この版の知らない値を含みうるため。値は組み立てない）
static var _version_line_regex: RegEx = RegEx.create_from_string("(?m)^\\s*format_version\\s*=\\s*([0-9]{1,18})\\s*$")

var _path: String
var _load_state: LoadState = LoadState.EMPTY
## 直前の読み込みで破損を見つけ、退避できなかったか
var _is_move_aside_failed: bool = false


## dir はテストで別の場所を使うための引数。アプリは既定値を使う。
func _init(dir: String = "user://") -> void:
	_path = dir.path_join(FILE_NAME)


## 破損・新しい版・無いときは初期値。結果は load_state() で読める。
func load() -> UserSettings:
	_is_move_aside_failed = false
	if not SaveFileIO.exists(_path):
		# 本体も .bak も無い。書き込みの途中の .tmp だけが残っていれば消しておく
		SaveFileIO.read(_path, _is_usable)
		_load_state = LoadState.EMPTY
		return UserSettings.new()
	var bak_path: String = _path + SaveFileIO.BAK_SUFFIX
	if FileAccess.file_exists(_path) and FileAccess.file_exists(bak_path) \
			and not _is_usable(SaveFileIO.read_limited(_path)):
		if not SaveFileIO.move_aside(_path, _path):
			_load_state = LoadState.CORRUPTED
			_is_move_aside_failed = true
			return UserSettings.new()
	var text: String = SaveFileIO.read(_path, _is_usable)
	if text.is_empty():
		_load_state = LoadState.CORRUPTED
		var source: String = _path if FileAccess.file_exists(_path) else bak_path
		_is_move_aside_failed = not SaveFileIO.move_aside(source, _path)
		return UserSettings.new()
	# 書式で読めないのに使えると判断したのは、新しい版のとき（_is_usable）
	var sections: Variant = parse(text)
	if sections == null or (_value(sections as Dictionary, "meta", "format_version") as int) > FORMAT_VERSION:
		_load_state = LoadState.NEWER_VERSION
		return UserSettings.new()
	_load_state = LoadState.OK
	return _settings_of(sections as Dictionary)


## 直前の load（save の中の読み直しを含む）の結果。
func load_state() -> LoadState:
	return _load_state


## 上書きする。新しい版・退避できなかった破損のときは書かずに false。
func save(settings: UserSettings) -> bool:
	# 書く前に今のファイルを確かめ直す（新しい版・退避できない破損を上書きしない）。素の load() は組み込みの load(path) になる
	self.load()
	if _load_state == LoadState.NEWER_VERSION or _is_move_aside_failed:
		return false
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", FORMAT_VERSION)
	config.set_value("audio", "bgm_volume", settings.bgm_volume)
	config.set_value("audio", "se_volume", settings.se_volume)
	config.set_value("ui", "show_hints", settings.show_hints)
	config.set_value("progress", "tutorial_completed", settings.tutorial_completed)
	return SaveFileIO.write(_path, config.encode_to_text())


## 設定の書式を読む。節 → {キー → 値（int・float・bool）}。受け付けない行・値が1つでもあれば null。
## 同じ節・キーが2回出たら後のものを使う（ConfigFile と同じ）。
static func parse(text: String) -> Variant:
	var sections: Dictionary = {}
	var section: String = ""
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		var header: RegExMatch = _section_regex.search(line)
		if header != null:
			section = header.get_string(1)
			if not sections.has(section):
				sections[section] = {}
			continue
		var entry: RegExMatch = _entry_regex.search(line)
		if entry == null or section.is_empty():
			return null
		var value: Variant = _scalar(entry.get_string(2).strip_edges())
		if value == null:
			return null
		(sections[section] as Dictionary)[entry.get_string(1)] = value
	return sections


## 整数・小数・true・false はその値。単純な文字列と英字だけの語は、型違いとして文字列のまま返す（キーごとに初期値になる）。
## それ以外（Object(...)・Resource(...)・Vector2(...) など、ConfigFile ならオブジェクトや値を組み立てる書き方）は null。
static func _scalar(text: String) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if _int_regex.search(text) != null:
		# 桁が多すぎる整数は int に収まらないので、型違いとして扱う
		return text.to_int() if text.length() <= 18 else text
	if _float_regex.search(text) != null:
		return text.to_float()
	if _mismatch_regex.search(text) != null:
		return text
	return null


## 本体を使うか .bak へ回るかを決める: 上の書式で読めて、format_version が今の版以上の整数なら使う
## （中のキーはキーごとに直す。今の版より古い版は無いので、それより小さい値は破損）。
## 書式で読めなくても、版の行が今の版より新しければ使う（新しい版として、中身を確かめずに書き込まない。戦績と同じ。
## コミット前レビュー L-6）。
static func _is_usable(text: String) -> bool:
	if text.is_empty():
		return false
	var sections: Variant = parse(text)
	if sections == null:
		var version_line: RegExMatch = _version_line_regex.search(text)
		return version_line != null and version_line.get_string(1).to_int() > FORMAT_VERSION
	var version: Variant = _value(sections as Dictionary, "meta", "format_version")
	return typeof(version) == TYPE_INT and (version as int) >= FORMAT_VERSION


## キーごとに確かめて読む。外れたキーは初期値のまま。
static func _settings_of(sections: Dictionary) -> UserSettings:
	var settings := UserSettings.new()
	settings.bgm_volume = _volume(_value(sections, "audio", "bgm_volume"), settings.bgm_volume)
	settings.se_volume = _volume(_value(sections, "audio", "se_volume"), settings.se_volume)
	settings.show_hints = _flag(_value(sections, "ui", "show_hints"), settings.show_hints)
	settings.tutorial_completed = _flag(_value(sections, "progress", "tutorial_completed"), settings.tutorial_completed)
	return settings


## 0.0〜1.0 の有限の数（整数の 0・1 も数として読む）。外れたら fallback。
static func _volume(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var number: float = float(value)
	# 範囲は内側にあることを肯定形で確かめる（NaN は比較がすべて偽になり、外れとして扱われる）
	if is_finite(number) and number >= 0.0 and number <= 1.0:
		return number
	return fallback


## 無いキーは null。
static func _value(sections: Dictionary, section: String, key: String) -> Variant:
	var entries: Variant = sections.get(section)
	return null if entries == null else (entries as Dictionary).get(key)


static func _flag(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback

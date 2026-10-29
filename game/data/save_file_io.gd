## 端末内保存のファイルの読み書き（component-design.md §4.3「書き込み手順」。NFR-08）。全ファイルで共通に使う。
## 強制終了でも直前に確定した状態を残すため、`.tmp` に全体を書いてから名前を入れ替える。
class_name SaveFileIO
extends RefCounted

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"
## 読み込む大きさの上限（component-design.md §4.3「読み込み時の検証」の 5MB。改変されたファイルを全量読み込まない）
const MAX_READ_BYTES: int = 5 * 1024 * 1024


## 1. .tmp に全体を書いて閉じる → 2. 本体があれば .bak へ → 3. .tmp を本体へ → 4. .bak を消す。どこかで失敗したら false。
static func write(path: String, text: String) -> bool:
	var tmp_path: String = path + TMP_SUFFIX
	var bak_path: String = path + BAK_SUFFIX
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	var is_stored: bool = file.store_string(text)
	file.close()
	if not is_stored:
		DirAccess.remove_absolute(tmp_path)
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		if DirAccess.rename_absolute(path, bak_path) != OK:
			DirAccess.remove_absolute(tmp_path)
			return false
	if DirAccess.rename_absolute(tmp_path, path) != OK:
		# 本体を .bak へ移した後なら、読み込みは .bak を使う（手順2と3の間で止まったのと同じ状態）
		return false
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)
	return true


## 本体を読み、is_valid（文字列 → bool）が偽なら .bak を読む。どちらも無いか駄目なら空文字。
## .tmp は書き込みの途中で止まった可能性があるので、読まずに消す。上限を超える大きさのファイルは読まない。
static func read(path: String, is_valid: Callable) -> String:
	var tmp_path: String = path + TMP_SUFFIX
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	for candidate: String in [path, path + BAK_SUFFIX]:
		var text: String = read_limited(candidate)
		if not text.is_empty() and is_valid.call(text):
			return text
	return ""


## 本体か .bak があるか（.tmp だけは「無い」）。
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


## 本体・.bak・.tmp をすべて消す（.bak から削除済みのデータが復活しないように）。1つでも消せなければ false。
static func delete(path: String) -> bool:
	var is_ok: bool = true
	for candidate: String in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if FileAccess.file_exists(candidate) and DirAccess.remove_absolute(candidate) != OK:
			is_ok = false
	return is_ok


## 1つのファイルを、上限を超えない大きさなら読む（無い・読めない・大きすぎるなら空文字）。.bak への切り替えはしない。
static func read_limited(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	if file.get_length() > MAX_READ_BYTES:
		file.close()
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

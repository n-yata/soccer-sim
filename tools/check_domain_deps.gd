## ドメイン層の禁止依存の検出（NFR-13）。
##
## 実行: godot --headless --path game --script <このファイルの絶対パス> -- [検査するディレクトリ] [--self-check <カテゴリ>]
##   ディレクトリを省くと res://domain を検査する。
##   通常: 禁止した参照が見つかれば終了コード 1、0 件なら 0。
##   --self-check <カテゴリ>: 検査そのものの空振りを確かめる（tools/run-tests.sh が fixture に対して使う）。
##     次をすべて満たせば 0、そうでなければ 1:
##     ・そのカテゴリの全ルールが1回以上当たる
##     ・行末に「# expect」の目印を付けた行が、すべて検出される（1つのルールに複数の書き方を割り当てたとき、
##       2つ目以降の書き方が退行しても気づけるようにするため）
##     ・ほかのカテゴリが1つも当たらない
##   検査できなければ 2（ディレクトリが無い・スクリプトが 0 件・正規表現を解釈できない・引数が不正・
##   読めないファイルがある・実行時エラーで最後まで走らなかった）。
##
## 禁止事項の正本は architecture-overview.md「ドメイン層」。検索する API 名の一覧は、このファイルを正本とする。
## ルールを足したら、game/tests/fixtures/forbidden_deps/<カテゴリ>/ にも、そのルールに当たる行を「# expect」付きで足す
## （足さなければ --self-check が失敗して気づける）。
extends SceneTree

const DEFAULT_TARGET: String = "res://domain"
const EXIT_CLEAN: int = 0
const EXIT_FOUND: int = 1
const EXIT_ERROR: int = 2
const SELF_CHECK_FLAG: String = "--self-check"
const EXPECT_MARKER: String = "# expect"

## extends で継承してよい組み込みの型。これ以外は検査対象のディレクトリ内の class_name だけを許す
## （Node の派生は名前が Node で始まらないもの（Control・Timer など）が多く、禁止側を列挙すると漏れるため許可側で持つ）
const ALLOWED_BASE_TYPES: Array[String] = ["RefCounted", "Resource", "Object"]
const EXTENDS_RULE: String = "extends に許可していない型"

## カテゴリ → 正規表現の一覧。コメントと文字列の中身を除いた行に当てる。
const RULES: Dictionary = {
	"node": [
		"\\bNode(2D|3D)?\\b",
		"\\bSceneTree\\b",
		"\\b(get_tree|get_node|get_node_or_null|get_parent|get_viewport|get_window|get_children|get_child|find_child|add_child|remove_child|queue_free|create_timer)\\s*\\(",
		"(?<![\\w%])\\$[A-Za-z_\"]",
		"(?<![\\w\\)\\]])%[A-Za-z_\"]",
		"\\bEngine\\s*\\.\\s*get_main_loop\\b",
		# 文字列でクラス名・シングルトン名・式を渡して、型名を書かずに禁止した API へ届く経路。
		# ClassDB と Expression はドメインで使う理由が無いので、名前ごと禁止する
		"\\bEngine\\s*\\.\\s*get_singleton\\s*\\(|\\b(ClassDB|Expression)\\b",
	],
	"file": [
		"\\b(FileAccess|DirAccess|ResourceLoader|ResourceSaver|ConfigFile)\\b",
		"(?<![\\w.])(pre)?load\\s*\\(",
		# インスタンスの読み込み（Image.new().load(...) など）
		"\\.\\s*load\\s*\\(",
		"\\.\\s*load_from_file\\s*\\(",
	],
	# Godot 4 では時刻の取得は Time に集約されている（Godot 3 の OS.get_ticks_msec などは無い）。
	# 別名（var clock = Time）でも見逃さないよう、名前そのものを禁止する
	"time": [
		"\\bTime\\b",
		"\\bEngine\\s*\\.\\s*get_(physics|process)_frames\\b",
	],
	# RandomNumberGenerator は名前ごとは禁止しない（生成器は型注釈付きの引数としてドメインへ渡すため）。
	# 型を変数に入れてから new() する別名の経路は検出できない（申し送り）
	"random": [
		"(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\\s*\\(",
		"\\.\\s*(shuffle|pick_random)\\s*\\(",
		"\\bRandomNumberGenerator\\s*\\.\\s*new\\s*\\(",
	],
}

## 処理が最後まで走ったことの記録。GDScript では実行時エラーで関数が打ち切られると、戻り値の型の既定値
## （int なら 0、つまり「違反なし」）が返り、呼び出し側はそのまま進んでしまう。最後まで走った数を数えて突き合わせ、
## 合わなければ検査できなかったとして EXIT_ERROR にする（fail closed）
var _started_dirs: int = 0
var _finished_dirs: int = 0
var _finished_files: int = 0
var _is_class_scan_finished: bool = false
var _is_self_check_finished: bool = false
var _is_run_finished: bool = false

## "パス:行番号" → true。目印を付けた行と、報告した行（--self-check で突き合わせる）
var _expected_lines: Dictionary = {}
var _reported_lines: Dictionary = {}

## 行のどこにある extends も拾う（1行の「class_name X extends Y」と、内部クラスの「class X extends Y:」を含む）。
## 継承先は識別子のときだけ許可リストと照合する。パス指定（extends "res://..."）は識別子にならないので許可しない
var _extends_regex: RegEx = RegEx.create_from_string("(?:^|\\s)extends\\s+([^\\s:]+)")


func _init() -> void:
	var code: int = _run(OS.get_cmdline_user_args())
	if not _is_run_finished:
		printerr("check_domain_deps: 実行時エラーで検査を最後まで行えなかった")
		code = EXIT_ERROR
	quit(code)


func _finish(code: int) -> int:
	_is_run_finished = true
	return code


func _run(args: PackedStringArray) -> int:
	var target: String = DEFAULT_TARGET
	var self_check_category: String = ""
	var i: int = 0
	while i < args.size():
		if args[i] == SELF_CHECK_FLAG and i + 1 < args.size() and RULES.has(args[i + 1]):
			self_check_category = args[i + 1]
			i += 2
		elif not args[i].begins_with("--"):
			target = args[i]
			i += 1
		else:
			printerr("check_domain_deps: 引数が不正: %s" % " ".join(args))
			return _finish(EXIT_ERROR)
	if not DirAccess.dir_exists_absolute(target):
		printerr("check_domain_deps: ディレクトリが無い: %s" % target)
		return _finish(EXIT_ERROR)
	var compiled: Array[Dictionary] = _compile_rules()
	if compiled.is_empty():
		return _finish(EXIT_ERROR)
	var files: Array[String] = []
	_collect_scripts(target, files)
	if _finished_dirs != _started_dirs:
		return _finish(EXIT_ERROR)
	if files.is_empty():
		# 「違反が無い」と「1件も検査していない」を区別するため、0件は失敗にする
		printerr("check_domain_deps: 検査するスクリプトが 0 件: %s" % target)
		return _finish(EXIT_ERROR)
	var allowed_bases: Array[String] = ALLOWED_BASE_TYPES.duplicate()
	allowed_bases.append_array(_class_names_under(target))
	if not _is_class_scan_finished:
		return _finish(EXIT_ERROR)
	var hits: Dictionary = {}   # "カテゴリ\tルール" → 件数
	var found: int = 0
	for path: String in files:
		found += _check_file(path, compiled, allowed_bases, hits)
	if _finished_files != files.size():
		printerr("check_domain_deps: 最後まで検査できたスクリプトが %d / %d 件" % [_finished_files, files.size()])
		return _finish(EXIT_ERROR)
	print("check_domain_deps: %s のスクリプト %d 件を検査し、禁止した参照が %d 件" % [target, files.size(), found])
	if not self_check_category.is_empty():
		var result: int = _self_check_result(self_check_category, hits)
		return _finish(result if _is_self_check_finished else EXIT_ERROR)
	return _finish(EXIT_FOUND if found > 0 else EXIT_CLEAN)


func _compile_rules() -> Array[Dictionary]:
	var compiled: Array[Dictionary] = []
	for category: String in RULES:
		var patterns: Array = RULES[category]
		for pattern: String in patterns:
			var regex := RegEx.new()
			if regex.compile(pattern) != OK:
				printerr("check_domain_deps: 正規表現を解釈できない: %s" % pattern)
				return []
			compiled.append({"category": category, "rule": pattern, "regex": regex})
	return compiled


func _collect_scripts(dir_path: String, out: Array[String]) -> void:
	_started_dirs += 1
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect_scripts(dir_path.path_join(sub_dir), out)
	_finished_dirs += 1


## 検査対象のディレクトリの下で宣言された class_name（ドメイン内の継承を許すため）。
## 行を正規表現で読むのではなく、Godot が構文解析したグローバルなクラスの一覧から取る
## （複数行の文字列やコメントの中の「class_name X」にだまされないため）。
## 検査対象が res:// の外にあるときは、一覧に載らないので何も許さない（厳しい側に倒れる）。
func _class_names_under(target: String) -> Array[String]:
	var names: Array[String] = []
	var prefix: String = target.trim_suffix("/") + "/"
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with(prefix):
			names.append(String(entry["class"]))
	_is_class_scan_finished = true
	return names


func _check_file(path: String, compiled: Array[Dictionary], allowed_bases: Array[String],
		hits: Dictionary) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# _finished_files が増えないので、全体は「検査できなかった」（EXIT_ERROR）になる
		printerr("%s: 読めない（%s）" % [path, error_string(FileAccess.get_open_error())])
		return 0
	var found: int = 0
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		var location: String = "%s:%d" % [path, line_number]
		# 目印はコメントなので、コメントを落とす前の行で読む
		if line.strip_edges().ends_with(EXPECT_MARKER):
			_expected_lines[location] = true
		var code: String = _strip_comment_and_strings(line)
		var extends_match: RegExMatch = _extends_regex.search(code)
		if extends_match != null and not allowed_bases.has(extends_match.get_string(1)):
			found += _report(location, "node", EXTENDS_RULE, extends_match.get_string(), hits)
		for rule: Dictionary in compiled:
			var regex: RegEx = rule["regex"]
			var match: RegExMatch = regex.search(code)
			if match != null:
				found += _report(location, rule["category"] as String, rule["rule"] as String,
						match.get_string(), hits)
	_finished_files += 1
	return found


func _report(location: String, category: String, rule: String, matched: String, hits: Dictionary) -> int:
	print("%s: [%s] %s（ルール: %s）" % [location, category, matched.strip_edges(), rule])
	var key: String = category + "\t" + rule
	hits[key] = (hits.get(key, 0) as int) + 1
	_reported_lines[location] = true
	return 1


func _self_check_result(category: String, hits: Dictionary) -> int:
	var expected_rules: Array[String] = []
	for pattern: String in (RULES[category] as Array):
		expected_rules.append(pattern)
	if category == "node":
		expected_rules.append(EXTENDS_RULE)
	var is_ok: bool = true
	var hit_rule_count: int = 0
	for rule: String in expected_rules:
		if hits.has(category + "\t" + rule):
			hit_rule_count += 1
		else:
			print("self-check: [%s] 当たらなかったルール: %s" % [category, rule])
			is_ok = false
	var detected_line_count: int = 0
	for location: String in _expected_lines:
		if _reported_lines.has(location):
			detected_line_count += 1
		else:
			print("self-check: [%s] 検出されなかった行: %s" % [category, location])
			is_ok = false
	if _expected_lines.is_empty():
		print("self-check: [%s] 目印（%s）の付いた行が無い" % [category, EXPECT_MARKER])
		is_ok = false
	for key: String in hits:
		if not key.begins_with(category + "\t"):
			print("self-check: [%s] ほかのカテゴリが当たった: %s" % [category, key.replace("\t", " ")])
			is_ok = false
	print("self-check: [%s] ルール %d 件中 %d 件、行 %d 件中 %d 件を検出した" % [
			category, expected_rules.size(), hit_rule_count, _expected_lines.size(), detected_line_count])
	_is_self_check_finished = true
	return EXIT_CLEAN if is_ok else EXIT_FOUND


## コメント（# 以降）を落とし、文字列リテラルの中身を空白に置き換える。
## 解説文などの文字列に「Node」「Time」の語が出ても誤検出しないようにするため。
## 引用符そのものは残す（$"Path" の形を検出するため）。行単位なので、複数行の文字列は扱えない（申し送り）。
func _strip_comment_and_strings(line: String) -> String:
	var result: String = ""
	var quote: String = ""
	var is_escaped: bool = false
	for i: int in line.length():
		var ch: String = line[i]
		if quote.is_empty():
			if ch == "#":
				break
			if ch == "\"" or ch == "'":
				quote = ch
			result += ch
		else:
			if is_escaped:
				is_escaped = false
			elif ch == "\\":
				is_escaped = true
			elif ch == quote:
				quote = ""
				result += ch
				continue
			result += " "
	return result

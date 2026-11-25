## 回答結果（user://quiz_answers.json）の読み込みと追記（component-design.md §4.3・data-definition.md §2.3）。
## 破損・新しい版の扱いと書き込みの手順は VersionedJsonFile。読み込みは型・必須・範囲を確かめ、1つでも外れたら全体を使わない
## （破損として退避する。NFR-09）。問題 ID は ID の形であることだけを確かめ、quiz.json にあるかは見ない（問題を削除した後も、
## 古い回答を破損にしないため。集計から外すのは UserDataService）。
class_name QuizAnswerStore
extends RefCounted

const FILE_NAME: String = "quiz_answers.json"
const FORMAT_VERSION: int = 1
## 件数の上限（data-definition.md §2.3）。超えたら古いものから捨てて追記する
const MAX_ANSWERS: int = 30000

var _file: VersionedJsonFile
var _reader: SaveDataReader
var _id_regex: RegEx
var _datetime_regex: RegEx


## dir はテストで別の場所を使うための引数。アプリは既定値を使う。
func _init(dir: String = "user://") -> void:
	_id_regex = RegEx.create_from_string(ContentRepository.ID_PATTERN)
	_datetime_regex = RegEx.create_from_string(SuspendedMatchDecoder.DATETIME_PATTERN)
	_file = VersionedJsonFile.new(dir.path_join(FILE_NAME), FORMAT_VERSION, _decode)


## 回答の順（古いものが先）。破損・新しい版・無いときは空。結果は load_state() で読める。
func load_all() -> Array[QuizAnswer]:
	var loaded: Variant = _file.load()
	if loaded == null:
		return []
	# 覚えている結果は書き換えさせない（append が足したり捨てたりする）
	return (loaded as Array[QuizAnswer]).duplicate()


## 直前の load_all（append の中の読み直しを含む）の結果。
func load_state() -> VersionedJsonFile.LoadState:
	return _file.load_state()


## 1件足す。新しい版・退避できなかった破損のときは書かずに false。件数の上限を超えるなら古いものから捨てる。
func append(answer: QuizAnswer) -> bool:
	var answers: Array[QuizAnswer] = load_all()
	if not _file.can_write():
		return false
	answers.append(answer)
	if answers.size() > MAX_ANSWERS:
		answers = answers.slice(answers.size() - MAX_ANSWERS)
	var items: Array = []
	for item: QuizAnswer in answers:
		items.append({"question_id": item.question_id, "correct": item.correct, "answered_at": item.answered_at})
	return _file.write(JSON.stringify({"format_version": FORMAT_VERSION, "answers": items}), answers)


## 直前の読み込みで見つかった誤り（開発時の確認用）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


## 誤りがあれば null。
func _decode(root: Variant) -> Variant:
	_reader = SaveDataReader.new()
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return null
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", FORMAT_VERSION, FORMAT_VERSION)
	var items: Array = _reader.array(fields, "answers", "answers", 0, MAX_ANSWERS)
	var answers: Array[QuizAnswer] = []
	for index: int in range(items.size()):
		var location: String = "answers[%d]" % index
		if typeof(items[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var item: Dictionary = items[index]
		answers.append(QuizAnswer.new(_reader.text(item, "question_id", location + ".question_id", _id_regex),
				_reader.boolean(item, "correct", location + ".correct"),
				_reader.text(item, "answered_at", location + ".answered_at", _datetime_regex)))
	return answers if _reader.is_ok() else null

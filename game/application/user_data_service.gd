## 画面向けの戦績・設定・理解度チェックの回答結果の参照と保存（component-design.md §3.4。モジュール構成図の A2）。
## 戦績の追加はここだけを通す（MatchController の終了処理が呼ぶ。持っている値を1か所で更新するため）。
## 戦績・設定・回答結果は、それぞれ最初に使うときに1回だけ読み、結果をメモリに持つ。読み込みの失敗の通知も、その1回だけ出す。
## 保存の失敗の通知は、データごとに、失敗が続く間は最初の1回だけ出す（終了処理のやり直し・スライダーの操作・回答のたびに
## 重ねない。新しい版は読み込みの通知で知らせ済み）。
class_name UserDataService
extends RefCounted

## 戦績・設定の保存・読み込みに失敗した（App が storage_error へ中継する）
signal storage_failed(kind: AppScreens.StorageErrorKind)

var _record_store: RecordStore
## 記録した順（古いものが先）。読む前は null
var _records: Variant = null
## 直前の保存が失敗したか（新しい版のファイルは、読んだ時点で保存できないので真にする）
var _is_failing: bool = false
var _settings_store: SettingsStore
## 設定。読む前は null
var _settings: UserSettings
## 直前の設定の保存が失敗したか（戦績の _is_failing と同じ扱い）
var _is_settings_failing: bool = false
var _quiz_store: QuizAnswerStore
## 場面問題（正答状況の集計の分母と、問題 ID → 学習目標 ID）
var _questions: Array[QuizQuestionDef]
## 保存できた回答（ファイルの順。古いものが先）。読む前は null
var _answers: Variant = null
## 保存に失敗した回答（古いものが先）。次の回答のときに先に書き直す。集計には、保存できた回答の後に含める
var _unsaved_answers: Array[QuizAnswer] = []
## 直前の回答の保存が失敗したか（戦績の _is_failing と同じ扱い）
var _is_quiz_failing: bool = false


## questions は場面問題（LibraryService.quiz_questions() と同じもの）。
func _init(record_store: RecordStore, settings_store: SettingsStore, quiz_store: QuizAnswerStore,
		questions: Array[QuizQuestionDef]) -> void:
	_record_store = record_store
	_settings_store = settings_store
	_quiz_store = quiz_store
	_questions = questions.duplicate()


## 新しい順（終了日時の新しい順。同じ日時は後に記録したものが先）。写しを返す。
func records() -> Array[MatchRecord]:
	var ordered: Array[MatchRecord] = _loaded().duplicate()
	ordered.reverse()
	# 記録した順を逆にしてから、日時で安定に並べる（sort_custom は安定でないので、同じ日時は位置で比べる）
	var positions: Dictionary = {}
	for index: int in range(ordered.size()):
		positions[ordered[index]] = index
	ordered.sort_custom(func(a: MatchRecord, b: MatchRecord) -> bool:
		if a.finished_at != b.finished_at:
			return a.finished_at > b.finished_at
		return (positions[a] as int) < (positions[b] as int))
	return ordered


## 戦績を1件足す。同じ試合 ID があれば記録しない（true）。保存に失敗したら通知して false（呼んだ側は通知を重ねない）。
func append_record(record: MatchRecord) -> bool:
	_loaded()
	if _record_store.append(record):
		_is_failing = false
		# 上限で古い戦績を捨てていることがあるので、保存したものを読み直す（終わった試合ごとに1回だけ）
		_records = _record_store.load_all()
		return true
	if not _is_failing:
		_emit_save_failed(_record_store.load_state())
	_is_failing = true
	return false


## {"win": int, "draw": int, "lose": int}。保持している戦績（上限までの直近の試合）から数える。
func totals() -> Dictionary:
	var counts: Dictionary = {"win": 0, "draw": 0, "lose": 0}
	for record: MatchRecord in _loaded():
		match record.result:
			GameEnums.MatchResult.WIN:
				counts["win"] += 1
			GameEnums.MatchResult.DRAW:
				counts["draw"] += 1
			GameEnums.MatchResult.LOSE:
				counts["lose"] += 1
	return counts


func _loaded() -> Array[MatchRecord]:
	if _records != null:
		return _records
	var loaded: Array[MatchRecord] = _record_store.load_all()
	_is_failing = _emit_load_failed(_record_store.load_state())
	_records = loaded
	return loaded


## 学習目標 ID → {"answered": int, "correct": int, "total": int}（screen-09-quiz.md「正答状況の数え方」）。
## answered・correct は問題ごとの最新の回答で数える。total はその学習目標の問題の数。quiz.json に無い問題の回答は数えない。
func quiz_progress() -> Dictionary:
	var latest: Dictionary = {}
	for answer: QuizAnswer in _loaded_answers() + _unsaved_answers:
		latest[answer.question_id] = answer.correct
	var progress: Dictionary = {}
	for goal_id: String in QuizQuestionDef.GOAL_IDS:
		progress[goal_id] = {"answered": 0, "correct": 0, "total": 0}
	for question: QuizQuestionDef in _questions:
		var counts: Dictionary = progress[question.goal_id]
		counts["total"] += 1
		if latest.has(question.id):
			counts["answered"] += 1
			if latest[question.id] as bool:
				counts["correct"] += 1
	return progress


## 回答を1件足す。保存に失敗した回答は持っておき（画面の正答状況に含める）、次の回答のときに古いものから書き直す
## （書き直さないと、次の保存が成功してファイルを読み直した時点で、失敗した回答が集計から黙って消えるため）。
## 今回の回答まですべて書けたら true。書けないものが残れば通知して false（失敗が続く間の通知は1回だけ）。
func save_quiz_answer(answer: QuizAnswer) -> bool:
	_loaded_answers()
	_unsaved_answers.append(answer)
	var has_written: bool = false
	while not _unsaved_answers.is_empty() and _quiz_store.append(_unsaved_answers[0]):
		_unsaved_answers.pop_front()
		has_written = true
	if has_written:
		# 上限で古い回答を捨てていることがあるので、保存したものを読み直す
		_answers = _quiz_store.load_all()
	if _unsaved_answers.is_empty():
		_is_quiz_failing = false
		return true
	if not _is_quiz_failing:
		_emit_save_failed(_quiz_store.load_state())
	_is_quiz_failing = true
	return false


func _loaded_answers() -> Array[QuizAnswer]:
	if _answers != null:
		return _answers
	var loaded: Array[QuizAnswer] = _quiz_store.load_all()
	_is_quiz_failing = _emit_load_failed(_quiz_store.load_state())
	_answers = loaded
	return loaded


## 戦績・回答結果の読み込みの失敗を通知する。新しい版なら、保存が失敗するもの（真）として返す。
func _emit_load_failed(state: VersionedJsonFile.LoadState) -> bool:
	match state:
		VersionedJsonFile.LoadState.CORRUPTED:
			storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_LOAD)
		VersionedJsonFile.LoadState.NEWER_VERSION:
			storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_NEWER)
			return true
	return false


## 戦績・回答結果の保存の失敗を通知する（新しい版なら USER_DATA_NEWER）。
func _emit_save_failed(state: VersionedJsonFile.LoadState) -> void:
	storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_NEWER if state == VersionedJsonFile.LoadState.NEWER_VERSION
			else AppScreens.StorageErrorKind.USER_DATA_SAVE)


## 設定の写し（画面が書き換えても、保存するまで持っている値は変わらない）。
func settings() -> UserSettings:
	return _loaded_settings().duplicate_deep()


## 設定を保存する。失敗しても持っている値は更新する（画面上の値を保つ。screen-12-settings.md）。失敗したら通知して false。
func save_settings(settings_to_save: UserSettings) -> bool:
	_loaded_settings()
	_settings = settings_to_save.duplicate_deep()
	if _settings_store.save(_settings):
		_is_settings_failing = false
		return true
	if not _is_settings_failing:
		var is_newer: bool = _settings_store.load_state() == SettingsStore.LoadState.NEWER_VERSION
		storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_NEWER if is_newer
				else AppScreens.StorageErrorKind.USER_DATA_SAVE)
	_is_settings_failing = true
	return false


## チュートリアルを最後まで終えた（設定の tutorial_completed を真にして保存する）。
func mark_tutorial_completed() -> bool:
	var updated: UserSettings = settings()
	updated.tutorial_completed = true
	return save_settings(updated)


func _loaded_settings() -> UserSettings:
	if _settings != null:
		return _settings
	_settings = _settings_store.load()
	match _settings_store.load_state():
		SettingsStore.LoadState.CORRUPTED:
			storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_LOAD)
		SettingsStore.LoadState.NEWER_VERSION:
			storage_failed.emit(AppScreens.StorageErrorKind.USER_DATA_NEWER)
			_is_settings_failing = true
	return _settings

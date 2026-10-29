## 中断データの保存・読み込み・削除と、その失敗の扱い（component-design.md §3.2「保存の時点」・UC-05）。MatchController が持つ。
## ・保存に失敗しても試合は続ける。通知（storage_failed(SUSPEND_SAVE)）は失敗が続く間は最初の1回だけ出し、次に成功したら戻す
## ・タイトルの再開カード用に、再開できる中断データの写しを持つ（試合中は持たない。中断してタイトルへ戻ったときと起動時に読む）
## store が null なら何も保存しない（テストの多くとチュートリアル用。保存は常に成功した扱い）。
class_name SuspendKeeper
extends RefCounted

signal storage_failed(kind: AppScreens.StorageErrorKind)

var _store: SuspendedMatchStore
var _rules: MatchRuleConfig
## 直前の保存に失敗していて、中断データが最新の状態でないか
var _has_unsaved: bool = false
## 再開できる中断データの写し（タイトルの再開カード用）。無ければ null
var _resumable: MatchState
## 最終ターンまで終えたのに終了処理（戦績の記録）が済んでいない試合（FINALIZE_PENDING）。無ければ null
var _pending: MatchState


func _init(store: SuspendedMatchStore, rules: MatchRuleConfig) -> void:
	_store = store
	_rules = rules


## 上書き保存する。失敗したら通知して false。
func save(state: MatchState) -> bool:
	if _store == null:
		return true
	if _store.save(state):
		_has_unsaved = false
		return true
	if not _has_unsaved:
		storage_failed.emit(AppScreens.StorageErrorKind.SUSPEND_SAVE)
	_has_unsaved = true
	return false


func has_unsaved() -> bool:
	return _has_unsaved


## 中断データを消し、再開カード用の写しと終了処理待ちの試合も捨てる。
func delete() -> void:
	_resumable = null
	_pending = null
	_has_unsaved = false
	if _store != null:
		_store.delete()


## 新しい試合の最初の保存に失敗したとき、前の試合の中断データだけを消す（未保存の印は残す。次の保存の時点でやり直す）。
func drop_stale() -> void:
	if _store != null:
		_store.delete()


## 保存されている中断データを確かめ直し、再開できる写しを持つ（起動時と、中断してタイトルへ戻ったとき）。
## 破損 → 削除して通知（SUSPEND_LOAD）。FINISHED → 戦績は記録済みなので削除（FINALIZED）。
## 最終ターンまで終えた IN_PROGRESS → 終了処理待ち（pending）として持ち、FINALIZE_FAILED を返す（やり直しは MatchController）。
func inspect() -> AppScreens.StartupResult:
	_resumable = null
	_pending = null
	if _store == null:
		return AppScreens.StartupResult.NONE
	var loaded: SuspendedLoad = _store.load()
	match loaded.status:
		SuspendedLoad.Status.NONE:
			return AppScreens.StartupResult.NONE
		SuspendedLoad.Status.CORRUPTED:
			_store.delete()
			storage_failed.emit(AppScreens.StorageErrorKind.SUSPEND_LOAD)
			return AppScreens.StartupResult.CORRUPTED
	if loaded.state.status == GameEnums.MatchStatus.FINISHED:
		_store.delete()
		return AppScreens.StartupResult.FINALIZED
	if not is_resumable(loaded.state):
		_pending = loaded.state
		return AppScreens.StartupResult.FINALIZE_FAILED
	_resumable = loaded.state
	return AppScreens.StartupResult.RESUMABLE


## 再開のために読み直す（毎回保存データから。component-design.md §3.2 resume）。読めない・再開の対象でなければ、
## 削除して通知（SUSPEND_LOAD）し、null。
func load_for_resume() -> MatchState:
	if _store == null:
		return null
	var loaded: SuspendedLoad = _store.load()
	if loaded.status == SuspendedLoad.Status.OK and is_resumable(loaded.state):
		_resumable = null
		# 読み直した状態は保存データそのものなので、未保存の印を戻す（戻さないと、再開後の最初の保存の失敗を知らせない）
		_has_unsaved = false
		return loaded.state
	delete()
	storage_failed.emit(AppScreens.StorageErrorKind.SUSPEND_LOAD)
	return null


## 再開できる中断データの写し（無ければ null）。読むだけにする。
func resumable() -> MatchState:
	return _resumable


## 終了処理待ちの試合（無ければ null）。読むだけにする。
func pending() -> MatchState:
	return _pending


## 結果画面から出るときに終了処理のやり直しにも失敗した試合を、終了処理待ちとして持つ（中断データは消さずに残っている）。
func keep_pending(state: MatchState) -> void:
	_resumable = null
	_pending = state


## 試合を新しく始めたとき・再開したとき。試合中は再開カード・終了処理待ちを出さない
## （新しい試合なら、終了処理待ちの試合は利用者の確認を経て上書きされる。削除の時点①）。
func forget() -> void:
	_resumable = null
	_pending = null


func is_resumable(state: MatchState) -> bool:
	return state.status == GameEnums.MatchStatus.IN_PROGRESS and not MatchRules.is_play_complete(state, _rules)

## 試合進行の管理（component-design.md §3.2。モジュール構成図の A1）。ドメインの MatchRules を呼び、
## 利用者の視点への変換（ViewConverter）と、画面へのシグナル・画面の切り替えの要求を受け持つ。
## 利用者 = HOME、CPU = AWAY（§1.3）。
##
## 今回作った範囲は、試合の開始・1ターンの確定と開示・方式の選び直し・ハーフタイム・振り返り・中断データの保存と再開・
## 起動時の後始末・試合の終了処理（戦績の記録）とそのやり直し（2026-10-29）まで。チュートリアルは、その作業で足す
## （そのとき、設計書の引数 is_tutorial を足す）。保存の失敗の扱いと再開カード用の写しは SuspendKeeper が持つ。
## ファイルの目安 300 行を超えている（2026-10-29 に約 430 行）。UI の入口は設計上このクラス1つ（component-design.md §3.2）なので、
## 公開する関数はここに置き、中身を別のクラスへ分けている（変換は ViewConverter、保存は SuspendKeeper、終了処理は MatchFinalizer）。
class_name MatchController
extends RefCounted

## 中断データの保存・読み込みに失敗した（App が storage_error へ中継する。戦績の失敗は UserDataService が知らせる）
signal storage_failed(kind: AppScreens.StorageErrorKind)

## 盤面・スコア・相手の方式が変わった。ターンの途中（submit_turn の中）では出さず、continue_after_reveal・
## 方式の選び直し・ハーフタイムの確定・試合の開始の後に出す（試合画面は、これを受けて次のターンを始める）
signal state_changed(snapshot: BoardSnapshot)
## 開示（演出と判定理由の表示に使う）
signal turn_resolved(reveal: RevealView, snapshot: BoardSnapshot)
signal stage_changed(stage: GameEnums.MatchStage)

const USER: GameEnums.TeamSide = GameEnums.TeamSide.HOME
const CPU: GameEnums.TeamSide = GameEnums.TeamSide.AWAY

var _catalog: ContentCatalog
var _rules: MatchRuleConfig
var _config: ConfigRepository
var _rng: RandomNumberGenerator
var _opponent: OpponentPolicy
var _request_screen: Callable
var _assert_on_invalid_cpu: bool
var _state: MatchState
var _last_reveal: RevealView
## 直前の得点の側（GameEnums.TeamSide）。まだ得点が無ければ -1
var _last_goal_by: int = -1
## 開示を利用者が確認する前か（submit_turn の後、continue_after_reveal の前）。その間は次の操作を受け付けない
## （確定の二度押しで開示を飛ばさない。得点・ハーフタイムの画面を経ずに再開しない）
var _awaiting_continue: bool = false
## 盤面に出す動き（直前のターンの動き）。方式の選び直し・ハーフタイムで配置を作り直したら空にする
var _board_movements: Array[Movement] = []
var _keeper: SuspendKeeper
var _finalizer: MatchFinalizer
## 今の試合の終了処理（戦績の記録 → FINISHED で保存）が済んだか
var _is_finalized: bool = false
## 今の試合の戦績の終了日時（最初に終了処理をした時刻。まだなら空）
var _finished_at: String = ""
## 利用者の画面に出す手（MoveMenu。ドメインの視点）と、それを作った時の状態。状態は進むたびに丸ごと差し替わるので、
## 同じ状態の間は作り直さない（手のボタン・ヒント・プレビュー・決定の確かめで何度も引き、守備の手は攻撃側の手も数えるため。2026-11-03）
var _menu: MoveOptions
var _menu_state: MatchState


## request_screen は画面の切り替えを頼む関数（App.request_screen。テストでは記録用の関数）。
## assert_on_invalid_cpu: CPU の手が選べないとき assert で止めるか（開発時は止める。書き出し版は止めずに置き換える）。
## store は中断データの保存先。null なら保存しない（保存を確かめないテストとチュートリアル用）。
## user_data は戦績の記録先。null なら記録しない（記録は成功した扱い）。
func _init(catalog: ContentCatalog, config: ConfigRepository, rng: RandomNumberGenerator, opponent: OpponentPolicy,
		request_screen: Callable, assert_on_invalid_cpu: bool = OS.is_debug_build(),
		store: SuspendedMatchStore = null, user_data: UserDataService = null) -> void:
	_catalog = catalog
	_rules = config.match_rules()
	_config = config
	_rng = rng
	_opponent = opponent
	_request_screen = request_screen
	_assert_on_invalid_cpu = assert_on_invalid_cpu
	_keeper = SuspendKeeper.new(store, _rules)
	_keeper.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: storage_failed.emit(kind))
	_finalizer = MatchFinalizer.new(user_data, _keeper)


# --- 起動時・再開・中断（UC-05） ---

## 起動時に1回だけ呼ぶ後始末（確定事項「起動時の扱い」）。破損なら削除して storage_failed(SUSPEND_LOAD)。
## FINISHED なら削除し、最終ターンまで終えた IN_PROGRESS なら終了処理をやり直す（済めば削除して FINALIZED、だめなら FINALIZE_FAILED）。
func inspect_suspended() -> AppScreens.StartupResult:
	var result: AppScreens.StartupResult = _keeper.inspect()
	if _keeper.pending() == null:
		return result
	return AppScreens.StartupResult.FINALIZED if retry_pending_finalize() else AppScreens.StartupResult.FINALIZE_FAILED


## タイトルを開くたびに呼ぶ。試合中（start_match・resume の後、中断する前）は NONE。
func suspended_status() -> AppScreens.SuspendedStatus:
	if _keeper.resumable() != null:
		return AppScreens.SuspendedStatus.RESUMABLE
	if _keeper.pending() != null:
		return AppScreens.SuspendedStatus.FINALIZE_PENDING
	return AppScreens.SuspendedStatus.NONE


## FINALIZE_PENDING のときに、終了処理（戦績の記録 → FINISHED で保存 → 中断データの削除）をやり直す。済んだら true。
## 終了処理待ちの試合が無ければ false。終了日時はやり直した時刻（最終ターンの時刻は持っていない）。
func retry_pending_finalize() -> bool:
	var pending: MatchState = _keeper.pending()
	if pending == null:
		return false
	if _finalizer.finalize(pending, _now_text()) == null:
		return false
	_keeper.delete()
	return true


## 再開できる中断データの盤面（タイトルの再開カード用）。再開できる試合が無ければ null。
func suspended_snapshot() -> BoardSnapshot:
	var state: MatchState = _keeper.resumable()
	if state == null:
		return null
	return ViewConverter.snapshot(state, _catalog, [], _goal_side_of(state), _rules.turns_per_half,
			state.stage == GameEnums.MatchStage.HALFTIME)


## 中断した試合を保存データから読み直して再開し、進行段階が示す画面（TURN→S-03、STYLE_CHANGE→S-04、HALFTIME→S-05）を頼む。
## 読めなかったときは中断データを消し、storage_failed(SUSPEND_LOAD) を出してタイトルを頼み直し、false。
func resume() -> bool:
	var state: MatchState = _keeper.load_for_resume()
	if state == null:
		_request_screen.call(AppScreens.Id.S01_TITLE, {})
		return false
	_open(state)
	_last_goal_by = _goal_side_of(state)
	state_changed.emit(snapshot())
	_request_screen.call(_screen_of(state.stage), {})
	return true


## 直前の保存に失敗していて、中断データが最新の状態でないか（中断の確認で警告する）。
func has_unsaved_progress() -> bool:
	return _keeper.has_unsaved()


## 試合中のメニューから中断してタイトルへ。直前の保存に失敗していれば保存をやり直す（保存の時点④）。
## メモリ上の試合を閉じ、保存されている中断データを再開カード用に読み直してから、タイトルを頼む。保存をやり直して失敗したら false。
## 試合が終わった後（最終ターンの判定理由）は中断しない（false。結果画面と終了処理を通す。画面はメニューを開かない）。
func suspend_to_title() -> bool:
	if _state == null or is_match_over():
		return false
	var is_saved: bool = true
	if _keeper.has_unsaved():
		is_saved = _keeper.save(_state)
	_state = null
	_awaiting_continue = false
	_keeper.inspect()
	_request_screen.call(AppScreens.Id.S01_TITLE, {})
	return is_saved


## 試合を作る。CPU の陣形・方式を選び、前半のキックオフ側を注入された乱数で決める。陣形が無ければ false。
## 成功したら state_changed を出し、試合画面（S-03）を頼む（方式の選び直し・ハーフタイムの確定も同じ）。
func start_match(user_setup: TeamSetup) -> bool:
	var cpu_setup: TeamSetup = _opponent.choose_setup()
	var kickoff: GameEnums.TeamSide = USER if _rng.randi_range(0, 1) == 0 else CPU
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var match_id: String = "%04d%02d%02d-%02d%02d%02d-%04d" % [now["year"], now["month"], now["day"],
			now["hour"], now["minute"], now["second"], _rng.randi_range(0, 9999)]
	var state: MatchState = MatchRules.create_match(match_id, user_setup, cpu_setup, kickoff, _catalog,
			Time.get_datetime_string_from_datetime_dict(now, false))
	if state == null:
		push_error("MatchController: 試合を作れない（陣形が無い）: %s" % user_setup.formation_id)
		return false
	_open(state)
	# 保存の時点②。前の中断データはここで上書きされる（削除の時点①）。保存に失敗したら前の中断データを消す
	# （上書きできないまま残ると、新しい試合を中断したときに前の試合を再開してしまうため）
	if not _keeper.save(_state):
		_keeper.drop_stale()
	state_changed.emit(snapshot())
	_request_screen.call(AppScreens.Id.S03_MATCH, {})
	return true


## start_match が成功した後か。試合前に盤面・選べる手を問い合わせないために UI が確かめる。
func is_match_started() -> bool:
	return _state != null


## 後半の最終ターンまで終えたか。
func is_match_over() -> bool:
	return _state != null and MatchRules.is_play_complete(_state, _rules)


## 利用者の選べる手（画面に出す手。MoveMenu。手ごとに運ぶ先は0か1件。利用者の視点）。試合前は null。
func user_options() -> MoveOptions:
	if not _is_started_or_error("user_options"):
		return null
	return ViewConverter.options_to_user(_user_menu(), _state.possession)


## 利用者のヒント（利用者の視点）。設定でヒントが OFF なら UI は呼ばない。試合前は空。
func user_hints() -> Array[ChoiceHint]:
	if not _is_started_or_error("user_hints"):
		return []
	var hints: Array[ChoiceHint] = MoveHints.evaluate(_state, USER, _user_menu())
	return ViewConverter.hints_to_user(hints, _state.possession)


## 決定前のプレビュー: 利用者の手（利用者の視点）を、相手が何もしないと仮定して適用したときの、利用者の選手の動き
## （利用者の視点）。手を選べるとき（ターン中・開示の確認待ちでない・試合の後でない）以外は空。
## 試合前と、選べない手（UI の誤り）は push_error する。
func user_preview(user_choice: TurnChoice) -> Array[Movement]:
	if not _is_started_or_error("user_preview"):
		return []
	if user_choice == null or _awaiting_continue or _state.stage != GameEnums.MatchStage.TURN or is_match_over():
		return []
	var domain_choice: TurnChoice = ViewConverter.choice_to_domain(user_choice, _state.possession)
	if not MoveRules.is_allowed(_user_menu(), domain_choice):
		push_error("MatchController: 選べない手のプレビューは出せない")
		return []
	return ViewConverter.movements_to_user(MovePreview.own_movements(_state, USER, domain_choice))


## 利用者の手（利用者の視点）でターンを確定する。選べない手・試合中でない・前の開示を確認する前のときは
## false を返し、状態を変えない。
func submit_turn(user_choice: TurnChoice) -> bool:
	if _state == null or user_choice == null or _awaiting_continue or _state.stage != GameEnums.MatchStage.TURN \
			or is_match_over():
		return false
	var domain_choice: TurnChoice = ViewConverter.choice_to_domain(user_choice, _state.possession)
	if not MoveRules.is_allowed(_user_menu(), domain_choice):
		push_error("MatchController: 選べない手は受け付けない")
		return false
	var cpu_choice: TurnChoice = _cpu_choice()
	var resolution: TurnResolution = MatchRules.resolve_turn(_state, domain_choice, cpu_choice, _rules)
	if resolution == null:
		push_error("MatchController: ターンを解決できない")
		return false
	_state = resolution.next_state
	# 保存の時点①（得点・ハーフ終了で進行段階が変わる③もこの1回で兼ねる）。開示より前に保存する
	_keeper.save(_state)
	# 後半を終えたら終了処理。失敗しても、上の保存で IN_PROGRESS のまま残っている（leave_result・次の起動時にやり直す）
	if is_match_over():
		_finalize_current()
	var record: TurnRecord = resolution.record
	if record.outcome == GameEnums.TurnOutcome.GOAL:
		_last_goal_by = record.attacker
	_board_movements = record.movements
	_last_reveal = ViewConverter.reveal(record, _catalog)
	_awaiting_continue = true
	turn_resolved.emit(_last_reveal, snapshot())
	return true


## 開示を利用者が確認した後に呼ぶ。進行段階に応じて、次の画面を頼むか、次のターンの盤面を知らせる。
## 確認待ちの開示が無ければ何もしない（二度呼んでも画面の要求を重ねない）。
func continue_after_reveal() -> void:
	if _state == null or not _awaiting_continue:
		return
	_awaiting_continue = false
	if is_match_over():
		_request_screen.call(AppScreens.Id.S06_RESULT, {})
	elif _state.stage == GameEnums.MatchStage.STYLE_CHANGE:
		stage_changed.emit(_state.stage)
		_request_screen.call(AppScreens.Id.S04_STYLE_CHANGE, {})
	elif _state.stage == GameEnums.MatchStage.HALFTIME:
		stage_changed.emit(_state.stage)
		_request_screen.call(AppScreens.Id.S05_HALFTIME, {})
	else:
		state_changed.emit(snapshot())


## 得点後の方式の選び直し。CPU の方式も選び直して再開する。進行段階が違えば false。
func submit_style_change(user_styles: TeamStyles) -> bool:
	if _state == null or _awaiting_continue or _state.stage != GameEnums.MatchStage.STYLE_CHANGE:
		return false
	var next: MatchState = MatchRules.apply_style_change(_state, user_styles, _opponent.choose_styles())
	if next == null:
		return false
	_state = next
	_board_movements = []
	# 保存の時点③（選び直した方式を含めて保存する）
	_keeper.save(_state)
	state_changed.emit(snapshot())
	_request_screen.call(AppScreens.Id.S03_MATCH, {})
	return true


## ハーフタイムの陣形・方式の選び直し。CPU の陣形・方式も選び直して後半を始める。進行段階が違えば false。
func submit_halftime(user_setup: TeamSetup) -> bool:
	if _state == null or _awaiting_continue or _state.stage != GameEnums.MatchStage.HALFTIME:
		return false
	var next: MatchState = MatchRules.apply_halftime(_state, user_setup, _opponent.choose_setup(), _catalog)
	if next == null:
		return false
	_state = next
	_board_movements = []
	# 保存の時点③（選び直した陣形・方式を含めて保存する）
	_keeper.save(_state)
	state_changed.emit(snapshot())
	_request_screen.call(AppScreens.Id.S03_MATCH, {})
	return true


## 結果の画面（S-06）から出る。試合が終わる前は push_error して false。
## 終了処理が済んでいなければやり直す。済んでいれば中断データを消し（削除の時点②）、なお失敗したら消さずに終了処理待ちとして残す
## （戦績を失わないため。タイトルは FINALIZE_PENDING になる）。どちらでもタイトル（S-01）を頼む。
func leave_result() -> bool:
	if not is_match_over():
		push_error("MatchController: 試合が終わる前に結果の画面からは出られない")
		return false
	if not _is_finalized:
		_finalize_current()
	if _is_finalized:
		_keeper.delete()
	else:
		_keeper.keep_pending(_state)
	_request_screen.call(AppScreens.Id.S01_TITLE, {})
	return true


## 結果画面が開くたびに呼ぶ戦績（勝敗・スコア・陣形と方式の推移）。終了処理が済んでいなくても、今の試合の状態から作る。
## 試合が終わる前は null（UI の誤りなので push_error）。
func final_record() -> MatchRecord:
	if not is_match_over():
		push_error("MatchController: 試合が終わる前に final_record は呼べない")
		return null
	return MatchRecord.of(_state, _finished_at)


## チュートリアルの段階の盤面で試合の状態を作り直す（UC-06。App.new_tutorial_controller() で作った別インスタンスだけが使う）。
## 相手が ScriptedOpponent なら、台本をその段階の手に差し替える。盤面の無い段階（SCOPE）・作れない盤面は push_error して false。
## 画面の切り替えは頼まず、state_changed も出さない（チュートリアルの画面が自分で盤面を描き直す）。
func start_tutorial_step(step: TutorialStepDef) -> bool:
	if not step.has_board():
		push_error("MatchController: 盤面の無い段階は始められない: %s" % step.id)
		return false
	var state: MatchState = MatchRules.create_scene(step.home_setup, step.away_setup, step.turn_kind, step.possession,
			step.ball_area, _catalog)
	if state == null:
		push_error("MatchController: 段階の盤面を作れない: %s" % step.id)
		return false
	if _opponent is ScriptedOpponent:
		(_opponent as ScriptedOpponent).use_step(step)
	_open(state)
	return true


## 振り返り（S-07。アルゴリズム10）。メモリ上のターン記録を利用者の視点で集計し、得失点の流れの各ターンを
## 開示の値にして返す。遡るターン数は PresentationConfig。試合前は null（UI の誤りなので push_error）。
## 試合の途中でも呼べる（それまでのターンを集計する）が、画面は試合の後だけ開く。
func review() -> ReviewView:
	if not _is_started_or_error("review"):
		return null
	var view: ReviewView = ViewConverter.review(_state.turn_records, _catalog,
			_config.presentation().review_lookback_turns)
	view.turns_per_half = _rules.turns_per_half
	return view


## 開示の1拍目（プレー）で、ターン前の配置から判定時の配置へ駒とボールを動かす時間（秒。PresentationConfig）。
## 画面が使うときに初めて読む（試合を進めるだけの呼び出し側に、表示の設定ファイルを求めないため）。
func board_play_sec() -> float:
	return _config.presentation().board_play_sec


## 開示の2拍目（詰め直し）で、判定時の配置から次のターン開始時の配置へ駒を動かす時間（秒。PresentationConfig）。
func board_settle_sec() -> float:
	return _config.presentation().board_settle_sec


## 開示の1拍目の終わりから結果の演出を出す時間（秒。PresentationConfig）。
func board_result_sec() -> float:
	return _config.presentation().board_result_sec


## 開示で駒が動くときの値（PresentationConfig）。{"stagger": ボールに近い駒から順に動き出す遅れの幅（拍の時間の割合）,
## "hop": 動いている駒が浮く高さ（駒の半径の何倍か）}。
func piece_style() -> Dictionary:
	var presentation: PresentationConfig = _config.presentation()
	return {"stagger": presentation.piece_stagger, "hop": presentation.piece_hop_height}


## 開示の拍と拍の間の小休止（秒。PresentationConfig）。
func board_beat_gap_sec() -> float:
	return _config.presentation().board_beat_gap_sec


## 開示の1拍目のボールの軌道の値（PresentationConfig）。{"loft": 浮き球の高さ, "touch": ドリブルの弾みの高さ,
## "touches": 弾みの回数}。高さはボールの半径の何倍か。
func ball_style() -> Dictionary:
	var presentation: PresentationConfig = _config.presentation()
	return {"loft": presentation.ball_loft_height, "touch": presentation.ball_touch_height,
			"touches": presentation.ball_dribble_touches}


## 開示済みの相手の陣形・方式（FR-16・21）。試合前は null。
func opponent_setup() -> TeamSetup:
	if not _is_started_or_error("opponent_setup"):
		return null
	return _state.away_setup.duplicate_deep()


## 現在の盤面・スコア（利用者の視点）。動きは直前のターンのもの（方式の選び直し・ハーフタイムの後は空）。
## 試合前（start_match・resume の前、中断した後）は null で、呼ぶのは UI の誤り。タイトルの再開カードは suspended_snapshot を使う。
func snapshot() -> BoardSnapshot:
	if not _is_started_or_error("snapshot"):
		return null
	return ViewConverter.snapshot(_state, _catalog, _board_movements, _last_goal_by, _rules.turns_per_half,
			_state.stage == GameEnums.MatchStage.HALFTIME or is_match_over())


## 直前のターンの開示（まだ無ければ null）。写しではないので、受け取った側は読むだけにする。
func last_reveal() -> RevealView:
	return _last_reveal


## 進行段階（状態の写しを作らずに読む。画面が次のターンを始めるかを決めるのに使う）。試合前は TURN。
func stage() -> GameEnums.MatchStage:
	return GameEnums.MatchStage.TURN if _state == null else _state.stage


## 試合の状態の写し（テストと、試合を外から確かめる用。中断データの保存は SuspendKeeper がメモリ上の状態から直接行う）。
func state() -> MatchState:
	return null if _state == null else _state.duplicate_deep()


## 試合をメモリに置き、開示・盤面の動きの状態を初めからにする（新しい試合と再開で共通）。試合中は再開カードを出さない。
func _open(state: MatchState) -> void:
	_state = state
	_last_reveal = null
	_last_goal_by = -1
	_awaiting_continue = false
	_board_movements = []
	_is_finalized = false
	_finished_at = ""
	_keeper.forget()


## 今の試合の終了処理。済んだら FINISHED にした状態に置き換える。終了日時は最初に試みた時刻。
func _finalize_current() -> void:
	if _finished_at.is_empty():
		_finished_at = _now_text()
	var finished: MatchState = _finalizer.finalize(_state, _finished_at)
	if finished != null:
		_state = finished
		_is_finalized = true


## 端末のローカル時刻（ISO 8601。タイムゾーンなし）。
static func _now_text() -> String:
	return Time.get_datetime_string_from_system(false, false)


## 最後の得点の側（ターン記録の最後の GOAL の攻撃側）。得点が無ければ -1。再開した試合の「〜が得点しました」に使う。
static func _goal_side_of(state: MatchState) -> int:
	for index: int in range(state.turn_records.size() - 1, -1, -1):
		if state.turn_records[index].outcome == GameEnums.TurnOutcome.GOAL:
			return state.turn_records[index].attacker
	return -1


## 進行段階の画面（確定事項「再開先」）。
static func _screen_of(stage: GameEnums.MatchStage) -> AppScreens.Id:
	match stage:
		GameEnums.MatchStage.STYLE_CHANGE:
			return AppScreens.Id.S04_STYLE_CHANGE
		GameEnums.MatchStage.HALFTIME:
			return AppScreens.Id.S05_HALFTIME
	return AppScreens.Id.S03_MATCH


func _is_started_or_error(caller: String) -> bool:
	if _state != null:
		return true
	push_error("MatchController: 試合が始まる前に %s は呼べない" % caller)
	return false


## 利用者の画面に出す手（ドメインの視点）。同じ状態の間は作り直さない。
func _user_menu() -> MoveOptions:
	if _menu_state != _state:
		_menu = MoveMenu.options_for(_state, USER)
		_menu_state = _state
	return _menu


## CPU の手。選べない手は開発時の誤りなので、開発時は assert で止める。書き出し版では push_error して、
## 選べる手の先頭に置き換える（CPU 側の誤りで利用者に選び直しを求めないため。component-design.md §3.2）。
func _cpu_choice() -> TurnChoice:
	var options: MoveOptions = MoveRules.options_for(_state, CPU)
	var choice: TurnChoice = _opponent.choose_turn(_state, CPU)
	if choice != null and MoveRules.is_allowed(options, choice):
		return choice
	if _assert_on_invalid_cpu:
		assert(false, "MatchController: CPU の手が選べない")
	push_error("MatchController: CPU の手が選べないため、選べる手の先頭に置き換える")
	return _first_choice(options)


## 選べる手の先頭（手の enum の順、運ぶ先は一覧の順）。
static func _first_choice(options: MoveOptions) -> TurnChoice:
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for family: int in range(action_counts.size()):
		var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
		for action: int in range(action_counts[family]):
			if not options.is_available(family_value, action):
				continue
			if not MoveOptions.needs_target(family_value, action):
				return TurnChoice.new(family_value, action)
			return TurnChoice.new(family_value, action, options.targets(family_value, action)[0])
	return null

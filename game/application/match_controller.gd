## 試合進行の管理（component-design.md §3.2。モジュール構成図の A1）。ドメインの MatchRules を呼び、
## 利用者の視点への変換（ViewConverter）と、画面へのシグナル・画面の切り替えの要求を受け持つ。
## 利用者 = HOME、CPU = AWAY（§1.3）。
##
## 今回作った範囲は、試合の開始・1ターンの確定と開示・方式の選び直し・ハーフタイムまで。
## 中断データの保存と再開・起動時の後始末・戦績と終了処理・振り返り・チュートリアルは、それぞれの作業で足す
## （そのとき、設計書の引数 content・store・user_data・is_tutorial を足す）。
class_name MatchController
extends RefCounted

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


## request_screen は画面の切り替えを頼む関数（App.request_screen。テストでは記録用の関数）。
## assert_on_invalid_cpu: CPU の手が選べないとき assert で止めるか（開発時は止める。書き出し版は止めずに置き換える）。
func _init(catalog: ContentCatalog, config: ConfigRepository, rng: RandomNumberGenerator, opponent: OpponentPolicy,
		request_screen: Callable, assert_on_invalid_cpu: bool = OS.is_debug_build()) -> void:
	_catalog = catalog
	_rules = config.match_rules()
	_rng = rng
	_opponent = opponent
	_request_screen = request_screen
	_assert_on_invalid_cpu = assert_on_invalid_cpu


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
	_state = state
	_last_reveal = null
	_last_goal_by = -1
	_awaiting_continue = false
	_board_movements = []
	state_changed.emit(snapshot())
	_request_screen.call(AppScreens.Id.S03_MATCH, {})
	return true


## start_match が成功した後か。試合前に盤面・選べる手を問い合わせないために UI が確かめる。
func is_match_started() -> bool:
	return _state != null


## 後半の最終ターンまで終えたか。
func is_match_over() -> bool:
	return _state != null and MatchRules.is_play_complete(_state, _rules)


## 利用者の選べる手（利用者の視点）。試合前は null。
func user_options() -> MoveOptions:
	if not _is_started_or_error("user_options"):
		return null
	return ViewConverter.options_to_user(MoveRules.options_for(_state, USER), _state.possession)


## 利用者のヒント（利用者の視点）。設定でヒントが OFF なら UI は呼ばない。試合前は空。
func user_hints() -> Array[ChoiceHint]:
	if not _is_started_or_error("user_hints"):
		return []
	var hints: Array[ChoiceHint] = MoveHints.evaluate(_state, USER, MoveRules.options_for(_state, USER))
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
	if not MoveRules.is_allowed(MoveRules.options_for(_state, USER), domain_choice):
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
	if not MoveRules.is_allowed(MoveRules.options_for(_state, USER), domain_choice):
		push_error("MatchController: 選べない手は受け付けない")
		return false
	var cpu_choice: TurnChoice = _cpu_choice()
	var resolution: TurnResolution = MatchRules.resolve_turn(_state, domain_choice, cpu_choice, _rules)
	if resolution == null:
		push_error("MatchController: ターンを解決できない")
		return false
	_state = resolution.next_state
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
	state_changed.emit(snapshot())
	_request_screen.call(AppScreens.Id.S03_MATCH, {})
	return true


## 結果の画面（S-06）から出る。試合が終わる前は push_error して false。
## 終了処理（戦績の記録・中断データの削除）は保存・戦績の作業で足す。今はタイトル（S-01）を頼むだけ。
func leave_result() -> bool:
	if not is_match_over():
		push_error("MatchController: 試合が終わる前に結果の画面からは出られない")
		return false
	_request_screen.call(AppScreens.Id.S01_TITLE, {})
	return true


## 開示済みの相手の陣形・方式（FR-16・21）。試合前は null。
func opponent_setup() -> TeamSetup:
	if not _is_started_or_error("opponent_setup"):
		return null
	return _state.away_setup.duplicate_deep()


## 現在の盤面・スコア（利用者の視点）。動きは直前のターンのもの（方式の選び直し・ハーフタイムの後は空）。
## 試合前は null（中断データからの再開は保存の作業で足す。それまでは start_match の前に呼ぶのは UI の誤り）。
func snapshot() -> BoardSnapshot:
	if not _is_started_or_error("snapshot"):
		return null
	return ViewConverter.snapshot(_state, _catalog, _board_movements, _last_goal_by, _rules.turns_per_half)


## 直前のターンの開示（まだ無ければ null）。写しではないので、受け取った側は読むだけにする。
func last_reveal() -> RevealView:
	return _last_reveal


## 進行段階（状態の写しを作らずに読む。画面が次のターンを始めるかを決めるのに使う）。試合前は TURN。
func stage() -> GameEnums.MatchStage:
	return GameEnums.MatchStage.TURN if _state == null else _state.stage


## 試合の状態の写し（保存の作業で中断データを書くときにも使う）。
func state() -> MatchState:
	return null if _state == null else _state.duplicate_deep()


func _is_started_or_error(caller: String) -> bool:
	if _state != null:
		return true
	push_error("MatchController: 試合が始まる前に %s は呼べない" % caller)
	return false


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

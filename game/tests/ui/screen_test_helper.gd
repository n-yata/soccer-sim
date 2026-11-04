## 試合の画面（S-03〜S-06）のテストで使う、試合を作って目的の段階まで進める関数（テスト専用）。
## 利用者の手は forward_choice（シュートを選べればシュート、そうでなければ選べる最初の手で、運ぶ先はいちばん前）。
## 運ぶ先を一覧の先頭（いちばん後ろ）にすると、ボールが前に進まず得点が起きないため。
class_name ScreenTestHelper
extends RefCounted

const MAX_STEPS: int = 200
const SEED_SEARCH_LIMIT: int = 200

## どこまで進めるか
enum Stop { START, STYLE_CHANGE, HALFTIME, OVER, TRANSITION }


## 固定シードの乱数と本物の CpuOpponent で作った MatchController。画面の要求は request に渡す。
## store を渡すと中断データを保存し、user_data を渡すと戦績を記録する（同じシードなら、保存の有無で試合の進み方は変わらない）。
static func new_controller(seed_value: int, request: Callable, store: SuspendedMatchStore = null,
		user_data: UserDataService = null) -> MatchController:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var config := ConfigRepository.new()
	return MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng), request, true, store,
			user_data)


## App.user_data を、dir に戦績・設定を保存するサービスに差し替え、元のサービスを返す（after_test で戻す）。
## タイトル・戦績・設定・試合の画面は App.user_data を読むので、開発用の PC の戦績・設定を読み書きしないために使う。
static func use_user_data_in(dir: String) -> UserDataService:
	var original: UserDataService = App.user_data
	var service := UserDataService.new(RecordStore.new(ConfigRepository.new().match_rules(), dir), SettingsStore.new(dir),
			QuizAnswerStore.new(dir), App.library.quiz_questions())
	service.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: App.storage_error.emit(kind))
	App.user_data = service
	return original


## オーディオバス（BGM・SE）の音量とミュートを控える。設定を変えるテストは before_test で控え、after_test で restore_buses に渡す
## （AudioServer はテストの間で共有されるため）。
static func save_buses() -> Array:
	var saved: Array = []
	for bus_name: StringName in [AudioBuses.BGM_BUS, AudioBuses.SE_BUS]:
		var index: int = AudioServer.get_bus_index(bus_name)
		saved.append([index, AudioServer.get_bus_volume_db(index), AudioServer.is_bus_mute(index)])
	return saved


static func restore_buses(saved: Array) -> void:
	for entry: Array in saved:
		AudioServer.set_bus_volume_db(entry[0] as int, entry[1] as float)
		AudioServer.set_bus_mute(entry[0] as int, entry[2] as bool)


static func user_setup() -> TeamSetup:
	return TeamSetup.new("4-3-3", TeamStyles.new(GameEnums.DefenseStyle.MAN, GameEnums.AttackStyle.COUNTER))


## stop の段階に着くまで（または試合が終わるまで）、ターン・方式の選び直し・ハーフタイムを進める。
## 着いたら true、試合が先に終わったら false。
static func advance_until(controller: MatchController, stop: Stop) -> bool:
	for step: int in range(MAX_STEPS):
		if reached(controller, stop):
			return true
		if controller.is_match_over():
			return false
		var state: MatchState = controller.state()
		if state.stage == GameEnums.MatchStage.STYLE_CHANGE:
			controller.submit_style_change(controller.snapshot().user_setup.styles)
		elif state.stage == GameEnums.MatchStage.HALFTIME:
			controller.submit_halftime(controller.snapshot().user_setup)
		else:
			controller.submit_turn(forward_choice(controller.user_options()))
			controller.continue_after_reveal()
	return false


## シュートを選べればシュート。そうでなければ選べる最初の手（手の enum の順）で、運ぶ先は一覧の最後（いちばん前）。
## 利用者の手（画面に出す手）では運ぶ先は1つだけ。画面のテストは、同じ選び方を画面の操作（手のボタン）で行う。
static func forward_choice(options: MoveOptions) -> TurnChoice:
	if options.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT):
		return TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for family: int in range(action_counts.size()):
		var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
		for action: int in range(action_counts[family]):
			if not options.is_available(family_value, action):
				continue
			if not MoveOptions.needs_target(family_value, action):
				return TurnChoice.new(family_value, action)
			return TurnChoice.new(family_value, action, options.targets(family_value, action).back())
	return null


static func reached(controller: MatchController, stop: Stop) -> bool:
	match stop:
		Stop.STYLE_CHANGE:
			return controller.state().stage == GameEnums.MatchStage.STYLE_CHANGE
		Stop.HALFTIME:
			return controller.state().stage == GameEnums.MatchStage.HALFTIME
		Stop.OVER:
			return controller.is_match_over()
		Stop.TRANSITION:
			var state: MatchState = controller.state()
			return state.stage == GameEnums.MatchStage.TURN and state.turn_kind == GameEnums.TurnKind.TRANSITION
	return true


## 試合を始めてから、stop まで進めたシード（0 から順に探す）。見つからなければ -1。
## 得点（STYLE_CHANGE）はまれで、CPU が評価値の高い手に寄った後（2026-10-22。τ=0.5）は、この補助の利用者の手では
## 200 試合に数回しか起きない。そのため探す範囲を広くとる
## 探した結果は覚えておく（同じ段階を何度も探すと、そのたびに試合を最初から回すため。2026-10-29 に全体のテストが 10 分を超えた）。
## シードから試合の進み方は決まるので、覚えた値は同じ実行の中で変わらない。
static var _seed_cache: Dictionary = {}


static func seed_reaching(stop: Stop) -> int:
	if _seed_cache.has(stop):
		return _seed_cache[stop] as int
	var found: int = _search_seed(stop)
	_seed_cache[stop] = found
	return found


static func _search_seed(stop: Stop) -> int:
	for seed_value: int in range(SEED_SEARCH_LIMIT):
		var controller: MatchController = new_controller(seed_value, func(_s: AppScreens.Id, _p: Dictionary) -> void: pass)
		controller.start_match(user_setup())
		if advance_until(controller, stop):
			return seed_value
	return -1




# --- 段階から始める（単体テスト用。2026-11-05） ---
# 局所の性質を確かめるテストが、狙った段階まで毎回試合を回すと、全体テストが3分を超える。段階ごとの試合の時点を
# 実行の中で1回だけ作って覚え、テストには状態の写しを中断データとして渡し、本番と同じ再開の経路で MatchController を作る
# （本番のコードにテスト専用の入口を足さない）。乱数の状態も覚えて戻すので、再開した後の展開は元の試合と同じになる。

## 試合の一時点（試合の状態と、そのときの乱数の状態）
class Point:
	var state: MatchState
	var rng_state: int

	func _init(p_state: MatchState, p_rng_state: int) -> void:
		state = p_state
		rng_state = p_rng_state


## 段階 → [段階に着いた時点, 着く直前の時点]。直前は、段階に入る1手（ターン・選び直し・ハーフタイムの確定）を進める前
static var _point_cache: Dictionary = {}
## 中断データを置く一時ディレクトリの通し番号（gdUnit4 がスイートの終わりに user://tmp ごと消す）
static var _fixture_count: int = 0


## stop の段階から始まる MatchController。store を渡さなければ一時ディレクトリに中断データを置く。
## 状態を中断データとして保存し、inspect_suspended・resume で開く（resume が頼んだ画面は request に届く）。
## OVER は最終ターンの直前から再開し、finish_over なら試合が終わるまで進める（確定の処理が走る）。
## 確定の処理の知らせ（storage_failed）を受けたいテストは finish_over を false にし、つないでから advance_until で終える。
static func controller_at(stop: Stop, request: Callable, store: SuspendedMatchStore = null,
		user_data: UserDataService = null, finish_over: bool = true, config: ConfigRepository = null) -> MatchController:
	if stop == Stop.OVER:
		var controller: MatchController = controller_before(stop, request, store, user_data, config)
		if controller != null and finish_over and not advance_until(controller, Stop.OVER):
			push_error("ScreenTestHelper: 最終ターンの直前から試合を終えられない")
			return null
		return controller
	return _resume(_points(stop)[0] as Point, request, store, user_data, config)


## stop の段階に入る1手の直前から始まる MatchController。advance_until(controller, stop) で、元の試合と同じ1手で着く
## （段階に入るときの保存・画面の要求を確かめるため）。
static func controller_before(stop: Stop, request: Callable, store: SuspendedMatchStore = null,
		user_data: UserDataService = null, config: ConfigRepository = null) -> MatchController:
	return _resume(_points(stop)[1] as Point, request, store, user_data, config)


## 一時ディレクトリ（呼ぶたびに別）に中断データを置く SuspendedMatchStore。
static func fixture_store() -> SuspendedMatchStore:
	_fixture_count += 1
	var dir: String = "user://tmp/screen_test_helper/fixture%d" % _fixture_count
	DirAccess.make_dir_recursive_absolute(dir)
	return SuspendedMatchStore.new(ContentRepository.new().load_catalog(), ConfigRepository.new().match_rules(), dir)


static func _resume(point: Point, request: Callable, store: SuspendedMatchStore,
		user_data: UserDataService, config: ConfigRepository) -> MatchController:
	if point == null:
		return null
	if store == null:
		store = fixture_store()
	if not store.save(point.state.duplicate_deep()):
		push_error("ScreenTestHelper: 段階の状態を中断データに保存できない")
		return null
	var rng := RandomNumberGenerator.new()
	rng.state = point.rng_state
	var controller: MatchController = _new_controller_with(rng, request, store, user_data, config)
	controller.inspect_suspended()
	if not controller.resume():
		push_error("ScreenTestHelper: 段階の状態から再開できない")
		return null
	return controller


## config が null なら同梱の設定
static func _new_controller_with(rng: RandomNumberGenerator, request: Callable, store: SuspendedMatchStore,
		user_data: UserDataService, config: ConfigRepository = null) -> MatchController:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	if config == null:
		config = ConfigRepository.new()
	return MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng), request, true, store,
			user_data)


## stop の [着いた時点, 着く直前の時点]。seed_reaching のシードで試合を1回だけ進めて覚える。
## OVER は得点の起きるシード（STYLE_CHANGE に届くシード）で作る（振り返りのテストが得点のある試合を要るため）。
## 段階に着けなければ push_error して [null, null]（呼んだテストは null で止まる。着いていない状態で黙って通らない）。
static func _points(stop: Stop) -> Array:
	if _point_cache.has(stop):
		return _point_cache[stop]
	var seed_value: int = seed_reaching(Stop.STYLE_CHANGE if stop == Stop.OVER else stop)
	if seed_value == -1:
		push_error("ScreenTestHelper: %s に届くシードが無い" % Stop.keys()[stop])
		return [null, null]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var controller: MatchController = _new_controller_with(rng, func(_s: AppScreens.Id, _p: Dictionary) -> void: pass,
			null, null)
	controller.start_match(user_setup())
	var before: Point = null
	for step: int in range(MAX_STEPS):
		if reached(controller, stop):
			break
		before = Point.new(controller.state(), rng.state)
		var state: MatchState = controller.state()
		if state.stage == GameEnums.MatchStage.STYLE_CHANGE:
			controller.submit_style_change(controller.snapshot().user_setup.styles)
		elif state.stage == GameEnums.MatchStage.HALFTIME:
			controller.submit_halftime(controller.snapshot().user_setup)
		else:
			controller.submit_turn(forward_choice(controller.user_options()))
			controller.continue_after_reveal()
	if not reached(controller, stop) or before == null:
		push_error("ScreenTestHelper: %s に着けない" % Stop.keys()[stop])
		return [null, null]
	var points: Array = [Point.new(controller.state(), rng.state), before]
	_point_cache[stop] = points
	return points

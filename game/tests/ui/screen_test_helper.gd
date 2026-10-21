## 試合の画面（S-03〜S-06）のテストで使う、試合を作って目的の段階まで進める関数（テスト専用）。
## 利用者の手は forward_choice（シュートを選べればシュート、そうでなければ選べる最初の手で、運ぶ先はいちばん前）。
## 運ぶ先を一覧の先頭（いちばん後ろ）にすると、ボールが前に進まず得点が起きないため。
class_name ScreenTestHelper
extends RefCounted

const MAX_STEPS: int = 200

## どこまで進めるか
enum Stop { START, STYLE_CHANGE, HALFTIME, OVER, TRANSITION }


## 固定シードの乱数と本物の CpuOpponent で作った MatchController。画面の要求は request に渡す。
static func new_controller(seed_value: int, request: Callable) -> MatchController:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var config := ConfigRepository.new()
	return MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng), request, true)


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
## 画面のテストは、同じ選び方を画面の操作（手のボタン・選べるエリアの最後）で行う。
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
static func seed_reaching(stop: Stop) -> int:
	for seed_value: int in range(50):
		var controller: MatchController = new_controller(seed_value, func(_s: AppScreens.Id, _p: Dictionary) -> void: pass)
		controller.start_match(user_setup())
		if advance_until(controller, stop):
			return seed_value
	return -1

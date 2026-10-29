## 同梱の静的データ（tutorial.json・simplifications.json）の検証（data-definition.md §3.4・§3.6・FR-12・FR-23・NFR-17 ②）。
## 形と範囲は読み込み（TutorialContentReader）が確かめる。ここでは、試合の規則の上で段階が成り立つかと、
## 単純化カタログ（functional-overview.md「単純化カタログ」）との一致を確かめる。
extends GdUnitTestSuite

## functional-overview.md「単純化カタログ」の件数（SIM-01〜SIM-12）。カタログの行を増減したら、ここと simplifications.json を直す
const CATALOG_SIMPLIFICATION_COUNT: int = 12

var _repository: ContentRepository
var _catalog: ContentCatalog
var _rules: MatchRuleConfig


func before() -> void:
	_repository = ContentRepository.new()
	_catalog = _repository.load_catalog()
	_rules = ConfigRepository.new().match_rules()


func _scene(step: TutorialStepDef) -> MatchState:
	return MatchRules.create_scene(step.home_setup, step.away_setup, step.turn_kind, step.possession, step.ball_area,
			_catalog)


func _actions_of(step: TutorialStepDef) -> Array[int]:
	var family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind, step.possession == GameEnums.TeamSide.HOME)
	var names: Dictionary = TurnChoice.ACTION_ENUMS[family]
	var actions: Array[int] = []
	for action_name: String in step.allowed_actions:
		actions.append(names[action_name] as int)
	return actions


func test_the_bundled_content_has_no_validation_errors() -> void:
	assert_array(_repository.validation_errors()).is_empty()
	assert_int(_catalog.tutorial_steps.size()).is_greater(1)


func test_simplifications_match_the_catalog_ids_and_count() -> void:
	var ids: Array[String] = []
	for simplification: SimplificationDef in _catalog.simplifications:
		ids.append(simplification.id)
	var expected: Array[String] = []
	for number: int in range(1, CATALOG_SIMPLIFICATION_COUNT + 1):
		expected.append("SIM-%02d" % number)
	assert_array(ids).is_equal(expected)


## FR-12: 7要素を少なくとも1回ずつ体験する
func test_the_steps_cover_all_seven_elements() -> void:
	var covered: Dictionary = {}
	for step: TutorialStepDef in _catalog.tutorial_steps:
		for cover: String in step.covers:
			covered[cover] = true
	for cover: String in TutorialStepDef.COVER_NAMES:
		assert_bool(covered.has(cover)).override_failure_message("体験しない要素: " + cover).is_true()


## FR-12・FR-23: 最後は単純化の一覧
func test_the_last_step_shows_the_scope() -> void:
	assert_int(_catalog.tutorial_steps.back().kind).is_equal(TutorialStepDef.Kind.SCOPE)


func test_every_board_can_be_built() -> void:
	for step: TutorialStepDef in _catalog.tutorial_steps:
		if step.has_board():
			assert_object(_scene(step)).override_failure_message("盤面が作れない: " + step.id).is_not_null()


## 選べる手は試合の規則で選べる手の部分集合で、どれも1つ以上の運ぶ先がある（選択不可の手だけの段階にしない）
func test_every_allowed_action_can_be_chosen_by_the_rules() -> void:
	for step: TutorialStepDef in _catalog.tutorial_steps:
		if step.kind != TutorialStepDef.Kind.OPERATE:
			continue
		var family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind,
				step.possession == GameEnums.TeamSide.HOME)
		var options: MoveOptions = MoveRules.options_for(_scene(step), GameEnums.TeamSide.HOME)
		for action: int in _actions_of(step):
			assert_bool(options.is_available(family, action)) \
					.override_failure_message("%s: 選べない手 %d" % [step.id, action]).is_true()


## 相手の台本の手は、試合の規則で相手が選べる手（MatchController が CPU の手として受け付ける）
func test_every_opponent_choice_can_be_chosen_by_the_rules() -> void:
	for step: TutorialStepDef in _catalog.tutorial_steps:
		if step.kind != TutorialStepDef.Kind.OPERATE:
			continue
		var options: MoveOptions = MoveRules.options_for(_scene(step), GameEnums.TeamSide.AWAY)
		assert_bool(MoveRules.is_allowed(options, step.opponent_choice)) \
				.override_failure_message("%s: 相手の手が選べない" % step.id).is_true()


## 選べる手のどれを、どの運ぶ先で決定しても、相手の台本の手と組んでターンを解決できる
func test_every_allowed_choice_resolves_with_the_opponent_choice() -> void:
	for step: TutorialStepDef in _catalog.tutorial_steps:
		if step.kind != TutorialStepDef.Kind.OPERATE:
			continue
		var state: MatchState = _scene(step)
		var family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind,
				step.possession == GameEnums.TeamSide.HOME)
		var options: MoveOptions = MoveRules.options_for(state, GameEnums.TeamSide.HOME)
		for action: int in _actions_of(step):
			var choices: Array[TurnChoice] = []
			if MoveOptions.needs_target(family, action):
				for area: PitchArea in options.targets(family, action):
					choices.append(TurnChoice.new(family, action, area))
			else:
				choices.append(TurnChoice.new(family, action))
			for choice: TurnChoice in choices:
				var resolution: TurnResolution = MatchRules.resolve_turn(state, choice, step.opponent_choice, _rules)
				assert_object(resolution).override_failure_message("%s: 解決できない" % step.id).is_not_null()

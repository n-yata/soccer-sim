## 静的データの単純化カタログ（simplifications.json）とチュートリアルの段階（tutorial.json）を、形と範囲を確かめながら読む
## （data-definition.md §3.4・§3.6）。ContentRepository が JSON を読んで渡す。項目の読み出しは SaveDataReader。
## ここで確かめるのは形・型・範囲だけ。段階の手が試合の規則で選べるか、7要素を網羅するかはテストで確かめる
## （tests/content/tutorial_content_test.gd。ルールで確かめるにはドメインの計算が要るため）。
class_name TutorialContentReader
extends RefCounted

const SIMPLIFICATION_ID_PATTERN: String = "^SIM-[0-9]{2}$"
const NAME_LENGTH_MAX: int = 40
const SIMPLIFICATION_TEXT_LENGTH_MAX: int = 300
const STEP_TEXT_LENGTH_MAX: int = 300
## 段階の数の上限（多すぎる定義は誤り。データ定義の「1件以上」に、読み込みの上限として足す）
const MAX_STEPS: int = 30
const MAX_SIMPLIFICATIONS: int = 50

var _formation_ids: Array[String]
var _reader: SaveDataReader
var _simplification_id_regex: RegEx
var _id_regex: RegEx


## formation_ids は段階の盤面の陣形として使える ID（読み込んだ陣形）。
func _init(formation_ids: Array[String]) -> void:
	_formation_ids = formation_ids
	_simplification_id_regex = RegEx.create_from_string(SIMPLIFICATION_ID_PATTERN)
	_id_regex = RegEx.create_from_string(ContentRepository.ID_PATTERN)


## 誤りがあれば空。誤りは errors()。
func read_simplifications(root: Variant) -> Array[SimplificationDef]:
	_reader = SaveDataReader.new()
	var result: Array[SimplificationDef] = []
	var entries: Array = _entries(root, "simplifications", MAX_SIMPLIFICATIONS)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "simplifications[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var fields: Dictionary = entries[index]
		var id: String = _reader.text(fields, "id", location + ".id", _simplification_id_regex)
		if seen.has(id):
			_reader.fail(location + ".id", "重複: %s" % id)
		seen[id] = true
		result.append(SimplificationDef.new(id, _bounded_text(fields, "name", location, NAME_LENGTH_MAX),
				_bounded_text(fields, "in_game", location, SIMPLIFICATION_TEXT_LENGTH_MAX),
				_bounded_text(fields, "in_real", location, SIMPLIFICATION_TEXT_LENGTH_MAX)))
	if not _reader.is_ok():
		result.clear()
	return result


## 誤りがあれば空。誤りは errors()。
func read_tutorial(root: Variant) -> Array[TutorialStepDef]:
	_reader = SaveDataReader.new()
	var result: Array[TutorialStepDef] = []
	var entries: Array = _entries(root, "steps", MAX_STEPS)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var location: String = "steps[%d]" % index
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var step: TutorialStepDef = _step(entries[index] as Dictionary, location, seen)
		# 最後の1件だけが SCOPE（data-definition.md §3.6）
		var is_last: bool = index == entries.size() - 1
		if (step.kind == TutorialStepDef.Kind.SCOPE) != is_last:
			_reader.fail(location + ".kind", "最後の1件だけが SCOPE になっていない")
		result.append(step)
	if not _reader.is_ok():
		result.clear()
	return result


## 直前の読み込みで見つかった誤り（「場所: 理由」）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


func _entries(root: Variant, key: String, max_count: int) -> Array:
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return []
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", ContentRepository.FORMAT_VERSION,
			ContentRepository.FORMAT_VERSION)
	return _reader.array(fields, key, key, 1, max_count)


func _bounded_text(fields: Dictionary, key: String, location: String, max_length: int) -> String:
	var text: String = _reader.text(fields, key, location + "." + key)
	if text.is_empty() or text.length() > max_length:
		_reader.fail(location + "." + key, "1〜%d 文字でない: %d 文字" % [max_length, text.length()])
	return text


func _step(fields: Dictionary, location: String, seen: Dictionary) -> TutorialStepDef:
	var step := TutorialStepDef.new()
	step.id = _reader.text(fields, "id", location + ".id", _id_regex)
	if seen.has(step.id):
		_reader.fail(location + ".id", "重複: %s" % step.id)
	seen[step.id] = true
	var kind: int = _reader.enum_value(fields, "kind", location + ".kind", TutorialStepDef.Kind)
	step.kind = (kind if kind >= 0 else TutorialStepDef.Kind.EXPLAIN) as TutorialStepDef.Kind
	step.text = _bounded_text(fields, "text", location, STEP_TEXT_LENGTH_MAX)
	step.covers = _covers(fields, location)
	if kind < 0 or not step.has_board():
		return step
	var setup: Dictionary = _reader.object(fields, "setup", location + ".setup")
	step.home_setup = _team_setup(setup, "home", location + ".setup.home")
	step.away_setup = _team_setup(setup, "away", location + ".setup.away")
	step.turn_kind = maxi(0, _reader.enum_value(setup, "turn_kind", location + ".setup.turn_kind",
			GameEnums.TurnKind)) as GameEnums.TurnKind
	step.possession = maxi(0, _reader.enum_value(setup, "possession", location + ".setup.possession",
			GameEnums.TeamSide)) as GameEnums.TeamSide
	step.ball_area = _reader.area(setup, "ball_area", location + ".setup.ball_area")
	if step.kind == TutorialStepDef.Kind.OPERATE:
		_operate(step, fields, location)
	return step


## 体験する要素（7要素の名前。0件以上。重複しない）。
func _covers(fields: Dictionary, location: String) -> Array[String]:
	var covers: Array[String] = []
	var values: Array = _reader.array(fields, "covers", location + ".covers", 0, TutorialStepDef.COVER_NAMES.size())
	for value: Variant in values:
		if typeof(value) != TYPE_STRING or not TutorialStepDef.COVER_NAMES.has(value) or covers.has(value):
			_reader.fail(location + ".covers", "要素の名前でないか重複: %s" % str(value))
			continue
		covers.append(value as String)
	return covers


## 利用者の選べる手（その局面の手の種類の区分値の名前。1件以上）と、相手の手。
func _operate(step: TutorialStepDef, fields: Dictionary, location: String) -> void:
	var user_family: GameEnums.ChoiceFamily = TurnChoice.family_for(step.turn_kind,
			step.possession == GameEnums.TeamSide.HOME)
	var actions: Dictionary = TurnChoice.ACTION_ENUMS[user_family]
	var values: Array = _reader.array(fields, "allowed_actions", location + ".allowed_actions", 1, actions.size())
	for value: Variant in values:
		if typeof(value) != TYPE_STRING or not actions.has(value) or step.allowed_actions.has(value):
			_reader.fail(location + ".allowed_actions", "その局面の手の名前でないか重複: %s" % str(value))
			continue
		step.allowed_actions.append(value as String)
	step.opponent_choice = _choice(fields, location + ".opponent_choice",
			TurnChoice.family_for(step.turn_kind, step.possession == GameEnums.TeamSide.AWAY))


## 相手の手（ターン記録の choices.* と同じ形）。手の種類は局面から決まる（違えば誤り）。
func _choice(fields: Dictionary, location: String, expected_family: GameEnums.ChoiceFamily) -> TurnChoice:
	var choice: Dictionary = _reader.object(fields, "opponent_choice", location)
	var family: int = _reader.enum_value(choice, "family", location + ".family", GameEnums.ChoiceFamily)
	if family < 0:
		return null
	if family != expected_family:
		_reader.fail(location + ".family", "その局面の相手の手の種類でない: %s" % str(choice.get("family")))
		return null
	var action: int = _reader.enum_value(choice, "action", location + ".action", TurnChoice.ACTION_ENUMS[family])
	var target: PitchArea = _reader.area_or_null(choice, "target", location + ".target")
	if action < 0:
		return null
	var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
	if (target != null) != MoveOptions.needs_target(family_value, action):
		_reader.fail(location + ".target", "運ぶ先を持つ手のときだけ null でない、になっていない")
	return TurnChoice.new(family_value, action, target)


## 陣形（読み込んだ陣形のどれか）と方式。
func _team_setup(fields: Dictionary, key: String, location: String) -> TeamSetup:
	var setup: Dictionary = _reader.object(fields, key, location)
	var formation_id: String = _reader.text(setup, "formation_id", location + ".formation_id")
	if not _formation_ids.has(formation_id):
		_reader.fail(location + ".formation_id", "陣形が無い: %s" % formation_id)
	var defense: int = maxi(0, _reader.enum_value(setup, "defense", location + ".defense", GameEnums.DefenseStyle))
	var attack: int = maxi(0, _reader.enum_value(setup, "attack", location + ".attack", GameEnums.AttackStyle))
	return TeamSetup.new(formation_id,
			TeamStyles.new(defense as GameEnums.DefenseStyle, attack as GameEnums.AttackStyle))

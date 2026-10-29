## 中断データの JSON（data-definition.md §2.1）を確かめながら試合の状態（MatchState）に戻す。書き出しは SuspendedMatchEncoder。
## 1つでも型・必須・範囲から外れたら null を返す（一部だけ正しいデータで再開しない。NFR-09）。誤りは errors() で読める。
## 範囲の根拠: 陣形と選手は ContentCatalog、ターン数の上限は MatchRuleConfig。
class_name SuspendedMatchDecoder
extends RefCounted

const MATCH_ID_PATTERN: String = "^\\d{8}-\\d{6}-\\d{4}$"
const DATETIME_PATTERN: String = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$"
const PLAYER_COUNT: int = 10
const MAX_SCORE: int = 99
const MAX_MOVEMENTS: int = 40
## 判定の人数の上限（data-definition.md §2.1「0〜10」）
const MAX_JUDGE_COUNT: int = 10

var _catalog: ContentCatalog
var _max_turn: int
var _max_records: int
var _reader: SaveDataReader
var _match_id_regex: RegEx
var _datetime_regex: RegEx
## 陣形 ID → {選手 ID → 基本エリア}（GK を除く。アルゴリズム1）
var _base_areas: Dictionary = {}


func _init(catalog: ContentCatalog, rules: MatchRuleConfig) -> void:
	_catalog = catalog
	_max_turn = rules.turns_per_half + rules.max_additional_turns
	_max_records = _max_turn * 2
	_match_id_regex = RegEx.create_from_string(MATCH_ID_PATTERN)
	_datetime_regex = RegEx.create_from_string(DATETIME_PATTERN)


## 誤りがあれば null。
func decode(root: Variant) -> MatchState:
	_reader = SaveDataReader.new()
	if typeof(root) != TYPE_DICTIONARY:
		_reader.fail("(最上位)", "オブジェクトでない")
		return null
	var fields: Dictionary = root
	_reader.integer(fields, "format_version", "format_version", SuspendedMatchEncoder.FORMAT_VERSION,
			SuspendedMatchEncoder.FORMAT_VERSION)
	var match_data: Dictionary = _reader.object(fields, "match", "match")
	if not _reader.is_ok():
		return null
	var state: MatchState = _match(match_data)
	return state if _reader.is_ok() else null


## 直前の decode で見つかった誤り（「場所: 理由」）。
func errors() -> Array[String]:
	return [] if _reader == null else _reader.errors()


func _match(fields: Dictionary) -> MatchState:
	var state := MatchState.new()
	state.match_id = _reader.text(fields, "match_id", "match.match_id", _match_id_regex)
	state.status = _reader.enum_value(fields, "status", "match.status", GameEnums.MatchStatus) as GameEnums.MatchStatus
	state.stage = _reader.enum_value(fields, "stage", "match.stage", GameEnums.MatchStage) as GameEnums.MatchStage
	state.half = _reader.integer(fields, "half", "match.half", 1, 2)
	# 項目どうしの整合のうち、再開先の画面を誤らせるもの（後半のハーフタイムは無い）。ほかの組み合わせは見ていない
	if state.stage == GameEnums.MatchStage.HALFTIME and state.half != 1:
		_reader.fail("match.stage", "ハーフタイムが前半でない")
	# ハーフを終えた後（FINISHED・終了処理待ち）は ターン数＋1 になる（data-definition.md §2.1）
	state.turn_number = _reader.integer(fields, "turn_number", "match.turn_number", 1, _max_turn + 1)
	state.turn_kind = _reader.enum_value(fields, "turn_kind", "match.turn_kind", GameEnums.TurnKind) as GameEnums.TurnKind
	state.possession = _side(fields, "possession", "match.possession")
	state.ball_area = _reader.area(fields, "ball_area", "match.ball_area")
	state.first_half_kickoff = _side(fields, "first_half_kickoff", "match.first_half_kickoff")
	var score: Dictionary = _reader.object(fields, "score", "match.score")
	state.home_score = _reader.integer(score, "HOME", "match.score.HOME", 0, MAX_SCORE)
	state.away_score = _reader.integer(score, "AWAY", "match.score.AWAY", 0, MAX_SCORE)
	var setups: Array[TeamSetup] = _setups(fields, "match.setups")
	if setups.is_empty():
		return state
	state.home_setup = setups[0]
	state.away_setup = setups[1]
	var players: Dictionary = _reader.object(fields, "players", "match.players")
	state.home_players = _players(players, "HOME", "match.players.HOME", state.home_setup.formation_id)
	state.away_players = _players(players, "AWAY", "match.players.AWAY", state.away_setup.formation_id)
	var origin: Variant = _reader.object_or_null(fields, "transition_origin", "match.transition_origin")
	var is_transition: bool = state.turn_kind == GameEnums.TurnKind.TRANSITION
	if (origin != null) != is_transition:
		_reader.fail("match.transition_origin", "トランジションのターンでだけ null でない、になっていない")
	elif origin != null:
		state.transition_origin = _pair(origin as Dictionary, "match.transition_origin", setups)
	state.started_at = _reader.text(fields, "started_at", "match.started_at", _datetime_regex)
	var records: Array = _reader.array(fields, "turn_records", "match.turn_records", 0, _max_records)
	for index: int in range(records.size()):
		var location: String = "match.turn_records[%d]" % index
		if typeof(records[index]) != TYPE_DICTIONARY:
			_reader.fail(location, "オブジェクトでない")
			continue
		var record: TurnRecord = _record(records[index] as Dictionary, location)
		if record != null:
			if record.seq != index + 1:
				_reader.fail(location + ".seq", "1 から連番でない: %d" % record.seq)
			state.turn_records.append(record)
	return state


func _side(fields: Dictionary, key: String, location: String) -> GameEnums.TeamSide:
	return _reader.enum_value(fields, key, location, GameEnums.TeamSide) as GameEnums.TeamSide


## [HOME, AWAY] の陣形と方式。誤りがあれば空。
func _setups(fields: Dictionary, location: String) -> Array[TeamSetup]:
	var setups: Dictionary = _reader.object(fields, "setups", location)
	var result: Array[TeamSetup] = []
	for side_name: String in ["HOME", "AWAY"]:
		var setup_location: String = location + "." + side_name
		var setup: Dictionary = _reader.object(setups, side_name, setup_location)
		var formation_id: String = _reader.text(setup, "formation_id", setup_location + ".formation_id")
		if not formation_id.is_empty() and _catalog.formation(formation_id) == null:
			_reader.fail(setup_location + ".formation_id", "陣形が無い: %s" % formation_id)
			formation_id = ""
		var defense: int = _reader.enum_value(setup, "defense", setup_location + ".defense", GameEnums.DefenseStyle)
		var attack: int = _reader.enum_value(setup, "attack", setup_location + ".attack", GameEnums.AttackStyle)
		if formation_id.is_empty() or defense < 0 or attack < 0:
			return []
		result.append(TeamSetup.new(formation_id,
				TeamStyles.new(defense as GameEnums.DefenseStyle, attack as GameEnums.AttackStyle)))
	return result


## 1チームの配置（ちょうど10人で、陣形の GK 以外の選手と1対1）。基本エリアは陣形から導いたものと一致すること。
func _players(fields: Dictionary, key: String, location: String, formation_id: String) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	var entries: Array = _reader.array(fields, key, location, PLAYER_COUNT, PLAYER_COUNT)
	var expected: Dictionary = _base_areas_of(formation_id)
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var player_location: String = "%s[%d]" % [location, index]
		if typeof(entries[index]) != TYPE_DICTIONARY:
			_reader.fail(player_location, "オブジェクトでない")
			continue
		var entry: Dictionary = entries[index]
		var player_id: String = _reader.text(entry, "player_id", player_location + ".player_id")
		if not expected.has(player_id) or seen.has(player_id):
			_reader.fail(player_location + ".player_id", "陣形の選手でないか、重なっている: %s" % player_id)
			continue
		seen[player_id] = true
		var base: PitchArea = _reader.area(entry, "base_area", player_location + ".base_area")
		var fixed: PitchArea = _reader.area_or_null(entry, "fixed_area", player_location + ".fixed_area")
		var current: PitchArea = _reader.area(entry, "current_area", player_location + ".current_area")
		var moved: bool = _reader.boolean(entry, "moved_in_turn", player_location + ".moved_in_turn")
		if base == null or current == null:
			continue
		if not base.equals(expected[player_id] as PitchArea):
			_reader.fail(player_location + ".base_area", "陣形から導いたエリアと違う: %s" % base.to_key())
		var player := PlayerState.new(player_id, base, fixed, current)
		player.moved_in_turn = moved
		result.append(player)
	return result


## 配置の組（attacker_side と HOME・AWAY の配置）。setups は [HOME, AWAY]。
func _pair(fields: Dictionary, location: String, setups: Array[TeamSetup]) -> LayoutPair:
	var attacker_side: GameEnums.TeamSide = _side(fields, "attacker_side", location + ".attacker_side")
	var home: TeamLayout = _layout(fields, "HOME", location + ".HOME", setups[0].formation_id)
	var away: TeamLayout = _layout(fields, "AWAY", location + ".AWAY", setups[1].formation_id)
	if attacker_side == GameEnums.TeamSide.HOME:
		return LayoutPair.new(home, away, attacker_side)
	return LayoutPair.new(away, home, attacker_side)


## 配置（選手の current_area を配置の現在エリアにする。SuspendedMatchEncoder の注記）。
## 基本エリアは、その時点の陣形から導いたものと一致することを確かめる（ハーフタイムで陣形が変わるので、記録ごとの陣形で見る）。
func _layout(fields: Dictionary, key: String, location: String, formation_id: String) -> TeamLayout:
	return TeamLayout.from_players(_players(fields, key, location, formation_id))


func _record(fields: Dictionary, location: String) -> TurnRecord:
	var record := TurnRecord.new()
	record.seq = _reader.integer(fields, "seq", location + ".seq", 1, _max_records)
	record.half = _reader.integer(fields, "half", location + ".half", 1, 2)
	record.turn_number = _reader.integer(fields, "turn_number", location + ".turn_number", 1, _max_turn)
	record.turn_kind = _reader.enum_value(fields, "turn_kind", location + ".turn_kind", GameEnums.TurnKind) as GameEnums.TurnKind
	record.attacker = _side(fields, "attacker", location + ".attacker")
	var setups: Array[TeamSetup] = _setups(fields, location + ".setups")
	if setups.is_empty():
		return null
	record.home_setup = setups[0]
	record.away_setup = setups[1]
	var choices: Dictionary = _reader.object(fields, "choices", location + ".choices")
	record.home_choice = _choice(choices, "HOME", location + ".choices.HOME")
	record.away_choice = _choice(choices, "AWAY", location + ".choices.AWAY")
	record.ball_before = _reader.area(fields, "ball_before", location + ".ball_before")
	record.ball_after = _reader.area(fields, "ball_after", location + ".ball_after")
	record.pair_before = _pair(_reader.object(fields, "players_before", location + ".players_before"),
			location + ".players_before", setups)
	record.pair_at_judgement = _pair(_reader.object(fields, "players_at_judgement", location + ".players_at_judgement"),
			location + ".players_at_judgement", setups)
	var ids: Dictionary = {GameEnums.TeamSide.HOME: _base_areas_of(setups[0].formation_id),
			GameEnums.TeamSide.AWAY: _base_areas_of(setups[1].formation_id)}
	var movements: Array = _reader.array(fields, "movements", location + ".movements", 0, MAX_MOVEMENTS)
	for index: int in range(movements.size()):
		var movement: Movement = _movement(movements[index], "%s.movements[%d]" % [location, index], ids)
		if movement != null:
			record.movements.append(movement)
	record.outcome = _reader.enum_value(fields, "outcome", location + ".outcome", GameEnums.TurnOutcome) as GameEnums.TurnOutcome
	var judge: Variant = _reader.object_or_null(fields, "judge", location + ".judge")
	if (judge == null) != (record.outcome == GameEnums.TurnOutcome.NO_CONTEST):
		_reader.fail(location + ".judge", "判定なしのときだけ null、になっていない")
	elif judge != null:
		record.judge = _judge(judge as Dictionary, location + ".judge")
	return record


func _choice(fields: Dictionary, key: String, location: String) -> TurnChoice:
	var choice: Dictionary = _reader.object(fields, key, location)
	var family: int = _reader.enum_value(choice, "family", location + ".family", GameEnums.ChoiceFamily)
	if family < 0:
		return null
	var actions: Dictionary = SuspendedMatchEncoder.ACTION_ENUMS[family]
	var action: int = _reader.enum_value(choice, "action", location + ".action", actions)
	var target: PitchArea = _reader.area_or_null(choice, "target", location + ".target")
	if action < 0:
		return null
	var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
	if (target != null) != MoveOptions.needs_target(family_value, action):
		_reader.fail(location + ".target", "運ぶ先を持つ手のときだけ null でない、になっていない")
	return TurnChoice.new(family_value, action, target)


## ids は側 → {その側の選手 ID → 基本エリア}。
func _movement(value: Variant, location: String, ids: Dictionary) -> Movement:
	if typeof(value) != TYPE_DICTIONARY:
		_reader.fail(location, "オブジェクトでない")
		return null
	var fields: Dictionary = value
	var side: int = _reader.enum_value(fields, "side", location + ".side", GameEnums.TeamSide)
	var player_id: String = _reader.text(fields, "player_id", location + ".player_id")
	var from: PitchArea = _reader.area(fields, "from", location + ".from")
	var to: PitchArea = _reader.area(fields, "to", location + ".to")
	var reason: int = _reader.enum_value(fields, "reason", location + ".reason", GameEnums.MovementReason)
	if side < 0 or from == null or to == null or reason < 0:
		return null
	if not (ids[side] as Dictionary).has(player_id):
		_reader.fail(location + ".player_id", "その側の選手でない: %s" % player_id)
		return null
	return Movement.new(side as GameEnums.TeamSide, player_id, from, to, reason as GameEnums.MovementReason)


func _judge(fields: Dictionary, location: String) -> JudgeDetail:
	var compare: PitchArea = _reader.area(fields, "compare_area", location + ".compare_area")
	var attackers: int = _reader.integer(fields, "attacker_count", location + ".attacker_count", 0, MAX_JUDGE_COUNT)
	var defenders: int = _reader.integer(fields, "defender_count", location + ".defender_count", 0, MAX_JUDGE_COUNT)
	var cover: int = _reader.enum_value(fields, "cover", location + ".cover", GameEnums.CoverKind)
	var read: int = _reader.enum_value(fields, "read", location + ".read", GameEnums.ReadKind)
	if compare == null or cover < 0 or read < 0:
		return null
	return JudgeDetail.new(compare, attackers, defenders, cover as GameEnums.CoverKind, read as GameEnums.ReadKind)


## 陣形の GK 以外の選手 → 基本エリア。陣形が無ければ空（_setups で誤りにしてある）。
func _base_areas_of(formation_id: String) -> Dictionary:
	if _base_areas.has(formation_id):
		return _base_areas[formation_id]
	var areas: Dictionary = {}
	var formation: FormationDef = _catalog.formation(formation_id)
	if formation != null:
		var layout: TeamLayout = BaseLayoutDeriver.derive(formation)
		for player: PlayerState in layout.players:
			areas[player.player_id] = player.base_area
	_base_areas[formation_id] = areas
	return areas

## 試合の状態（MatchState）を中断データの JSON の形（data-definition.md §2.1）にする。読み込みは SuspendedMatchDecoder。
## 区分値は enum の名前、エリアは "M2-L1" の形（component-design.md §4.3「JSON の共通の形」）。
##
## 配置（TeamLayout）は、選手ごとの状態と、配置としての現在エリアを別々に持つ。ターンの中の計算は配置の現在エリアを読み、
## 配置の中の選手の current_area は読まないので、配置は「配置の現在エリア」を current_area として書く。
## 配置には、どちらが攻撃側かを attacker_side として書く（動きの側を決めるのに使う。data-definition.md §2.1 の注記）。
class_name SuspendedMatchEncoder
extends RefCounted

const FORMAT_VERSION: int = 1

## ChoiceFamily → その手の区分値の enum（action を名前で書くため）
const ACTION_ENUMS: Dictionary = {
	GameEnums.ChoiceFamily.ATTACK: GameEnums.PlayType,
	GameEnums.ChoiceFamily.DEFENSE: GameEnums.DefenseAction,
	GameEnums.ChoiceFamily.NEG_TRANS: GameEnums.NegTransAction,
	GameEnums.ChoiceFamily.POS_TRANS: GameEnums.PosTransAction,
}


static func encode(state: MatchState) -> Dictionary:
	var records: Array = []
	for record: TurnRecord in state.turn_records:
		records.append(_record(record))
	var match_data: Dictionary = {
		"match_id": state.match_id,
		"status": GameEnums.MatchStatus.find_key(state.status),
		"stage": GameEnums.MatchStage.find_key(state.stage),
		"half": state.half,
		"turn_number": state.turn_number,
		"turn_kind": GameEnums.TurnKind.find_key(state.turn_kind),
		"possession": _side(state.possession),
		"ball_area": state.ball_area.to_key(),
		"first_half_kickoff": _side(state.first_half_kickoff),
		"score": {"HOME": state.home_score, "AWAY": state.away_score},
		"setups": _setups(state.home_setup, state.away_setup),
		"players": {"HOME": _players(state.home_players), "AWAY": _players(state.away_players)},
		"transition_origin": null if state.transition_origin == null else _pair(state.transition_origin),
		"started_at": state.started_at,
		"turn_records": records,
	}
	return {"format_version": FORMAT_VERSION, "match": match_data}


static func to_json(state: MatchState) -> String:
	return JSON.stringify(encode(state))


static func _side(side: GameEnums.TeamSide) -> String:
	return GameEnums.TeamSide.find_key(side)


static func _area(area: PitchArea) -> Variant:
	return null if area == null else area.to_key()


static func _setups(home: TeamSetup, away: TeamSetup) -> Dictionary:
	return {"HOME": setup_fields(home), "AWAY": setup_fields(away)}


## 陣形と方式の形 {formation_id, defense, attack}。戦績の推移（MatchRecordCodec）も同じ形で書く。
static func setup_fields(setup: TeamSetup) -> Dictionary:
	return {"formation_id": setup.formation_id, "defense": GameEnums.DefenseStyle.find_key(setup.styles.defense),
			"attack": GameEnums.AttackStyle.find_key(setup.styles.attack)}


static func _player(player: PlayerState, current: PitchArea) -> Dictionary:
	return {"player_id": player.player_id, "base_area": player.base_area.to_key(), "fixed_area": _area(player.fixed_area),
			"current_area": current.to_key(), "moved_in_turn": player.moved_in_turn}


static func _players(players: Array[PlayerState]) -> Array:
	var result: Array = []
	for player: PlayerState in players:
		result.append(_player(player, player.current_area))
	return result


static func _layout(layout: TeamLayout) -> Array:
	var result: Array = []
	for player: PlayerState in layout.players:
		result.append(_player(player, layout.current_area_of(player.player_id)))
	return result


## 配置の組。HOME・AWAY のそれぞれの配置と、どちらが攻撃側か。
static func _pair(pair: LayoutPair) -> Dictionary:
	var home: TeamLayout = pair.attacker if pair.attacker_side == GameEnums.TeamSide.HOME else pair.defender
	var away: TeamLayout = pair.defender if pair.attacker_side == GameEnums.TeamSide.HOME else pair.attacker
	return {"attacker_side": _side(pair.attacker_side), "HOME": _layout(home), "AWAY": _layout(away)}


static func _choice(choice: TurnChoice) -> Dictionary:
	var actions: Dictionary = ACTION_ENUMS[choice.family]
	return {"family": GameEnums.ChoiceFamily.find_key(choice.family), "action": actions.find_key(choice.action),
			"target": _area(choice.target)}


static func _record(record: TurnRecord) -> Dictionary:
	var movements: Array = []
	for movement: Movement in record.movements:
		movements.append({"side": _side(movement.side), "player_id": movement.player_id, "from": movement.from.to_key(),
				"to": movement.to.to_key(), "reason": GameEnums.MovementReason.find_key(movement.reason)})
	var judge: Variant = null
	if record.judge != null:
		judge = {"compare_area": record.judge.compare_area.to_key(), "attacker_count": record.judge.attacker_count,
				"defender_count": record.judge.defender_count, "cover": GameEnums.CoverKind.find_key(record.judge.cover),
				"read": GameEnums.ReadKind.find_key(record.judge.read)}
	return {
		"seq": record.seq,
		"half": record.half,
		"turn_number": record.turn_number,
		"turn_kind": GameEnums.TurnKind.find_key(record.turn_kind),
		"attacker": _side(record.attacker),
		"setups": _setups(record.home_setup, record.away_setup),
		"choices": {"HOME": _choice(record.home_choice), "AWAY": _choice(record.away_choice)},
		"ball_before": record.ball_before.to_key(),
		"ball_after": record.ball_after.to_key(),
		"players_before": _pair(record.pair_before),
		"players_at_judgement": _pair(record.pair_at_judgement),
		"movements": movements,
		"judge": judge,
		"outcome": GameEnums.TurnOutcome.find_key(record.outcome),
	}

## 試合の状態（component-design.md §2.2。ER図「試合」）。MatchRules が写しを作って書き換え、新しい状態として返す。
##
## 選手は基本エリア・固定先・今いるエリア（current_area）を持ち、位置はターンをまたいで持ち越す（1ターン1マス。2026-10-24）。
## 攻守ターンの現在エリアは、ターン開始時に今いるエリアからアルゴリズム2で1マス動かして出す
## （StyleLayoutCalculator.turn_start）。トランジションの起点は、判定時の現在エリアを含む配置（LayoutPair）で持つ。
class_name MatchState
extends RefCounted

var match_id: String = ""
var status: GameEnums.MatchStatus = GameEnums.MatchStatus.IN_PROGRESS
var stage: GameEnums.MatchStage = GameEnums.MatchStage.TURN
## 1〜2
var half: int = 1
## 1〜1ハーフのターン数。ハーフを終えると ターン数＋1 になる
var turn_number: int = 1
var turn_kind: GameEnums.TurnKind = GameEnums.TurnKind.OPEN_PLAY
var possession: GameEnums.TeamSide = GameEnums.TeamSide.HOME
## ボール位置（保持側の視点）
var ball_area: PitchArea
var first_half_kickoff: GameEnums.TeamSide = GameEnums.TeamSide.HOME
var home_score: int = 0
var away_score: int = 0
var home_setup: TeamSetup
var away_setup: TeamSetup
var home_players: Array[PlayerState] = []
var away_players: Array[PlayerState] = []
## トランジションの起点（保持側 = 奪取側を attacker として持つ）。攻守ターンでは null
var transition_origin: LayoutPair
## 開始日時。時刻の取得はドメインで行わないため、呼び出し側が渡す
var started_at: String = ""
var turn_records: Array[TurnRecord] = []


static func other(side: GameEnums.TeamSide) -> GameEnums.TeamSide:
	return GameEnums.TeamSide.AWAY if side == GameEnums.TeamSide.HOME else GameEnums.TeamSide.HOME


func setup_of(side: GameEnums.TeamSide) -> TeamSetup:
	return home_setup if side == GameEnums.TeamSide.HOME else away_setup


func players_of(side: GameEnums.TeamSide) -> Array[PlayerState]:
	return home_players if side == GameEnums.TeamSide.HOME else away_players


func score_of(side: GameEnums.TeamSide) -> int:
	return home_score if side == GameEnums.TeamSide.HOME else away_score


## 選手・陣形と方式・起点・ターン記録まで写す。
func duplicate_deep() -> MatchState:
	var copy := MatchState.new()
	copy.match_id = match_id
	copy.status = status
	copy.stage = stage
	copy.half = half
	copy.turn_number = turn_number
	copy.turn_kind = turn_kind
	copy.possession = possession
	copy.ball_area = null if ball_area == null else ball_area.duplicate_deep()
	copy.first_half_kickoff = first_half_kickoff
	copy.home_score = home_score
	copy.away_score = away_score
	copy.home_setup = null if home_setup == null else home_setup.duplicate_deep()
	copy.away_setup = null if away_setup == null else away_setup.duplicate_deep()
	for player: PlayerState in home_players:
		copy.home_players.append(player.duplicate_deep())
	for player: PlayerState in away_players:
		copy.away_players.append(player.duplicate_deep())
	copy.transition_origin = null if transition_origin == null else transition_origin.duplicate_deep()
	copy.started_at = started_at
	for record: TurnRecord in turn_records:
		copy.turn_records.append(record.duplicate_deep())
	return copy

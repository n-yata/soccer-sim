## ターン記録（component-design.md §2.2。ER図「ターン記録」）。振り返り（FR-18）と開示の動き（FR-24）の入力。
## 座標は判定時の攻撃側（トランジションでは奪取側）の視点。選手の配置と動きは、各チーム自身の視点（§1.2）。
class_name TurnRecord
extends RefCounted

var seq: int
var half: int
var turn_number: int
var turn_kind: GameEnums.TurnKind
## 攻撃側（トランジションでは奪取側）
var attacker: GameEnums.TeamSide
var home_setup: TeamSetup
var away_setup: TeamSetup
## 両者の選択。運ぶ先は攻撃側の視点
var home_choice: TurnChoice
var away_choice: TurnChoice
var ball_before: PitchArea
## 判定直後にボールがあるエリア（攻撃側の視点）。GOAL はシュートしたエリア、SAVE は守備側の D1-C（攻撃側の視点で A2-C）
var ball_after: PitchArea
## ターン開始時の配置（攻守ターンはアルゴリズム2を適用した後、トランジションは起点）
var pair_before: LayoutPair
## 両者の手を適用した後の、判定時の配置
var pair_at_judgement: LayoutPair
## 方式の動き（ターン開始時）と、両者の手による動き
var movements: Array[Movement] = []
## 判定の内訳。NO_CONTEST のときだけ null
var judge: JudgeDetail
var outcome: GameEnums.TurnOutcome


## 選択・配置・動き・内訳まで写す。
func duplicate_deep() -> TurnRecord:
	var copy := TurnRecord.new()
	copy.seq = seq
	copy.half = half
	copy.turn_number = turn_number
	copy.turn_kind = turn_kind
	copy.attacker = attacker
	copy.home_setup = home_setup.duplicate_deep()
	copy.away_setup = away_setup.duplicate_deep()
	copy.home_choice = home_choice.duplicate_deep()
	copy.away_choice = away_choice.duplicate_deep()
	copy.ball_before = ball_before.duplicate_deep()
	copy.ball_after = ball_after.duplicate_deep()
	copy.pair_before = pair_before.duplicate_deep()
	copy.pair_at_judgement = pair_at_judgement.duplicate_deep()
	for movement: Movement in movements:
		copy.movements.append(movement.duplicate_deep())
	copy.judge = null if judge == null else judge.duplicate_deep()
	copy.outcome = outcome
	return copy

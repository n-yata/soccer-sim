## 相手の手の出どころ（component-design.md §3.3）。MatchController は相手の手をこのインターフェース経由で得る。
## choose_turn は利用者の手を受け取らないので、利用者の手を参照できない形になっている（FR-11）。
## 基底クラスは直接使わない（CpuOpponent など、手を決める側が継承する）。
class_name OpponentPolicy
extends RefCounted


## side のターンの手（判定時の攻撃側の視点）。
func choose_turn(_state: MatchState, _side: GameEnums.TeamSide) -> TurnChoice:
	push_error("OpponentPolicy: choose_turn が実装されていない")
	return null


## 試合開始時・ハーフタイムの陣形と方式。
func choose_setup() -> TeamSetup:
	push_error("OpponentPolicy: choose_setup が実装されていない")
	return null


## 得失点後の方式。
func choose_styles() -> TeamStyles:
	push_error("OpponentPolicy: choose_styles が実装されていない")
	return null

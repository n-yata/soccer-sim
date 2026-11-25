## チュートリアルの段階が決めた手を返す相手（component-design.md §3.3）。MatchController.start_tutorial_step が段階ごとに
## 台本（use_step）を差し替える。チュートリアルでは試合の開始・方式の選び直し・ハーフタイムを行わないので、陣形と方式は
## 段階の盤面の値を返すだけにする。
class_name ScriptedOpponent
extends OpponentPolicy

var _choice: TurnChoice
var _setup: TeamSetup


## 段階の相手の手と陣形・方式に差し替える（相手の手を持たない段階では null）。
func use_step(step: TutorialStepDef) -> void:
	_choice = null if step.opponent_choice == null else step.opponent_choice.duplicate_deep()
	_setup = null if step.away_setup == null else step.away_setup.duplicate_deep()


## 台本の手（写し）。台本に手が無ければ null（MatchController は CPU の手が選べないものとして扱う）。
func choose_turn(_state: MatchState, _side: GameEnums.TeamSide) -> TurnChoice:
	return null if _choice == null else _choice.duplicate_deep()


func choose_setup() -> TeamSetup:
	return null if _setup == null else _setup.duplicate_deep()


func choose_styles() -> TeamStyles:
	return null if _setup == null else _setup.styles.duplicate_deep()

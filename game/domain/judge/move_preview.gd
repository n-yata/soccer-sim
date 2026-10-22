## 決定前のプレビュー（component-design.md §2.4）。選んだ手を、相手が何もしないと仮定して適用したときの、
## 自チームの動きを出す。画面で「決定」の前に、どの選手がどこへ動くかを見せるために使う。
##
## 計算は判定と同じ関数を通す（OpenPlayJudge.apply_attack・apply_defense、TransitionJudge.judge）。
## 表示した動きと、判定で実際に起きる自チームの動き（相手の手の影響を除く）を食い違わせないため。
## 「相手が何もしない」は、選手を動かさない手で表す。攻守ターンは相手の手を適用せず、トランジションは
## 奪取側の相手を即時奪回、喪失側の相手を保持とする（どちらも配置を変えない）。
class_name MovePreview
extends RefCounted


## side が choice を選んだときの、side の選手の動き（動いたチーム自身の視点。Movement の約束どおり）。
## choice は判定時の攻撃側（トランジションは奪取側）の視点。選べるかは見ない（呼び出し側が MoveRules.is_allowed で
## 確かめる）。適用できない手なら空。state は MatchRules が作った試合中の状態であることを前提とし、書き換えない。
static func own_movements(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[Movement]:
	var holder_styles: TeamStyles = state.setup_of(state.possession).styles
	var other_styles: TeamStyles = state.setup_of(MatchState.other(state.possession)).styles
	var movements: Array[Movement] = []
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		var is_winner: bool = side == state.possession
		var winner: TurnChoice = choice if is_winner \
				else TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)
		var loser: TurnChoice = choice if not is_winner \
				else TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
		var output: JudgeOutput = TransitionJudge.judge(state.transition_origin, holder_styles, other_styles,
				state.ball_area, winner, loser)
		if output != null:
			movements = output.movements
	else:
		var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
		var step: LayoutStep = null
		if side == state.possession:
			if choice.is_complete_for(GameEnums.ChoiceFamily.ATTACK):
				step = OpenPlayJudge.apply_attack(start, other_styles, state.ball_area, choice)
		elif choice.is_complete_for(GameEnums.ChoiceFamily.DEFENSE):
			step = OpenPlayJudge.apply_defense(start, other_styles, choice)
		if step != null:
			movements = step.movements
	return _of_side(movements, side)


## side の動きだけ（ドリブルに付いていく相手のマークの付け直しなど、相手の動きを除く）。
static func _of_side(movements: Array[Movement], side: GameEnums.TeamSide) -> Array[Movement]:
	var result: Array[Movement] = []
	for movement: Movement in movements:
		if movement.side == side:
			result.append(movement.duplicate_deep())
	return result

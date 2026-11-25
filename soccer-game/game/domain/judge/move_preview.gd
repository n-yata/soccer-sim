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
			# 相手が何もしなくてもオフサイドになる手は、判定でプレーが止まり誰も動かないので、動きを出さない（2026-10-25）
			if choice.is_complete_for(GameEnums.ChoiceFamily.ATTACK) \
					and not OffsideRule.is_offside(start, state.ball_area, choice):
				step = OpenPlayJudge.apply_attack(start, other_styles, state.ball_area, choice)
		elif choice.is_complete_for(GameEnums.ChoiceFamily.DEFENSE):
			step = OpenPlayJudge.apply_defense(start, other_styles, choice)
		if step != null:
			movements = step.movements
	return _of_side(movements, side)


## side が choice を選び、相手が何もしないと仮定したときの配置の並び [ターン開始時, 次のターン開始時]
## （2026-11-05。プレビューで手の動きと詰め直しを見せるため。2026-11-06 に、判定時をはさむ2拍から1拍にした）。
## 相手が何もしないときの結果は次のとおり仮定する。
## - 攻撃（運ぶ先のある手）: 手が通る（前進。ボールは運ぶ先へ、保持のまま）
## - シュート: 決まるかで置き直しが変わるので、次のターン開始時の代わりに判定時
## - 守備: ボールは動かず、相手の保持のまま（膠着）
## - トランジション: own_movements と同じく、相手を動かない手にして判定した結果
## 適用できない手・オフサイドになる手（カウンターを含む）は、ターン開始時だけ（1つ）。配置は判定と試合の進め方と同じ関数で作る。
static func team_steps(state: MatchState, side: GameEnums.TeamSide, choice: TurnChoice) -> Array[LayoutPair]:
	var holder_styles: TeamStyles = state.setup_of(state.possession).styles
	var other_styles: TeamStyles = state.setup_of(MatchState.other(state.possession)).styles
	var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
	var steps: Array[LayoutPair] = [start]
	var output: JudgeOutput = null
	var holder_choice: TurnChoice = choice
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		var is_winner: bool = side == state.possession
		holder_choice = choice if is_winner \
				else TurnChoice.new(GameEnums.ChoiceFamily.POS_TRANS, GameEnums.PosTransAction.SECURE)
		var loser: TurnChoice = choice if not is_winner \
				else TurnChoice.new(GameEnums.ChoiceFamily.NEG_TRANS, GameEnums.NegTransAction.COUNTER_PRESS)
		output = TransitionJudge.judge(state.transition_origin, holder_styles, other_styles, state.ball_area,
				holder_choice, loser)
	elif side == state.possession:
		if not choice.is_complete_for(GameEnums.ChoiceFamily.ATTACK) or OffsideRule.is_offside(start, state.ball_area, choice):
			return steps
		var attacked: LayoutStep = OpenPlayJudge.apply_attack(start, other_styles, state.ball_area, choice)
		if choice.action == GameEnums.PlayType.SHOT:
			steps.append(attacked.pair)
			return steps
		output = JudgeOutput.new(GameEnums.TurnOutcome.ADVANCE, null, attacked.pair, attacked.movements)
	elif choice.is_complete_for(GameEnums.ChoiceFamily.DEFENSE):
		var defended: LayoutStep = OpenPlayJudge.apply_defense(start, other_styles, choice)
		if defended != null:
			output = JudgeOutput.new(GameEnums.TurnOutcome.STALL, null, defended.pair, defended.movements)
			# 膠着のボールの位置は判定前のまま。保持側の手は運ばない手として渡す（ドリブルを戻す動きを起こさない）
			holder_choice = TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHORT_PASS)
	if output == null or output.outcome == GameEnums.TurnOutcome.OFFSIDE:
		return steps
	steps.append(StyleLayoutCalculator.turn_start(MatchRules.preview_next(state, output, holder_choice)).pair)
	return steps


## side の動きだけ（ドリブルに付いていく相手のマークの付け直しなど、相手の動きを除く）。
static func _of_side(movements: Array[Movement], side: GameEnums.TeamSide) -> Array[Movement]:
	var result: Array[Movement] = []
	for movement: Movement in movements:
		if movement.side == side:
			result.append(movement.duplicate_deep())
	return result

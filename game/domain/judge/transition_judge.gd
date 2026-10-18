## アルゴリズム6: トランジションターンの判定（functional-overview.md。component-design.md §2.4）。
##
## origin は直前のターン終了時点（ロスト・阻止の瞬間）の配置で、奪取側を attacker として持つ。
## ball（奪ったエリア X）・運ぶ先・比較エリアは奪取側の視点（§1.2）。
## 結果の反映（保持・ボール位置・次のターン種別・配置区間のリセット）は試合進行（アルゴリズム7）が行う。
class_name TransitionJudge
extends RefCounted


## 奪取側・喪失側の手を適用し、組み合わせごとの規則で結果を決める。
## 選べない手（手の種類の取り違え、カウンターの運ぶ先の欠け）とボール位置の欠けでは null を返す。
static func judge(origin: LayoutPair, winner_styles: TeamStyles, loser_styles: TeamStyles,
		ball: PitchArea, winner_choice: TurnChoice, loser_choice: TurnChoice) -> JudgeOutput:
	if ball == null or winner_choice == null or loser_choice == null \
			or not winner_choice.is_complete_for(GameEnums.ChoiceFamily.POS_TRANS) \
			or not loser_choice.is_complete_for(GameEnums.ChoiceFamily.NEG_TRANS):
		return null
	var is_counter: bool = winner_choice.action == GameEnums.PosTransAction.COUNTER
	var movements: Array[Movement] = []
	# 奪取側: カウンターなら（カウンター型は）大外が飛び出す。保持は直前の配置のまま
	var winner: TeamLayout = origin.attacker.duplicate_deep()
	if is_counter:
		winner = counter_layout(origin.attacker, winner_styles)
		movements.append_array(_breakout_movements(origin.attacker, winner, origin.attacker_side))
	var pair := LayoutPair.new(winner, origin.defender.duplicate_deep(), origin.attacker_side)
	# 喪失側: リトリートなら基本配置に戻って守備方式で動く（マンツーマンは飛び出した後の奪取側につく）。即時奪回は直前のまま
	if loser_choice.action == GameEnums.NegTransAction.RETREAT:
		var step: LayoutStep = StyleLayoutCalculator.retreat(pair, loser_styles, ball)
		pair = step.pair
		movements.append_array(step.movements)
	if is_counter:
		var detail: JudgeDetail = OpenPlayJudge.detail_at(pair, winner_choice.target, false)
		return JudgeOutput.new(OpenPlayJudge.outcome_of(detail, false), detail, pair, movements)
	if loser_choice.action == GameEnums.NegTransAction.RETREAT:
		# リトリート×保持: 両者が争わないことを選んだので判定しない
		return JudgeOutput.new(GameEnums.TurnOutcome.NO_CONTEST, null, pair, movements)
	# 即時奪回×保持: X と上下左右の隣接エリアの人数合計を比べる。同数以下は奪回失敗
	var winner_total: int = _total_around(pair.attacker, ball)
	var loser_total: int = _total_around(pair.defender, ball.mirrored())
	var outcome: GameEnums.TurnOutcome = GameEnums.TurnOutcome.REGAIN if loser_total > winner_total \
			else GameEnums.TurnOutcome.REGAIN_FAILED
	var regain_detail := JudgeDetail.new(ball.duplicate_deep(), winner_total, loser_total, GameEnums.CoverKind.NONE)
	return JudgeOutput.new(outcome, regain_detail, pair, movements)


## カウンターのときの奪取側の配置。カウンター型なら、固定されていない選手のうち、直前の配置で大外（L2/R2）に
## いる選手が1ゾーン前へ出る（前が盤外なら残る）。保持型は直前の配置のまま。飛び出しは方式の動きなので固定しない
## （アルゴリズム2の手順2と同じく、固定された選手は方式の動きの対象外）。
## MoveRules.pos_transition_options に渡す配置を作るのにも使う。
static func counter_layout(winner: TeamLayout, winner_styles: TeamStyles) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for player: PlayerState in winner.players:
		var copied: PlayerState = player.duplicate_deep()
		var area: PitchArea = winner.current_area_of(copied.player_id).duplicate_deep()
		if winner_styles.attack == GameEnums.AttackStyle.COUNTER and not copied.is_fixed() \
				and (area.lane == GameEnums.Lane.L2 or area.lane == GameEnums.Lane.R2) and area.forward() != null:
			area = area.forward()
		current[copied.player_id] = area
		players.append(copied)
	return TeamLayout.new(players, current)


static func _breakout_movements(before: TeamLayout, after: TeamLayout, side: GameEnums.TeamSide) -> Array[Movement]:
	var result: Array[Movement] = []
	for player: PlayerState in before.players:
		var from: PitchArea = before.current_area_of(player.player_id)
		var to: PitchArea = after.current_area_of(player.player_id)
		if not from.equals(to):
			result.append(Movement.new(side, player.player_id, from.duplicate_deep(), to.duplicate_deep(),
					GameEnums.MovementReason.COUNTER_BREAKOUT))
	return result


## center と上下左右の隣接エリアの人数の合計（layout 自身から見た座標）。
static func _total_around(layout: TeamLayout, center: PitchArea) -> int:
	var total: int = layout.count_at(center)
	for area: PitchArea in center.neighbors4():
		total += layout.count_at(area)
	return total

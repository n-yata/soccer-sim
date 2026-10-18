## アルゴリズム5: 攻守ターンの判定の手順2〜6（functional-overview.md。component-design.md §2.4）。
##
## pair はアルゴリズム2を適用済みの配置。ball・運ぶ先・比較エリアは攻撃側から見た座標（§1.2）。
## 結果の反映（手順7。ボールの移動・保持の入れ替え・得点）は試合進行（アルゴリズム7）が行う。
##
## 判定の規則（人数差の符号・敵陣の大外は GK のカバーが届かない）はルールの定義そのもので、調整値ではない。
class_name OpenPlayJudge
extends RefCounted

## 敵陣ゾーンで同数のとき、GK のカバーが届かないレーン
const _OUT_OF_GK_REACH_LANES: Array[GameEnums.Lane] = [GameEnums.Lane.L2, GameEnums.Lane.R2]


## 両者の手を適用し、比較エリアの人数差とカバーの有無で結果を決める。
## 選べない手（手の種類の取り違え、運ぶ先の欠け、適用できない守備の手）とボール位置の欠けでは null を返す。
## 呼び出し側は MoveRules.is_allowed で先に拒否している前提で、ここでは適用できるかだけを見る。
## 攻撃側の方式はアルゴリズム2で配置に織り込み済みのため使わない（引数は component-design.md の形に合わせて受け取る）。
static func judge(pair: LayoutPair, _attacker_styles: TeamStyles, defender_styles: TeamStyles,
		ball: PitchArea, attack: TurnChoice, defense: TurnChoice) -> JudgeOutput:
	if ball == null or attack == null or defense == null \
			or not attack.is_complete_for(GameEnums.ChoiceFamily.ATTACK) \
			or not defense.is_complete_for(GameEnums.ChoiceFamily.DEFENSE):
		return null
	var is_man: bool = defender_styles.defense == GameEnums.DefenseStyle.MAN
	var movements: Array[Movement] = []
	# 手順2: 守備の手
	var step: LayoutStep = DefenseMover.apply(pair, defense.action as GameEnums.DefenseAction, defense.target)
	if step == null:
		return null
	movements.append_array(step.movements)
	# マンツーマンでプレス・カバーに出たマーカーは固定され、残りのマーカーで付け直す（アルゴリズム4のエッジケース・JE-02/03）
	if is_man:
		step = StyleLayoutCalculator.remark(step.pair, defender_styles)
		movements.append_array(step.movements)
	# 手順3: 攻撃の手（ドリブルだけが選手を動かす）
	if attack.action == GameEnums.PlayType.DRIBBLE:
		step = _dribble(step.pair, ball, attack.target)
		movements.append_array(step.movements)
		if is_man:
			step = StyleLayoutCalculator.remark(step.pair, defender_styles)
			movements.append_array(step.movements)
	# 手順4〜6
	var compare: PitchArea = ball if attack.action == GameEnums.PlayType.SHOT else attack.target
	var detail: JudgeDetail = detail_at(step.pair, compare, attack.action == GameEnums.PlayType.SHOT)
	return JudgeOutput.new(outcome_of(detail, attack.action == GameEnums.PlayType.SHOT), detail, step.pair, movements)


## ボールを持つ選手（ball にいる攻撃側の選手。固定された選手を優先し、同じなら配置の順で先）を
## to へ動かして固定する。ball に攻撃側がいなければ誰も動かさない（ボールだけが進み、人数で判定する）。
## 攻撃側が固定されるのはドリブルだけなので、ball で固定されている選手は直前にボールを運んできた選手。
## その選手に運ばせ続ける（矢印・演出で運ぶ選手が入れ替わらず、固定される選手も無駄に増えない）。
static func _dribble(pair: LayoutPair, ball: PitchArea, to: PitchArea) -> LayoutStep:
	var carrier: PlayerState = null
	for player: PlayerState in pair.attacker.players:
		if not ball.equals(pair.attacker.current_area_of(player.player_id)):
			continue
		if carrier == null or (player.is_fixed() and not carrier.is_fixed()):
			carrier = player
	var no_movements: Array[Movement] = []
	if carrier == null:
		return LayoutStep.new(pair.duplicate_deep(), no_movements)
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for player: PlayerState in pair.attacker.players:
		var copied: PlayerState = player.duplicate_deep()
		current[copied.player_id] = pair.attacker.current_area_of(copied.player_id).duplicate_deep()
		if copied.player_id == carrier.player_id:
			copied.fixed_area = to.duplicate_deep()
			current[copied.player_id] = to.duplicate_deep()
		players.append(copied)
	var movements: Array[Movement] = [
		Movement.new(pair.attacker_side, carrier.player_id, ball.duplicate_deep(), to.duplicate_deep(),
				GameEnums.MovementReason.DRIBBLE),
	]
	var moved := LayoutPair.new(TeamLayout.new(players, current), pair.defender.duplicate_deep(), pair.attacker_side)
	return LayoutStep.new(moved, movements)


## 手順5〜6の前半。比較エリアの人数と、同数のときのカバーの内訳（シュートはカバー判定をしない）。
## compare は攻撃側の視点。トランジションのカウンター（アルゴリズム6）と共有する。
static func detail_at(pair: LayoutPair, compare: PitchArea, is_shot: bool) -> JudgeDetail:
	var attackers: int = pair.attacker.count_at(compare)
	var defenders: int = pair.defender.count_at(compare.mirrored())
	var cover: GameEnums.CoverKind = GameEnums.CoverKind.NONE
	if not is_shot and attackers == defenders:
		# 背後 = 守備側ゴール方向へ1ゾーン = 攻撃側から見て1ゾーン前
		var behind: PitchArea = compare.forward()
		if behind == null:
			cover = GameEnums.CoverKind.OUT_OF_GK_REACH if compare.lane in _OUT_OF_GK_REACH_LANES \
					else GameEnums.CoverKind.GOALKEEPER
		elif pair.defender.count_at(behind.mirrored()) > pair.attacker.count_at(behind):
			cover = GameEnums.CoverKind.DEFENDER
	return JudgeDetail.new(compare.duplicate_deep(), attackers, defenders, cover)


## 手順5〜6の後半。内訳から結果を決める。トランジションのカウンター（アルゴリズム6）と共有する。
static func outcome_of(detail: JudgeDetail, is_shot: bool) -> GameEnums.TurnOutcome:
	var diff: int = detail.attacker_count - detail.defender_count
	if is_shot:
		return GameEnums.TurnOutcome.GOAL if diff > 0 else GameEnums.TurnOutcome.SAVE
	if diff > 0:
		return GameEnums.TurnOutcome.ADVANCE
	if diff < 0:
		return GameEnums.TurnOutcome.LOSS
	# 同数: GK か守備側のカバーがいれば膠着、いなければ（GK のカバーが届かない場合を含む）前進
	if detail.cover == GameEnums.CoverKind.GOALKEEPER or detail.cover == GameEnums.CoverKind.DEFENDER:
		return GameEnums.TurnOutcome.STALL
	return GameEnums.TurnOutcome.ADVANCE

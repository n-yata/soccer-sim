## アルゴリズム5: 攻守ターンの判定の手順2〜6（functional-overview.md。component-design.md §2.4）。
##
## pair はアルゴリズム2を適用済みの配置。ball・運ぶ先・比較エリアは攻撃側から見た座標（§1.2）。
## 結果の反映（手順7。ボールの移動・保持の入れ替え・得点）は試合進行（アルゴリズム7）が行う。
##
## 判定の規則（人数差の符号・読みを当てたときに要る人数差・カバー）はルールの定義そのもので、調整値ではない。
class_name OpenPlayJudge
extends RefCounted

## 守備に読まれたパス・ドリブルが通るのに要る、攻撃側の人数の上回り（読みの段階ごと。外れは同数の扱いが別なので持たない）
const _ADVANTAGE_NEEDED: Dictionary[GameEnums.ReadKind, int] = {GameEnums.ReadKind.EXACT: 2, GameEnums.ReadKind.NEAR: 1}

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
	var movements: Array[Movement] = []
	# 手順2: 守備の手
	var step: LayoutStep = apply_defense(pair, defender_styles, defense)
	if step == null:
		return null
	movements.append_array(step.movements)
	# 手順3: 攻撃の手
	step = apply_attack(step.pair, defender_styles, ball, attack, pair)
	movements.append_array(step.movements)
	# 手順4〜6
	var compare: PitchArea = ball if attack.action == GameEnums.PlayType.SHOT else attack.target
	var detail: JudgeDetail = detail_at(step.pair, compare, attack.action == GameEnums.PlayType.SHOT)
	detail.read = read_of(defense.target, compare, ball)
	return JudgeOutput.new(outcome_of(detail, attack.action == GameEnums.PlayType.SHOT), detail, step.pair, movements)


## 手順2。守備の手を適用する（DefenseMover）。マンツーマンでプレス・カバーに出たマーカーは固定され、残りのマーカーで
## 付け直す（アルゴリズム4のエッジケース・JE-02/03）。適用できない手なら null。
## 判定と、決定前のプレビュー（MovePreview。相手が何もしない場合）で共有する。
static func apply_defense(pair: LayoutPair, defender_styles: TeamStyles, defense: TurnChoice) -> LayoutStep:
	var step: LayoutStep = DefenseMover.apply(pair, defense.action as GameEnums.DefenseAction, defense.target)
	if step == null:
		return null
	if defender_styles.defense != GameEnums.DefenseStyle.MAN:
		return step
	var movements: Array[Movement] = step.movements.duplicate()
	var marked: LayoutStep = StyleLayoutCalculator.remark(step.pair, defender_styles, pair.defender)
	movements.append_array(marked.movements)
	return LayoutStep.new(marked.pair, movements)


## 手順3。攻撃の手を適用する。ドリブルだけが選手を動かし（運ぶ選手を運ぶ先に固定）、守備側がマンツーマンなら
## マークを付け直す。ドリブル以外は配置の写しと空の動き。判定と、ヒント（MoveHints。相手が何もしない場合）で共有する。
## start はターン開始の配置（省略したら pair）。守備の手の後に呼ぶときに渡し、付け直しのマーカーをターン開始から
## 1マス以内に保つ（StyleLayoutCalculator.remark）。
static func apply_attack(pair: LayoutPair, defender_styles: TeamStyles, ball: PitchArea, attack: TurnChoice,
		start: LayoutPair = null) -> LayoutStep:
	var movements: Array[Movement] = []
	if attack.action != GameEnums.PlayType.DRIBBLE:
		return LayoutStep.new(pair.duplicate_deep(), movements)
	var step: LayoutStep = _dribble(pair, ball, attack.target)
	movements.append_array(step.movements)
	if defender_styles.defense == GameEnums.DefenseStyle.MAN:
		step = StyleLayoutCalculator.remark(step.pair, defender_styles, (pair if start == null else start).defender)
		movements.append_array(step.movements)
	return LayoutStep.new(step.pair, movements)


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


## 守備の読みの段階。restricted は守備の手で制限したエリア、compare は比較エリア（運ぶ先。シュートはボールのエリア）。
## どちらも攻撃側の視点。隣は同じ列でレーンが1つ隣だけ（列が違うエリアは、背後のカバーとして判定に効く）。
## ボールのエリアへの寄せは、持っている選手への寄せで、運ぶ先の読みではないので隣に数えない
## （数えると、ボールへのプレスだけで横への同数のパスがすべて奪われ、カバーのいない外側へ通す JE-02 が成り立たない）。
static func read_of(restricted: PitchArea, compare: PitchArea, ball: PitchArea) -> GameEnums.ReadKind:
	if restricted.equals(compare):
		return GameEnums.ReadKind.EXACT
	if restricted.equals(ball):
		return GameEnums.ReadKind.NONE
	if restricted.zone == compare.zone and absi(restricted.lane - compare.lane) == 1:
		return GameEnums.ReadKind.NEAR
	return GameEnums.ReadKind.NONE


## 手順5〜6の前半。比較エリアの人数と、同数のときのカバーの内訳（シュートはカバー判定をしない）。
## カバーは、背後のエリアで守備側が攻撃側より多いときだけ。背後が盤外（比較エリアが敵陣ゴール前の A2）ならカバーなし（GK はカバーに数えない。
## 敵陣の同数を GK が止めると、ほとんどの攻撃が敵陣で膠着して点が入らなかったため。2026-10-24）。
## 読み（read）は NONE で返す。攻守ターンの判定（judge）だけが入れる。
## compare は攻撃側の視点。トランジションのカウンター（アルゴリズム6）と共有する。
static func detail_at(pair: LayoutPair, compare: PitchArea, is_shot: bool) -> JudgeDetail:
	var attackers: int = pair.attacker.count_at(compare)
	var defenders: int = pair.defender.count_at(compare.mirrored())
	var cover: GameEnums.CoverKind = GameEnums.CoverKind.NONE
	if not is_shot and attackers == defenders:
		# 背後 = 守備側ゴール方向へ1列 = 攻撃側から見て1列前
		var behind: PitchArea = compare.forward()
		if behind != null and pair.defender.count_at(behind.mirrored()) > pair.attacker.count_at(behind):
			cover = GameEnums.CoverKind.DEFENDER
	return JudgeDetail.new(compare.duplicate_deep(), attackers, defenders, cover)


## 手順5〜6の後半。内訳から結果を決める。トランジションのカウンター（アルゴリズム6）と共有する。
## 読みを当てた守備が得をする（2026-10-24。読み合いを報わせ、攻守がこまめに入れ替わるようにするため）:
## - シュート: 人数で上回れば得点。同数でも、ぴったり読まれていなければ得点。それ以外は阻止
## - それ以外でぴったり読まれた: 攻撃側が 2人以上多ければ前進、それ以外はロスト
## - それ以外で隣を読まれた: 1人以上多ければ前進、それ以外はロスト（同数をカバーの有無によらず奪える。
##   ぴったり読むのは難しく、守備が奪えるのがまれだったため、近くを読んだ守備にも得をさせる）
## - それ以外で読まれていない: 多ければ前進、少なければロスト。同数は、守備のカバーがいれば膠着、いなければ前進
static func outcome_of(detail: JudgeDetail, is_shot: bool) -> GameEnums.TurnOutcome:
	var diff: int = detail.attacker_count - detail.defender_count
	if is_shot:
		var scores: bool = diff > 0 or (diff == 0 and detail.read != GameEnums.ReadKind.EXACT)
		return GameEnums.TurnOutcome.GOAL if scores else GameEnums.TurnOutcome.SAVE
	if detail.read != GameEnums.ReadKind.NONE:
		var needed: int = _ADVANTAGE_NEEDED[detail.read]
		return GameEnums.TurnOutcome.ADVANCE if diff >= needed else GameEnums.TurnOutcome.LOSS
	if diff > 0:
		return GameEnums.TurnOutcome.ADVANCE
	if diff < 0:
		return GameEnums.TurnOutcome.LOSS
	if detail.cover == GameEnums.CoverKind.DEFENDER:
		return GameEnums.TurnOutcome.STALL
	return GameEnums.TurnOutcome.ADVANCE

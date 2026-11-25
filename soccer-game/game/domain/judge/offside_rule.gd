## オフサイド（functional-overview.md アルゴリズム5。2026-10-25）。前へのパスの受け手が、パスの時点で守備の最終ラインより
## 前の列にいればオフサイド。判定（OpenPlayJudge）・ヒント（MoveHints）・盤面のライン（ViewConverter）が同じ規則を使う。
##
## 列は攻撃側の視点の番号（0 = D1 … 5 = A2）。ラインの列と同じ列はオンサイド（盤面の単位では、同じ列を「並んでいる」とみなす）。
## GK は盤面にいないので、フィールドの最後の選手が実際のサッカーの「後ろから2人目」に当たる。
class_name OffsideRule
extends RefCounted


## 実効のオフサイドラインの列（0 始まり）。守備側の選手の今いるエリアを攻撃側の視点に写した、いちばん大きい列（守備側の
## ゴールにいちばん近い列）。ただし、実際のサッカーと同じくボールより前にいない受け手はオフサイドではないので、ボールの列が
## それより前ならボールの列（2026-10-25）。自陣の受け手もオフサイドにならないので、自陣の境（2）より手前なら 2。
## 守備側が0人なら 5（誰もオフサイドにならない）。defender は守備側の視点の配置、ball は攻撃側の視点。
static func line_row(defender: TeamLayout, ball: PitchArea) -> int:
	if defender.players.is_empty():
		return PitchArea.ZONE_COUNT - 1
	var deepest: int = 0
	for player: PlayerState in defender.players:
		deepest = maxi(deepest, defender.current_area_of(player.player_id).mirrored().zone)
	return maxi(maxi(deepest, ball.zone), PitchArea.OWN_HALF_ZONES - 1)


## オフサイドの対象の手の受け手のエリア（攻撃側の視点）。スルーパスは走り込む前の受け手の位置、前へのショートパス
## （運ぶ先がボールより前の列）・背後へのロングボールは運ぶ先。それ以外の手（横・後ろへのパス、サイドチェンジ、ドリブル、
## シュート）は対象外で null。
static func receiver_area(pair: LayoutPair, ball: PitchArea, attack: TurnChoice) -> PitchArea:
	if attack == null or attack.family != GameEnums.ChoiceFamily.ATTACK or attack.target == null:
		return null
	match attack.action:
		GameEnums.PlayType.THROUGH_PASS:
			var runner: PlayerState = OpenPlayJudge.through_pass_runner(pair.attacker, ball, attack.target)
			return null if runner == null else pair.attacker.current_area_of(runner.player_id)
		GameEnums.PlayType.SHORT_PASS:
			return attack.target if attack.target.zone > ball.zone else null
		GameEnums.PlayType.LONG_BEHIND:
			return attack.target
	return null


## attack の受け手が、pair の守備側のラインより前の列にいるか。pair は判定に使う配置（判定ではターン開始と守備の手を
## 適用した後の両方、ヒントではターン開始の配置）。
static func is_offside(pair: LayoutPair, ball: PitchArea, attack: TurnChoice) -> bool:
	var receiver: PitchArea = receiver_area(pair, ball, attack)
	return receiver != null and receiver.zone > line_row(pair.defender, ball)


## カウンター（奪った側の前へのパス。2026-11-06）がオフサイドなら、受け手のいたエリア（奪取側の視点）。オンサイドなら null。
## 受け手は、飛び出しの後の配置 counter で運ぶ先 target にいる奪取側の選手。飛び出しはパスと同時の走り込みなので、スルーパスと
## 同じく走り込む前（直前の配置 origin）の位置で、奪った時点の喪失側のラインと比べる。オンサイドの受け手が1人でもいれば
## オフサイドではない。運ぶ先に味方がいない（奪った選手が自分で運ぶ）カウンターはドリブルなので対象外で null。
## origin は奪取側を attacker に持つ。ball は奪取側の視点。
static func counter_offside_area(origin: LayoutPair, counter: TeamLayout, ball: PitchArea, target: PitchArea) -> PitchArea:
	var line: int = line_row(origin.defender, ball)
	var spot: PitchArea = null
	for player: PlayerState in counter.players:
		if not counter.current_area_of(player.player_id).equals(target):
			continue
		var before: PitchArea = origin.attacker.current_area_of(player.player_id)
		if before.zone <= line:
			return null
		if spot == null:
			spot = before.duplicate_deep()
	return spot

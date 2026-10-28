## ヒント（FR-19）と、CPU の評価値（アルゴリズム8）の共通の計算（component-design.md §2.4）。
## 選べる各手について、相手が何もしないと仮定して手を適用した後の、比較エリアの人数とカバーの有無を出す。
## 利用者に見せる判断材料と CPU が使う材料を食い違わせないため、同じ関数で出す。
##
## 人数の計算は判定と共有する（OpenPlayJudge.apply_attack・detail_at、TransitionJudge.counter_layout・total_around）。
## 運ぶ先は判定時の攻撃側（トランジションは奪取側）の視点。
class_name MoveHints
extends RefCounted


## options の選べる手ごと（運ぶ先を持つ手は運ぶ先ごと）のヒント。並びは手の enum の順、運ぶ先は options の順。
## 人数は side（その手を選ぶ側）から見た値。リトリート・保持・スルーパス（人数でなく読みで決まる）は比べない（is_compared = false）。
## state は MatchRules が作った試合中の状態であること（ボール位置があり、トランジションでは起点がある）を前提とする。
static func evaluate(state: MatchState, side: GameEnums.TeamSide, options: MoveOptions) -> Array[ChoiceHint]:
	var hints: Array[ChoiceHint] = []
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		if side == state.possession:
			_add_winner_hints(hints, state, options)
		else:
			_add_loser_hints(hints, state, options)
		return hints
	var start: LayoutPair = StyleLayoutCalculator.turn_start(state).pair
	if side == state.possession:
		_add_attack_hints(hints, state, start, options)
	else:
		_add_defense_hints(hints, start, options)
	return hints


## 攻撃の手: 攻撃の手だけを適用した後の、運ぶ先（シュートはボール位置）の人数とカバー。
static func _add_attack_hints(hints: Array[ChoiceHint], state: MatchState, start: LayoutPair, options: MoveOptions) -> void:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	var defender_styles: TeamStyles = state.setup_of(MatchState.other(state.possession)).styles
	for action: int in GameEnums.PlayType.values():
		for choice: TurnChoice in _choices(options, family, action):
			var is_shot: bool = action == GameEnums.PlayType.SHOT
			var step: LayoutStep = OpenPlayJudge.apply_attack(start, defender_styles, state.ball_area, choice)
			var pair: LayoutPair = step.pair
			var compare: PitchArea = state.ball_area if is_shot else choice.target
			var detail: JudgeDetail = OpenPlayJudge.detail_at(pair, compare, is_shot)
			# スルーパスは人数に関係なく、読みだけで通るかが決まる（アルゴリズム5）ので、人数を比べない手にする
			var is_compared: bool = action != GameEnums.PlayType.THROUGH_PASS
			var hint := ChoiceHint.new(family, action, choice.target, is_compared,
					detail.attacker_count, detail.defender_count, detail.cover)
			# 今の配置（守備の手の前）のラインで、受け手がオフサイドになるか（2026-10-25）
			hint.is_offside = OffsideRule.is_offside(start, state.ball_area, choice)
			# 相手が何もしなくても、マンツーマンのマーカーが受け手について運ぶ先へ入ってくるスルーパス（判定と同じ関数。2026-10-28）
			hint.is_marked = action == GameEnums.PlayType.THROUGH_PASS \
					and OpenPlayJudge.defender_entered(step.movements, start.attacker_side, choice.target)
			hints.append(hint)


## 守備の手: 制限するエリアの、守備の手を適用する前の人数とカバー（脅威度の材料）。
## 適用後の人数で数えると、プレス・カバー・マークの付け直しで手ごとに変わり方が異なり、エリアどうしの脅威の比較にならないため。
static func _add_defense_hints(hints: Array[ChoiceHint], start: LayoutPair, options: MoveOptions) -> void:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.DEFENSE
	for action: int in GameEnums.DefenseAction.values():
		for choice: TurnChoice in _choices(options, family, action):
			var detail: JudgeDetail = OpenPlayJudge.detail_at(start, choice.target, false)
			hints.append(ChoiceHint.new(family, action, choice.target, true,
					detail.defender_count, detail.attacker_count, detail.cover))


## 奪取側: カウンターはカウンターの配置（飛び出しの後）で運ぶ先の人数とカバー。喪失側は直前の配置のまま。保持は比べない。
static func _add_winner_hints(hints: Array[ChoiceHint], state: MatchState, options: MoveOptions) -> void:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.POS_TRANS
	var origin: LayoutPair = state.transition_origin
	var counter := LayoutPair.new(
			TransitionJudge.counter_layout(origin.attacker, state.setup_of(state.possession).styles),
			origin.defender.duplicate_deep(), origin.attacker_side)
	for action: int in GameEnums.PosTransAction.values():
		for choice: TurnChoice in _choices(options, family, action):
			if action == GameEnums.PosTransAction.SECURE:
				hints.append(ChoiceHint.new(family, action, null, false, 0, 0, GameEnums.CoverKind.NONE))
				continue
			var detail: JudgeDetail = OpenPlayJudge.detail_at(counter, choice.target, false)
			hints.append(ChoiceHint.new(family, action, choice.target, true,
					detail.attacker_count, detail.defender_count, detail.cover))


## 喪失側: 即時奪回はボール位置と上下左右の人数の合計（奪取側は直前の配置のまま）。リトリートは比べない。
static func _add_loser_hints(hints: Array[ChoiceHint], state: MatchState, options: MoveOptions) -> void:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.NEG_TRANS
	var origin: LayoutPair = state.transition_origin
	for action: int in GameEnums.NegTransAction.values():
		for _choice: TurnChoice in _choices(options, family, action):
			if action == GameEnums.NegTransAction.RETREAT:
				hints.append(ChoiceHint.new(family, action, null, false, 0, 0, GameEnums.CoverKind.NONE))
				continue
			var own: int = TransitionJudge.total_around(origin.defender, state.ball_area.mirrored())
			var opponent: int = TransitionJudge.total_around(origin.attacker, state.ball_area)
			hints.append(ChoiceHint.new(family, action, null, true, own, opponent, GameEnums.CoverKind.NONE))


## options で選べる (family, action) の選択の一覧。運ぶ先を持つ手は運ぶ先ごと、持たない手は1件（選べなければ0件）。
static func _choices(options: MoveOptions, family: GameEnums.ChoiceFamily, action: int) -> Array[TurnChoice]:
	var result: Array[TurnChoice] = []
	if not options.is_available(family, action):
		return result
	if not MoveOptions.needs_target(family, action):
		result.append(TurnChoice.new(family, action))
		return result
	for target: PitchArea in options.targets(family, action):
		result.append(TurnChoice.new(family, action, target))
	return result

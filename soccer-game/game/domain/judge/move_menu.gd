## 画面に出す手（2026-11-03。手の選択の簡素化。functional-overview.md アルゴリズム3）。
## ルール上選べる手（MoveRules.options_for）から、枠ごとに手と運ぶ先を1つずつゲームが選ぶ。利用者は行き先を選ばず、手を選ぶだけ。
## 利用者の手のボタンと CPU の候補はこれを使う。試合進行の確かめはルール上選べる手を使う（チュートリアルの決め打ちの相手の手を通すため）。
##
## 攻撃・カウンターは、枠の手の候補のうち攻撃側にいちばん有利なもの（_is_better の順）。守備は、攻撃側のメニューの行き先を予測先にする。
## 同じ局面なら同じ手になる（乱数を使わない）。
class_name MoveMenu
extends RefCounted

## 枠ごとの手。並びはボタンの並びで、攻撃と守備で読みが対応する手を同じ位置にそろえる
## （ショートパス ↔ パスコースを切る、ロングパス ↔ 背後を埋める、ドリブル ↔ ドリブルのコースを切る、シュート ↔ シュートコースを塞ぐ）。
## 1つの枠に入る手は、局面でどれか1つだけになる（ショートパスかスルーパス、ロングボールかサイドチェンジ、シュートかバックパス）。
const SLOTS: Dictionary = {
	GameEnums.ChoiceFamily.ATTACK: [
		[GameEnums.PlayType.SHORT_PASS, GameEnums.PlayType.THROUGH_PASS],
		[GameEnums.PlayType.LONG_BEHIND, GameEnums.PlayType.SWITCH],
		[GameEnums.PlayType.DRIBBLE],
		[GameEnums.PlayType.SHOT, GameEnums.PlayType.BACK_PASS],
	],
	GameEnums.ChoiceFamily.DEFENSE: [
		[GameEnums.DefenseAction.PRESS],
		[GameEnums.DefenseAction.COVER],
		[GameEnums.DefenseAction.CLOSE_DOWN],
		[GameEnums.DefenseAction.BLOCK_SHOT],
	],
	GameEnums.ChoiceFamily.NEG_TRANS: [[GameEnums.NegTransAction.COUNTER_PRESS], [GameEnums.NegTransAction.RETREAT]],
	GameEnums.ChoiceFamily.POS_TRANS: [[GameEnums.PosTransAction.COUNTER], [GameEnums.PosTransAction.SECURE]],
}


## side に出す手。手ごとに運ぶ先は0か1件。運ぶ先は判定時の攻撃側（トランジションは奪取側）の視点（MoveRules.options_for と同じ）。
static func options_for(state: MatchState, side: GameEnums.TeamSide) -> MoveOptions:
	var candidates: MoveOptions = MoveRules.options_for(state, side)
	var family: GameEnums.ChoiceFamily = TurnChoice.family_for(state.turn_kind, side == state.possession)
	match family:
		GameEnums.ChoiceFamily.DEFENSE:
			return _defense_menu(state, candidates)
		GameEnums.ChoiceFamily.NEG_TRANS:
			# 即時奪回・リトリートは運ぶ先を持たないので、選べる手がそのままメニュー
			return candidates
	return _best_per_slot(state, side, family, candidates)


## action と同じ枠の手（チュートリアルの絞り込みを枠で効かせるため）。枠に無い手は action だけ。
static func slot_actions(family: GameEnums.ChoiceFamily, action: int) -> Array[int]:
	var result: Array[int] = []
	var index: int = slot_index(family, action)
	if index < 0:
		result.append(action)
		return result
	result.assign((SLOTS[family] as Array)[index] as Array)
	return result


## action の枠の位置（ボタンの並び。0 から）。枠に無い手は -1。
static func slot_index(family: GameEnums.ChoiceFamily, action: int) -> int:
	var slots: Array = SLOTS[family] as Array
	for index: int in range(slots.size()):
		if action in (slots[index] as Array):
			return index
	return -1


## 攻撃・カウンター: 枠ごとに、運ぶ先を持たない手（シュート・保持）が選べればそれを、無ければ候補の中でいちばん有利な手と運ぶ先を1つ。
static func _best_per_slot(state: MatchState, side: GameEnums.TeamSide, family: GameEnums.ChoiceFamily,
		candidates: MoveOptions) -> MoveOptions:
	var menu := MoveOptions.new()
	var hints: Array[ChoiceHint] = MoveHints.evaluate(state, side, candidates)
	for slot: Array in SLOTS[family] as Array:
		var best: ChoiceHint = null
		var untargeted: int = -1
		for action: int in slot:
			if not MoveOptions.needs_target(family, action) and candidates.is_available(family, action):
				untargeted = action
				break
		if untargeted >= 0:
			menu.allow(family, untargeted)
			continue
		for hint: ChoiceHint in hints:
			if hint.action in slot and hint.target != null and (best == null or _is_better(hint, best, state.ball_area)):
				best = hint
		if best != null:
			menu.add_target(family, best.action, best.target.duplicate_deep())
	return menu


## a が b より攻撃側に有利か（design.md「ゲームが行き先を選ぶ規則」）。オフサイドにならない → マーク注意でない → 人数差が大きい
## → 前進の列数が大きい、の順に比べる。すべて同じなら偽（候補の順で先のものを残す）。ball は攻撃側の視点。
static func _is_better(a: ChoiceHint, b: ChoiceHint, ball: PitchArea) -> bool:
	if a.is_offside != b.is_offside:
		return not a.is_offside
	if a.is_marked != b.is_marked:
		return not a.is_marked
	if a.diff() != b.diff():
		return a.diff() > b.diff()
	return a.target.zone - ball.zone > b.target.zone - ball.zone


## 守備: パスコースを切る（プレス）・背後を埋める（カバー）は、攻撃側のメニューのショートパス・ロングパスの行き先を予測先にする。
## ドリブルのコースを切るは、ドリブルの枠の行き先を予測先にする（2026-11-05）。シュートコースを塞ぐは、選べればボールのエリア。
## 予測先で選べなければ、選べるうちで予測先にいちばん近いエリア。
static func _defense_menu(state: MatchState, candidates: MoveOptions) -> MoveOptions:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.DEFENSE
	var attack_menu: MoveOptions = options_for(state, state.possession)
	var menu := MoveOptions.new()
	for action: int in GameEnums.DefenseAction.values():
		var predicted: PitchArea = state.ball_area
		if action == GameEnums.DefenseAction.PRESS:
			# ショートパスの枠が無ければドリブルの行き先へ（ドリブルは常にあるので、守備の手が1つも無くならない）
			predicted = _slot_target(attack_menu, 0)
			if predicted == null:
				predicted = _slot_target(attack_menu, 2)
		elif action == GameEnums.DefenseAction.COVER:
			predicted = _slot_target(attack_menu, 1)
		elif action == GameEnums.DefenseAction.CLOSE_DOWN:
			predicted = _slot_target(attack_menu, 2)
		if predicted == null:
			continue
		var nearest: PitchArea = _nearest(candidates.targets(family, action), predicted)
		if nearest != null:
			menu.add_target(family, action, nearest.duplicate_deep())
	return menu


## 攻撃のメニューの、slot 番目の枠の行き先。その枠の手が無ければ null。
static func _slot_target(attack_menu: MoveOptions, slot: int) -> PitchArea:
	var family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
	for action: int in (SLOTS[family] as Array)[slot] as Array:
		var targets: Array[PitchArea] = attack_menu.targets(family, action)
		if not targets.is_empty():
			return targets[0]
	return null


## areas のうち predicted にいちばん近いもの（steps_to。同じなら先のもの）。areas が空なら null。
static func _nearest(areas: Array[PitchArea], predicted: PitchArea) -> PitchArea:
	var best: PitchArea = null
	var best_steps: int = 0
	for area: PitchArea in areas:
		var steps: int = area.steps_to(predicted)
		if best == null or steps < best_steps:
			best = area
			best_steps = steps
	return best

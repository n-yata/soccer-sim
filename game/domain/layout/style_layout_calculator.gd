## アルゴリズム2: 現在配置の算出（方式による動き方。functional-overview.md。component-design.md §2.3）。
##
## 各チームの配置はそのチーム自身から見た座標、ボール位置は攻撃側から見た座標で受け取る（§1.2）。
## 選手の位置はターンをまたいで持ち越す。方式の動きは、方式が目指す位置（目標）を基本エリアから出し、
## 今いるエリアから目標へ1マス（斜めを含む）だけ近づける。1ターンに動けるのは1マスまでのため（2026-10-24）。
##
## 余りのマーカーの置き場所とマークの対象の優先順は、ルールの定義そのもので、調整値ではない。そのため定数で持つ。
class_name StyleLayoutCalculator
extends RefCounted

## マンツーマンで余ったマーカーの置き場所（守備側から見た D2-C。カバー役）
const _SPARE_MARKER_LANE: GameEnums.Lane = GameEnums.Lane.C
const _SPARE_MARKER_ZONE: GameEnums.Zone = GameEnums.Zone.D2
## マンツーマンでマークする列の最後（守備側から見て1〜4列目。3列のころの D・M を6列で読み替えた。2026-10-25）
const _MARK_LAST_ZONE: GameEnums.Zone = GameEnums.Zone.M2
## マークの対象の優先順（同じ列の中。列は自陣のゴールに近いほうが先）。C → ハーフスペース → 大外、同じ順位なら守備側から見て左が先
const _MARK_LANE_PRIORITY: Array[GameEnums.Lane] = [
	GameEnums.Lane.C, GameEnums.Lane.L1, GameEnums.Lane.R1, GameEnums.Lane.L2, GameEnums.Lane.R2,
]


## 試合の状態からターン開始時の両チームの配置（保持側を attacker として持つ）を出す。
## 攻守ターンは今いるエリアから手順2〜4（compute）を適用した配置と方式の動き。トランジションは起点の写しで、動きは無い。
## 選べる手（MoveRules.options_for。judge/）と試合進行（MatchRules。match/）の両方から呼ぶため layout/ に置く。
static func turn_start(state: MatchState) -> LayoutStep:
	if state.turn_kind == GameEnums.TurnKind.TRANSITION:
		var no_movements: Array[Movement] = []
		return LayoutStep.new(state.transition_origin.duplicate_deep(), no_movements)
	var defender_side: GameEnums.TeamSide = MatchState.other(state.possession)
	return compute(
			TeamLayout.from_players(state.players_of(state.possession)), state.setup_of(state.possession).styles,
			TeamLayout.from_players(state.players_of(defender_side)), state.setup_of(defender_side).styles,
			state.ball_area, state.possession)


## 手順2〜4。ターン開始時の両チームの配置と、方式の動きを返す。固定は解除しない。
## 起点は各選手の今いるエリア（layout の現在エリア）。目標は基本エリア（固定されていれば固定先）から方式の動きで出し、
## 固定されていない選手を目標へ1マス近づける。前のターンに動いた選手（moved_in_turn）は動かさない。
## movements は位置が変わった選手だけで、攻撃側 → 守備側の順。
static func compute(attacker: TeamLayout, attacker_styles: TeamStyles,
		defender: TeamLayout, defender_styles: TeamStyles,
		ball: PitchArea, attacker_side: GameEnums.TeamSide) -> LayoutStep:
	var attacker_now: Dictionary = _current_areas(attacker)
	var attacker_targets: Dictionary = _start_areas(attacker)
	var attacker_reasons: Dictionary = {}
	if attacker_styles.attack == GameEnums.AttackStyle.POSSESSION:
		_advance_wide_players(attacker, attacker_targets, attacker_reasons)
	var attacker_areas: Dictionary = _stepped(attacker, attacker_now, attacker_targets)
	var defender_now: Dictionary = _current_areas(defender)
	var defender_targets: Dictionary = _start_areas(defender)
	var defender_reasons: Dictionary = {}
	if defender_styles.defense == GameEnums.DefenseStyle.ZONE:
		_slide(defender, defender_targets, defender_reasons, ball.mirrored())
	else:
		# マンツーマンの対象は、攻撃側が動いた後の位置
		_mark(defender, defender_targets, defender_reasons, attacker.players, attacker_areas, defender_now)
	var defender_areas: Dictionary = _stepped(defender, defender_now, defender_targets)
	var pair := LayoutPair.new(
			_layout_with(attacker, attacker_areas), _layout_with(defender, defender_areas), attacker_side)
	var movements: Array[Movement] = []
	movements.append_array(_movements(attacker, attacker_now, attacker_areas, attacker_reasons, attacker_side))
	movements.append_array(
			_movements(defender, defender_now, defender_areas, defender_reasons, pair.defender_side()))
	return LayoutStep.new(pair, movements)


## マンツーマンのマークを付け直す（ドリブル・プレス・カバーの後に呼ぶ）。割り当ては pair の現在エリアで決める。
## マーカーは、ターン開始の位置（start の守備側。省略したら pair の守備側）から対象へ1マス近づいた位置に置く。
## 1ターンの中で付け直しが2回（プレスの後とドリブルの後）あっても、ターン開始から1マス以内に保つため。
## マーカーでない選手は動かない。ZONE ではずれる基準がターン開始時のボール位置なので、何も動かさない。
static func remark(pair: LayoutPair, defender_styles: TeamStyles, start: TeamLayout = null) -> LayoutStep:
	var copied: LayoutPair = pair.duplicate_deep()
	var no_movements: Array[Movement] = []
	if defender_styles.defense != GameEnums.DefenseStyle.MAN:
		return LayoutStep.new(copied, no_movements)
	var defender_now: Dictionary = _current_areas(copied.defender)
	var targets: Dictionary = defender_now.duplicate()
	var reasons: Dictionary = {}
	_mark(copied.defender, targets, reasons, copied.attacker.players, _current_areas(copied.attacker), defender_now)
	var origins: Dictionary = defender_now if start == null else _current_areas(start)
	var defender_areas: Dictionary = {}
	for player: PlayerState in copied.defender.players:
		var here: PitchArea = defender_now[player.player_id] as PitchArea
		# マーカーでない選手（固定された選手を含む）は、目標が今の位置のままなので動かない
		if (targets[player.player_id] as PitchArea).equals(here):
			defender_areas[player.player_id] = here.duplicate_deep()
		else:
			defender_areas[player.player_id] = (origins[player.player_id] as PitchArea).step_toward(
					targets[player.player_id] as PitchArea)
	var result := LayoutPair.new(copied.attacker, _layout_with(copied.defender, defender_areas), copied.attacker_side)
	return LayoutStep.new(result,
			_movements(copied.defender, defender_now, defender_areas, reasons, copied.defender_side()))


## アルゴリズム6のリトリート。守備側（喪失側）の固定を解き、基本配置＋守備方式の目標へ1マス近づく。
## ball は攻撃側（奪取側）から見た座標。マンツーマンの対象は pair.attacker の現在の配置。
## 動きは直前の配置から位置が変わった選手だけで、理由は RETREAT_RESET にまとめる。
static func retreat(pair: LayoutPair, defender_styles: TeamStyles, ball: PitchArea) -> LayoutStep:
	var released: TeamLayout = _released(pair.defender)
	var now: Dictionary = _current_areas(released)
	var targets: Dictionary = _start_areas(released)
	var reasons: Dictionary = {}
	if defender_styles.defense == GameEnums.DefenseStyle.ZONE:
		_slide(released, targets, reasons, ball.mirrored())
	else:
		_mark(released, targets, reasons, pair.attacker.players, _current_areas(pair.attacker), now)
	var areas: Dictionary = _stepped(released, now, targets, true)
	var defender: TeamLayout = _layout_with(released, areas)
	var movements: Array[Movement] = []
	for player: PlayerState in released.players:
		var from: PitchArea = now[player.player_id] as PitchArea
		var to: PitchArea = areas[player.player_id] as PitchArea
		if not to.equals(from):
			movements.append(Movement.new(pair.defender_side(), player.player_id, from.duplicate_deep(),
					to.duplicate_deep(), GameEnums.MovementReason.RETREAT_RESET))
	return LayoutStep.new(LayoutPair.new(pair.attacker.duplicate_deep(), defender, pair.attacker_side), movements)


## layout の固定を解いた写し（位置は変えない）。
static func _released(layout: TeamLayout) -> TeamLayout:
	var players: Array[PlayerState] = []
	for player: PlayerState in layout.players:
		var copied: PlayerState = player.duplicate_deep()
		copied.fixed_area = null
		players.append(copied)
	return TeamLayout.new(players, _current_areas(layout))


## 選手 ID → 目標の起点。固定された選手は固定先、それ以外は基本エリア。
static func _start_areas(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		var area: PitchArea = player.fixed_area if player.is_fixed() else player.base_area
		result[player.player_id] = area.duplicate_deep()
	return result


static func _current_areas(layout: TeamLayout) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		result[player.player_id] = layout.current_area_of(player.player_id)
	return result


## 今いるエリアから目標へ1マス近づいた位置。前のターンに動いた選手（moved_in_turn）は、ターン開始の方式の動きでは
## 動かさない（ターン開始から次のターン開始までを1マス以内に保つ）。ignore_moved はターンの途中の動き
## （付け直し・リトリート）で、ターン開始からの1マスとして数えるので moved_in_turn を見ない。
static func _stepped(layout: TeamLayout, now: Dictionary, targets: Dictionary, ignore_moved: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for player: PlayerState in layout.players:
		var here: PitchArea = now[player.player_id] as PitchArea
		if player.moved_in_turn and not ignore_moved:
			result[player.player_id] = here.duplicate_deep()
		else:
			result[player.player_id] = here.step_toward(targets[player.player_id] as PitchArea)
	return result


## POSSESSION: 固定されていない大外（L2/R2）の選手の目標が1列前。最後の列（A2）の選手はそのまま。
static func _advance_wide_players(layout: TeamLayout, areas: Dictionary, reasons: Dictionary) -> void:
	for player: PlayerState in layout.players:
		if player.is_fixed():
			continue
		var area: PitchArea = areas[player.player_id] as PitchArea
		if area.lane != GameEnums.Lane.L2 and area.lane != GameEnums.Lane.R2:
			continue
		var ahead: PitchArea = area.forward()
		if ahead != null:
			areas[player.player_id] = ahead
			reasons[player.player_id] = GameEnums.MovementReason.POSSESSION_ADVANCE


## ZONE: ボールが左右どちらかのハーフスペース／大外なら、固定されていない全員の目標が1レーンボールサイドへずれる。
## ボールサイドの大外の選手はそのまま。ball は守備側から見た座標。
static func _slide(layout: TeamLayout, areas: Dictionary, reasons: Dictionary, ball: PitchArea) -> void:
	var direction: int = signi(ball.lane - GameEnums.Lane.C)
	if direction == 0:
		return
	for player: PlayerState in layout.players:
		if player.is_fixed():
			continue
		var area: PitchArea = areas[player.player_id] as PitchArea
		var lane: int = clampi(area.lane + direction, GameEnums.Lane.L2, GameEnums.Lane.R2)
		if lane != area.lane:
			areas[player.player_id] = PitchArea.new(lane as GameEnums.Lane, area.zone)
			reasons[player.player_id] = GameEnums.MovementReason.SLIDE


## MAN: 守備側の1〜4列目にいる攻撃側の選手に、マーカーを1人ずつつける（目標を対象と同じエリアにする）。
## マーカーは固定されていない、基本エリアが1〜4列目の選手。優先順の上からマーカーの人数分の対象をマークする。
## 対象のエリアに既にいるマーカーを先に残し、残りは優先順に、今いるエリアがいちばん近い（列差＋レーン差が最小。
## 同じなら配置の選手の順）マーカーを割り当てる。余ったマーカーの目標は D2-C。
## 近さを今いるエリア（positions）で測るのは、1ターン1マスで追いかけるので、基本エリアで選ぶと
## 遠いマーカーが走り続けて追いつかないため。attacker_areas は攻撃側から見た座標。
static func _mark(defender: TeamLayout, areas: Dictionary, reasons: Dictionary,
		attacker_players: Array[PlayerState], attacker_areas: Dictionary, positions: Dictionary) -> void:
	var targets: Array[PitchArea] = []
	for player: PlayerState in attacker_players:
		var seen: PitchArea = (attacker_areas[player.player_id] as PitchArea).mirrored()
		if seen.zone <= _MARK_LAST_ZONE:
			targets.append(seen)
	# sort_custom は安定でないため、同じ順位の対象は元の並び（攻撃側の選手の順）を添字で比べる
	var order: Array[int] = []
	for index: int in range(targets.size()):
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool:
		var rank_a: int = _target_rank(targets[a])
		var rank_b: int = _target_rank(targets[b])
		return rank_a < rank_b or (rank_a == rank_b and a < b))
	var markers: Array[PlayerState] = []
	for player: PlayerState in defender.players:
		if not player.is_fixed() and player.base_area.zone <= _MARK_LAST_ZONE:
			markers.append(player)
	# マークする対象は優先順の上からマーカーの人数分。誰をつけるかは、その後で決める
	order.resize(mini(order.size(), markers.size()))
	# 対象と同じエリアに既にいるマーカーは、そのまま残す。remark で、ドリブルした対象のマーカーが
	# 別の対象のマーカーと入れ替わって矢印が交差しないようにするため（マーカーがついていく）
	var unassigned: Array[int] = []
	for index: int in order:
		var standing: int = _nearest_marker(markers, positions, targets[index])
		if (positions[markers[standing].player_id] as PitchArea).distance_to(targets[index]) == 0:
			_place(markers[standing], targets[index], areas, reasons)
			markers.remove_at(standing)
		else:
			unassigned.append(index)
	for index: int in unassigned:
		var nearest: int = _nearest_marker(markers, positions, targets[index])
		_place(markers[nearest], targets[index], areas, reasons)
		markers.remove_at(nearest)
	for spare: PlayerState in markers:
		_place(spare, PitchArea.new(_SPARE_MARKER_LANE, _SPARE_MARKER_ZONE), areas, reasons)


## 今いるエリアが target にいちばん近いマーカーの添字（同じ距離なら先のもの）。markers は空でないこと。
static func _nearest_marker(markers: Array[PlayerState], positions: Dictionary, target: PitchArea) -> int:
	var nearest: int = 0
	for candidate: int in range(1, markers.size()):
		if (positions[markers[candidate].player_id] as PitchArea).distance_to(target) \
				< (positions[markers[nearest].player_id] as PitchArea).distance_to(target):
			nearest = candidate
	return nearest


static func _target_rank(area: PitchArea) -> int:
	return area.zone * _MARK_LANE_PRIORITY.size() + _MARK_LANE_PRIORITY.find(area.lane)


## マーカーの目標を area にする。理由は常に MARK（目標がたまたま基本エリアと同じでも、マークのために動くので
## RETURN にしない。理由は動いた選手の記録にだけ使う）。
static func _place(player: PlayerState, area: PitchArea, areas: Dictionary, reasons: Dictionary) -> void:
	reasons[player.player_id] = GameEnums.MovementReason.MARK
	areas[player.player_id] = area


## layout の選手（固定を含む）を写し、現在エリアを areas にした配置。
static func _layout_with(layout: TeamLayout, areas: Dictionary) -> TeamLayout:
	var players: Array[PlayerState] = []
	for player: PlayerState in layout.players:
		players.append(player.duplicate_deep())
	return TeamLayout.new(players, areas)


## 位置が変わった選手の動き。理由は目標を決めた方式の動き。方式の動きの理由が無ければ（目標が基本エリア）RETURN。
static func _movements(layout: TeamLayout, start: Dictionary, areas: Dictionary, reasons: Dictionary,
		side: GameEnums.TeamSide) -> Array[Movement]:
	var result: Array[Movement] = []
	for player: PlayerState in layout.players:
		var from: PitchArea = start[player.player_id] as PitchArea
		var to: PitchArea = areas[player.player_id] as PitchArea
		if not from.equals(to):
			var reason: GameEnums.MovementReason = reasons.get(player.player_id, GameEnums.MovementReason.RETURN) as GameEnums.MovementReason
			result.append(Movement.new(side, player.player_id, from.duplicate_deep(), to.duplicate_deep(), reason))
	return result

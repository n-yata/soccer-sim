## アルゴリズム2: 現在配置の算出（方式による動き方。functional-overview.md。component-design.md §2.3）。
##
## 各チームの配置はそのチーム自身から見た座標、ボール位置は攻撃側から見た座標で受け取る（§1.2）。
## 固定されていない選手は、毎回基本エリアを起点に方式の動きを適用する（前のターンの方式の動きを持ち越さない）。
##
## 余りのマーカーの置き場所とマークの対象の優先順は、ルールの定義そのもので、調整値ではない。そのため定数で持つ。
class_name StyleLayoutCalculator
extends RefCounted

## マンツーマンで余ったマーカーの置き場所（守備側から見た D-C。カバー役）
const _SPARE_MARKER_LANE: GameEnums.Lane = GameEnums.Lane.C
const _SPARE_MARKER_ZONE: GameEnums.Zone = GameEnums.Zone.D
## マークの対象の優先順（同じゾーンの中）。C → ハーフスペース → 大外、同じ順位なら守備側から見て左が先
const _MARK_LANE_PRIORITY: Array[GameEnums.Lane] = [
	GameEnums.Lane.C, GameEnums.Lane.L1, GameEnums.Lane.R1, GameEnums.Lane.L2, GameEnums.Lane.R2,
]


## 手順1。全選手を基本エリアに戻し、固定を解除する。
static func reset_segment(layout: TeamLayout) -> TeamLayout:
	var players: Array[PlayerState] = []
	for player: PlayerState in layout.players:
		players.append(PlayerState.new(player.player_id, player.base_area.duplicate_deep()))
	return TeamLayout.at_base(players)


## 手順2〜4。ターン開始時の両チームの配置と、方式の動きを返す。固定は解除しない。
## movements は起点（固定されていなければ基本エリア）から変わった選手だけで、攻撃側 → 守備側の順。
static func compute(attacker: TeamLayout, attacker_styles: TeamStyles,
		defender: TeamLayout, defender_styles: TeamStyles,
		ball: PitchArea, attacker_side: GameEnums.TeamSide) -> LayoutStep:
	var attacker_start: Dictionary = _start_areas(attacker)
	var defender_start: Dictionary = _start_areas(defender)
	var attacker_areas: Dictionary = attacker_start.duplicate()
	var attacker_reasons: Dictionary = {}
	if attacker_styles.attack == GameEnums.AttackStyle.POSSESSION:
		_advance_wide_players(attacker, attacker_areas, attacker_reasons)
	var defender_areas: Dictionary = defender_start.duplicate()
	var defender_reasons: Dictionary = {}
	if defender_styles.defense == GameEnums.DefenseStyle.ZONE:
		_slide(defender, defender_areas, defender_reasons, ball.mirrored())
	else:
		_mark(defender, defender_areas, defender_reasons, attacker.players, attacker_areas)
	var pair := LayoutPair.new(
			_layout_with(attacker, attacker_areas), _layout_with(defender, defender_areas), attacker_side)
	var movements: Array[Movement] = []
	movements.append_array(_movements(attacker, attacker_start, attacker_areas, attacker_reasons, attacker_side))
	movements.append_array(
			_movements(defender, defender_start, defender_areas, defender_reasons, pair.defender_side()))
	return LayoutStep.new(pair, movements)


## マンツーマンのマークを付け直す（ドリブル・プレス・カバーの後に呼ぶ）。起点は pair の現在エリア。
## ZONE ではずれる基準がターン開始時のボール位置なので、何も動かさない。
static func remark(pair: LayoutPair, defender_styles: TeamStyles) -> LayoutStep:
	var copied: LayoutPair = pair.duplicate_deep()
	var no_movements: Array[Movement] = []
	if defender_styles.defense != GameEnums.DefenseStyle.MAN:
		return LayoutStep.new(copied, no_movements)
	var defender_start: Dictionary = _current_areas(copied.defender)
	var defender_areas: Dictionary = defender_start.duplicate()
	var reasons: Dictionary = {}
	_mark(copied.defender, defender_areas, reasons, copied.attacker.players, _current_areas(copied.attacker))
	var result := LayoutPair.new(copied.attacker, _layout_with(copied.defender, defender_areas), copied.attacker_side)
	return LayoutStep.new(result,
			_movements(copied.defender, defender_start, defender_areas, reasons, copied.defender_side()))


## 選手 ID → 起点のエリア。固定された選手は固定先、それ以外は基本エリア。
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


## POSSESSION: 固定されていない大外（L2/R2）の選手が1ゾーン前へ出る。A の選手はそのまま。
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


## ZONE: ボールが左右どちらかのハーフスペース／大外なら、固定されていない全員が1レーンボールサイドへずれる。
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


## MAN: 守備側の D・M にいる攻撃側の選手に、マーカーを1人ずつ同じエリアにつける。
## マーカーは固定されていない、基本エリアが D・M の選手。優先順の上からマーカーの人数分の対象をマークする。
## 対象のエリアに既にいるマーカーを先に残し、残りは優先順に、起点がいちばん近い（ゾーン差＋レーン差が最小。
## 同じなら配置の選手の順）マーカーを割り当てる。余ったマーカーは D-C へ。
## attacker_areas は攻撃側から見た座標。
static func _mark(defender: TeamLayout, areas: Dictionary, reasons: Dictionary,
		attacker_players: Array[PlayerState], attacker_areas: Dictionary) -> void:
	var targets: Array[PitchArea] = []
	for player: PlayerState in attacker_players:
		var seen: PitchArea = (attacker_areas[player.player_id] as PitchArea).mirrored()
		if seen.zone != GameEnums.Zone.A:
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
		if not player.is_fixed() and player.base_area.zone != GameEnums.Zone.A:
			markers.append(player)
	# マークする対象は優先順の上からマーカーの人数分。誰をつけるかは、その後で決める
	order.resize(mini(order.size(), markers.size()))
	# 対象と同じエリアに既にいるマーカーは、そのまま残す。remark で、ドリブルした対象のマーカーが
	# 別の対象のマーカーと入れ替わって矢印が交差しないようにするため（マーカーがついていく）
	var unassigned: Array[int] = []
	for index: int in order:
		var standing: int = _nearest_marker(markers, areas, targets[index])
		if _distance(areas[markers[standing].player_id] as PitchArea, targets[index]) == 0:
			_place(markers[standing], targets[index], areas, reasons)
			markers.remove_at(standing)
		else:
			unassigned.append(index)
	for index: int in unassigned:
		var nearest: int = _nearest_marker(markers, areas, targets[index])
		_place(markers[nearest], targets[index], areas, reasons)
		markers.remove_at(nearest)
	for spare: PlayerState in markers:
		_place(spare, PitchArea.new(_SPARE_MARKER_LANE, _SPARE_MARKER_ZONE), areas, reasons)


## 起点が target にいちばん近いマーカーの添字（同じ距離なら先のもの）。markers は空でないこと。
static func _nearest_marker(markers: Array[PlayerState], areas: Dictionary, target: PitchArea) -> int:
	var nearest: int = 0
	for candidate: int in range(1, markers.size()):
		if _distance(areas[markers[candidate].player_id] as PitchArea, target) \
				< _distance(areas[markers[nearest].player_id] as PitchArea, target):
			nearest = candidate
	return nearest


static func _target_rank(area: PitchArea) -> int:
	return area.zone * _MARK_LANE_PRIORITY.size() + _MARK_LANE_PRIORITY.find(area.lane)


static func _distance(a: PitchArea, b: PitchArea) -> int:
	return absi(a.zone - b.zone) + absi(a.lane - b.lane)


static func _place(player: PlayerState, area: PitchArea, areas: Dictionary, reasons: Dictionary) -> void:
	if not area.equals(areas[player.player_id] as PitchArea):
		reasons[player.player_id] = GameEnums.MovementReason.MARK
	areas[player.player_id] = area


## layout の選手（固定を含む）を写し、現在エリアを areas にした配置。
static func _layout_with(layout: TeamLayout, areas: Dictionary) -> TeamLayout:
	var players: Array[PlayerState] = []
	for player: PlayerState in layout.players:
		players.append(player.duplicate_deep())
	return TeamLayout.new(players, areas)


static func _movements(layout: TeamLayout, start: Dictionary, areas: Dictionary, reasons: Dictionary,
		side: GameEnums.TeamSide) -> Array[Movement]:
	var result: Array[Movement] = []
	for player: PlayerState in layout.players:
		var from: PitchArea = start[player.player_id] as PitchArea
		var to: PitchArea = areas[player.player_id] as PitchArea
		if not from.equals(to):
			result.append(Movement.new(side, player.player_id, from.duplicate_deep(), to.duplicate_deep(),
					reasons[player.player_id] as GameEnums.MovementReason))
	return result

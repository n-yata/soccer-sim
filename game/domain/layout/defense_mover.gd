## アルゴリズム4: 守備の手による移動（functional-overview.md。component-design.md §2.3）。
##
## target は攻撃側から見た座標で受け取り、守備側の視点（T_d = target.mirrored()）に直して計算する。
## 動きは守備側から見た座標で返す（§1.2）。マンツーマンのマークの付け直しは呼び出し側が
## StyleLayoutCalculator.remark で行う（このクラスは方式を受け取らない）。
##
## 隣接エリアの優先順（前方 → 横 → 背後）はルールの定義そのもので、調整値ではない。
class_name DefenseMover
extends RefCounted


## 守備の手を適用し、動いた選手を行き先に固定した配置を返す。movements は位置が変わったときだけ1件。
## 選べない手（動かせる選手がいない、COVER の背後が盤外）なら null を返す（MoveRules.defense_options の条件と同じ）。
static func apply(pair: LayoutPair, action: GameEnums.DefenseAction, target: PitchArea) -> LayoutStep:
	var restricted: PitchArea = target.mirrored()
	var source: PitchArea = null
	var destination: PitchArea = restricted
	var reason: GameEnums.MovementReason = GameEnums.MovementReason.PRESS
	if action == GameEnums.DefenseAction.COVER:
		destination = restricted.backward()
		reason = GameEnums.MovementReason.COVER
		if pair.defender.count_at(restricted) >= 1:
			source = restricted
	if destination == null:
		return null
	if source == null:
		var candidates: Array[PitchArea] = _neighbors_by_priority(restricted)
		if action == GameEnums.DefenseAction.COVER:
			candidates = cover_neighbors(restricted)
		source = _press_source(pair, candidates)
	if source == null:
		return null
	var mover: PlayerState = _pick_player(pair.defender, source)
	var defender: TeamLayout = _moved(pair.defender, mover.player_id, destination)
	var movements: Array[Movement] = []
	# COVER で、隣接から選んだ選手がすでに背後（行き先）にいることがある（T_d が空で、背後にだけ守備側がいる）。
	# その場で固定し、動きには含めない（位置が変わった選手だけを動きにする。StyleLayoutCalculator と同じ決めごと）
	if not source.equals(destination):
		movements.append(Movement.new(pair.defender_side(), mover.player_id, source.duplicate_deep(),
				destination.duplicate_deep(), reason))
	return LayoutStep.new(LayoutPair.new(pair.attacker.duplicate_deep(), defender, pair.attacker_side), movements)


## カバーで背後へ下がる選手を探す隣接エリア（守備側の視点）。前方を除いた横 → 背後。
## 前方の選手は、T_d の背後まで2ゾーン下がることになり、1ターンに動ける1マスを超えるため（2026-10-24）。
## 選べる手の条件（MoveRules.defense_options）も、この並びで確かめる。
static func cover_neighbors(restricted: PitchArea) -> Array[PitchArea]:
	var result: Array[PitchArea] = _neighbors_by_priority(restricted)
	# 前方は並びの先頭（_neighbors_by_priority）
	if restricted.forward() != null:
		result.remove_at(0)
	return result


## candidates（優先順に並べた隣接エリア）のうち、守備側が1人以上いて余り（守備側人数 − 攻撃側人数）が最大のエリア。
## 同じ余りなら並びの先。プレスの並びは前方 → 横（中央寄りのレーンが先、同じなら守備側の左）→ 背後で、
## 最終ラインを最後まで崩さないため（チャレンジ＆カバー原則 TP-03）。いなければ null。
static func _press_source(pair: LayoutPair, candidates: Array[PitchArea]) -> PitchArea:
	var best: PitchArea = null
	var best_surplus: int = 0
	for area: PitchArea in candidates:
		var defenders: int = pair.defender.count_at(area)
		if defenders < 1:
			continue
		var surplus: int = defenders - pair.attacker.count_at(area.mirrored())
		# 優先順に並べてあるので、より大きい余りのときだけ置き換える（同じ余りなら先のエリアが残る）
		if best == null or surplus > best_surplus:
			best = area
			best_surplus = surplus
	return best


## 守備側の視点で、前方 → 横（中央寄り、同じなら左） → 背後の順に並べた上下左右の隣接エリア（盤内のみ）。
static func _neighbors_by_priority(center: PitchArea) -> Array[PitchArea]:
	var result: Array[PitchArea] = []
	var front: PitchArea = center.forward()
	if front != null:
		result.append(front)
	var sides: Array[PitchArea] = []
	for area: PitchArea in center.neighbors4():
		if area.zone == center.zone:
			sides.append(area)
	sides.sort_custom(func(a: PitchArea, b: PitchArea) -> bool:
		var distance_a: int = absi(a.lane - GameEnums.Lane.C)
		var distance_b: int = absi(b.lane - GameEnums.Lane.C)
		return distance_a < distance_b or (distance_a == distance_b and a.lane < b.lane))
	result.append_array(sides)
	var back: PitchArea = center.backward()
	if back != null:
		result.append(back)
	return result


## area にいる選手のうち、固定されていない選手を優先し、同じなら配置の選手の順で先の選手。
## 呼び出し側が area に1人以上いることを確かめてある。
static func _pick_player(layout: TeamLayout, area: PitchArea) -> PlayerState:
	var fixed_fallback: PlayerState = null
	for player: PlayerState in layout.players:
		if not area.equals(layout.current_area_of(player.player_id)):
			continue
		if not player.is_fixed():
			return player
		if fixed_fallback == null:
			fixed_fallback = player
	return fixed_fallback


## player_id を destination へ動かして固定した配置（ほかの選手は写すだけ）。
static func _moved(layout: TeamLayout, player_id: String, destination: PitchArea) -> TeamLayout:
	var players: Array[PlayerState] = []
	var current: Dictionary = {}
	for player: PlayerState in layout.players:
		var copied: PlayerState = player.duplicate_deep()
		current[copied.player_id] = layout.current_area_of(copied.player_id).duplicate_deep()
		if copied.player_id == player_id:
			copied.fixed_area = destination.duplicate_deep()
			current[copied.player_id] = destination.duplicate_deep()
		players.append(copied)
	return TeamLayout.new(players, current)

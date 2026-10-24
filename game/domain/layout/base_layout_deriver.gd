## アルゴリズム1: 基本配置の導出（functional-overview.md。component-design.md §2.3）。
##
## 境界の数値はルールの定義そのもので、調整値ではない。そのため Resource に出さず定数で持つ
## （調整値の一覧の正本は functional-overview.md「設定値として外部化する値」で、ここには含まれない）。
class_name BaseLayoutDeriver
extends RefCounted

const CENTER_X: float = 50.0
## d = |x - 50| がこれ以下なら C（ちょうども C）
const CENTER_MAX_DISTANCE: float = 15.0
## d がこれ以上なら大外（ちょうども大外）。間はハーフスペース
const WIDE_MIN_DISTANCE: float = 30.0
## y がこれ未満なら D（ちょうどは M）
const DEFENSE_ZONE_END_Y: float = 100.0 / 3.0
## y がこれ未満なら M（ちょうどは A）
const MIDDLE_ZONE_END_Y: float = 200.0 / 3.0
## 重なった選手を散らすときの、各レーン（L2・L1・C・R1・R2）の中心の x。ピッチの幅を5等分した中心
const SPREAD_LANE_CENTERS: Array[float] = [10.0, 30.0, 50.0, 70.0, 90.0]
## 散らし方の比較で、浮動小数の誤差を同じとみなす幅
const _EPSILON: float = 0.0001


## 座標（0〜100。y が大きいほど相手ゴール側）からエリアを決める。
static func area_of(x: float, y: float) -> PitchArea:
	return PitchArea.new(_lane_of(x), _zone_of(y))


## GK を除く選手の基本エリアを持つ配置。固定は無く、現在エリアは基本エリアと同じ。
## 座標のエリアで同じエリアに2人以上いるゾーンは、そのゾーンの選手を1マス1人に散らす（_spread_lanes）。
static func derive(formation: FormationDef) -> TeamLayout:
	var slots: Array[PlayerSlotDef] = []
	for slot: PlayerSlotDef in formation.players:
		if not slot.is_goalkeeper():
			slots.append(slot)
	var areas: Array[PitchArea] = []
	for slot: PlayerSlotDef in slots:
		areas.append(area_of(slot.x, slot.y))
	for zone: GameEnums.Zone in [GameEnums.Zone.D, GameEnums.Zone.M, GameEnums.Zone.A]:
		_spread_zone(slots, areas, zone)
	var players: Array[PlayerState] = []
	for index: int in range(slots.size()):
		players.append(PlayerState.new(slots[index].id, areas[index]))
	return TeamLayout.at_base(players)


## zone の選手が同じレーンに重なっていれば、左右の並び順（x。同じ x は陣形データの順）のまま、1マス1人のレーンへ
## 置き直す（2026-10-24）。レーンより人数が多いゾーンは1マス1人にできないので、そのままにする。
static func _spread_zone(slots: Array[PlayerSlotDef], areas: Array[PitchArea], zone: GameEnums.Zone) -> void:
	var indices: Array[int] = []
	var lanes_used: Dictionary = {}
	var overlaps: bool = false
	for index: int in range(slots.size()):
		if areas[index].zone != zone:
			continue
		indices.append(index)
		overlaps = overlaps or lanes_used.has(areas[index].lane)
		lanes_used[areas[index].lane] = true
	if not overlaps or indices.size() > SPREAD_LANE_CENTERS.size():
		return
	indices.sort_custom(func(a: int, b: int) -> bool:
		return slots[a].x < slots[b].x or (slots[a].x == slots[b].x and a < b))
	var xs: Array[float] = []
	for index: int in indices:
		xs.append(slots[index].x)
	var lanes: Array[int] = _spread_lanes(xs)
	# 置き方を比べられなかった（座標が NaN。読み込みが弾くので通常は起きない）ときは、座標のエリアのままにする
	if lanes.size() != indices.size():
		return
	for order: int in range(indices.size()):
		areas[indices[order]] = PitchArea.new(lanes[order] as GameEnums.Lane, zone)


## 左から並んだ xs を、左から並んだ別々のレーンへ置く。レーンの中心（SPREAD_LANE_CENTERS）との差の合計が最小の
## 置き方を選ぶ。同じなら、置いたレーンの中心の平均が xs の平均に近い（左右の釣り合いが取れた）置き方、それも同じなら
## 左を先に詰めた置き方（組み合わせを辞書順に調べて、先に見つけたもの）。
static func _spread_lanes(xs: Array[float]) -> Array[int]:
	var mean_x: float = 0.0
	for x: float in xs:
		mean_x += x / xs.size()
	var best: Array[int] = []
	var best_cost: float = INF
	var best_balance: float = INF
	for lanes: Array[int] in _increasing_lanes(xs.size(), 0):
		var cost: float = 0.0
		var mean_center: float = 0.0
		for order: int in range(xs.size()):
			cost += absf(xs[order] - SPREAD_LANE_CENTERS[lanes[order]])
			mean_center += SPREAD_LANE_CENTERS[lanes[order]] / xs.size()
		var balance: float = absf(mean_center - mean_x)
		if cost < best_cost - _EPSILON or (absf(cost - best_cost) <= _EPSILON and balance < best_balance - _EPSILON):
			best = lanes
			best_cost = cost
			best_balance = balance
	return best


## first 以上のレーンから count 個を左から選ぶ組み合わせを、辞書順にすべて返す。
static func _increasing_lanes(count: int, first: int) -> Array[Array]:
	var result: Array[Array] = []
	if count == 0:
		var empty: Array[int] = []
		result.append(empty)
		return result
	for lane: int in range(first, SPREAD_LANE_CENTERS.size() - count + 1):
		for rest: Array in _increasing_lanes(count - 1, lane + 1):
			var lanes: Array[int] = [lane]
			lanes.append_array(rest)
			result.append(lanes)
	return result


static func _lane_of(x: float) -> GameEnums.Lane:
	var distance: float = absf(x - CENTER_X)
	if distance <= CENTER_MAX_DISTANCE:
		return GameEnums.Lane.C
	var is_left: bool = x < CENTER_X
	if distance < WIDE_MIN_DISTANCE:
		return GameEnums.Lane.L1 if is_left else GameEnums.Lane.R1
	return GameEnums.Lane.L2 if is_left else GameEnums.Lane.R2


static func _zone_of(y: float) -> GameEnums.Zone:
	if y < DEFENSE_ZONE_END_Y:
		return GameEnums.Zone.D
	if y < MIDDLE_ZONE_END_Y:
		return GameEnums.Zone.M
	return GameEnums.Zone.A

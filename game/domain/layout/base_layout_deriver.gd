## アルゴリズム1: 基本配置の導出（functional-overview.md。component-design.md §2.3）と、キックオフの位置（アルゴリズム7）。
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
## 座標の y の全長（0〜100）。これを列の数で等分する
const PITCH_LENGTH: float = 100.0
## 重なった選手を散らすときの、各レーン（L2・L1・C・R1・R2）の中心の x。ピッチの幅を5等分した中心
const SPREAD_LANE_CENTERS: Array[float] = [10.0, 30.0, 50.0, 70.0, 90.0]
## 散らし方の比較で、浮動小数の誤差を同じとみなす幅
const _EPSILON: float = 0.0001


## 座標（0〜100。y が大きいほど相手ゴール側）からエリアを決める。
static func area_of(x: float, y: float) -> PitchArea:
	return PitchArea.new(_lane_of(x), _zone_of(y))


## GK を除く選手の基本エリアを持つ配置。固定は無く、現在エリアは基本エリアと同じ。
## 座標のエリアで同じエリアに2人以上いる列は、その列の選手を1マス1人に散らす（_spread_lanes）。
static func derive(formation: FormationDef) -> TeamLayout:
	var slots: Array[PlayerSlotDef] = []
	for slot: PlayerSlotDef in formation.players:
		if not slot.is_goalkeeper():
			slots.append(slot)
	var xs: Array[float] = []
	var areas: Array[PitchArea] = []
	for slot: PlayerSlotDef in slots:
		xs.append(slot.x)
		areas.append(area_of(slot.x, slot.y))
	_spread_rows(xs, areas)
	var players: Array[PlayerState] = []
	for index: int in range(slots.size()):
		players.append(PlayerState.new(slots[index].id, areas[index]))
	return TeamLayout.at_base(players)


## キックオフの位置（選手 ID → エリア。2026-10-25）。陣形を自陣（1〜3列目）に縮めて置く。
## 列は、基本エリアの列番号を2で割って切り捨てたもの（D1・D2→D1、M1・M2→D2、A1・A2→M1）。座標の y を半分にした
## 列と一致する（列 r の y は [r·h, (r+1)·h) で、その半分は列 floor(r/2) に入る。h = 100/6。y = 100 ちょうどだけは、列6を5に丸めた分の例外で半分が M2 に入るが、陣形データには無い）ので、座標を持ち回らずに
## 基本エリアから決める。同じ列に重なれば、基本エリアのレーンの中心を座標の代わりにして散らす（同じなら配置の順）。
static func kickoff_areas(players: Array[PlayerState]) -> Dictionary:
	var xs: Array[float] = []
	var areas: Array[PitchArea] = []
	for player: PlayerState in players:
		xs.append(SPREAD_LANE_CENTERS[player.base_area.lane])
		@warning_ignore("integer_division")
		areas.append(PitchArea.new(player.base_area.lane, (player.base_area.zone / 2) as GameEnums.Zone))
	_spread_rows(xs, areas)
	var result: Dictionary = {}
	for index: int in range(players.size()):
		result[players[index].player_id] = areas[index]
	return result


## 列ごとに _spread_zone をかける。xs は各選手の左右の位置（座標の x か、その代わりの値）。areas を書き換える。
static func _spread_rows(xs: Array[float], areas: Array[PitchArea]) -> void:
	for zone_index: int in range(PitchArea.ZONE_COUNT):
		_spread_zone(xs, areas, zone_index as GameEnums.Zone)


## zone の選手が同じレーンに重なっていれば、左右の並び順（x。同じ x は並びの順）のまま、1マス1人のレーンへ
## 置き直す（2026-10-24）。レーンより人数が多い列は1マス1人にできないので、そのままにする。
static func _spread_zone(xs: Array[float], areas: Array[PitchArea], zone: GameEnums.Zone) -> void:
	var indices: Array[int] = []
	var lanes_used: Dictionary = {}
	var overlaps: bool = false
	for index: int in range(areas.size()):
		if areas[index].zone != zone:
			continue
		indices.append(index)
		overlaps = overlaps or lanes_used.has(areas[index].lane)
		lanes_used[areas[index].lane] = true
	if not overlaps or indices.size() > SPREAD_LANE_CENTERS.size():
		return
	indices.sort_custom(func(a: int, b: int) -> bool:
		return xs[a] < xs[b] or (xs[a] == xs[b] and a < b))
	var sorted_xs: Array[float] = []
	for index: int in indices:
		sorted_xs.append(xs[index])
	var lanes: Array[int] = _spread_lanes(sorted_xs)
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


## y を列の数で等分した列。境界ちょうどは前の列（y = 50 は M2）。y = 100 は最後の列。
## 掛けてから割る（y × 6 / 100）のは、100/6 の端数で境界ちょうどの値が手前の列に落ちないようにするため。
static func _zone_of(y: float) -> GameEnums.Zone:
	var index: int = int(floor(y * PitchArea.ZONE_COUNT / PITCH_LENGTH))
	return clampi(index, 0, PitchArea.ZONE_COUNT - 1) as GameEnums.Zone

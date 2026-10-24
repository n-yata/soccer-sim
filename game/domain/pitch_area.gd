## 15エリアの1つ（component-design.md §2.2）。
## 視点を持たない値で、誰から見た座標かは持ち主が決める（component-design.md §1.2）。
## 作成後に値を変えない。位置を変える関数は新しい値を返す。
class_name PitchArea
extends RefCounted

const LANE_COUNT: int = 5
const ZONE_COUNT: int = 3
const _LANE_NAMES: Array[String] = ["L2", "L1", "C", "R1", "R2"]
const _ZONE_NAMES: Array[String] = ["D", "M", "A"]

var lane: GameEnums.Lane
var zone: GameEnums.Zone


func _init(p_lane: GameEnums.Lane, p_zone: GameEnums.Zone) -> void:
	lane = p_lane
	zone = p_zone


## 相手チームから見た同じ場所（L2↔R2, L1↔R1, C↔C, D↔A, M↔M）。
## GameEnums.Lane と Zone の並びが左右・前後で対称であることを使って計算する。
func mirrored() -> PitchArea:
	return PitchArea.new(
			(LANE_COUNT - 1 - lane) as GameEnums.Lane,
			(ZONE_COUNT - 1 - zone) as GameEnums.Zone)


## 前（相手ゴール側）へ1ゾーン。盤外なら null。
func forward() -> PitchArea:
	return _at(lane, zone + 1)


## 後ろ（自陣ゴール側）へ1ゾーン。盤外なら null。
func backward() -> PitchArea:
	return _at(lane, zone - 1)


## 上下左右の隣接（盤内のみ）。順序は all() と同じ。
func neighbors4() -> Array[PitchArea]:
	var result: Array[PitchArea] = []
	for area: PitchArea in all():
		if absi(area.lane - lane) + absi(area.zone - zone) == 1:
			result.append(area)
	return result


## 斜めを含む隣接8エリア（盤内のみ）。順序は all() と同じ。
func neighbors8() -> Array[PitchArea]:
	var result: Array[PitchArea] = []
	for area: PitchArea in all():
		if equals(area):
			continue
		if absi(area.lane - lane) <= 1 and absi(area.zone - zone) <= 1:
			result.append(area)
	return result


## other が null なら false。
func equals(other: PitchArea) -> bool:
	return other != null and other.lane == lane and other.zone == zone


## エリアの間の距離（ゾーン差＋レーン差）。マンツーマンのマーカーの選び方（アルゴリズム2）と、
## ボールのエリアに置く保持者の選び方（アルゴリズム7）で同じ測り方を使うため、ここに1つだけ持つ。
func distance_to(other: PitchArea) -> int:
	return absi(zone - other.zone) + absi(lane - other.lane)


## 1ターンに動くのに要るターン数（ゾーン差とレーン差の大きい方。斜めも1マス。functional-overview.md アルゴリズム2）。
func steps_to(other: PitchArea) -> int:
	return maxi(absi(zone - other.zone), absi(lane - other.lane))


## 1ターンで動ける範囲（同じエリアか、斜めを含む周り8エリア）か。
func is_within_one(other: PitchArea) -> bool:
	return steps_to(other) <= 1


## target へ1マス近づいたエリア。ゾーン差・レーン差をそれぞれ1ずつ詰める（斜めを優先し、最も少ないターンで着く）。
func step_toward(target: PitchArea) -> PitchArea:
	return PitchArea.new((lane + signi(target.lane - lane)) as GameEnums.Lane,
			(zone + signi(target.zone - zone)) as GameEnums.Zone)


## "M-L1" 形式。保存データと判定例の表記に合わせる。
func to_key() -> String:
	return "%s-%s" % [_ZONE_NAMES[zone], _LANE_NAMES[lane]]


func duplicate_deep() -> PitchArea:
	return PitchArea.new(lane, zone)


## 不正な文字列なら null。大文字・小文字は区別する。
static func from_key(key: String) -> PitchArea:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 2:
		return null
	var zone_index: int = _ZONE_NAMES.find(parts[0])
	var lane_index: int = _LANE_NAMES.find(parts[1])
	if zone_index < 0 or lane_index < 0:
		return null
	return PitchArea.new(lane_index as GameEnums.Lane, zone_index as GameEnums.Zone)


## 15エリア。D→M→A、各ゾーンの中は L2→R2 の順。
static func all() -> Array[PitchArea]:
	var result: Array[PitchArea] = []
	for zone_index: int in ZONE_COUNT:
		for lane_index: int in LANE_COUNT:
			result.append(PitchArea.new(lane_index as GameEnums.Lane, zone_index as GameEnums.Zone))
	return result


static func _at(lane_index: int, zone_index: int) -> PitchArea:
	if lane_index < 0 or lane_index >= LANE_COUNT or zone_index < 0 or zone_index >= ZONE_COUNT:
		return null
	return PitchArea.new(lane_index as GameEnums.Lane, zone_index as GameEnums.Zone)

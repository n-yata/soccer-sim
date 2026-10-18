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


## 座標（0〜100。y が大きいほど相手ゴール側）からエリアを決める。
static func area_of(x: float, y: float) -> PitchArea:
	return PitchArea.new(_lane_of(x), _zone_of(y))


## GK を除く選手の基本エリアを持つ配置。固定は無く、現在エリアは基本エリアと同じ。
static func derive(formation: FormationDef) -> TeamLayout:
	var players: Array[PlayerState] = []
	for slot: PlayerSlotDef in formation.players:
		if slot.is_goalkeeper():
			continue
		players.append(PlayerState.new(slot.id, area_of(slot.x, slot.y)))
	return TeamLayout.at_base(players)


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

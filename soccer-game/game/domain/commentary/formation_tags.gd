## 陣形の特徴タグ（アルゴリズム9）。フォーメーションラボ（soccer-sim）の formationTags.ts の deriveTags・getTags を移植した。
## 4陣形（4-4-2・4-3-3・4-2-3-1・3-5-2）に関係するタグだけを導出する（5バック・中盤ダイヤ・アンカー1枚は移植しない）。
## 座標（x・y とも 0〜100。y が大きいほど相手ゴール側）だけから導く。
class_name FormationTags
extends RefCounted

# --- 導出のしきい値（移植元の値。変えると全組み合わせの解説が静かに変わる。テストの期待表も合わせて直す） ---
## ウイング: 左右の外側のレーン（x ≤ 25 か x ≥ 75）にいて、高い（y ≥ 80）FW
const WING_LEFT_X: float = 25.0
const WING_RIGHT_X: float = 75.0
const WING_MIN_Y: float = 80.0
## ウイングバック: ウイングよりさらに外側（x ≤ 15 か x ≥ 85）で、低い（y ≤ 50）MF。高さで切るのは、4-4-2 のサイドMF
## （y = 55）をウイングバックにしないため
const WING_BACK_LEFT_X: float = 15.0
const WING_BACK_RIGHT_X: float = 85.0
const WING_BACK_MAX_Y: float = 50.0
## 守備的MF（y ≤ 42）・攻撃的MF（y ≥ 58）の高さ
const DEFENSIVE_MF_MAX_Y: float = 42.0
const ATTACKING_MF_MIN_Y: float = 58.0
## 4人の中盤を「フラット」とみなす y の幅
const FLAT_MIDFIELD_Y_SPREAD: float = 10.0

## 導出するタグと、extra_tags に書けるタグ（座標に現れない特徴）。静的データの検証が使う
const KNOWN: Array[String] = ["3バック", "4バック", "1トップ", "2トップ", "3トップ", "ウイング有", "ウイングバック有",
		"守備的MF2枚", "攻撃的MF3枚", "中盤3枚", "中盤フラット4枚", "中盤実質5枚", "ライン間が空く"]


## 座標から導く特徴タグ（並びは移植元と同じ）。
static func derive(formation: FormationDef) -> Array[String]:
	var tags: Array[String] = []
	var defenders: Array[PlayerSlotDef] = _by_type(formation, "DF")
	var midfielders: Array[PlayerSlotDef] = _by_type(formation, "MF")
	var forwards: Array[PlayerSlotDef] = _by_type(formation, "FW")

	if defenders.size() == 3:
		tags.append("3バック")
	if defenders.size() == 4:
		tags.append("4バック")
	if forwards.size() >= 1 and forwards.size() <= 3:
		tags.append("%dトップ" % forwards.size())

	var wings: int = 0
	for slot: PlayerSlotDef in forwards:
		if _is_wide(slot.x, WING_LEFT_X, WING_RIGHT_X) and slot.y >= WING_MIN_Y:
			wings += 1
	if wings >= 2:
		tags.append("ウイング有")

	var wing_backs: int = 0
	var defensive: int = 0
	var attacking: int = 0
	for slot: PlayerSlotDef in midfielders:
		if _is_wide(slot.x, WING_BACK_LEFT_X, WING_BACK_RIGHT_X) and slot.y <= WING_BACK_MAX_Y:
			wing_backs += 1
		if slot.y <= DEFENSIVE_MF_MAX_Y:
			defensive += 1
		if slot.y >= ATTACKING_MF_MIN_Y:
			attacking += 1
	if wing_backs >= 2:
		tags.append("ウイングバック有")
	if defensive == 2:
		tags.append("守備的MF2枚")
	if attacking >= 3:
		tags.append("攻撃的MF3枚")

	if midfielders.size() == 3:
		tags.append("中盤3枚")
	if midfielders.size() == 4 and _height_spread(midfielders) <= FLAT_MIDFIELD_Y_SPREAD:
		tags.append("中盤フラット4枚")
	# ウイングバックを中盤に数える形（3-5-2）や、守備的MF＋攻撃的MFで5枚になる形（4-2-3-1）も同じタグ
	if midfielders.size() >= 5:
		tags.append("中盤実質5枚")
	return tags


## 導出したタグに extra_tags を足したもの（重複は除き、導出の順を先に）。ルールの当てはめはこちらを使う
## （derive だけだと、座標に現れない特徴のタグ（ライン間が空く）が抜け、そのルールが静かに当たらなくなる）。
static func of(formation: FormationDef) -> Array[String]:
	var tags: Array[String] = derive(formation)
	for tag: String in formation.extra_tags:
		if not tags.has(tag):
			tags.append(tag)
	return tags


static func _by_type(formation: FormationDef, position_type: String) -> Array[PlayerSlotDef]:
	var result: Array[PlayerSlotDef] = []
	for slot: PlayerSlotDef in formation.players:
		if slot.position_type == position_type:
			result.append(slot)
	return result


static func _is_wide(x: float, left_x: float, right_x: float) -> bool:
	return x <= left_x or x >= right_x


static func _height_spread(slots: Array[PlayerSlotDef]) -> float:
	var min_y: float = INF
	var max_y: float = -INF
	for slot: PlayerSlotDef in slots:
		min_y = minf(min_y, slot.y)
		max_y = maxf(max_y, slot.y)
	return max_y - min_y

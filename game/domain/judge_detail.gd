## 判定の内訳（component-design.md §2.2。ターン記録の比較エリア・人数・カバー）。
## compare_area は判定時の攻撃側から見た座標（§1.2）。
class_name JudgeDetail
extends RefCounted

var compare_area: PitchArea
var attacker_count: int
var defender_count: int
## 同数のときのカバー判定の内訳。人数差がついたとき・シュートでは NONE
var cover: GameEnums.CoverKind
## 守備が比較エリアを読んでいたか（守備の手で制限したエリアが比較エリアと同じ）。攻守ターンの判定だけが真にする。
## トランジション・ヒント（相手が何もしない場合）では偽
var is_read: bool


func _init(p_compare_area: PitchArea, p_attacker_count: int, p_defender_count: int,
		p_cover: GameEnums.CoverKind, p_is_read: bool = false) -> void:
	compare_area = p_compare_area
	attacker_count = p_attacker_count
	defender_count = p_defender_count
	cover = p_cover
	is_read = p_is_read


## 比較エリアの PitchArea まで写す。
func duplicate_deep() -> JudgeDetail:
	return JudgeDetail.new(compare_area.duplicate_deep(), attacker_count, defender_count, cover, is_read)

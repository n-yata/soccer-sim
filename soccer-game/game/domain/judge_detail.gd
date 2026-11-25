## 判定の内訳（component-design.md §2.2。ターン記録の比較エリア・人数・カバー・読み）。
## compare_area は判定時の攻撃側から見た座標（§1.2）。
class_name JudgeDetail
extends RefCounted

var compare_area: PitchArea
var attacker_count: int
var defender_count: int
## 同数のときのカバー判定の内訳。人数差がついたとき・シュートでは NONE
var cover: GameEnums.CoverKind
## 守備の読みの段階（守備の手で制限したエリアと比較エリアの近さ）。攻守ターンの判定だけが入れる。
## トランジション・ヒント（相手が何もしない場合）では NONE
var read: GameEnums.ReadKind


func _init(p_compare_area: PitchArea, p_attacker_count: int, p_defender_count: int,
		p_cover: GameEnums.CoverKind, p_read: GameEnums.ReadKind = GameEnums.ReadKind.NONE) -> void:
	compare_area = p_compare_area
	attacker_count = p_attacker_count
	defender_count = p_defender_count
	cover = p_cover
	read = p_read


## 比較エリアの PitchArea まで写す。
func duplicate_deep() -> JudgeDetail:
	return JudgeDetail.new(compare_area.duplicate_deep(), attacker_count, defender_count, cover, read)

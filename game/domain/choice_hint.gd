## ヒント（FR-19）の1項目（component-design.md §2.2）。手と運ぶ先ごとに、相手が何もしないと仮定して手を
## 適用した後の比較の人数と、同数のときのカバーの有無を持つ。CPU の評価値（アルゴリズム8）の材料にもなる。
## 判断材料を示すだけで、推奨の印や評価値は持たない（FR-19「最善の選択を指示しない」）。
class_name ChoiceHint
extends RefCounted

var family: GameEnums.ChoiceFamily
var action: int
## 運ぶ先（判定時の攻撃側の視点）。運ぶ先を持たない手では null
var target: PitchArea
## 人数を比べる手か。リトリート・保持は比べない
var is_compared: bool
## その手を選ぶ側から見た、自分の人数と相手の人数（即時奪回はボール位置と上下左右の合計）
var own_count: int
var opponent_count: int
## 同数のときのカバーの内訳（攻撃側から見た判定の値）
var cover: GameEnums.CoverKind


func _init(p_family: GameEnums.ChoiceFamily, p_action: int, p_target: PitchArea, p_is_compared: bool,
		p_own_count: int, p_opponent_count: int, p_cover: GameEnums.CoverKind) -> void:
	family = p_family
	action = p_action
	target = p_target
	is_compared = p_is_compared
	own_count = p_own_count
	opponent_count = p_opponent_count
	cover = p_cover


## 人数差（札の「+1」「±0」などに使う）。
func diff() -> int:
	return own_count - opponent_count


## 運ぶ先の PitchArea まで写す。
func duplicate_deep() -> ChoiceHint:
	var copied_target: PitchArea = null if target == null else target.duplicate_deep()
	return ChoiceHint.new(family, action, copied_target, is_compared, own_count, opponent_count, cover)

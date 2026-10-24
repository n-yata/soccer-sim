## 選手単位の配置状態（component-design.md §2.2）。座標はその選手のチーム自身から見た値（§1.2）。
class_name PlayerState
extends RefCounted

var player_id: String
## 陣形から導いたエリア（アルゴリズム1）
var base_area: PitchArea
## プレス・カバー・ドリブルで動いて固定されたエリア。固定されていなければ null（アルゴリズム2の手順2）
var fixed_area: PitchArea
## 今いるエリア。ターンをまたいで持ち越す（1ターンに動けるのは1マスまでのため。アルゴリズム2）。
## 試合の状態（MatchState の選手）に持たせる値で、ターンの中の計算では TeamLayout の現在エリアが正
## （TeamLayout.from_players で配置を作り、MatchRules が判定後の配置から写し戻す）
var current_area: PitchArea
## 前のターンの手・トランジションの動き・保持者を置く動きで、そのターンの開始時の位置から動いたか。
## 動いた選手は、次のターン開始の方式の動きでは動かない（ターン開始から次のターン開始までを1マス以内に保つため）
var moved_in_turn: bool = false


## p_current_area を省略したら、固定先があれば固定先、なければ基本エリアにいる。
func _init(p_player_id: String, p_base_area: PitchArea, p_fixed_area: PitchArea = null,
		p_current_area: PitchArea = null) -> void:
	player_id = p_player_id
	base_area = p_base_area
	fixed_area = p_fixed_area
	if p_current_area != null:
		current_area = p_current_area
	elif p_fixed_area != null:
		current_area = p_fixed_area.duplicate_deep()
	else:
		current_area = p_base_area.duplicate_deep()


func is_fixed() -> bool:
	return fixed_area != null


func duplicate_deep() -> PlayerState:
	var copied_fixed: PitchArea = null if fixed_area == null else fixed_area.duplicate_deep()
	var copied := PlayerState.new(player_id, base_area.duplicate_deep(), copied_fixed, current_area.duplicate_deep())
	copied.moved_in_turn = moved_in_turn
	return copied

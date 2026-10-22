## 開示で駒を動かすときの、選手ごとの道筋の計算（screen-common.md §5 の TacticsBoard）。
## TacticsBoard の行数を増やさないため、位置の計算だけをここに置く（描画と Tween はボードが持つ）。
## 駒の位置は、エリアの自分の側の駒の列で、配置の選手の順の添字（slot）から、ボードの piece_center で求める。
class_name BoardShift
extends RefCounted


## players（BoardSnapshot.user_players と同じ形）の各選手の、そのエリアの中での添字（配置の選手の順）。
static func slots(players: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	var counts: Dictionary = {}
	for player: Dictionary in players:
		var key: String = player["area"] as String
		var slot: int = counts.get(key, 0) as int
		result.append(slot)
		counts[key] = slot + 1
	return result


## 動く前（before）から動いた後（after）で駒の位置が変わった選手の道筋。エリアが同じでも、列の位置が変われば入れる
## （ほかの選手が出入りして列が詰まったとき、駒が瞬間的に飛ばないように）。
## 各要素は {"player_id": String, "is_user": bool, "from": Vector2, "to": Vector2}。
## 動く前に居ない選手（ID が見つからない）は入れない。center は (エリアのキー, is_user, 添字) → 駒の中心。
static func paths(before: Array[Dictionary], after: Array[Dictionary], is_user: bool, center: Callable) -> Array[Dictionary]:
	var before_slots: Array[int] = slots(before)
	var origins: Dictionary = {}
	for index: int in range(before.size()):
		origins[before[index]["player_id"]] = [before[index]["area"], before_slots[index]]
	var after_slots: Array[int] = slots(after)
	var result: Array[Dictionary] = []
	for index: int in range(after.size()):
		var player_id: String = after[index]["player_id"] as String
		if not origins.has(player_id):
			continue
		var origin: Array = origins[player_id] as Array
		var from: Vector2 = center.call(origin[0], is_user, origin[1]) as Vector2
		var to: Vector2 = center.call(after[index]["area"], is_user, after_slots[index]) as Vector2
		if from.is_equal_approx(to):
			continue
		result.append({"player_id": player_id, "is_user": is_user, "from": from, "to": to})
	return result

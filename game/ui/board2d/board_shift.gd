## 開示で駒を動かすときの、動きの状態（道筋と進み具合）と道筋の計算（screen-common.md §5 の TacticsBoard）。
## 状態はボードが1つ持ち、Tween で進み具合を進める（Tween はノードが作るため、ボードが持つ）。
## 駒の位置は、エリアの自分の側の駒の列で、配置の選手の順の添字（slot）から、ボードの slot_center で求める。
class_name BoardShift
extends RefCounted

## 動かしている駒の道筋。各要素は {"player_id": String, "is_user": bool, "from": Vector2, "to": Vector2}
var piece_paths: Array[Dictionary] = []
## ボールの道筋 {"from": Vector2, "to": Vector2}。ボールが動かなければ空
var ball_path: Dictionary = {}
## 進み具合（0〜1）。動いていなければ 1
var progress: float = 1.0


## 駒かボールのどちらかが動いているか。
func is_active() -> bool:
	return not piece_paths.is_empty() or not ball_path.is_empty()


## 動きを始める（道筋を入れ、進み具合を始めに戻す）。どちらも空なら動かない（is_active が偽）。
func start(p_piece_paths: Array[Dictionary], p_ball_path: Dictionary) -> void:
	piece_paths = p_piece_paths.duplicate()
	ball_path = p_ball_path.duplicate()
	progress = 0.0 if is_active() else 1.0


## 動きを止める（道筋を消し、進み具合を終わりにする）。
func clear() -> void:
	piece_paths.clear()
	ball_path = {}
	progress = 1.0


## player_id の駒を描く位置。動いていれば道筋の途中、そうでなければ rest（駒の列の位置）。
func piece_position(player_id: String, rest: Vector2) -> Vector2:
	for path: Dictionary in piece_paths:
		if path["player_id"] == player_id:
			return (path["from"] as Vector2).lerp(path["to"] as Vector2, progress)
	return rest


## ボールを描く位置。動いていれば道筋の途中、そうでなければ rest（いまのエリアの位置）。
func ball_position(rest: Vector2) -> Vector2:
	if ball_path.is_empty():
		return rest
	return (ball_path["from"] as Vector2).lerp(ball_path["to"] as Vector2, progress)


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

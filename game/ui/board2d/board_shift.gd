## 開示で駒を動かすときの、動きの状態（拍の並びと進み具合）と道筋の計算（screen-common.md §5 の TacticsBoard）。
## 状態はボードが1つ持ち、Tween で拍と進み具合を進める（Tween はノードが作るため、ボードが持つ）。
## 拍は順に動く（開示では、1拍目 = 判定前 → 判定時のプレー、2拍目 = 判定時 → 次のターン開始時の詰め直し。2026-11-03）。
## 駒の位置は、エリアの自分の側の駒の列で、配置の選手の順の添字（slot）から、ボードの slot_center で求める。
class_name BoardShift
extends RefCounted

## 動かす拍の並び。各要素は {"piece_paths": Array[Dictionary], "ball_path": Dictionary, "sec": float, "keyframe": int}
## （keyframe は、その拍がどの keyframe から始まるか。動きの無い拍を取り除いた後も、1拍目かどうかを見分けるため）。
## 駒の道筋は {"player_id": String, "is_user": bool, "from": Vector2, "to": Vector2}、ボールの道筋は {"from", "to"}（動かなければ空）
var beats: Array[Dictionary] = []
## いま動かしている拍の添字
var beat_index: int = 0
## いまの拍の中の進み具合（0〜1）。動いていなければ 1
var progress: float = 1.0
## ボールの軌道の値 {"loft", "touch", "touches"}（BallFlight.lift。MatchController.ball_style()）。空なら高さは 0
var ball_style: Dictionary = {}
## 駒の動きの値 {"stagger", "hop"}（PieceMotion。MatchController.piece_style()）。空ならずらしも弾みも無い
var piece_style: Dictionary = {}


## 駒かボールのどれかが動いているか。
func is_active() -> bool:
	return not beats.is_empty()


## どれかの拍で駒が動くか（動かない拍の間も、後の拍で動く駒を拍の始まりの位置に描くため、拍を問わない）。
func has_pieces() -> bool:
	for beat: Dictionary in beats:
		if not (beat["piece_paths"] as Array).is_empty():
			return true
	return false


## 動きを始める（拍を入れ、1拍目の始めに戻す）。駒もボールも動かない拍と、時間が 0 以下の拍は取り除く
## （待ち時間を作らない）。残りが空なら動かない（is_active が偽）。
func start(p_beats: Array[Dictionary]) -> void:
	beats.clear()
	for beat: Dictionary in p_beats:
		var moves: bool = not (beat["piece_paths"] as Array).is_empty() or not (beat["ball_path"] as Dictionary).is_empty()
		if moves and (beat["sec"] as float) > 0.0:
			beats.append(beat.duplicate(true))
	beat_index = 0
	progress = 0.0 if is_active() else 1.0


## index の拍を始める（Tween が拍の変わり目で呼ぶ）。
func begin_beat(index: int) -> void:
	beat_index = index
	progress = 0.0


## 動きを止める（拍を消し、進み具合を終わりにする）。
func clear() -> void:
	beats.clear()
	beat_index = 0
	progress = 1.0


## index の拍の駒の道筋。範囲外なら空。
func piece_paths_of(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if index >= 0 and index < beats.size():
		result.assign(beats[index]["piece_paths"] as Array)
	return result


## index の拍のボールの道筋。範囲外か、その拍でボールが動かなければ空。
func ball_path_of(index: int) -> Dictionary:
	if index >= 0 and index < beats.size():
		return beats[index]["ball_path"] as Dictionary
	return {}


## player_id の駒を描く位置。いまの拍で動いていれば道筋の途中。まだ動いていなければ、後の拍で最初に動く道筋の元
## （その拍の始まりの位置）。どちらでもなければ rest（駒の列の位置。動き終えた駒と動かない駒）。
## 前の拍の行き先を見ないのは、前の拍の行き先は後の拍の元と同じ位置で、後の拍に出てこなければ rest と同じ位置だから。
## いまの拍の駒は、ボールに近い順に少し遅れて動き出し、加速して減速して止まる（PieceMotion。piece_style）。
func piece_position(player_id: String, rest: Vector2) -> Vector2:
	for index: int in range(beat_index, beats.size()):
		for path: Dictionary in beats[index]["piece_paths"] as Array:
			if path["player_id"] == player_id:
				if index != beat_index:
					return path["from"] as Vector2
				return (path["from"] as Vector2).lerp(path["to"] as Vector2, PieceMotion.smooth(_piece_t(path)))
	return rest


## player_id の駒の高さ（駒の半径の何倍か）。いまの拍で動いている駒だけが浮く。ほかは 0（地面）。
func piece_lift(player_id: String) -> float:
	for path: Dictionary in piece_paths_of(beat_index):
		if path["player_id"] == player_id:
			return PieceMotion.hop(_piece_t(path), piece_style.get("hop", 0.0) as float)
	return 0.0


## いまの拍の中での、その駒の進み具合（ずらしの分だけ遅れる）。
func _piece_t(path: Dictionary) -> float:
	return PieceMotion.local_t(progress, path.get("order", 0.0) as float, piece_style.get("stagger", 0.0) as float)


## ボールを描く位置（地面の位置。影もここに描く）。駒と同じ決め方で、rest はいまのエリアの位置。
## いまの拍では、道筋の軌道（"flight"。無ければまっすぐ）の進み方で進む。
func ball_position(rest: Vector2) -> Vector2:
	for index: int in range(beat_index, beats.size()):
		var path: Dictionary = beats[index]["ball_path"] as Dictionary
		if not path.is_empty():
			return _point_on(path, index)
	return rest


## ボールの高さ（ボールの半径の何倍か）。いまの拍でボールが動いていなければ 0（地面）。
func ball_lift() -> float:
	var path: Dictionary = ball_path_of(beat_index)
	if path.is_empty():
		return 0.0
	return BallFlight.lift(_flight_of(path), progress, ball_style)


static func _flight_of(path: Dictionary) -> BallFlight.Kind:
	return path.get("flight", BallFlight.Kind.STRAIGHT) as BallFlight.Kind


## index の拍のボールの道筋の上で、いまの位置。いまの拍なら軌道の進み方の分、後の拍なら元。
## （駒は 2026-11-05 から、ずらしとイージングのある piece_position の進み方で動く。ボールは軌道どおりに動かす）
func _point_on(path: Dictionary, index: int) -> Vector2:
	if index != beat_index:
		return path["from"] as Vector2
	return (path["from"] as Vector2).lerp(path["to"] as Vector2, BallFlight.along(_flight_of(path), progress))


## 拍の始まりの配置の並び（keyframes。TacticsBoard.start_shift）から拍を組み立てる。i 番目の拍は keyframes[i] から
## keyframes[i + 1] へ、最後の拍は end（いまの盤面 {"user", "opponent", "ball"}）へ。各拍の駒の道筋は paths、ボールの道筋は
## 始まりと終わりのエリアが違うときだけ（どちらかが読めなければ空）。keyframe に "flight"（BallFlight.Kind）があれば、
## その拍のボールの軌道にする。center は slot_center、ball_point はエリアのキー → ボールの位置。
static func build_beats(keyframes: Array[Dictionary], end: Dictionary, center: Callable, ball_point: Callable) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	for index: int in range(keyframes.size()):
		var start: Dictionary = keyframes[index]
		var finish: Dictionary = end if index == keyframes.size() - 1 else keyframes[index + 1]
		var piece_paths: Array[Dictionary] = paths(_players_in(start, "user"), _players_in(finish, "user"), true, center)
		piece_paths.append_array(paths(_players_in(start, "opponent"), _players_in(finish, "opponent"), false, center))
		_order_by_distance(piece_paths, start["ball"] as String, ball_point)
		var ball_path: Dictionary = _ball_path(start["ball"] as String, finish["ball"] as String, ball_point)
		if not ball_path.is_empty() and start.has("flight"):
			ball_path["flight"] = start["flight"] as BallFlight.Kind
		beats.append({"piece_paths": piece_paths, "ball_path": ball_path, "sec": start["sec"] as float, "keyframe": index})
	return beats


## 駒の道筋に、ずらしの順 "order"（拍の始まりのボールの位置に近い順。0 = いちばん近い 〜 1 = いちばん遠い）を入れる。
## 同じ距離の駒は同じ順にする（並べ替えは安定でないので、順位で付けると同じ距離の片方だけが遅れるため）。
## 1人だけ・全員が同じ距離・ボールのエリアが読めない拍は、全員 0（遅れずに動く）。
static func _order_by_distance(piece_paths: Array[Dictionary], ball_key: String, ball_point: Callable) -> void:
	for path: Dictionary in piece_paths:
		path["order"] = 0.0
	if piece_paths.size() < 2 or PitchArea.from_key(ball_key) == null:
		return
	var ball: Vector2 = ball_point.call(ball_key) as Vector2
	var distances: Array[float] = []
	for path: Dictionary in piece_paths:
		var distance: float = snappedf((path["from"] as Vector2).distance_to(ball), 0.001)
		if not distances.has(distance):
			distances.append(distance)
	if distances.size() < 2:
		return
	distances.sort()
	for path: Dictionary in piece_paths:
		var distance: float = snappedf((path["from"] as Vector2).distance_to(ball), 0.001)
		path["order"] = float(distances.find(distance)) / (distances.size() - 1)


static func _players_in(keyframe: Dictionary, key: String) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	players.assign(keyframe[key] as Array)
	return players


static func _ball_path(from_key: String, to_key: String, ball_point: Callable) -> Dictionary:
	if PitchArea.from_key(from_key) == null or PitchArea.from_key(to_key) == null or from_key == to_key:
		return {}
	return {"from": ball_point.call(from_key) as Vector2, "to": ball_point.call(to_key) as Vector2}


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

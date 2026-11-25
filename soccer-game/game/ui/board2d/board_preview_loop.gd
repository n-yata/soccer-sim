## 作戦ボードの決定前のプレビュー（screen-common.md §5 の TacticsBoard）。自分の駒を、半透明の駒で配置から次の配置へ動かし、
## 動き終えたら少し止めて最初へ戻すのをくり返す（2026-11-05）。ボードの子ノードで、Tween はノードが作るのでここに置く
## （開示の BoardReveal と同じ考え方）。駒の位置（配置ごとの駒の列の位置）はボードが計算して load_centers で渡す。
class_name BoardPreviewLoop
extends Node

## 描き直しが要る（区間・進み具合が変わった）
signal changed

## いま動かしている区間（0 = 1つ目の配置 → 2つ目の配置）と、その中の進み具合（0〜1）
var segment: int = 0
var progress: float = 0.0

## 半透明の駒を出す選手 → 配置ごとの駒の中心（平面図）。どこかの配置で位置が変わる選手だけ
var _centers: Dictionary = {}
var _frame_count: int = 0
var _move_sec: float = 0.0
var _hold_sec: float = 0.0
var _tween: Tween


## 1区間を動く時間と、動き終えて止める時間 {"move_sec", "hold_sec"}（MatchController.preview_style()）。
## 有限でない値・負の値は 0 として扱う（動く時間が 0 なら動かさない）。
func set_style(style: Dictionary) -> void:
	var move: float = style.get("move_sec", 0.0) as float
	var hold: float = style.get("hold_sec", 0.0) as float
	_move_sec = move if is_finite(move) and move > 0.0 else 0.0
	_hold_sec = hold if is_finite(hold) and hold > 0.0 else 0.0


## いま使う時間 {"move_sec", "hold_sec"}（set_style で 0 にした値は 0）。
func style() -> Dictionary:
	return {"move_sec": _move_sec, "hold_sec": _hold_sec}


## 選手 → 配置ごとの駒の中心 を入れ、くり返しを始める（前のくり返しは止める）。配置が2つ未満なら何も出さない。
func load_centers(centers: Dictionary) -> void:
	clear()
	for player_id: String in centers:
		var points: Array = centers[player_id] as Array
		_frame_count = maxi(_frame_count, points.size())
		for point: Vector2 in points:
			if not point.is_equal_approx(points[0] as Vector2):
				_centers[player_id] = points.duplicate()
				break
	# 配置が1つだけなら、位置の変わる選手はいない
	if _centers.is_empty():
		clear()
		return
	if _move_sec > 0.0 and is_inside_tree():
		_tween = create_tween().set_loops()
		for index: int in range(_frame_count - 1):
			_tween.tween_callback(_begin.bind(index))
			_tween.tween_method(_set_progress, 0.0, 1.0, _move_sec)
		if _hold_sec > 0.0:
			_tween.tween_interval(_hold_sec)
	changed.emit()


## くり返しを止め、半透明の駒を消す。
func clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_centers.clear()
	_frame_count = 0
	segment = 0
	progress = 0.0
	changed.emit()


## 半透明の駒を出す選手（どこかの配置で位置が変わる選手）。
func ghost_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_centers.keys())
	return ids


## player_id の半透明の駒の位置。いまの区間の始まりの配置から次の配置へ、開示と同じイージングで進む。
func ghost_position(player_id: String) -> Vector2:
	var points: Array = _centers.get(player_id, []) as Array
	if points.is_empty():
		return Vector2.ZERO
	var from: int = clampi(segment, 0, points.size() - 1)
	var to: int = mini(from + 1, points.size() - 1)
	return (points[from] as Vector2).lerp(points[to] as Vector2, PieceMotion.smooth(progress))


func is_active() -> bool:
	return not _centers.is_empty()


func _begin(index: int) -> void:
	segment = index
	progress = 0.0
	changed.emit()


func _set_progress(value: float) -> void:
	progress = value
	changed.emit()

## 開示の結果の演出の描画（screen-common.md §5 の TacticsBoard の描き方 ⑤.5）。BoardPainter.paint が、立っているものの後に呼ぶ。
## 値はボードの公開の問い合わせ（result_effect・result_progress・area_rect・goal_rect など）だけから読む（2026-11-03 に BoardPainter から分けた）。
class_name ResultEffectPainter
extends RefCounted


## 進み具合 p で薄くし（α = 1 − p）、輪は広げる。得点はゴールを決めた側の色で塗って口から輪を広げ、セーブ・ボールを奪ったときは
## エリアの中央から輪を広げ、オフサイドはエリアの下寄りに旗を立てる。
static func paint(board: TacticsBoard) -> void:
	var effect: Dictionary = board.result_effect()
	if effect.is_empty():
		return
	var p: float = board.result_progress()
	var color: Color = _color(board, &"you" if (effect["is_user"] as bool) else &"opponent")
	color.a = 1.0 - p
	var reach: float = board.cell_size().x * (0.15 + 0.3 * p)
	match effect["kind"] as ResultEffect.Kind:
		ResultEffect.Kind.GOAL:
			var is_top: bool = effect["is_user"] as bool
			board.draw_colored_polygon(BoardPainter.quad(board, board.goal_rect(is_top)), color)
			_draw_ring(board, board.goal_mouth(is_top), reach, color)
		ResultEffect.Kind.SAVE, ResultEffect.Kind.WIN_BALL:
			_draw_ring(board, board.area_rect(effect["area"] as String).get_center(), reach, color)
		ResultEffect.Kind.OFFSIDE:
			_draw_flag(board, effect["area"] as String, color)


static func _color(board: TacticsBoard, name: StringName) -> Color:
	return board.get_theme_color(name, TacticsBoard.THEME_TYPE)


## 平面図の円を画面へ写した輪（奥ほど潰れて見える）。
static func _draw_ring(board: TacticsBoard, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = []
	for step: int in range(33):
		var angle: float = TAU * step / 32.0
		points.append(board.to_screen(center + Vector2(cos(angle), sin(angle)) * radius))
	board.draw_polyline(points, color, 4.0)


## 旗（ポールと三角）。key のエリアの下寄りに立てる（エリアの上側に描くボールと重ねない）。大きさはエリアに合わせ、奥ほど小さい。
static func _draw_flag(board: TacticsBoard, key: String, color: Color) -> void:
	var rect: Rect2 = board.area_rect(key)
	var cell: Vector2 = board.cell_size()
	var foot: Vector2 = board.to_screen(rect.get_center() + Vector2(0, cell.y * 0.35))
	var scale: float = BoardProjection.scale_at(foot.y, board.size)
	var top: Vector2 = foot + Vector2(0, -cell.y * 0.95 * scale)
	var pole: Color = _color(board, &"text")
	pole.a = color.a
	board.draw_line(foot, top, pole, 4.0)
	var flag := PackedVector2Array([top, top + Vector2(cell.x * 0.4, cell.y * 0.18) * scale, top + Vector2(0, cell.y * 0.36 * scale)])
	board.draw_colored_polygon(flag, color)
	var edge: Color = _color(board, &"bg")
	edge.a = color.a
	flag.append(top)
	board.draw_polyline(flag, edge, 2.0)

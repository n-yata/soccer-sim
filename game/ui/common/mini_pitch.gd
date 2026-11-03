## 30エリアの人数を小さく描く表示専用の部品（screen-common.md §5）。作戦ボードと同じ向きで、
## 横 = レーン（L2〜R2 を左から）、縦 = 列（A2〜D1 を上から）、攻撃方向が上（2026-10-23 に縦向きへ揃えた）。
## 小さい表示なので、作戦ボードの遠近と立体の駒は付けない（真上から見た平面）。
## 1チームの人数（show_counts。陣形カード）と、1ターンの両チームの人数・動きの矢印・ボール（show_turn。振り返りの
## 得失点の流れ。2026-10-29）を描く。2チームでは、各マスに「自分−相手」の人数（例 `1−0`。判定理由の「1対0」と
## 同じく自分が先）を出す。どちらかが1人以上いるマスだけ。矢印はチームの色で、自分は少し左・相手は少し右にずらす。
## 噛み合わせ（show_matchup。S-05）は、2チームの人数に優劣記号（▲・＝・▼）を続ける（色に頼らない。NFR-20）。
class_name MiniPitch
extends Control

## 1チームの陣形カード用の1マス（screen-common.md §5。人数の数字 24px が入る大きさ）。
## 6列にしたとき、陣形カードの大きさ（220×180）を変えないよう、縦を 60 から 30 にした（2026-10-25）
const CELL_SIZE: Vector2 = Vector2(44, 30)
const THEME_TYPE: StringName = &"MiniPitch"
## 優劣記号（screen-common.md §3。自分が多い・同数・少ない）
const ADVANTAGE_MARK: String = "▲"
const EVEN_MARK: String = "＝"
const DISADVANTAGE_MARK: String = "▼"

var _cell_size: Vector2
var _counts: Dictionary = {}
var _opponent_counts: Dictionary = {}
var _two_teams: bool = false
var _shows_marks: bool = false
var _movements: Array[Movement] = []
var _ball_area: String = ""


## cell_size は1マスの大きさ（振り返りでは2チームの人数が入るよう大きくする）。
func _init(cell_size: Vector2 = CELL_SIZE) -> void:
	_cell_size = cell_size
	custom_minimum_size = cell_size * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## エリアのマスの位置と大きさ（この部品の左上が原点）。横 = レーン（左が L2）、縦 = 列（上が A2）。
static func cell_rect(area: PitchArea, cell_size: Vector2) -> Rect2:
	return Rect2(Vector2(area.lane * cell_size.x, (PitchArea.ZONE_COUNT - 1 - area.zone) * cell_size.y), cell_size)


## 1チームの人数（PitchArea のキー → 人数）。2チームは show_turn（2026-10-29 に、使っていなかった two_teams の引数を外した）。
func show_counts(counts: Dictionary) -> void:
	_counts = counts.duplicate()
	_opponent_counts.clear()
	_two_teams = false
	_shows_marks = false
	_movements.clear()
	_ball_area = ""
	queue_redraw()


## 1ターンの両チームの人数（利用者の視点のキー → 人数）・動き（利用者の視点。作戦ボードと同じ理由のものだけ矢印にする）・
## ボールのエリア（空なら描かない）。
func show_turn(user_counts: Dictionary, opponent_counts: Dictionary, movements: Array[Movement], ball_key: String) -> void:
	_counts = user_counts.duplicate()
	_opponent_counts = opponent_counts.duplicate()
	_two_teams = true
	_shows_marks = false
	_movements = movements.duplicate()
	_ball_area = ball_key
	queue_redraw()


## 両チームの基本配置の人数（利用者の視点のキー → 人数）を、優劣記号つきで（S-05 の噛み合わせ）。動きとボールは描かない。
func show_matchup(user_counts: Dictionary, opponent_counts: Dictionary) -> void:
	show_turn(user_counts, opponent_counts, [] as Array[Movement], "")
	_shows_marks = true


## 表示している人数（PitchArea のキー → 人数）の写し。2チームでは利用者の人数。
func counts() -> Dictionary:
	return _counts.duplicate()


func opponent_counts() -> Dictionary:
	return _opponent_counts.duplicate()


func ball_area() -> String:
	return _ball_area


## 矢印を描く動き（TacticsBoard.DRAWN_REASONS の理由で、動いたもの。受け取った順）。
func drawn_movements() -> Array[Movement]:
	var result: Array[Movement] = []
	for movement: Movement in _movements:
		if movement.reason in TacticsBoard.DRAWN_REASONS and not movement.from.equals(movement.to):
			result.append(movement)
	return result


func _draw() -> void:
	var board: Rect2 = Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(board, get_theme_color("pitch", THEME_TYPE))
	_draw_zone_lines(board, get_theme_color("zone_line", THEME_TYPE))
	if not _ball_area.is_empty() and PitchArea.from_key(_ball_area) != null:
		var ball_cell: Rect2 = cell_rect(PitchArea.from_key(_ball_area), _cell_size)
		draw_circle(ball_cell.position + Vector2(ball_cell.size.x / 2.0, 6.0), 4.0, get_theme_color("ball", THEME_TYPE))
	for area: PitchArea in PitchArea.all():
		var text: String = count_text(area.to_key())
		if not text.is_empty():
			_draw_centered(cell_rect(area, _cell_size).get_center(), text)
	for movement: Movement in drawn_movements():
		_draw_arrow(movement)
	# 外枠だけを白線で描く。ハーフウェイライン（M1 と M2 の境）は列の境界の点線で足り、小さい表示を簡素に保つため白線では描かない
	draw_rect(board, get_theme_color("pitch_line", THEME_TYPE), false, 2.0)


## マスに出す文字。1チームは人数（0 なら空）、2チームは「自分−相手」（両方 0 なら空。噛み合わせでは優劣記号を続ける）。
func count_text(key: String) -> String:
	var user_count: int = _counts.get(key, 0) as int
	if not _two_teams:
		return "" if user_count <= 0 else str(user_count)
	var opponent_count: int = _opponent_counts.get(key, 0) as int
	if user_count <= 0 and opponent_count <= 0:
		return ""
	var text: String = "%d%s%d" % [user_count, MatchTexts.MINUS_SIGN, opponent_count]
	if not _shows_marks:
		return text
	if user_count > opponent_count:
		return text + ADVANTAGE_MARK
	return text + (EVEN_MARK if user_count == opponent_count else DISADVANTAGE_MARK)


func _draw_centered(center: Vector2, text: String) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_font_size("font_size", THEME_TYPE)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", THEME_TYPE))


## 移動元のマスの中心から移動先のマスの中心へ、チームの色の矢印。利用者の矢印は少し左、相手は少し右にずらす（重なりを避ける）。
func _draw_arrow(movement: Movement) -> void:
	var is_user: bool = movement.side == GameEnums.TeamSide.HOME
	var offset := Vector2(-3.0 if is_user else 3.0, 0)
	var from_point: Vector2 = cell_rect(movement.from, _cell_size).get_center() + offset
	var to_point: Vector2 = cell_rect(movement.to, _cell_size).get_center() + offset
	var color: Color = get_theme_color("you" if is_user else "opponent", THEME_TYPE)
	draw_line(from_point, to_point, color, 3.0)
	var direction: Vector2 = (to_point - from_point).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([to_point + direction * 4.0, to_point - direction * 6.0 + side * 5.0,
			to_point - direction * 6.0 - side * 5.0]), color)


## 30エリアの境界を点線で描く（screen-common.md §3 の zone_line）。外枠は白線で別に描く。
func _draw_zone_lines(board: Rect2, color: Color) -> void:
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		var x: float = lane_index * _cell_size.x
		draw_dashed_line(Vector2(x, 0), Vector2(x, board.size.y), color, 1.0, 4.0)
	for row_index: int in range(1, PitchArea.ZONE_COUNT):
		var y: float = row_index * _cell_size.y
		draw_dashed_line(Vector2(0, y), Vector2(board.size.x, y), color, 1.0, 4.0)

## 30エリアの人数を小さく描く表示専用の部品（screen-common.md §5）。作戦ボードと同じ向きで、
## 横 = レーン（L2〜R2 を左から）、縦 = 列（A2〜D1 を上から）、攻撃方向が上（2026-10-23 に縦向きへ揃えた）。
## 小さい表示なので、作戦ボードの遠近と立体の駒は付けない（真上から見た平面）。
## 今は1チームの人数だけを描く。2チームの表示（two_teams）と動きの矢印は、使う画面の作業で足す。
class_name MiniPitch
extends Control

## 1チームの陣形カード用の1マス（screen-common.md §5。人数の数字 24px が入る大きさ）。
## 6列にしたとき、陣形カードの大きさ（220×180）を変えないよう、縦を 60 から 30 にした（2026-10-25）
const CELL_SIZE: Vector2 = Vector2(44, 30)
const THEME_TYPE: StringName = &"MiniPitch"

var _counts: Dictionary = {}


func _init() -> void:
	custom_minimum_size = CELL_SIZE * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## エリアのマスの位置と大きさ（この部品の左上が原点）。横 = レーン（左が L2）、縦 = 列（上が A2）。
static func cell_rect(area: PitchArea, cell_size: Vector2) -> Rect2:
	return Rect2(Vector2(area.lane * cell_size.x, (PitchArea.ZONE_COUNT - 1 - area.zone) * cell_size.y), cell_size)


## PitchArea のキー → 人数。two_teams は今は使わない（1チーム分を描く）。
func show_counts(counts: Dictionary, _two_teams: bool) -> void:
	_counts = counts.duplicate()
	queue_redraw()


## 表示している人数（PitchArea のキー → 人数）の写し。
func counts() -> Dictionary:
	return _counts.duplicate()


func _draw() -> void:
	var board: Rect2 = Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(board, get_theme_color("pitch", THEME_TYPE))
	var zone_line: Color = get_theme_color("zone_line", THEME_TYPE)
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_font_size("font_size", THEME_TYPE)
	var font_color: Color = get_theme_color("font_color", THEME_TYPE)
	_draw_zone_lines(board, zone_line)
	for area: PitchArea in PitchArea.all():
		var cell: Rect2 = cell_rect(area, CELL_SIZE)
		var count: int = _counts.get(area.to_key(), 0) as int
		if count > 0:
			var text: String = str(count)
			var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline: Vector2 = cell.get_center() + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) / 2.0 - 2.0)
			draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
	# 外枠だけを白線で描く。ハーフウェイライン（M1 と M2 の境）は列の境界の点線で足り、小さい表示を簡素に保つため白線では描かない
	draw_rect(board, get_theme_color("pitch_line", THEME_TYPE), false, 2.0)


## 30エリアの境界を点線で描く（screen-common.md §3 の zone_line）。外枠は白線で別に描く。
func _draw_zone_lines(board: Rect2, color: Color) -> void:
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		var x: float = lane_index * CELL_SIZE.x
		draw_dashed_line(Vector2(x, 0), Vector2(x, board.size.y), color, 1.0, 4.0)
	for row_index: int in range(1, PitchArea.ZONE_COUNT):
		var y: float = row_index * CELL_SIZE.y
		draw_dashed_line(Vector2(0, y), Vector2(board.size.x, y), color, 1.0, 4.0)

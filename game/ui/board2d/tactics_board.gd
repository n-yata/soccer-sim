## 作戦ボード（screen-common.md §5 の TacticsBoard）。15エリアの盤面を描き、エリアを押す操作を受ける。
## ピッチを横に置き、利用者の攻撃方向は常に右（列は左から D・M・A、行は上から L2〜R2）。受け取るエリアは
## すべて利用者の視点のキー（BoardSnapshot・RevealView の値）で、ボードはエリアを変換しない。
## 描画と入力とテストは、同じ計算（area_rect・area_at・pieces_in など）を使う。色はテーマの型 TacticsBoard。
## ファイルの目安（300行）を超えているが、描画を別のクラスへ切り出さない。描画は重ね表示の値（選べるエリア・
## ヒント・矢印・比較）とエリアの位置の計算をすべて読むため、切り出すとそれらを外へ公開することになり、
## 「表示している値と描いている値が同じ」ことをこのクラスの中で保てなくなる。3D 演出の作業で描画が増えたら見直す。
class_name TacticsBoard
extends Control

## 選べるエリアを押して、同じエリアの中で離した
signal area_pressed(area_key: String)

const THEME_TYPE: StringName = &"TacticsBoard"
## 1エリアの最小の大きさ（screen-common.md §1.1。上端の帯 32px ＋ 駒 40px × 2段、幅 96dp）
const MIN_CELL: Vector2 = Vector2(192, 112)
const BAND_HEIGHT: float = 32.0
const PIECE_DIAMETER: float = 40.0
## 1チームで描く駒の上限。これを超えると、駒を (上限 - 1) つと「+N」の札にする
const MAX_PIECES: int = 4

var _user_players: Array[Dictionary] = []
var _opponent_players: Array[Dictionary] = []
var _user_counts: Dictionary = {}
var _opponent_counts: Dictionary = {}
var _ball_area: String = ""
var _selectable: Array[String] = []
var _selected: String = ""
var _hints: Dictionary = {}
var _intent_from: String = ""
var _intent_to: String = ""
var _movements: Array[Movement] = []
var _compare_area: String = ""
var _compare_tag: String = ""
var _pressed_key: String = ""


func _init() -> void:
	custom_minimum_size = MIN_CELL * Vector2(PitchArea.ZONE_COUNT, PitchArea.LANE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


# --- 外から渡す値 ---

func show_snapshot(snapshot: BoardSnapshot) -> void:
	_user_players = snapshot.user_players.duplicate()
	_opponent_players = snapshot.opponent_players.duplicate()
	_user_counts = snapshot.user_counts.duplicate()
	_opponent_counts = snapshot.opponent_counts.duplicate()
	_ball_area = snapshot.ball_area
	queue_redraw()


## 押せるエリア（点線の枠）。これ以外のエリアは押しても反応しない。
func set_selectable(keys: Array[String]) -> void:
	_selectable = keys.duplicate()
	queue_redraw()


## 選んだエリア（塗り）。空文字で外す。
func set_selected(key: String) -> void:
	_selected = key
	queue_redraw()


## エリアのキー → ヒントの札の文（`+1`・`±0 GK外`）。
func set_hints(hints: Dictionary) -> void:
	_hints = hints.duplicate()
	queue_redraw()


## ボールから運ぶ先への矢印（選んだ手の意図）。
func show_intent(from_key: String, to_key: String) -> void:
	_intent_from = from_key
	_intent_to = to_key
	queue_redraw()


## 動いた選手の矢印（利用者の視点の Movement）。
func show_movements(movements: Array[Movement]) -> void:
	_movements = movements.duplicate()
	queue_redraw()


## 比較エリアの光と人数の札（`自分対相手`）。
func show_compare(key: String, user_count: int, opponent_count: int) -> void:
	_compare_area = key
	_compare_tag = "%d対%d" % [user_count, opponent_count]
	queue_redraw()


## 盤面（駒・記号・ボール）以外の重ね表示をすべて消す。
func clear_overlays() -> void:
	_selectable.clear()
	_selected = ""
	_hints.clear()
	_intent_from = ""
	_intent_to = ""
	_movements.clear()
	_compare_area = ""
	_compare_tag = ""
	_pressed_key = ""
	queue_redraw()


# --- 位置の計算 ---

func cell_size() -> Vector2:
	return size / Vector2(PitchArea.ZONE_COUNT, PitchArea.LANE_COUNT)


func area_rect(key: String) -> Rect2:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return Rect2()
	var cell: Vector2 = cell_size()
	return Rect2(Vector2(area.zone * cell.x, area.lane * cell.y), cell)


## 位置のエリアのキー。盤面の外なら空文字。
func area_at(point: Vector2) -> String:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return ""
	var cell: Vector2 = cell_size()
	var zone: int = clampi(floori(point.x / cell.x), 0, PitchArea.ZONE_COUNT - 1)
	var lane: int = clampi(floori(point.y / cell.y), 0, PitchArea.LANE_COUNT - 1)
	return PitchArea.new(lane as GameEnums.Lane, zone as GameEnums.Zone).to_key()


# --- 表示している値（テストと描画で使う） ---

## エリアの背番号（小さい順）。{"user": [...], "opponent": [...]}
func pieces_in(key: String) -> Dictionary:
	return {"user": _numbers_in(_user_players, key), "opponent": _numbers_in(_opponent_players, key)}


## 描く駒の数（上限を超えたら上限 - 1 つと「+N」）。
func visible_piece_count(key: String, is_user: bool) -> int:
	var count: int = (pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	return count if count <= MAX_PIECES else MAX_PIECES - 1


## 「+N」の札。上限以内なら空。
func overflow_tag(key: String, is_user: bool) -> String:
	var count: int = (pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	return "" if count <= MAX_PIECES else "+%d" % (count - visible_piece_count(key, is_user))


## 角の優劣記号（利用者から見て、優位 ▲・同数 ＝・不利 ▼）。人数 0 同士も同数。
func mark_of(key: String) -> String:
	var user_count: int = _user_counts.get(key, 0) as int
	var opponent_count: int = _opponent_counts.get(key, 0) as int
	if user_count > opponent_count:
		return "▲"
	if user_count < opponent_count:
		return "▼"
	return "＝"


func ball_area() -> String:
	return _ball_area


func selectable_areas() -> Array[String]:
	return _selectable.duplicate()


func selected_area() -> String:
	return _selected


func hint_of(key: String) -> String:
	return _hints.get(key, "") as String


func has_intent() -> bool:
	return not _intent_to.is_empty()


func movement_count() -> int:
	return _movements.size()


func compare_tag() -> String:
	return _compare_tag


# --- 入力 ---

## 押した位置のエリアを覚え、同じエリアの中で離したときだけ選んだとみなす（screen-common.md §4.1）。
func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_pressed_key = area_at(button.position)
		return
	var released_key: String = area_at(button.position)
	var pressed_key: String = _pressed_key
	_pressed_key = ""
	if released_key.is_empty() or released_key != pressed_key or not _selectable.has(released_key):
		return
	accept_event()
	area_pressed.emit(released_key)


# --- 描画 ---

func _draw() -> void:
	_draw_pitch()
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		_draw_area_fill(key)
	_draw_zone_lines()
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		_draw_pieces(key, true)
		_draw_pieces(key, false)
		_draw_band(key)
	_draw_lane_names()
	_draw_ball()
	_draw_movements()
	_draw_intent()
	_draw_compare()


func _color(name: StringName) -> Color:
	return get_theme_color(name, THEME_TYPE)


func _font_size(name: StringName) -> int:
	return get_theme_font_size(name, THEME_TYPE)


func _draw_pitch() -> void:
	var board := Rect2(Vector2.ZERO, size)
	draw_rect(board, _color(&"pitch"))
	var cell: Vector2 = cell_size()
	# 芝目（縦の帯）とハーフスペースのレーン
	var stripes: int = PitchArea.ZONE_COUNT * 2
	for index: int in range(stripes):
		if index % 2 == 1:
			draw_rect(Rect2(Vector2(size.x * index / stripes, 0), Vector2(size.x / stripes, size.y)), _color(&"pitch_stripe"))
	for lane: int in [GameEnums.Lane.L1, GameEnums.Lane.R1]:
		var tint: Color = _color(&"pitch_halfspace")
		draw_rect(Rect2(Vector2(0, lane * cell.y), Vector2(size.x, cell.y)), tint)
	# 白線: 外枠・ハーフウェイライン・センターサークル・ペナルティエリア・ゴール
	var line: Color = _color(&"pitch_line")
	draw_rect(board, line, false, 3.0)
	draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), line, 2.0)
	draw_arc(size / 2.0, size.y * 0.13, 0.0, TAU, 48, line, 2.0)
	var box := Vector2(size.x * 0.13, size.y * 0.56)
	draw_rect(Rect2(Vector2(0, (size.y - box.y) / 2.0), box), line, false, 2.0)
	draw_rect(Rect2(Vector2(size.x - box.x, (size.y - box.y) / 2.0), box), line, false, 2.0)
	var goal := Vector2(8, size.y * 0.16)
	draw_rect(Rect2(Vector2(0, (size.y - goal.y) / 2.0), goal), line)
	draw_rect(Rect2(Vector2(size.x - goal.x, (size.y - goal.y) / 2.0), goal), line)


func _draw_zone_lines() -> void:
	var color: Color = _color(&"zone_line")
	var cell: Vector2 = cell_size()
	for zone_index: int in range(1, PitchArea.ZONE_COUNT):
		draw_dashed_line(Vector2(zone_index * cell.x, 0), Vector2(zone_index * cell.x, size.y), color, 1.0, 6.0)
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		draw_dashed_line(Vector2(0, lane_index * cell.y), Vector2(size.x, lane_index * cell.y), color, 1.0, 6.0)


## 選んだエリアの塗り・選べるエリアの点線の枠。
func _draw_area_fill(key: String) -> void:
	var rect: Rect2 = area_rect(key).grow(-3.0)
	if key == _selected:
		draw_rect(rect, _color(&"selected_fill"))
	if _selectable.has(key):
		var accent: Color = _color(&"accent")
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
		for index: int in range(4):
			draw_dashed_line(corners[index], corners[(index + 1) % 4], accent, 3.0, 10.0)


## 自分の駒をエリアの左半分、相手の駒を右半分に、上端の帯の下へ2列×2段で並べる。
func _draw_pieces(key: String, is_user: bool) -> void:
	var numbers: Array = pieces_in(key)["user" if is_user else "opponent"] as Array
	if numbers.is_empty():
		return
	var rect: Rect2 = area_rect(key)
	var half := Vector2(rect.size.x / 2.0, rect.size.y - BAND_HEIGHT)
	var origin := Vector2(rect.position.x + (0.0 if is_user else half.x), rect.position.y + BAND_HEIGHT)
	var step := Vector2(half.x / 2.0, half.y / 2.0)
	var radius: float = minf(PIECE_DIAMETER / 2.0, minf(step.x, step.y) / 2.0 - 1.0)
	var color: Color = _color(&"you" if is_user else &"opponent")
	var text_color: Color = _color(&"bg")
	var font: Font = get_theme_default_font()
	var font_size: int = _font_size(&"number_size")
	var shown: int = visible_piece_count(key, is_user)
	for index: int in range(shown + (1 if shown < numbers.size() else 0)):
		var center: Vector2 = origin + Vector2((index % 2 + 0.5) * step.x, (floorf(index / 2.0) + 0.5) * step.y)
		if index >= shown:
			_draw_centered_text(font, center, overflow_tag(key, is_user), font_size, _color(&"text"))
			continue
		if is_user:
			draw_circle(center, radius, color)
		else:
			var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
					center + Vector2(0, radius), center + Vector2(-radius, 0)])
			draw_colored_polygon(points, color)
		_draw_centered_text(font, center, str(numbers[index]), font_size, text_color)


## 上端の帯: 左上に優劣記号、右上にヒントの札。
func _draw_band(key: String) -> void:
	var rect: Rect2 = area_rect(key)
	var font: Font = get_theme_default_font()
	var mark: String = mark_of(key)
	var mark_size: int = _font_size(&"mark_size")
	var mark_box := Rect2(rect.position + Vector2(4, 2), Vector2(32, BAND_HEIGHT - 4))
	draw_rect(mark_box, _color(&"mark_bg"))
	var mark_color: Color = _color(&"accent") if mark == "▲" else (_color(&"opponent") if mark == "▼" else _color(&"text"))
	_draw_centered_text(font, mark_box.get_center(), mark, mark_size, mark_color)
	var hint: String = hint_of(key)
	if hint.is_empty():
		return
	var tag_size: int = _font_size(&"tag_size")
	var width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 16.0
	var tag_box := Rect2(Vector2(rect.end.x - width - 4.0, rect.position.y + 2.0), Vector2(width, BAND_HEIGHT - 4))
	draw_rect(tag_box, _color(&"accent"))
	_draw_centered_text(font, tag_box.get_center(), hint, tag_size, _color(&"bg"))


## レーン名を各レーンの左端に（自陣の列の帯の中、記号の右）。
func _draw_lane_names() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = _font_size(&"lane_size")
	var color: Color = _color(&"lane_text")
	for lane: int in GameEnums.Lane.values():
		var rect: Rect2 = area_rect(PitchArea.new(lane as GameEnums.Lane, GameEnums.Zone.D).to_key())
		var baseline := Vector2(rect.position.x + 44.0, rect.position.y + BAND_HEIGHT / 2.0 + font.get_ascent(font_size) / 2.0 - 2.0)
		draw_string(font, baseline, MatchTexts.lane_name(lane as GameEnums.Lane), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_ball() -> void:
	if _ball_area.is_empty():
		return
	var rect: Rect2 = area_rect(_ball_area)
	var center := Vector2(rect.get_center().x, rect.position.y + BAND_HEIGHT / 2.0)
	draw_circle(center, 10.0, _color(&"ball"))
	draw_arc(center, 10.0, 0.0, TAU, 24, _color(&"bg"), 2.0)


func _draw_compare() -> void:
	if _compare_area.is_empty():
		return
	var rect: Rect2 = area_rect(_compare_area).grow(-2.0)
	draw_rect(rect, _color(&"accent"), false, 5.0)
	var font: Font = get_theme_default_font()
	var tag_size: int = _font_size(&"tag_size")
	var width: float = font.get_string_size(_compare_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 20.0
	var tag_box := Rect2(Vector2(rect.get_center().x - width / 2.0, rect.end.y - 36.0), Vector2(width, 32))
	draw_rect(tag_box, _color(&"accent"))
	_draw_centered_text(font, tag_box.get_center(), _compare_tag, tag_size, _color(&"bg"))


## 動きの矢印。ドリブル（ボール）は accent の太線、プレス・カバーはチームの色の実線、方式の動きは白の点線。
## 同じエリアの間を両チームが動くと重なるので、チームごとに少しずらす。凡例を左下の隅に重ねる。
func _draw_movements() -> void:
	if _movements.is_empty():
		return
	for movement: Movement in _movements:
		var offset := Vector2(0, -8.0 if movement.side == GameEnums.TeamSide.HOME else 8.0)
		var from_point: Vector2 = area_rect(movement.from.to_key()).get_center() + offset
		var to_point: Vector2 = area_rect(movement.to.to_key()).get_center() + offset
		if from_point.distance_to(to_point) < 1.0:
			continue
		match movement.reason:
			GameEnums.MovementReason.DRIBBLE:
				_draw_arrow(from_point, to_point, _color(&"accent"), 6.0, false)
			GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER:
				var team: Color = _color(&"you" if movement.side == GameEnums.TeamSide.HOME else &"opponent")
				_draw_arrow(from_point, to_point, team, 3.0, false)
			_:
				_draw_arrow(from_point, to_point, _color(&"text"), 2.0, true)
	_draw_legend()


func _draw_intent() -> void:
	if _intent_to.is_empty() or _intent_from.is_empty():
		return
	var from_point: Vector2 = area_rect(_intent_from).get_center()
	var to_point: Vector2 = area_rect(_intent_to).get_center()
	if from_point.distance_to(to_point) < 1.0:
		return
	_draw_arrow(from_point, to_point, _color(&"accent"), 6.0, false)


func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = _font_size(&"legend_size")
	var items: Array = [["ボール", _color(&"accent"), false], ["寄せ・カバー", _color(&"you"), false],
			["方式の動き", _color(&"text"), true]]
	var press_row: int = 1
	var box := Rect2(Vector2(8, size.y - 8 - items.size() * 28 - 8), Vector2(200, items.size() * 28 + 8))
	draw_rect(box, _color(&"mark_bg"))
	for index: int in range(items.size()):
		var y: float = box.position.y + 18.0 + index * 28.0
		var color: Color = items[index][1] as Color
		if items[index][2] as bool:
			draw_dashed_line(Vector2(box.position.x + 10, y), Vector2(box.position.x + 50, y), color, 2.0, 6.0)
		elif index == press_row:
			# 寄せ・カバーは動いたチームの色で描くので、見本も両チームの色を並べる
			draw_line(Vector2(box.position.x + 10, y), Vector2(box.position.x + 28, y), _color(&"you"), 4.0)
			draw_line(Vector2(box.position.x + 32, y), Vector2(box.position.x + 50, y), _color(&"opponent"), 4.0)
		else:
			draw_line(Vector2(box.position.x + 10, y), Vector2(box.position.x + 50, y), color, 4.0)
		draw_string(font, Vector2(box.position.x + 60, y + font.get_ascent(font_size) / 2.0 - 2.0), items[index][0] as String,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _color(&"text"))


func _draw_arrow(from_point: Vector2, to_point: Vector2, color: Color, width: float, dashed: bool) -> void:
	var direction: Vector2 = (to_point - from_point).normalized()
	var head_length: float = 14.0 + width
	var shaft_end: Vector2 = to_point - direction * head_length * 0.8
	if dashed:
		draw_dashed_line(from_point, shaft_end, color, width, 8.0)
	else:
		draw_line(from_point, shaft_end, color, width)
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	draw_colored_polygon(PackedVector2Array([to_point, to_point - direction * head_length + side,
			to_point - direction * head_length - side]), color)


func _draw_centered_text(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(center.x - text_size.x / 2.0, center.y + font.get_ascent(font_size) / 2.0 - 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _numbers_in(players: Array[Dictionary], key: String) -> Array[int]:
	var numbers: Array[int] = []
	for player: Dictionary in players:
		if player["area"] == key:
			numbers.append(player["number"] as int)
	numbers.sort()
	return numbers

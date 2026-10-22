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
## 1エリアの最小の大きさ（screen-common.md §1.1。押せる範囲 48dp 以上）
const MIN_CELL: Vector2 = Vector2(192, 112)
## 駒の直径と中心の間隔の上限。セルの幅が狭いときは、1チーム MAX_PIECES 個がエリアの半分に収まるよう縮める
const PIECE_DIAMETER: float = 26.0
const PIECE_STEP: float = 28.0
## エリアの中央から最初の駒までの余白（自分と相手の駒の列を分ける）と、エリアの端に残す余白
const PIECE_CENTER_GAP: float = 6.0
const PIECE_EDGE_MARGIN: float = 2.0
## 1チームで描く駒の上限。これを超えると、駒を (上限 - 1) つと「+N」の札にする
const MAX_PIECES: int = 4
## 盤面に描く動き（ドリブル・寄せ・カバー）。方式の動きと、保持者の動き（戻る・置かれる）は描かない
const DRAWN_REASONS: Array[GameEnums.MovementReason] = [
	GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER, GameEnums.MovementReason.DRIBBLE,
]
const HINT_HEIGHT: float = 26.0

var _user_players: Array[Dictionary] = []
var _opponent_players: Array[Dictionary] = []
var _ball_area: String = ""
var _selectable: Array[String] = []
var _selected: String = ""
var _hints: Dictionary = {}
var _even_hints: Array[String] = []
var _intent_from: String = ""
var _intent_to: String = ""
var _movements: Array[Movement] = []
var _preview: Array[Movement] = []
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


## エリアのキー → ヒントの札の文（`+1`・`±0 GK外`）。even_keys は人数差が ±0 の札のキーで、控えめな色で描く。
## 札は選べるエリアにだけ描く。
func set_hints(hints: Dictionary, even_keys: Array[String] = []) -> void:
	_hints = hints.duplicate()
	_even_hints = even_keys.duplicate()
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


## 決定前のプレビュー: 選んだ手で動く自分の選手（利用者の視点の Movement）。移動先の輪と点線の矢印を描く。
## 開示後の矢印（show_movements）と違い、理由で絞らない（その手で起きる自分の動きをすべて見せる）。
func show_preview(movements: Array[Movement]) -> void:
	_preview = movements.duplicate()
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
	_even_hints.clear()
	_intent_from = ""
	_intent_to = ""
	_movements.clear()
	_preview.clear()
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


func ball_area() -> String:
	return _ball_area


func selectable_areas() -> Array[String]:
	return _selectable.duplicate()


func selected_area() -> String:
	return _selected


func hint_of(key: String) -> String:
	return _hints.get(key, "") as String


func is_hint_even(key: String) -> bool:
	return _even_hints.has(key)


## 駒の中心の間隔（描画とテストで共有）。中央の余白から MAX_PIECES 個ぶんがエリアの半分に収まるよう、PIECE_STEP を上限に縮める。
func piece_step() -> float:
	var half_width: float = cell_size().x / 2.0
	return minf(PIECE_STEP, (half_width - PIECE_EDGE_MARGIN - PIECE_CENTER_GAP) / MAX_PIECES)


## 駒の半径。隣の駒と重ならないよう、間隔に合わせて縮める。
func piece_radius() -> float:
	return minf(PIECE_DIAMETER / 2.0, piece_step() / 2.0 - 1.0)


## index 番目の駒（上限を超えたときの「+N」の札の位置を含む）の中心。自分は中央から左へ、相手は中央から右へ並べる。
func piece_center(key: String, is_user: bool, index: int) -> Vector2:
	var rect: Rect2 = area_rect(key)
	var direction: float = -1.0 if is_user else 1.0
	var offset: float = PIECE_CENTER_GAP + piece_step() * (index + 0.5)
	return Vector2(rect.get_center().x + direction * offset, rect.get_center().y)


## 札を描くエリア（札があり、選べるエリア）。選べるエリアの順。
func drawn_hint_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in _selectable:
		if not hint_of(key).is_empty():
			keys.append(key)
	return keys


## 矢印を描く動き（DRAWN_REASONS の理由のものだけ。受け取った順）。
func drawn_movements() -> Array[Movement]:
	var result: Array[Movement] = []
	for movement: Movement in _movements:
		if movement.reason in DRAWN_REASONS:
			result.append(movement)
	return result


func preview_movements() -> Array[Movement]:
	return _preview.duplicate()


## index 番目のプレビューの移動先の輪の中心。移動先のエリアの自分の駒の列の続き（そのエリアの自分の駒の数 ＋
## 同じエリアへの先の輪の数）に置く。1エリアに5人以上が集まるのはまれなので、最後の位置（MAX_PIECES - 1）で止める。
func preview_center(index: int) -> Vector2:
	var key: String = _preview[index].to.to_key()
	var slot: int = (pieces_in(key)["user"] as Array).size()
	for earlier: int in range(index):
		if _preview[earlier].to.to_key() == key:
			slot += 1
	return piece_center(key, true, mini(slot, MAX_PIECES - 1))


## index 番目のプレビューの矢印の始点。動く選手の駒（移動元のエリアの自分の駒の列で、盤面の選手の順の位置）の中心。
## 駒は番号を描かないが、矢印がどの ● から出るかが分かるよう、駒の上から引く。見つからなければエリアの中央。
func preview_origin(index: int) -> Vector2:
	var key: String = _preview[index].from.to_key()
	var slot: int = 0
	for player: Dictionary in _user_players:
		if player["area"] != key:
			continue
		if player["player_id"] == _preview[index].player_id:
			return piece_center(key, true, mini(slot, MAX_PIECES - 1))
		slot += 1
	return area_rect(key).get_center()


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
	_draw_lane_names()
	for area: PitchArea in PitchArea.all():
		var key: String = area.to_key()
		_draw_pieces(key, true)
		_draw_pieces(key, false)
	_draw_ball()
	_draw_movements()
	_draw_preview()
	_draw_intent()
	# 札は矢印の上に描く（選んだ手の矢印が、通り道のエリアの札の字を隠さないように）
	for key: String in drawn_hint_keys():
		_draw_hint(key)
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


## ボールのあるエリアの薄い塗り・選んだエリアの塗り・選べるエリアの点線の枠。
func _draw_area_fill(key: String) -> void:
	var rect: Rect2 = area_rect(key).grow(-3.0)
	if key == _ball_area:
		draw_rect(rect, _color(&"ball_area_fill"))
	if key == _selected:
		draw_rect(rect, _color(&"selected_fill"))
	if _selectable.has(key):
		var accent: Color = _color(&"accent")
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
		for index: int in range(4):
			draw_dashed_line(corners[index], corners[(index + 1) % 4], accent, 3.0, 10.0)


## 駒は番号を付けず、エリアの縦の中央に1列で並べる。自分の ● は中央から左へ、相手の ◆ は中央から右へ。
## 上限を超えたら、駒を (上限 - 1) つと「+N」の札にする。
func _draw_pieces(key: String, is_user: bool) -> void:
	var count: int = (pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	if count == 0:
		return
	var radius: float = piece_radius()
	var color: Color = _color(&"you" if is_user else &"opponent")
	var shown: int = visible_piece_count(key, is_user)
	for index: int in range(shown + (1 if shown < count else 0)):
		var center: Vector2 = piece_center(key, is_user, index)
		if index >= shown:
			_draw_centered_text(get_theme_default_font(), center, overflow_tag(key, is_user), _font_size(&"tag_size"), _color(&"text"))
			continue
		if is_user:
			draw_circle(center, radius, color)
		else:
			var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
					center + Vector2(0, radius), center + Vector2(-radius, 0)])
			draw_colored_polygon(points, color)


## ヒントの札をエリアの下端の中央に。差がある札は accent、±0 の札は控えめな色。
func _draw_hint(key: String) -> void:
	var rect: Rect2 = area_rect(key)
	var font: Font = get_theme_default_font()
	var hint: String = hint_of(key)
	var tag_size: int = _font_size(&"hint_size")
	var width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 14.0
	var tag_box := Rect2(Vector2(rect.get_center().x - width / 2.0, rect.end.y - HINT_HEIGHT - 8.0), Vector2(width, HINT_HEIGHT))
	var is_even: bool = is_hint_even(key)
	draw_rect(tag_box, _color(&"tag_muted_bg") if is_even else _color(&"accent"))
	_draw_centered_text(font, tag_box.get_center(), hint, tag_size, _color(&"text") if is_even else _color(&"bg"))


## レーン名を各レーンの自陣のエリアの左上に、小さく薄く。
func _draw_lane_names() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = _font_size(&"lane_size")
	var color: Color = _color(&"lane_text")
	for lane: int in GameEnums.Lane.values():
		var rect: Rect2 = area_rect(PitchArea.new(lane as GameEnums.Lane, GameEnums.Zone.D).to_key())
		var baseline := Vector2(rect.position.x + 8.0, rect.position.y + 6.0 + font.get_ascent(font_size))
		draw_string(font, baseline, MatchTexts.lane_name(lane as GameEnums.Lane), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## ボールはエリアの上側の中央（駒の列と札に重ならない位置）。
func _draw_ball() -> void:
	if _ball_area.is_empty():
		return
	var rect: Rect2 = area_rect(_ball_area)
	var center := Vector2(rect.get_center().x, rect.position.y + 22.0)
	draw_circle(center, 11.0, _color(&"ball"))
	draw_arc(center, 11.0, 0.0, TAU, 24, _color(&"bg"), 2.0)


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


## 動きの矢印。ドリブル（ボール）は accent の太線、プレス・カバーはチームの色の実線。それ以外の動きは描かない。
## 同じエリアの間を両チームが動くと重なるので、チームごとに少しずらす。
func _draw_movements() -> void:
	for movement: Movement in drawn_movements():
		var offset := Vector2(0, -8.0 if movement.side == GameEnums.TeamSide.HOME else 8.0)
		var from_point: Vector2 = area_rect(movement.from.to_key()).get_center() + offset
		var to_point: Vector2 = area_rect(movement.to.to_key()).get_center() + offset
		if from_point.distance_to(to_point) < 1.0:
			continue
		if movement.reason == GameEnums.MovementReason.DRIBBLE:
			_draw_arrow(from_point, to_point, _color(&"accent"), 6.0)
		else:
			var team: Color = _color(&"you" if movement.side == GameEnums.TeamSide.HOME else &"opponent")
			_draw_arrow(from_point, to_point, team, 4.0)


## 決定前のプレビュー。移動先に自分の色の輪（中抜き）、動く選手の駒から輪へ点線の矢印。
## 開示後の動き（実線の矢印）・いまの駒（塗りの ●）と、線の種類と塗りで区別する（グレースケールでも形で分かる）。
## 矢印は緩く曲げる（同じ列を横に動くとき、途中のエリアの駒の上を通らないように）。
func _draw_preview() -> void:
	var color: Color = _color(&"you")
	var radius: float = piece_radius()
	for index: int in range(_preview.size()):
		var center: Vector2 = preview_center(index)
		var origin: Vector2 = preview_origin(index)
		if origin.distance_to(center) > radius * 2.0:
			_draw_curved_dashed_arrow(origin, center, radius, color, 3.0)
		draw_arc(center, radius - 1.5, 0.0, TAU, 24, color, 3.0)


func _draw_intent() -> void:
	if _intent_to.is_empty() or _intent_from.is_empty():
		return
	var from_point: Vector2 = area_rect(_intent_from).get_center()
	var to_point: Vector2 = area_rect(_intent_to).get_center()
	if from_point.distance_to(to_point) < 1.0:
		return
	_draw_arrow(from_point, to_point, _color(&"accent"), 6.0)


func _draw_arrow(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to_point - from_point).normalized()
	var head_length: float = 14.0 + width
	var shaft_end: Vector2 = to_point - direction * head_length * 0.8
	draw_line(from_point, shaft_end, color, width)
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	draw_colored_polygon(PackedVector2Array([to_point, to_point - direction * head_length + side,
			to_point - direction * head_length - side]), color)


## 駒の縁から駒の縁へ、2次ベジェ曲線の点線と矢じり。曲がりの大きさは距離の 2 割（上限はセルの高さの 3 割）。
func _draw_curved_dashed_arrow(from_center: Vector2, to_center: Vector2, radius: float, color: Color, width: float) -> void:
	var bulge: float = minf(from_center.distance_to(to_center) * 0.2, cell_size().y * 0.3)
	var control: Vector2 = (from_center + to_center) / 2.0 + (to_center - from_center).normalized().orthogonal() * bulge
	var start: Vector2 = from_center + (control - from_center).normalized() * radius
	var tip: Vector2 = to_center + (control - to_center).normalized() * radius
	var head_length: float = 12.0 + width
	var segments: int = 24
	var points: Array[Vector2] = []
	for step: int in range(segments + 1):
		var t: float = float(step) / segments
		points.append(start.lerp(control, t).lerp(control.lerp(tip, t), t))
	# 矢じりの分を残して、1区間おきに描く（点線）
	for step: int in range(0, segments, 2):
		if points[step + 1].distance_to(tip) < head_length * 0.8:
			break
		draw_line(points[step], points[step + 1], color, width)
	var direction: Vector2 = (tip - points[segments - 2]).normalized()
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	draw_colored_polygon(PackedVector2Array([tip, tip - direction * head_length + side,
			tip - direction * head_length - side]), color)


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

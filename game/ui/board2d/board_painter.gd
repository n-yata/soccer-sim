## 作戦ボードの描画（screen-common.md §5 の TacticsBoard の描き方）。ボードの _draw から呼ぶ。
## 値はボードの公開の問い合わせ（pieces_in・drawn_movements・preview_center など）だけから読む。テストも同じ問い合わせを
## 通るので、「表示している値と描いている値が同じ」ことが保たれる。色・字の大きさはテーマの型 TacticsBoard。
class_name BoardPainter
extends RefCounted


static func paint(board: TacticsBoard) -> void:
	_draw_pitch(board)
	for area: PitchArea in PitchArea.all():
		_draw_area_fill(board, area.to_key())
	_draw_zone_lines(board)
	_draw_lane_names(board)
	if board.is_shifting_pieces():
		_draw_shifting_pieces(board)
	else:
		for area: PitchArea in PitchArea.all():
			_draw_pieces(board, area.to_key(), true)
			_draw_pieces(board, area.to_key(), false)
	_draw_ball(board)
	_draw_movements(board)
	_draw_preview(board)
	_draw_intent(board)
	# 札は矢印の上に描く（選んだ手の矢印が、通り道のエリアの札の字を隠さないように）
	for key: String in board.drawn_hint_keys():
		_draw_hint(board, key)
	_draw_compare(board)


static func _color(board: TacticsBoard, name: StringName) -> Color:
	return board.get_theme_color(name, TacticsBoard.THEME_TYPE)


static func _font_size(board: TacticsBoard, name: StringName) -> int:
	return board.get_theme_font_size(name, TacticsBoard.THEME_TYPE)


static func _draw_pitch(board: TacticsBoard) -> void:
	var size: Vector2 = board.size
	var whole := Rect2(Vector2.ZERO, size)
	board.draw_rect(whole, _color(board, &"pitch"))
	var cell: Vector2 = board.cell_size()
	# 芝目（縦の帯）とハーフスペースのレーン
	var stripes: int = PitchArea.ZONE_COUNT * 2
	for index: int in range(stripes):
		if index % 2 == 1:
			board.draw_rect(Rect2(Vector2(size.x * index / stripes, 0), Vector2(size.x / stripes, size.y)), _color(board, &"pitch_stripe"))
	for lane: int in [GameEnums.Lane.L1, GameEnums.Lane.R1]:
		board.draw_rect(Rect2(Vector2(0, lane * cell.y), Vector2(size.x, cell.y)), _color(board, &"pitch_halfspace"))
	# 白線: 外枠・ハーフウェイライン・センターサークル・ペナルティエリア・ゴール
	var line: Color = _color(board, &"pitch_line")
	board.draw_rect(whole, line, false, 3.0)
	board.draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), line, 2.0)
	board.draw_arc(size / 2.0, size.y * 0.13, 0.0, TAU, 48, line, 2.0)
	var box := Vector2(size.x * 0.13, size.y * 0.56)
	board.draw_rect(Rect2(Vector2(0, (size.y - box.y) / 2.0), box), line, false, 2.0)
	board.draw_rect(Rect2(Vector2(size.x - box.x, (size.y - box.y) / 2.0), box), line, false, 2.0)
	var goal := Vector2(8, size.y * 0.16)
	board.draw_rect(Rect2(Vector2(0, (size.y - goal.y) / 2.0), goal), line)
	board.draw_rect(Rect2(Vector2(size.x - goal.x, (size.y - goal.y) / 2.0), goal), line)


static func _draw_zone_lines(board: TacticsBoard) -> void:
	var color: Color = _color(board, &"zone_line")
	var cell: Vector2 = board.cell_size()
	for zone_index: int in range(1, PitchArea.ZONE_COUNT):
		board.draw_dashed_line(Vector2(zone_index * cell.x, 0), Vector2(zone_index * cell.x, board.size.y), color, 1.0, 6.0)
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		board.draw_dashed_line(Vector2(0, lane_index * cell.y), Vector2(board.size.x, lane_index * cell.y), color, 1.0, 6.0)


## ボールのあるエリアの薄い塗り・選んだエリアの塗り・選べるエリアの点線の枠。
static func _draw_area_fill(board: TacticsBoard, key: String) -> void:
	var rect: Rect2 = board.area_rect(key).grow(-3.0)
	if key == board.ball_area():
		board.draw_rect(rect, _color(board, &"ball_area_fill"))
	if key == board.selected_area():
		board.draw_rect(rect, _color(board, &"selected_fill"))
	if board.selectable_areas().has(key):
		var accent: Color = _color(board, &"accent")
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
		for index: int in range(4):
			board.draw_dashed_line(corners[index], corners[(index + 1) % 4], accent, 3.0, 10.0)


## 駒は番号を付けず、エリアの縦の中央に1列で並べる。自分の ● は中央から左へ、相手の ◆ は中央から右へ。
## 上限を超えたら、駒を (上限 - 1) つと「+N」の札にする。
static func _draw_pieces(board: TacticsBoard, key: String, is_user: bool) -> void:
	var count: int = (board.pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	if count == 0:
		return
	var radius: float = board.piece_radius()
	var color: Color = _color(board, &"you" if is_user else &"opponent")
	var shown: int = board.visible_piece_count(key, is_user)
	for index: int in range(shown + (1 if shown < count else 0)):
		var center: Vector2 = board.piece_center(key, is_user, index)
		if index >= shown:
			_draw_centered_text(board, center, board.overflow_tag(key, is_user), _font_size(board, &"tag_size"), _color(board, &"text"))
			continue
		_draw_piece(board, center, radius, color, is_user)


static func _draw_piece(board: TacticsBoard, center: Vector2, radius: float, color: Color, is_user: bool) -> void:
	if is_user:
		board.draw_circle(center, radius, color)
	else:
		var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0)])
		board.draw_colored_polygon(points, color)


## 動いている間は、駒を選手ごとに描く。動く選手は道筋の途中、動かない選手は駒の列の位置（「+N」の札は出さない。
## 動き終えると、いつもの描き方に戻る）。
static func _draw_shifting_pieces(board: TacticsBoard) -> void:
	var radius: float = board.piece_radius()
	for is_user: bool in [true, false]:
		var players: Array[Dictionary] = board.players(is_user)
		var slots: Array[int] = BoardShift.slots(players)
		var color: Color = _color(board, &"you" if is_user else &"opponent")
		for index: int in range(players.size()):
			var rest: Vector2 = board.slot_center(players[index]["area"] as String, is_user, slots[index])
			_draw_piece(board, board.shifting_piece_center(players[index]["player_id"] as String, rest), radius, color, is_user)


## ヒントの札をエリアの下端の中央に。差がある札は accent、±0 の札は控えめな色。
static func _draw_hint(board: TacticsBoard, key: String) -> void:
	var rect: Rect2 = board.area_rect(key)
	var font: Font = board.get_theme_default_font()
	var hint: String = board.hint_of(key)
	var tag_size: int = _font_size(board, &"hint_size")
	var width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 14.0
	var height: float = TacticsBoard.HINT_HEIGHT
	var tag_box := Rect2(Vector2(rect.get_center().x - width / 2.0, rect.end.y - height - 8.0), Vector2(width, height))
	var is_even: bool = board.is_hint_even(key)
	board.draw_rect(tag_box, _color(board, &"tag_muted_bg") if is_even else _color(board, &"accent"))
	_draw_centered_text(board, tag_box.get_center(), hint, tag_size, _color(board, &"text") if is_even else _color(board, &"bg"))


## レーン名を各レーンの自陣のエリアの左上に、小さく薄く。
static func _draw_lane_names(board: TacticsBoard) -> void:
	var font: Font = board.get_theme_default_font()
	var font_size: int = _font_size(board, &"lane_size")
	var color: Color = _color(board, &"lane_text")
	for lane: int in GameEnums.Lane.values():
		var rect: Rect2 = board.area_rect(PitchArea.new(lane as GameEnums.Lane, GameEnums.Zone.D).to_key())
		var baseline := Vector2(rect.position.x + 8.0, rect.position.y + 6.0 + font.get_ascent(font_size))
		board.draw_string(font, baseline, MatchTexts.lane_name(lane as GameEnums.Lane), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## ボールはエリアの上側の中央（駒の列と札に重ならない位置）。
static func _draw_ball(board: TacticsBoard) -> void:
	if board.ball_area().is_empty():
		return
	var center: Vector2 = board.ball_center()
	board.draw_circle(center, TacticsBoard.BALL_RADIUS, _color(board, &"ball"))
	board.draw_arc(center, TacticsBoard.BALL_RADIUS, 0.0, TAU, 24, _color(board, &"bg"), 2.0)


static func _draw_compare(board: TacticsBoard) -> void:
	if board.compare_area().is_empty():
		return
	var rect: Rect2 = board.area_rect(board.compare_area()).grow(-2.0)
	board.draw_rect(rect, _color(board, &"accent"), false, 5.0)
	var font: Font = board.get_theme_default_font()
	var tag_size: int = _font_size(board, &"tag_size")
	var tag: String = board.compare_tag()
	var width: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 20.0
	var tag_box := Rect2(Vector2(rect.get_center().x - width / 2.0, rect.end.y - 36.0), Vector2(width, 32))
	board.draw_rect(tag_box, _color(board, &"accent"))
	_draw_centered_text(board, tag_box.get_center(), tag, tag_size, _color(board, &"bg"))


## 動きの矢印。ドリブル（ボール）は accent の太線、プレス・カバーはチームの色の実線。それ以外の動きは描かない。
## 同じエリアの間を両チームが動くと重なるので、チームごとに少しずらす。
static func _draw_movements(board: TacticsBoard) -> void:
	for movement: Movement in board.drawn_movements():
		var offset := Vector2(0, -8.0 if movement.side == GameEnums.TeamSide.HOME else 8.0)
		var from_point: Vector2 = board.area_rect(movement.from.to_key()).get_center() + offset
		var to_point: Vector2 = board.area_rect(movement.to.to_key()).get_center() + offset
		if from_point.distance_to(to_point) < 1.0:
			continue
		if movement.reason == GameEnums.MovementReason.DRIBBLE:
			_draw_arrow(board, from_point, to_point, _color(board, &"accent"), 6.0)
		else:
			var team: Color = _color(board, &"you" if movement.side == GameEnums.TeamSide.HOME else &"opponent")
			_draw_arrow(board, from_point, to_point, team, 4.0)


## 決定前のプレビュー。移動先に自分の色の輪（中抜き）、動く選手の駒から輪へ点線の矢印。
## 開示後の動き（実線の矢印）・いまの駒（塗りの ●）と、線の種類と塗りで区別する（グレースケールでも形で分かる）。
## 矢印は緩く曲げる（同じ列を横に動くとき、途中のエリアの駒の上を通らないように）。
static func _draw_preview(board: TacticsBoard) -> void:
	var color: Color = _color(board, &"you")
	var radius: float = board.piece_radius()
	for index: int in range(board.preview_movements().size()):
		var center: Vector2 = board.preview_center(index)
		var origin: Vector2 = board.preview_origin(index)
		if origin.distance_to(center) > radius * 2.0:
			_draw_curved_dashed_arrow(board, origin, center, radius, color, 3.0)
		board.draw_arc(center, radius - 1.5, 0.0, TAU, 24, color, 3.0)


static func _draw_intent(board: TacticsBoard) -> void:
	var keys: Array[String] = board.intent_keys()
	if keys.is_empty():
		return
	var from_point: Vector2 = board.area_rect(keys[0]).get_center()
	var to_point: Vector2 = board.area_rect(keys[1]).get_center()
	if from_point.distance_to(to_point) < 1.0:
		return
	_draw_arrow(board, from_point, to_point, _color(board, &"accent"), 6.0)


static func _draw_arrow(board: TacticsBoard, from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to_point - from_point).normalized()
	var head_length: float = 14.0 + width
	var shaft_end: Vector2 = to_point - direction * head_length * 0.8
	board.draw_line(from_point, shaft_end, color, width)
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	board.draw_colored_polygon(PackedVector2Array([to_point, to_point - direction * head_length + side,
			to_point - direction * head_length - side]), color)


## 駒の縁から駒の縁へ、2次ベジェ曲線の点線と矢じり。曲がりの大きさは距離の 2 割（上限はセルの高さの 3 割）。
static func _draw_curved_dashed_arrow(board: TacticsBoard, from_center: Vector2, to_center: Vector2, radius: float,
		color: Color, width: float) -> void:
	var bulge: float = minf(from_center.distance_to(to_center) * 0.2, board.cell_size().y * 0.3)
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
		board.draw_line(points[step], points[step + 1], color, width)
	var direction: Vector2 = (tip - points[segments - 2]).normalized()
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	board.draw_colored_polygon(PackedVector2Array([tip, tip - direction * head_length + side,
			tip - direction * head_length - side]), color)


static func _draw_centered_text(board: TacticsBoard, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = board.get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(center.x - text_size.x / 2.0, center.y + font.get_ascent(font_size) / 2.0 - 2.0)
	board.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

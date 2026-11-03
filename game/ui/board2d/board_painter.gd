## 作戦ボードの描画（screen-common.md §5 の TacticsBoard の描き方）。ボードの _draw から呼ぶ。
## 縦向きのピッチを斜めから見せる（奥 = 上が敵陣）。位置はボードの平面図の座標で受け取り、board.to_screen で画面に写して描く。
## 値はボードの公開の問い合わせ（area_rect・standing_order・drawn_movements など）だけから読む。テストも同じ問い合わせを
## 通るので、「表示している値と描いている値が同じ」ことが保たれる。色・字の大きさはテーマの型 TacticsBoard。
class_name BoardPainter
extends RefCounted

## 駒を描く大きさ（平面図の台座の半径に対する倍率）。立てて描くので、平面図の大きさより少し大きく見せる
const PIECE_DRAW_RATE: float = 1.25
## 札の余白（文字の左右に足す幅の合計）と、集計の札で縮めてよい字の大きさの下限。
## 下限は、最小の盤（TacticsBoard.MIN_CELL）のいちばん奥の行に、2桁が3つ並ぶ札（「勝12 負10 膠11」）が収まる大きさ
## （12px では 0.1px はみ出した。2026-10-29 に実測）。1桁の札は、試合画面と同じ大きさの盤の奥の行でも 16px で収まる
const TAG_PADDING: float = 14.0
const MIN_TALLY_FONT_SIZE: int = 11


static func paint(board: TacticsBoard) -> void:
	_draw_ground(board)
	for area: PitchArea in PitchArea.all():
		_draw_area_fill(board, area.to_key())
	_draw_lines(board)
	_draw_lane_names(board)
	_draw_offside_line(board)
	_draw_movements(board)
	_draw_intent(board)
	_draw_preview_paths(board)
	_draw_standing_things(board)
	# 札は駒と矢印の上に描く（通り道のエリアの札の字を隠さないように）
	for key: String in board.drawn_hint_keys():
		_draw_hint(board, key)
	for key: String in board.drawn_tally_keys():
		_draw_tally(board, key)
	_draw_compare(board)


static func _color(board: TacticsBoard, name: StringName) -> Color:
	return board.get_theme_color(name, TacticsBoard.THEME_TYPE)


static func _font_size(board: TacticsBoard, name: StringName) -> int:
	return board.get_theme_font_size(name, TacticsBoard.THEME_TYPE)


## 平面図の矩形の四隅を写した四角形（奥が狭い台形）。
static func _quad(board: TacticsBoard, plan: Rect2) -> PackedVector2Array:
	return PackedVector2Array([board.to_screen(plan.position), board.to_screen(Vector2(plan.end.x, plan.position.y)),
			board.to_screen(plan.end), board.to_screen(Vector2(plan.position.x, plan.end.y))])


## 相手のオフサイドライン（2026-10-25）。相手チームの色の太い点線を、ラインの列の上端に横いっぱいに引く。
static func _draw_offside_line(board: TacticsBoard) -> void:
	if not board.is_offside_line_drawn():
		return
	var y: float = board.offside_line_plan_y()
	board.draw_dashed_line(board.to_screen(Vector2(0, y)), board.to_screen(Vector2(board.size.x, y)),
			_color(board, &"opponent"), 4.0, 14.0)


static func _outline(board: TacticsBoard, plan: Rect2, color: Color, width: float) -> void:
	var quad: PackedVector2Array = _quad(board, plan)
	quad.append(quad[0])
	board.draw_polyline(quad, color, width)


## 地面: 盤面の地・ピッチ・芝目（横の帯）・ハーフスペースの列。
static func _draw_ground(board: TacticsBoard) -> void:
	var size: Vector2 = board.size
	board.draw_rect(Rect2(Vector2.ZERO, size), _color(board, &"bg"))
	board.draw_colored_polygon(_quad(board, Rect2(Vector2.ZERO, size)), _color(board, &"pitch"))
	var stripes: int = PitchArea.ZONE_COUNT * 2
	for index: int in range(stripes):
		if index % 2 == 1:
			board.draw_colored_polygon(_quad(board, Rect2(Vector2(0, size.y * index / stripes), Vector2(size.x, size.y / stripes))),
					_color(board, &"pitch_stripe"))
	var cell: Vector2 = board.cell_size()
	for lane: int in [GameEnums.Lane.L1, GameEnums.Lane.R1]:
		board.draw_colored_polygon(_quad(board, Rect2(Vector2(lane * cell.x, 0), Vector2(cell.x, size.y))), _color(board, &"pitch_halfspace"))


## ボールのあるエリアの薄い塗り・選んだエリアの塗り・選べるエリアの点線の枠。
static func _draw_area_fill(board: TacticsBoard, key: String) -> void:
	var quad: PackedVector2Array = _quad(board, board.area_rect(key).grow(-3.0))
	if key == board.ball_area():
		board.draw_colored_polygon(quad, _color(board, &"ball_area_fill"))
	if key == board.selected_area():
		board.draw_colored_polygon(quad, _color(board, &"selected_fill"))
	if board.selectable_areas().has(key):
		var accent: Color = _color(board, &"accent")
		for index: int in range(4):
			board.draw_dashed_line(quad[index], quad[(index + 1) % 4], accent, 3.0, 10.0)


## 上下のペナルティエリアの平面図の矩形（上が相手のゴール側）。シュートを打てる3マス（6列目の L1・C・R1）に
## ぴったり合わせる（2026-10-25。どこから打てるかを白線で読めるようにする）。
static func penalty_areas(board: TacticsBoard) -> Array[Rect2]:
	var areas: Array[Rect2] = [
		board.area_rect("A2-L1").merge(board.area_rect("A2-R1")),
		board.area_rect("D1-L1").merge(board.area_rect("D1-R1")),
	]
	return areas


## 白線（外枠・ハーフウェイライン・センターサークル・上下のペナルティエリアとゴール）と、エリアの点線。
static func _draw_lines(board: TacticsBoard) -> void:
	var size: Vector2 = board.size
	var line: Color = _color(board, &"pitch_line")
	_outline(board, Rect2(Vector2.ZERO, size), line, 3.0)
	board.draw_line(board.to_screen(Vector2(0, size.y / 2.0)), board.to_screen(Vector2(size.x, size.y / 2.0)), line, 2.0)
	var circle: PackedVector2Array = []
	for step: int in range(49):
		var angle: float = TAU * step / 48.0
		circle.append(board.to_screen(size / 2.0 + Vector2(cos(angle), sin(angle)) * size.x * 0.09))
	board.draw_polyline(circle, line, 2.0)
	for area: Rect2 in penalty_areas(board):
		_outline(board, area, line, 2.0)
	var goal := Vector2(size.x * 0.16, 8.0)
	board.draw_colored_polygon(_quad(board, Rect2(Vector2((size.x - goal.x) / 2.0, 0), goal)), line)
	board.draw_colored_polygon(_quad(board, Rect2(Vector2((size.x - goal.x) / 2.0, size.y - goal.y), goal)), line)
	var zone: Color = _color(board, &"zone_line")
	var cell: Vector2 = board.cell_size()
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		board.draw_dashed_line(board.to_screen(Vector2(lane_index * cell.x, 0)), board.to_screen(Vector2(lane_index * cell.x, size.y)),
				zone, 1.0, 6.0)
	for row_index: int in range(1, PitchArea.ZONE_COUNT):
		board.draw_dashed_line(board.to_screen(Vector2(0, row_index * cell.y)), board.to_screen(Vector2(size.x, row_index * cell.y)),
				zone, 1.0, 6.0)


## レーン名を、自陣（手前の行）の各エリアの左上に。
static func _draw_lane_names(board: TacticsBoard) -> void:
	var font: Font = board.get_theme_default_font()
	var font_size: int = _font_size(board, &"lane_size")
	var color: Color = _color(board, &"lane_text")
	for lane: int in GameEnums.Lane.values():
		var rect: Rect2 = board.area_rect(PitchArea.new(lane as GameEnums.Lane, GameEnums.Zone.D1).to_key())
		var at: Vector2 = board.to_screen(rect.position + Vector2(10.0, 8.0))
		board.draw_string(font, at + Vector2(0, font.get_ascent(font_size)), MatchTexts.lane_name(lane as GameEnums.Lane),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 立っているもの（駒・プレビューの駒・ボール・「+N」の札）を、奥から手前の順に（ボードの standing_order の順）。
static func _draw_standing_things(board: TacticsBoard) -> void:
	var radius: float = board.piece_radius() * PIECE_DRAW_RATE
	for thing: Dictionary in board.standing_order():
		var foot: Vector2 = board.to_screen(thing["plan"] as Vector2)
		var scale: float = BoardProjection.scale_at(foot.y, board.size)
		match thing["kind"]:
			"piece":
				_draw_chess_piece(board, foot, radius * scale, thing["is_user"] as bool, 0.38 if thing["is_preview"] else 1.0)
			"ball":
				_draw_lifted_ball(board, foot, scale, thing["lift"] as float)
			"tag":
				_draw_overflow_tag(board, foot + Vector2(0, -radius * scale), thing["text"] as String)


## チェスの駒: 影 → 台座 → 胴 → 首の輪 → 頭。自分はポーン（丸い頭）、相手はビショップ風（とがった頭）。
## 色だけでなく頭の形で区別する（NFR-20 のグレースケールでも判別できる）。alpha はプレビューの半透明に使う。
static func _draw_chess_piece(board: TacticsBoard, foot: Vector2, r: float, is_user: bool, alpha: float) -> void:
	var base: Color = _color(board, &"you" if is_user else &"opponent")
	base.a = alpha
	var dark: Color = base.darkened(0.35)
	var light: Color = base.lightened(0.35)
	_ellipse(board, foot + Vector2(r * 0.25, r * 0.12), r * 1.15, r * 0.42, Color(0, 0, 0, 0.35 * alpha))
	_ellipse(board, foot, r, r * 0.36, dark)
	board.draw_rect(Rect2(foot + Vector2(-r, -r * 0.30), Vector2(r * 2.0, r * 0.30)), dark)
	_ellipse(board, foot + Vector2(0, -r * 0.30), r, r * 0.36, base)
	var neck_y: float = -r * 1.75
	board.draw_colored_polygon(PackedVector2Array([foot + Vector2(-r * 0.70, -r * 0.30), foot + Vector2(r * 0.70, -r * 0.30),
			foot + Vector2(r * 0.30, neck_y), foot + Vector2(-r * 0.30, neck_y)]), base)
	board.draw_line(foot + Vector2(-r * 0.45, -r * 0.45), foot + Vector2(-r * 0.20, neck_y + r * 0.1), light, maxf(1.5, r * 0.12))
	_ellipse(board, foot + Vector2(0, neck_y), r * 0.55, r * 0.18, dark)
	var head: Vector2 = foot + Vector2(0, neck_y - r * 0.55)
	if is_user:
		board.draw_circle(head, r * 0.62, base)
		board.draw_circle(head + Vector2(-r * 0.2, -r * 0.2), r * 0.18, light)
	else:
		var tip: Vector2 = head + Vector2(0, -r * 0.95)
		board.draw_colored_polygon(PackedVector2Array([tip, head + Vector2(r * 0.55, 0), head + Vector2(0, r * 0.45),
				head + Vector2(-r * 0.55, 0)]), base)
		board.draw_line(tip, head + Vector2(-r * 0.3, 0), light, maxf(1.5, r * 0.10))
		board.draw_circle(tip, r * 0.16, dark)


## 「+N」の札。駒の上に重なっても読めるよう、控えめな色の地を敷く。
static func _draw_overflow_tag(board: TacticsBoard, center: Vector2, text: String) -> void:
	var font: Font = board.get_theme_default_font()
	var tag_size: int = _font_size(board, &"tag_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 12.0
	var height: float = TacticsBoard.HINT_HEIGHT
	board.draw_rect(Rect2(center - Vector2(width, height) / 2.0, Vector2(width, height)), _color(board, &"tag_muted_bg"))
	_draw_centered_text(board, center, text, tag_size, _color(board, &"text"))


## ボールは少し浮かせて、地面に影を落とす。lift（ボールの半径の何倍か）の分だけさらに持ち上げる（浮き球・ドリブルの弾み）。
## 影は地面の位置のまま。
static func _draw_lifted_ball(board: TacticsBoard, foot: Vector2, scale: float, lift: float) -> void:
	var r: float = TacticsBoard.BALL_RADIUS * scale
	_ellipse(board, foot, r, r * 0.38, Color(0, 0, 0, 0.35))
	var center: Vector2 = foot + Vector2(0, -r * (1.6 + lift))
	board.draw_circle(center, r, _color(board, &"ball"))
	board.draw_arc(center, r, 0.0, TAU, 24, _color(board, &"bg"), 2.0)


static func _ellipse(board: TacticsBoard, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points: PackedVector2Array = []
	for step: int in range(24):
		var angle: float = TAU * step / 24.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	board.draw_colored_polygon(points, color)


## ヒントの札を、エリアの下端の中央に。差がある札は accent、±0 の札は控えめな色。
static func _draw_hint(board: TacticsBoard, key: String) -> void:
	var rect: Rect2 = board.area_rect(key)
	var bottom: Vector2 = board.to_screen(Vector2(rect.get_center().x, rect.end.y - 6.0))
	_draw_tag(board, bottom, board.hint_of(key), board.is_hint_even(key))


## 振り返りの集計の札。駒を描かない盤面なので、エリアの中央に置く（札の下端を中央より札の高さの半分だけ下げる）。
static func _draw_tally(board: TacticsBoard, key: String) -> void:
	var center: Vector2 = board.to_screen(board.area_rect(key).get_center())
	var text: String = board.tally_of(key)
	_draw_tag(board, center + Vector2(0, TacticsBoard.HINT_HEIGHT / 2.0), text, false, tally_font_size(board, key, text))


## 集計の札の字の大きさ。ヒントの札と同じ大きさで、札がエリアの幅（奥ほど狭い。上端の辺で測る）に収まらなければ、
## 収まるまで下限まで縮める（「勝3 負1 膠1」は、奥の行ではヒントの大きさのままだと収まらない）。
static func tally_font_size(board: TacticsBoard, key: String, text: String) -> int:
	var rect: Rect2 = board.area_rect(key)
	var room: float = board.to_screen(Vector2(rect.end.x, rect.position.y)).x - board.to_screen(rect.position).x
	var font: Font = board.get_theme_default_font()
	var font_size: int = _font_size(board, &"hint_size")
	while font_size > MIN_TALLY_FONT_SIZE and tag_width(font, text, font_size) > room:
		font_size -= 1
	return font_size


static func tag_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + TAG_PADDING


## 札（地の色つきの文字）。bottom は札の下端の中央（画面の座標）。is_muted なら控えめな地の色で描く。
## tag_size が 0 ならヒントの札の大きさ。
static func _draw_tag(board: TacticsBoard, bottom: Vector2, text: String, is_muted: bool, tag_size: int = 0) -> void:
	var font: Font = board.get_theme_default_font()
	if tag_size <= 0:
		tag_size = _font_size(board, &"hint_size")
	var width: float = tag_width(font, text, tag_size)
	var height: float = TacticsBoard.HINT_HEIGHT
	var tag_box := Rect2(bottom + Vector2(-width / 2.0, -height), Vector2(width, height))
	board.draw_rect(tag_box, _color(board, &"tag_muted_bg") if is_muted else _color(board, &"accent"))
	_draw_centered_text(board, tag_box.get_center(), text, tag_size, _color(board, &"text") if is_muted else _color(board, &"bg"))


static func _draw_compare(board: TacticsBoard) -> void:
	if board.compare_area().is_empty():
		return
	_outline(board, board.area_rect(board.compare_area()).grow(-2.0), _color(board, &"accent"), 5.0)
	var rect: Rect2 = board.area_rect(board.compare_area())
	var at: Vector2 = board.to_screen(Vector2(rect.get_center().x, rect.end.y - 6.0))
	var font: Font = board.get_theme_default_font()
	var tag_size: int = _font_size(board, &"tag_size")
	var tag: String = board.compare_tag()
	var width: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 20.0
	var tag_box := Rect2(at + Vector2(-width / 2.0, -32.0), Vector2(width, 32))
	board.draw_rect(tag_box, _color(board, &"accent"))
	_draw_centered_text(board, tag_box.get_center(), tag, tag_size, _color(board, &"bg"))


## 動きの矢印。ドリブル（ボール）は accent の太線、プレス・カバー・スルーパスの走り込み（受け手の動き。ボールは開示の動きで運ぶ先へ動く）はチームの色の実線。それ以外の動きは描かない。
## 同じエリアの間を両チームが動くと重なるので、チームごとに少しずらす。
static func _draw_movements(board: TacticsBoard) -> void:
	for movement: Movement in board.drawn_movements():
		var offset := Vector2(-8.0 if movement.side == GameEnums.TeamSide.HOME else 8.0, 0)
		var from_point: Vector2 = board.screen_center(movement.from.to_key()) + offset
		var to_point: Vector2 = board.screen_center(movement.to.to_key()) + offset
		if from_point.distance_to(to_point) < 1.0:
			continue
		if movement.reason == GameEnums.MovementReason.DRIBBLE:
			_draw_arrow(board, from_point, to_point, _color(board, &"accent"), 6.0)
		else:
			var team: Color = _color(board, &"you" if movement.side == GameEnums.TeamSide.HOME else &"opponent")
			_draw_arrow(board, from_point, to_point, team, 4.0)


static func _draw_intent(board: TacticsBoard) -> void:
	var keys: Array[String] = board.intent_keys()
	if keys.is_empty():
		return
	var from_point: Vector2 = board.screen_center(keys[0])
	var to_point: Vector2 = board.screen_center(keys[1])
	if from_point.distance_to(to_point) < 1.0:
		return
	_draw_arrow(board, from_point, to_point, _color(board, &"accent"), 6.0)


## 決定前のプレビューの点線の矢印（地面に沿った緩い曲線）。移動先の半透明の駒は、立っているものと一緒に描く。
## 開示後の動き（実線の矢印）・いまの駒（不透明）と、線の種類と透明度で区別する。
static func _draw_preview_paths(board: TacticsBoard) -> void:
	var color: Color = _color(board, &"you")
	var radius: float = board.piece_radius()
	for index: int in range(board.preview_movements().size()):
		var origin: Vector2 = board.preview_origin(index)
		var center: Vector2 = board.preview_center(index)
		if origin.distance_to(center) > radius * 2.0:
			_draw_curved_dashed_arrow(board, origin, center, color, 3.0)


static func _draw_arrow(board: TacticsBoard, from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to_point - from_point).normalized()
	var head_length: float = 14.0 + width
	var shaft_end: Vector2 = to_point - direction * head_length * 0.8
	board.draw_line(from_point, shaft_end, color, width)
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	board.draw_colored_polygon(PackedVector2Array([to_point, to_point - direction * head_length + side,
			to_point - direction * head_length - side]), color)


## 平面図の2点の間の、2次ベジェ曲線の点線と矢じり（曲線は平面図で作り、点ごとに画面へ写す）。
## 曲がりの大きさは距離の 2 割（上限はセルの高さの 3 割）。
static func _draw_curved_dashed_arrow(board: TacticsBoard, from_plan: Vector2, to_plan: Vector2, color: Color, width: float) -> void:
	var bulge: float = minf(from_plan.distance_to(to_plan) * 0.2, board.cell_size().y * 0.3)
	var control: Vector2 = (from_plan + to_plan) / 2.0 + (to_plan - from_plan).normalized().orthogonal() * bulge
	var segments: int = 24
	var points: Array[Vector2] = []
	for step: int in range(segments + 1):
		var t: float = float(step) / segments
		points.append(board.to_screen(from_plan.lerp(control, t).lerp(control.lerp(to_plan, t), t)))
	var tip: Vector2 = points[segments]
	var head_length: float = 12.0 + width
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

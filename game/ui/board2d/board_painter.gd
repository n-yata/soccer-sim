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
## レーン名をエリアの左下の角から離す距離（平面図の座標。左・下）
const LANE_NAME_INSET: Vector2 = Vector2(10.0, 6.0)


static func paint(board: TacticsBoard) -> void:
	_draw_ground(board)
	for area: PitchArea in PitchArea.all():
		_draw_area_fill(board, area.to_key())
	_draw_lines(board)
	_draw_lane_names(board)
	_draw_offside_line(board)
	_draw_movements(board)
	_draw_intent(board)
	_draw_standing_things(board)
	ResultEffectPainter.paint(board)
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


## 平面図の矩形の四隅を写した四角形（奥が狭い台形）。ResultEffectPainter も使う。
static func quad(board: TacticsBoard, plan: Rect2) -> PackedVector2Array:
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
	var corners: PackedVector2Array = quad(board, plan)
	corners.append(corners[0])
	board.draw_polyline(corners, color, width)


## 地面: 盤面の地・ピッチ・芝目（横の帯）・ハーフスペースの列。
static func _draw_ground(board: TacticsBoard) -> void:
	var size: Vector2 = board.size
	board.draw_rect(Rect2(Vector2.ZERO, size), _color(board, &"bg"))
	board.draw_colored_polygon(quad(board, Rect2(Vector2.ZERO, size)), _color(board, &"pitch"))
	var stripes: int = PitchArea.ZONE_COUNT * 2
	for index: int in range(stripes):
		if index % 2 == 1:
			board.draw_colored_polygon(quad(board, Rect2(Vector2(0, size.y * index / stripes), Vector2(size.x, size.y / stripes))),
					_color(board, &"pitch_stripe"))
	var cell: Vector2 = board.cell_size()
	for lane: int in [GameEnums.Lane.L1, GameEnums.Lane.R1]:
		board.draw_colored_polygon(quad(board, Rect2(Vector2(lane * cell.x, 0), Vector2(cell.x, size.y))), _color(board, &"pitch_halfspace"))


## ボールのあるエリアの薄い塗り・選んだエリアの塗り・選べるエリアの点線の枠。
static func _draw_area_fill(board: TacticsBoard, key: String) -> void:
	var corners: PackedVector2Array = quad(board, board.area_rect(key).grow(-3.0))
	if key == board.ball_area():
		board.draw_colored_polygon(corners, _color(board, &"ball_area_fill"))
	if key == board.selected_area():
		board.draw_colored_polygon(corners, _color(board, &"selected_fill"))
	if board.selectable_areas().has(key):
		var accent: Color = _color(board, &"accent")
		for index: int in range(4):
			board.draw_dashed_line(corners[index], corners[(index + 1) % 4], accent, 3.0, 10.0)


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
	for is_top: bool in [true, false]:
		board.draw_colored_polygon(quad(board, board.goal_rect(is_top)), line)
	var zone: Color = _color(board, &"zone_line")
	var cell: Vector2 = board.cell_size()
	for lane_index: int in range(1, PitchArea.LANE_COUNT):
		board.draw_dashed_line(board.to_screen(Vector2(lane_index * cell.x, 0)), board.to_screen(Vector2(lane_index * cell.x, size.y)),
				zone, 1.0, 6.0)
	for row_index: int in range(1, PitchArea.ZONE_COUNT):
		board.draw_dashed_line(board.to_screen(Vector2(0, row_index * cell.y)), board.to_screen(Vector2(size.x, row_index * cell.y)),
				zone, 1.0, 6.0)


## レーン名を、自陣（手前の行）の各エリアの左下に（位置は lane_name_baseline）。
static func _draw_lane_names(board: TacticsBoard) -> void:
	var font: Font = board.get_theme_default_font()
	var font_size: int = _font_size(board, &"lane_size")
	var color: Color = _color(board, &"lane_text")
	for lane: int in GameEnums.Lane.values():
		board.draw_string(font, lane_name_baseline(board, lane as GameEnums.Lane), MatchTexts.lane_name(lane as GameEnums.Lane),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 手前の行の lane のエリアに書くレーン名の、文字の基準線の左端（画面の座標）。エリアの左下に置く。
## 自分の駒はエリアの中央から左へ、足元を高さの半ばに並べるので、左上では駒の体に隠れた（2026-11-06）。
## 左下なら、1エリアに2人（奥の段）までは重ならない。3人目からの手前の段（PIECE_ROW_RATES）とは重なる
static func lane_name_baseline(board: TacticsBoard, lane: GameEnums.Lane) -> Vector2:
	var font: Font = board.get_theme_default_font()
	var font_size: int = _font_size(board, &"lane_size")
	var rect: Rect2 = board.area_rect(PitchArea.new(lane, GameEnums.Zone.D1).to_key())
	return board.to_screen(rect.position + Vector2(LANE_NAME_INSET.x, rect.size.y - LANE_NAME_INSET.y)) \
			- Vector2(0, font.get_descent(font_size))


## 立っているもの（駒・プレビューの駒・ボール・「+N」の札）を、奥から手前の順に（ボードの standing_order の順）。
static func _draw_standing_things(board: TacticsBoard) -> void:
	var radius: float = board.piece_radius() * PIECE_DRAW_RATE
	for thing: Dictionary in board.standing_order():
		var foot: Vector2 = board.to_screen(thing["plan"] as Vector2)
		var scale: float = BoardProjection.scale_at(foot.y, board.size)
		match thing["kind"]:
			"piece":
				var is_user: bool = thing["is_user"] as bool
				var alpha: float = 0.38 if thing["is_preview"] else 1.0
				var lift: float = thing.get("lift", 0.0) as float
				var sprite: Texture2D = PieceSprites.texture_for(board, is_user)
				if sprite != null:
					_draw_piece_sprite(board, sprite, foot, radius * scale, alpha, lift)
				else:
					_draw_player(board, foot, radius * scale, is_user, alpha, lift)
			"ball":
				_draw_lifted_ball(board, foot, scale, thing["lift"] as float)
			"tag":
				_draw_overflow_tag(board, foot + Vector2(0, -radius * scale), thing["text"] as String)


## 3D で描いた駒の絵（PieceSprites）を置く。床の影は平面のポーンと同じ楕円を地面に描く。alpha はプレビューの半透明に使う。
static func _draw_piece_sprite(board: TacticsBoard, sprite: Texture2D, ground: Vector2, r: float, alpha: float, lift: float) -> void:
	board.draw_colored_polygon(shadow_points(ground, r, lift), Color(0, 0, 0, 0.35 / (1.0 + lift) * alpha))
	board.draw_texture_rect(sprite, sprite_rect(ground, r, lift), false, Color(1, 1, 1, alpha))


## 駒の絵を置く範囲。絵の台座（半径 PieceSprites.BASE_RADIUS_PX）が r に、台座の中心（PieceSprites.FOOT_PX）が
## 足元から r × lift だけ上（開示の弾み）に来るよう縮めて置く
static func sprite_rect(ground: Vector2, r: float, lift: float) -> Rect2:
	var rate: float = r / PieceSprites.BASE_RADIUS_PX
	var foot: Vector2 = ground + Vector2(0, -r * lift)
	return Rect2(foot - PieceSprites.FOOT_PX * rate, Vector2(PieceSprites.TEXTURE_SIZE) * rate)


## 駒の床の影（地面に残り、浮くほど小さくなる）
static func shadow_points(ground: Vector2, r: float, lift: float) -> PackedVector2Array:
	var shrink: float = 1.0 / (1.0 + lift)
	return _ellipse_points(ground + Vector2(r * 0.25, r * 0.12), r * 1.10 * shrink, r * 0.40 * shrink)


## 縦じまの色。チームの色を 0.55 暗くする（相手のオレンジと胴のコントラストが 3:1 以上。0.45 では約 2.8:1 だった）
static func stripe_color(team: Color) -> Color:
	return team.darkened(0.55)


## 選手の駒（ユニフォームを着たポーンの平面の図形。player_parts の部品を順に塗る）。3D の絵がまだ無いときに使う。
## alpha はプレビューの半透明に使う。
static func _draw_player(board: TacticsBoard, ground: Vector2, r: float, is_user: bool, alpha: float, lift: float) -> void:
	var base: Color = _color(board, &"you" if is_user else &"opponent")
	var shadow_alpha: float = 0.35 / (1.0 + lift)
	for part: Dictionary in player_parts(ground, r, is_user, lift):
		var color: Color = _player_color(board, part["role"] as StringName, base, shadow_alpha)
		color.a *= alpha
		board.draw_colored_polygon(part["points"] as PackedVector2Array, color)


## 部品の役割 → 色の決め方（_player_color）。&"team"・&"team_light"・&"team_dark" はチームの色とその明るい色・暗い色、
## &"shadow" は影、ほかはテーマの色の名前。player_parts の役割はすべてここに載せる（テストで確かめる）
const PLAYER_ROLE_COLORS: Dictionary = {
	&"shadow": &"shadow",
	&"base": &"team", &"shirt": &"team", &"head": &"team",
	&"highlight": &"team_light",
	&"base_side": &"team_dark", &"ring": &"team_dark", &"stripe": &"team_stripe",
	&"emblem": &"bg",
}


## 部品の役割 → 色。台座の上面・胴・頭はチームの色、台座の側面・首の輪・縦じまはその暗い色、頭の光は明るい色
## （縦じまは、明るい色ではグレースケールで胴と見分けにくかった。2026-11-06）。
static func _player_color(board: TacticsBoard, role: StringName, base: Color, shadow_alpha: float) -> Color:
	var source: StringName = PLAYER_ROLE_COLORS.get(role, &"team")
	match source:
		&"shadow":
			return Color(0, 0, 0, shadow_alpha)
		&"team":
			return base
		&"team_light":
			return base.lightened(0.4)
		&"team_dark":
			return base.darkened(0.45)
		&"team_stripe":
			return stripe_color(base)
	return _color(board, source)


## 選手の駒の部品を、奥から手前へ塗る順に。各要素は {"role": StringName, "points": PackedVector2Array（画面の座標）}。
## ground は足元の地面、r は描く大きさ（台座の半径）。高さは約 3.0r、幅は ±r（台座）。
## チェスのポーンの形: 丸い台座（base・base_side）、上へ細くなる胴（shirt。ユニフォームの色）、首の輪（ring）、丸い頭（head）と光（highlight）。
## 顔・髪・脚のような人の部品は描かない（2026-11-06。人の形の選手は、シャビ「人間ぽさが残りすぎ」。案を並べて、シャビが案A「ポーン型」を選んだ）。
## 色だけでなく形でもチームを区別する（NFR-20）: 相手の胴は縦じま（stripe）、胸の印は自分が丸（●）・相手がひし形（◆）。
## lift（r の何倍か）の分だけ影のほかを持ち上げる（開示の弾み）。影は地面に残し、浮くほど小さくする。
## 色は役割ごとに PLAYER_ROLE_COLORS が決める。テストもこの部品を通して形を確かめる
static func player_parts(ground: Vector2, r: float, is_user: bool, lift: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	parts.append(_part(&"shadow", shadow_points(ground, r, lift)))
	var foot: Vector2 = ground + Vector2(0, -r * lift)
	var base_top_y: float = -r * 0.32
	parts.append(_part(&"base_side", _disc_side(foot, r, r * 0.36, base_top_y)))
	parts.append(_part(&"base", _ellipse_points(foot + Vector2(0, base_top_y), r, r * 0.36)))
	var body := PackedVector2Array([foot + Vector2(-r * 0.66, -r * 0.36), foot + Vector2(r * 0.66, -r * 0.36),
			foot + Vector2(r * 0.34, -r * 1.78), foot + Vector2(-r * 0.34, -r * 1.78)])
	parts.append(_part(&"shirt", body))
	if not is_user:
		# 縦じまは胴の形で切り取る（胴が上へ細くなるので、帯を胴の内側に収める）
		for side_sign: float in [-1.0, 1.0]:
			var x: float = side_sign * r * 0.2
			var band: PackedVector2Array = _box(foot, x - r * 0.09, x + r * 0.09, -r * 1.78, -r * 0.36)
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(band, body):
				parts.append(_part(&"stripe", clipped))
	parts.append(_part(&"ring", _ellipse_points(foot + Vector2(0, -r * 1.78), r * 0.52, r * 0.17)))
	var chest: Vector2 = foot + Vector2(0, -r * 1.10)
	var emblem: float = r * 0.17
	if is_user:
		parts.append(_part(&"emblem", _ellipse_points(chest, emblem, emblem, 12)))
	else:
		parts.append(_part(&"emblem", PackedVector2Array([chest + Vector2(0, -emblem * 1.2), chest + Vector2(emblem, 0),
				chest + Vector2(0, emblem * 1.2), chest + Vector2(-emblem, 0)])))
	var head: Vector2 = foot + Vector2(0, -r * 2.38)
	parts.append(_part(&"head", _ellipse_points(head, r * 0.62, r * 0.62, 32)))
	parts.append(_part(&"highlight", _ellipse_points(head + Vector2(-r * 0.2, -r * 0.2), r * 0.16, r * 0.16, 12)))
	return parts


## 円柱の段の側面: center を中心とする楕円（横 rx・縦 ry）の下半分と、そこから height（上がマイナス）だけ上までの帯
static func _disc_side(center: Vector2, rx: float, ry: float, height: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for step: int in range(13):
		var angle: float = PI * step / 12.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	points.append(center + Vector2(-rx, height))
	points.append(center + Vector2(rx, height))
	return points


## サッカーボールの黒い模様。中央の五角形と、縁の5枚（ボールの円で切り取る）。
static func ball_patches(center: Vector2, r: float) -> Array[PackedVector2Array]:
	var patches: Array[PackedVector2Array] = [_pentagon(center, r * 0.36, -PI / 2.0)]
	var ball: PackedVector2Array = _ellipse_points(center, r, r, 32)
	for index: int in range(5):
		var angle: float = -PI / 2.0 + PI / 5.0 + TAU * index / 5.0
		var rim: PackedVector2Array = _pentagon(center + Vector2(cos(angle), sin(angle)) * r * 0.98, r * 0.34, angle)
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(rim, ball):
			patches.append(clipped)
	return patches


static func _part(role: StringName, points: PackedVector2Array) -> Dictionary:
	return {"role": role, "points": points}


## foot からの相対の左右（x）・上下（y。上がマイナス）で囲む四角
static func _box(foot: Vector2, left: float, right: float, top: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([foot + Vector2(left, top), foot + Vector2(right, top), foot + Vector2(right, bottom),
			foot + Vector2(left, bottom)])


static func _pentagon(center: Vector2, radius: float, first_angle: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for index: int in range(5):
		var angle: float = first_angle + TAU * index / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _ellipse_points(center: Vector2, rx: float, ry: float, count: int = 24) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for step: int in range(count):
		var angle: float = TAU * step / count
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


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
	# サッカーボールの模様（2026-11-06。白い円だけから変えた）
	for patch: PackedVector2Array in ball_patches(center, r):
		board.draw_colored_polygon(patch, _color(board, &"bg"))
	board.draw_arc(center, r, 0.0, TAU, 32, _color(board, &"bg"), 1.5)


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


static func _draw_arrow(board: TacticsBoard, from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to_point - from_point).normalized()
	var head_length: float = 14.0 + width
	var shaft_end: Vector2 = to_point - direction * head_length * 0.8
	board.draw_line(from_point, shaft_end, color, width)
	var side: Vector2 = direction.orthogonal() * head_length * 0.5
	board.draw_colored_polygon(PackedVector2Array([to_point, to_point - direction * head_length + side,
			to_point - direction * head_length - side]), color)


static func _draw_centered_text(board: TacticsBoard, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = board.get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(center.x - text_size.x / 2.0, center.y + font.get_ascent(font_size) / 2.0 - 2.0)
	board.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

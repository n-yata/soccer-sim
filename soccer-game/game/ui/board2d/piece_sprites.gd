## 作戦ボードの選手の駒の 3D の絵（光沢のあるプラスチックのポーン）。
## 2026-11-06 にシャビが案「3D-1 光沢プラスチック」を選んだ。それまでの平面の図形では「3D が足りない」だった。
## チームごとのポーンを SubViewport の 3D で1回だけ描き、画像（縮小用のミップマップつき）にして持つ。BoardPainter がその絵を駒の位置に置く。
## 画面を持たない実行（headless のテスト）や描き終わる前は texture_for が null を返し、BoardPainter は平面のポーン（player_parts）で描く。
## 色だけでなく形でもチームを区別する（NFR-20）: 相手の胴は縦じま、胸の印は自分が丸（●）・相手がひし形（◆）。
class_name PieceSprites
extends Node

const NODE_NAME: StringName = &"PieceSprites"
## ボードに付けたかどうかの印（付ける処理は次のフレームに回すので、重ねて付けないため）
const PENDING_META: StringName = &"piece_sprites_pending"
## 絵の大きさ（px）。台座の半径 1 が BASE_RADIUS_PX に写る正射影で描く。台座の中心（地面）は絵の FOOT_PX に来る
const TEXTURE_SIZE: Vector2i = Vector2i(320, 480)
const BASE_RADIUS_PX: float = 128.0
const FOOT_PX: Vector2 = Vector2(160, 428)
## 見下ろす角度（度）。平面のポーンの台座の楕円（縦が横の 0.36 倍）と同じ傾き
const PITCH_DEGREES: float = 21.0
## ポーンの輪郭（半径, 高さ）。台座の半径を 1 とする。最後に頭の球（中心の高さ HEAD_Y・半径 HEAD_RADIUS）をつなぐ
const PROFILE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.16), Vector2(0.9, 0.24),
		Vector2(0.94, 0.32), Vector2(0.72, 0.40), Vector2(0.56, 0.56), Vector2(0.46, 0.95), Vector2(0.37, 1.45),
		Vector2(0.56, 1.52), Vector2(0.58, 1.6), Vector2(0.4, 1.68), Vector2(0.34, 1.76)]
const HEAD_Y: float = 2.3
const HEAD_RADIUS: float = 0.6
## 胴（縦じまを付ける高さ）と首の輪の高さ
const BODY_RANGE: Vector2 = Vector2(0.42, 1.46)
const RING_RANGE: Vector2 = Vector2(1.46, 1.7)
## 縦じま: 正面から見た横の位置（sin(角度)）と、その半分の幅
const STRIPE_CENTER: float = 0.34
const STRIPE_HALF_WIDTH: float = 0.13
const SEGMENTS: int = 128
## 駒が写るまで待つフレームの上限（約1秒）
const MAX_RENDER_FRAMES: int = 60
const ROUGHNESS: float = 0.18
## ボールの絵: 正方形の大きさ（px）と、絵の中のボールの半径（px）。ボールは絵の真ん中に写る
const BALL_KEY: StringName = &"ball"
const BALL_TEXTURE_SIZE: Vector2i = Vector2i(128, 128)
const BALL_RADIUS_PX: float = 56.0
## サッカーボールの黒い五角形の中心（正二十面体の12の頂点）。最初の1つがカメラの正面に来るよう回して描く
const PENTAGON_CENTERS: Array[Vector3] = [Vector3(0, 1, 1.618034), Vector3(0, -1, 1.618034), Vector3(0, 1, -1.618034),
		Vector3(0, -1, -1.618034), Vector3(1, 1.618034, 0), Vector3(-1, 1.618034, 0), Vector3(1, -1.618034, 0),
		Vector3(-1, -1.618034, 0), Vector3(1.618034, 0, 1), Vector3(-1.618034, 0, 1), Vector3(1.618034, 0, -1),
		Vector3(-1.618034, 0, -1)]
## 隣り合う五角形の中心どうしの角度（正二十面体の辺）と、五角形の頂点の位置（中心から隣の中心への 1/3。切頂二十面体）
const NEIGHBOR_ANGLE: float = 1.1071487
const PENTAGON_VERTEX_RATE: float = 1.0 / 3.0

var _colors: Dictionary = {}
## 胸の印の色（テーマの bg。平面のポーンの印と同じ色）
var _emblem_color: Color = Color.BLACK
## ボールの白（テーマの ball。黒い五角形は胸の印と同じ bg）
var _ball_color: Color = Color.WHITE
var _textures: Dictionary = {}
## 五角形の中心 → 頂点の向き（_pentagon_corners が覚えておく）
static var _corner_cache: Dictionary = {}


## チーム（自分なら true）の駒の絵。まだ無ければ null（初めて呼ばれたときに、ボードへ描く係を付ける）
static func texture_for(board: Control, is_user: bool) -> Texture2D:
	var sprites: PieceSprites = _sprites_of(board)
	return null if sprites == null else sprites._textures.get(is_user) as Texture2D


## サッカーボールの絵（駒と同じ光沢の 3D。2026-11-07。シャビ「サッカーボールも同じ質感を合わせて」）。まだ無ければ null
static func ball_texture(board: Control) -> Texture2D:
	var sprites: PieceSprites = _sprites_of(board)
	return null if sprites == null else sprites._textures.get(BALL_KEY) as Texture2D


## ボードに付いた描く係。まだ付いていなければ、次のフレームで付けるよう頼んで null を返す
static func _sprites_of(board: Control) -> PieceSprites:
	var sprites: PieceSprites = board.get_node_or_null(NodePath(NODE_NAME)) as PieceSprites
	if sprites == null:
		if not board.has_meta(PENDING_META):
			board.set_meta(PENDING_META, true)
			# 描いている最中には子を足さず、次のフレームで作って付ける（付ける直前に作るので、木の外に浮いたノードを残さない）。
			# その前にボードが消えていたら何もしない
			var attach: Callable = func() -> void:
				if not is_instance_valid(board):
					return
				# 木から外れていたら印を外す（木に戻って次に描くとき、もう一度付ける）
				if not board.is_inside_tree():
					board.remove_meta(PENDING_META)
					return
				var created := PieceSprites.new()
				created.name = NODE_NAME
				created._colors = {true: board.get_theme_color(&"you", TacticsBoard.THEME_TYPE),
						false: board.get_theme_color(&"opponent", TacticsBoard.THEME_TYPE)}
				created._emblem_color = board.get_theme_color(&"bg", TacticsBoard.THEME_TYPE)
				created._ball_color = board.get_theme_color(&"ball", TacticsBoard.THEME_TYPE)
				board.add_child(created)
			attach.call_deferred()
	return sprites


## 高さ y・回転の角度 angle（0 がカメラの正面）の胴の色。相手は正面側の胴に縦じま、首の輪は暗い色
static func color_at(team: Color, is_user: bool, y: float, angle: float) -> Color:
	var on_body: bool = y > BODY_RANGE.x and y < BODY_RANGE.y
	if not is_user and on_body and cos(angle) > 0.0:
		var side: float = sin(angle)
		if absf(side - STRIPE_CENTER) < STRIPE_HALF_WIDTH or absf(side + STRIPE_CENTER) < STRIPE_HALF_WIDTH:
			return BoardPainter.stripe_color(team)
	if y > RING_RANGE.x and y < RING_RANGE.y:
		return team.darkened(0.45)
	return team


## 輪郭に頭の球をつないだ点の並び
static func profile_points() -> PackedVector2Array:
	var points := PackedVector2Array(PROFILE)
	var neck: float = PROFILE[PROFILE.size() - 1].x
	var start: float = asin(-sqrt(1.0 - pow(neck / HEAD_RADIUS, 2.0)))
	for step: int in range(1, 25):
		var t: float = lerpf(start, PI / 2.0, float(step) / 24.0)
		points.append(Vector2(HEAD_RADIUS * cos(t), HEAD_Y + HEAD_RADIUS * sin(t)))
	return points


## ボールの表面の向き direction（模様の向き。長さは問わない）が、黒い五角形の中か。
## 五角形は切頂二十面体の並び: 中心は正二十面体の頂点、頂点は中心から隣の中心へ 1/3 進んだ向き
static func on_pentagon(direction: Vector3) -> bool:
	var point: Vector3 = direction.normalized()
	for center: Vector3 in PENTAGON_CENTERS:
		var c: Vector3 = center.normalized()
		if point.angle_to(c) > NEIGHBOR_ANGLE * 0.5:
			continue
		var corners: Array[Vector3] = _pentagon_corners(c)
		var inside: bool = true
		for index: int in range(corners.size()):
			var edge_normal: Vector3 = corners[index].cross(corners[(index + 1) % corners.size()])
			if signf(point.dot(edge_normal)) != signf(c.dot(edge_normal)):
				inside = false
				break
		if inside:
			return true
	return false


## 中心 c（長さ 1）の五角形の頂点の向きを、c のまわりの角度の順に（一度求めたら覚えて使い回す。ボールの面ごとに呼ぶため）
static func _pentagon_corners(c: Vector3) -> Array[Vector3]:
	if not _corner_cache.has(c):
		_corner_cache[c] = _compute_pentagon_corners(c)
	return _corner_cache[c]


static func _compute_pentagon_corners(c: Vector3) -> Array[Vector3]:
	var tangent: Vector3 = c.cross(Vector3.UP if absf(c.y) < 0.9 else Vector3.RIGHT).normalized()
	var bitangent: Vector3 = c.cross(tangent)
	var corners: Array[Vector3] = []
	for other: Vector3 in PENTAGON_CENTERS:
		var n: Vector3 = other.normalized()
		if absf(c.angle_to(n) - NEIGHBOR_ANGLE) < 0.01:
			corners.append((c + (n - c) * PENTAGON_VERTEX_RATE).normalized())
	corners.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.dot(bitangent), a.dot(tangent)) < atan2(b.dot(bitangent), b.dot(tangent)))
	return corners


## 模様をカメラの向きへ回す回転（最初の五角形の中心が、ボールの中心からカメラへの向きに来る）
static func ball_pattern_rotation() -> Quaternion:
	var pitch: float = deg_to_rad(PITCH_DEGREES)
	return Quaternion(PENTAGON_CENTERS[0].normalized(), Vector3(0, sin(pitch), cos(pitch)))


func _ready() -> void:
	# 画面を持たない実行では 3D を描けない（平面のポーン・ボールのまま）
	if DisplayServer.get_name() == "headless":
		return
	var below_center: float = (FOOT_PX.y - TEXTURE_SIZE.y / 2.0) / BASE_RADIUS_PX
	for is_user: bool in [true, false]:
		var team: Color = _colors.get(is_user, Color.WHITE)
		# 地面の原点が絵の FOOT_PX に来るよう、見る先の高さを決める（正射影なので、画面の縦のずれ = 高さ × cos(傾き)）
		_render(is_user, TEXTURE_SIZE, BASE_RADIUS_PX, Vector3(0, below_center / cos(deg_to_rad(PITCH_DEGREES)), 0),
				_pawn(team, is_user), "%s の駒" % ("自分" if is_user else "相手"))
	_render(BALL_KEY, BALL_TEXTURE_SIZE, BALL_RADIUS_PX, Vector3.ZERO, _ball(), "ボール")


## node を、半径 1 が unit_px に写る正射影で key の絵に描く（見る先 target が絵の真ん中）。光・材質の当て方は駒とボールで共通
func _render(key: Variant, size: Vector2i, unit_px: float, target: Vector3, node: Node3D, label: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	# 1回だけ描く設定（UPDATE_ONCE）では、試合画面を開いた直後だと駒が写る前に止まり、透明な絵になった（2026-11-06）。
	# 駒が写るまで描き続け、写ったら止める
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size.y / unit_px
	var pitch: float = deg_to_rad(PITCH_DEGREES)
	camera.position = target + Vector3(0, sin(pitch), cos(pitch)) * 10.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	environment.ambient_light_energy = 0.35
	camera.environment = environment
	viewport.add_child(camera)
	camera.look_at(target)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.0
	viewport.add_child(light)
	viewport.add_child(node)
	var image: Image = null
	for frame: int in range(MAX_RENDER_FRAMES):
		await RenderingServer.frame_post_draw
		var rendered: Image = viewport.get_texture().get_image()
		if rendered != null and not rendered.is_empty() and rendered.get_used_rect().has_area():
			image = rendered
			break
	viewport.queue_free()
	# 写らないまま上限に達したら、平面の図形のまま（絵を持たない）。実機でだけ起きたときに追えるよう、警告を残す
	if image == null:
		push_warning("PieceSprites: %s が %d フレームで写らなかった（平面の図形で描く）" % [label, MAX_RENDER_FRAMES])
		return
	# 透明な画素の色（黒）が縮めたときに縁へにじまないよう、縁の色を広げてからミップマップを作る
	image.fix_alpha_edges()
	image.generate_mipmaps()
	_textures[key] = ImageTexture.create_from_image(image)
	var board: CanvasItem = get_parent() as CanvasItem
	if board != null:
		# 縮めて置くので、ミップマップで滑らかにする
		board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		board.queue_redraw()


func _pawn(team: Color, is_user: bool) -> MeshInstance3D:
	var profile: PackedVector2Array = profile_points()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(profile.size() - 1):
		var a: Vector2 = profile[index]
		var b: Vector2 = profile[index + 1]
		for segment: int in range(SEGMENTS):
			var t0: float = TAU * segment / SEGMENTS
			# 一周の最後は 0 にそろえる（TAU のままだと sin がわずかにずれ、正面に継ぎ目の線が出た）
			var t1: float = 0.0 if segment + 1 == SEGMENTS else TAU * (segment + 1) / SEGMENTS
			var quad: Array[Vector3] = [Vector3(sin(t0) * a.x, a.y, cos(t0) * a.x), Vector3(sin(t1) * a.x, a.y, cos(t1) * a.x),
					Vector3(sin(t1) * b.x, b.y, cos(t1) * b.x), Vector3(sin(t0) * b.x, b.y, cos(t0) * b.x)]
			var color: Color = color_at(team, is_user, (a.y + b.y) / 2.0, TAU * (segment + 0.5) / SEGMENTS)
			for corner: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(color)
				tool.add_vertex(quad[corner])
	# 同じ位置・同じ色の頂点をまとめてから法線を作る（面ごとに折れず、なめらかな陰になる）
	tool.index()
	tool.generate_normals()
	var pawn := MeshInstance3D.new()
	pawn.mesh = tool.commit()
	pawn.material_override = _glossy_material()
	pawn.add_child(_emblem(is_user))
	return pawn


## 胸の印（自分は丸、相手はひし形）。胴の正面に貼る
func _emblem(is_user: bool) -> MeshInstance3D:
	var emblem := MeshInstance3D.new()
	if is_user:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.13
		cylinder.bottom_radius = 0.13
		cylinder.height = 0.04
		emblem.mesh = cylinder
		emblem.rotation_degrees = Vector3(90, 0, 0)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.18, 0.04)
		emblem.mesh = box
		emblem.rotation_degrees = Vector3(0, 0, 45)
	var material := StandardMaterial3D.new()
	material.albedo_color = _emblem_color
	material.roughness = 0.5
	emblem.material_override = material
	emblem.position = Vector3(0, 1.05, 0.455)
	return emblem


## 駒とボールで共通の光沢のあるプラスチックの材質（色は頂点の色）
func _glossy_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = ROUGHNESS
	material.metallic_specular = 0.7
	return material


## サッカーボール（半径 1 の球）。白地に黒の五角形（on_pentagon）を、最初の五角形がカメラの正面に来るよう回して塗る
func _ball() -> MeshInstance3D:
	var rotation: Quaternion = ball_pattern_rotation().inverse()
	# 五角形の縁がギザギザにならない細かさ（48×96 では、絵を拡大すると縁が段になった）
	var rings: int = 96
	var slices: int = 192
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(rings):
		var lat0: float = PI * ring / rings - PI / 2.0
		var lat1: float = PI * (ring + 1) / rings - PI / 2.0
		for slice: int in range(slices):
			var lon0: float = TAU * slice / slices
			var lon1: float = 0.0 if slice + 1 == slices else TAU * (slice + 1) / slices
			var quad: Array[Vector3] = [_on_sphere(lat0, lon0), _on_sphere(lat0, lon1), _on_sphere(lat1, lon1),
					_on_sphere(lat1, lon0)]
			var middle: Vector3 = _on_sphere((lat0 + lat1) / 2.0, TAU * (slice + 0.5) / slices)
			var color: Color = _emblem_color if on_pentagon(rotation * middle) else _ball_color
			for corner: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(color)
				tool.set_normal(quad[corner])
				tool.add_vertex(quad[corner])
	var ball := MeshInstance3D.new()
	ball.mesh = tool.commit()
	ball.material_override = _glossy_material()
	return ball


static func _on_sphere(latitude: float, longitude: float) -> Vector3:
	return Vector3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))

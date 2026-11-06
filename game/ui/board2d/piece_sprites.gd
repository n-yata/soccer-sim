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

var _colors: Dictionary = {}
## 胸の印の色（テーマの bg。平面のポーンの印と同じ色）
var _emblem_color: Color = Color.BLACK
var _textures: Dictionary = {}


## チーム（自分なら true）の駒の絵。まだ無ければ null（初めて呼ばれたときに、ボードへ描く係を付ける）
static func texture_for(board: Control, is_user: bool) -> Texture2D:
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
				board.add_child(created)
			attach.call_deferred()
		return null
	return sprites._textures.get(is_user) as Texture2D


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


func _ready() -> void:
	# 画面を持たない実行では 3D を描けない（平面のポーンのまま）
	if DisplayServer.get_name() == "headless":
		return
	for is_user: bool in [true, false]:
		_render(is_user)


func _render(is_user: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = TEXTURE_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	# 1回だけ描く設定（UPDATE_ONCE）では、試合画面を開いた直後だと駒が写る前に止まり、透明な絵になった（2026-11-06）。
	# 駒が写るまで描き続け、写ったら止める
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = TEXTURE_SIZE.y / BASE_RADIUS_PX
	var pitch: float = deg_to_rad(PITCH_DEGREES)
	# 地面の原点が絵の FOOT_PX に来るよう、見る先の高さを決める（正射影なので、画面の縦のずれ = 高さ × cos(傾き)）
	var below_center: float = (FOOT_PX.y - TEXTURE_SIZE.y / 2.0) / BASE_RADIUS_PX
	var target := Vector3(0, below_center / cos(pitch), 0)
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
	var team: Color = _colors.get(is_user, Color.WHITE)
	viewport.add_child(_pawn(team, is_user))
	var image: Image = null
	for frame: int in range(MAX_RENDER_FRAMES):
		await RenderingServer.frame_post_draw
		var rendered: Image = viewport.get_texture().get_image()
		if rendered != null and not rendered.is_empty() and rendered.get_used_rect().has_area():
			image = rendered
			break
	viewport.queue_free()
	# 写らないまま上限に達したら、平面のポーンのまま（絵を持たない）。実機でだけ起きたときに追えるよう、警告を残す
	if image == null:
		push_warning("PieceSprites: %s の駒が %d フレームで写らなかった（平面のポーンで描く）" % [
				"自分" if is_user else "相手", MAX_RENDER_FRAMES])
		return
	# 透明な画素の色（黒）が縮めたときに縁へにじまないよう、縁の色を広げてからミップマップを作る
	image.fix_alpha_edges()
	image.generate_mipmaps()
	_textures[is_user] = ImageTexture.create_from_image(image)
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
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = ROUGHNESS
	material.metallic_specular = 0.7
	pawn.material_override = material
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

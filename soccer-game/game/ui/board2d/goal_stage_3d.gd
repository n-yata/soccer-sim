## 試合のカットイン（screen-common.md の GoalCutIn。得点 2026-11-06、ボールを奪った・奪われた 2026-11-08）の3Dの舞台。
## 夜のスタジアム（芝・ライン・観客席・照明）、ゴール（ポスト・バー・網目のネット）、ボール、カメラは基本の形とシェーダーで組み、
## 2人の選手は外部の素材の体（GoalPlayerModel。game/assets/LICENSES.md「3Dモデル・動き」）を置く。
## 2人は場面ごとに、ボールを持つ側（holder: 点を決める選手・ドリブルする選手）と、それを止める側（stopper: キーパー・奪う選手）。
## 動きは場面の関数（得点は GoalCutInArt、シュートを止める場面は SaveCutInArt、奪う場面は StealCutInArt）で決め、set_progress(p) で時刻 p の姿に置く。
## GoalCutIn の SubViewport の中に置く。
class_name GoalStage3D
extends Node3D

## 芝の縞の幅（m）と、観客の数
const STRIPE_WIDTH: float = 5.5
const CROWD_COUNT: int = 2400
## ネットの網目の大きさ（m）
const NET_CELL: float = 0.16
## 背番号（フィールドの選手・キーパー・奪う選手）
const STRIKER_NUMBER: int = 9
const KEEPER_NUMBER: int = 1
const TACKLER_NUMBER: int = 4

## ボールの模様（12 面の五角形の向きに黒い丸）。物体の座標の法線で決めるので、回すと模様も回る
const BALL_SHADER: String = """
shader_type spatial;
varying vec3 object_normal;
void vertex() {
	object_normal = normalize(VERTEX);
}
void fragment() {
	float phi = 1.618034;
	vec3 faces[6] = vec3[](vec3(0.0, 1.0, phi), vec3(0.0, -1.0, phi), vec3(1.0, phi, 0.0), vec3(-1.0, phi, 0.0),
			vec3(phi, 0.0, 1.0), vec3(-phi, 0.0, 1.0));
	float best = 0.0;
	for (int i = 0; i < 6; i++) {
		best = max(best, abs(dot(object_normal, normalize(faces[i]))));
	}
	float patch = step(0.9, best);
	ALBEDO = mix(vec3(0.97), vec3(0.04, 0.05, 0.09), patch);
	ROUGHNESS = 0.45;
}
"""

## ネットの網目（UV の格子の線だけを残す）。bulge と hit（面の座標）で、刺さった点のまわりを面の法線の向きへ押し出す
const NET_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, unshaded, shadows_disabled;
uniform vec2 cells = vec2(24.0, 8.0);
uniform float bulge = 0.0;
uniform vec2 hit = vec2(0.0);
uniform float reach = 1.4;
uniform float depth = 0.5;
void vertex() {
	float d = distance(VERTEX.xz, hit);
	float k = max(0.0, 1.0 - d / reach);
	VERTEX.y -= bulge * depth * k * k;
}
void fragment() {
	vec2 g = fract(UV * cells);
	float line = step(g.x, 0.11) + step(g.y, 0.11);
	if (line < 0.5) {
		discard;
	}
	ALBEDO = vec3(0.92, 0.94, 0.97);
}
"""

var _camera: Camera3D
var _ball: MeshInstance3D
var _back_net: MeshInstance3D
var _net_material: ShaderMaterial
var _kind: GoalCutIn.Kind = GoalCutIn.Kind.GOAL
var _holder: GoalPlayerModel
var _stopper: GoalPlayerModel


## 舞台を組む。kind は場面、is_user は主役の側（得点した側・奪った側）が利用者か。ユニフォームの柄と胸の印でチームを
## 示す（自分は無地で ●、相手は縦じまで ◆。キーパーは長袖とグローブ。NFR-20）。colors は {"you", "opponent": チームの色,
## "keeper_you", "keeper_opponent": キーパーのユニフォームの色, "hair", "boot", "dark", "glove", "number_color"}、
## font は背番号の字。
func build(kind: GoalCutIn.Kind, is_user: bool, colors: Dictionary, font: Font = null) -> void:
	for child: Node in get_children():
		child.free()
	_kind = kind
	var hero: Color = colors["you" if is_user else "opponent"] as Color
	_build_environment()
	_build_pitch()
	_build_stands(hero)
	_build_goal()
	_build_ball()
	# ボールを持つ側は、得点なら主役の側、奪う場面なら奪われた側
	var holder_is_user: bool = is_user if kind == GoalCutIn.Kind.GOAL else not is_user
	var holder: Color = colors["you" if holder_is_user else "opponent"] as Color
	_holder = _add_figure("Holder", colors, font,
			_field_kit(holder, holder_is_user, STRIKER_NUMBER, "dark", GoalPlayerModel.HairStyle.FRINGE))
	var stopper_is_user: bool = not holder_is_user
	if kind == GoalCutIn.Kind.STEAL:
		_stopper = _add_figure("Stopper", colors, font,
				_field_kit(colors["you" if stopper_is_user else "opponent"] as Color, stopper_is_user, TACKLER_NUMBER, "light",
						GoalPlayerModel.HairStyle.SPIKY))
	else:
		var keeper: Color = colors["keeper_you" if stopper_is_user else "keeper_opponent"] as Color
		_stopper = _add_figure("Stopper", colors, font, {"shirt": keeper, "shorts": keeper.darkened(0.6), "sock": keeper,
				"trim": keeper.darkened(0.4), "round_emblem": stopper_is_user, "stripes": false, "number": KEEPER_NUMBER,
				"long_sleeves": true, "glove": colors["glove"], "skin": "light", "hair_style": GoalPlayerModel.HairStyle.MOHAWK})
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.near = 0.05
	_camera.far = 200.0
	add_child(_camera)
	_camera.current = true


func camera() -> Camera3D:
	return _camera


func ball() -> MeshInstance3D:
	return _ball


## ボールを持つ側の選手（点を決める選手・ドリブルする選手）
func holder() -> GoalPlayerModel:
	return _holder


## 止める側の選手（キーパー・奪う選手）
func stopper() -> GoalPlayerModel:
	return _stopper


func kind() -> GoalCutIn.Kind:
	return _kind


## 時刻 p の姿に置く（2人の選手の関節・ボール・ネットのふくらみ・カメラ）。
func set_progress(p: float) -> void:
	if _camera == null:
		return
	var view: Dictionary
	if _kind == GoalCutIn.Kind.STEAL:
		_holder.transform = StealCutInArt.dribbler_transform(p)
		_apply_motion(_holder, StealCutInArt.dribbler_motion(p))
		_stopper.transform = StealCutInArt.tackler_transform(p)
		_apply_motion(_stopper, StealCutInArt.tackler_motion(p))
		_ball.position = StealCutInArt.ball_position(p)
		_ball.rotation_degrees = Vector3(0.0, 30.0, StealCutInArt.ball_spin(p))
		_net_material.set_shader_parameter(&"bulge", 0.0)
		view = StealCutInArt.camera_at(p)
	elif _kind == GoalCutIn.Kind.SAVE:
		_holder.transform = SaveCutInArt.striker_transform(p)
		_apply_motion(_holder, SaveCutInArt.striker_motion(p))
		_stopper.transform = SaveCutInArt.keeper_transform(p)
		_apply_motion(_stopper, SaveCutInArt.keeper_motion(p))
		_ball.position = SaveCutInArt.ball_position(p)
		if SaveCutInArt.ball_in_hands(p):
			# つかんだボールは、キーパーの両手の間
			_ball.position = (_stopper.transform * _stopper.bone_position("hand_l")
					+ _stopper.transform * _stopper.bone_position("hand_r")) / 2.0
		_ball.rotation_degrees = Vector3(0.0, 30.0, SaveCutInArt.ball_spin(p))
		_net_material.set_shader_parameter(&"bulge", 0.0)
		view = SaveCutInArt.camera_at(p)
	else:
		_holder.transform = GoalCutInArt.striker_model_transform(p)
		_apply_motion(_holder, GoalCutInArt.striker_motion(p))
		_stopper.transform = GoalCutInArt.keeper_model_transform(p)
		_apply_motion(_stopper, GoalCutInArt.keeper_motion(p))
		_ball.position = GoalCutInArt.ball_position(p)
		_ball.rotation_degrees = Vector3(0.0, 30.0, GoalCutInArt.ball_spin(p))
		# 舞台の中の座標で計算する（木の外でも動くよう、global の変換を使わない）
		var contact: Vector3 = _back_net.transform.affine_inverse() * GoalCutInArt.net_contact(p)
		_net_material.set_shader_parameter(&"bulge", GoalCutInArt.net_bulge(p))
		_net_material.set_shader_parameter(&"hit", Vector2(contact.x, contact.z))
		view = GoalCutInArt.camera_at(p)
	_camera.fov = view["fov"] as float
	var at: Vector3 = view["position"] as Vector3
	var target: Vector3 = view["target"] as Vector3
	_camera.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)


static func _apply_motion(figure: GoalPlayerModel, motion: Dictionary) -> void:
	figure.set_motion(motion["clip"] as String, motion["time"] as float, motion["pose"] as Dictionary, motion["weight"] as float)
	# 軸足を留める場所は舞台の座標なので、体の空間へ移す
	figure.place_feet(motion["ground"] as float, figure.transform.affine_inverse() * (motion["plant"] as Vector3),
			motion["plant_weight"] as float)


# --- 組み立て ---

## フィールドの選手のユニフォーム（チームの色。自分は無地で ●、相手は縦じまで ◆）と髪型
static func _field_kit(team: Color, is_user_team: bool, number: int, skin: String,
		hair_style: GoalPlayerModel.HairStyle) -> Dictionary:
	return {"shirt": team, "shorts": team.darkened(0.55), "sock": team, "trim": team.darkened(0.45),
			"round_emblem": is_user_team, "stripes": not is_user_team, "number": number, "skin": skin, "hair_style": hair_style}


## 選手を1人組む。kit はユニフォームの色・柄と背番号。髪・スパイク・胸の印・背番号の色は colors から入れる
func _add_figure(node_name: String, colors: Dictionary, font: Font, kit: Dictionary) -> GoalPlayerModel:
	for key: String in ["hair", "boot", "dark", "number_color"]:
		kit[key] = colors[key]
	kit["font"] = font
	var figure := GoalPlayerModel.new()
	figure.name = node_name
	add_child(figure)
	figure.build(kit)
	return figure


func _build_environment() -> void:
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_material.sky_horizon_color = Color(0.12, 0.16, 0.26)
	sky_material.ground_horizon_color = Color(0.1, 0.12, 0.16)
	sky_material.ground_bottom_color = Color(0.02, 0.03, 0.05)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.2, 0.3)
	environment.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.name = "World"
	world.environment = environment
	add_child(world)
	# 照明: 投光器の強い光（影つき）と、反対からの弱い光
	var flood := DirectionalLight3D.new()
	flood.name = "Floodlight"
	flood.light_energy = 1.9
	flood.light_color = Color(1.0, 0.97, 0.9)
	flood.shadow_enabled = true
	flood.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	add_child(flood)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_energy = 0.6
	fill.light_color = Color(0.6, 0.75, 1.0)
	fill.rotation_degrees = Vector3(-25.0, -150.0, 0.0)
	add_child(fill)
	# 選手の前（-x の側。蹴る瞬間と喜ぶカットのカメラの側）からの光。顔と腕が影に沈まないようにする
	var front := DirectionalLight3D.new()
	front.name = "FrontLight"
	front.light_energy = 0.8
	front.light_color = Color(1.0, 0.95, 0.88)
	front.transform = Transform3D(Basis.looking_at(Vector3(1.0, -0.5, 0.35), Vector3.UP), Vector3.ZERO)
	add_child(front)
	# 投光器の塔（遠くの光る板。夜のスタジアムに見せる）
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.98, 0.9)
	var mast := _material(Color(0.08, 0.09, 0.11), 1.0)
	for corner: Vector3 in [Vector3(-16.0, 0.0, -38.0), Vector3(-16.0, 0.0, 38.0), Vector3(42.0, 0.0, -38.0),
			Vector3(42.0, 0.0, 38.0)]:
		_add_box("Mast%s" % corner, corner + Vector3(-0.4, 0.0, -0.4), corner + Vector3(0.4, 24.0, 0.4), mast)
		_add_box("Lamp%s" % corner, corner + Vector3(-2.6, 24.0, -0.6), corner + Vector3(2.6, 27.0, 0.6), lamp)


func _build_pitch() -> void:
	var grass := _material(Color(0.07, 0.25, 0.11), 0.95)
	var stripe := _material(Color(0.09, 0.3, 0.13), 0.95)
	_add_box("Pitch", Vector3(-30.0, -0.05, -30.0), Vector3(90.0, -0.0, 30.0), grass)
	var x: float = -30.0
	var index: int = 0
	while x < 60.0:
		if index % 2 == 0:
			_add_box("Stripe%d" % index, Vector3(x, -0.049, -30.0), Vector3(x + STRIPE_WIDTH, 0.001, 30.0), stripe)
		x += STRIPE_WIDTH
		index += 1
	# ライン: ゴールライン・ゴールエリア・ペナルティエリア・ペナルティマーク
	var line := _material(Color(0.95, 0.95, 0.95), 0.8)
	var w: float = 0.06
	_add_box("GoalLine", Vector3(-w, 0.0, -30.0), Vector3(w, 0.004, 30.0), line)
	for spec: Array in [[5.5, 9.16], [16.5, 20.16]]:
		var depth: float = spec[0]
		var half: float = spec[1]
		_add_box("BoxFront%s" % depth, Vector3(depth - w, 0.0, -half), Vector3(depth + w, 0.004, half), line)
		_add_box("BoxLeft%s" % depth, Vector3(0.0, 0.0, half - w), Vector3(depth, 0.004, half + w), line)
		_add_box("BoxRight%s" % depth, Vector3(0.0, 0.0, -half - w), Vector3(depth, 0.004, -half + w), line)


## 観客席（段になった暗い箱）と観客（小さな箱。色は得点した側のチームの色と、目立たない色を混ぜる）。
## ゴールの裏（-x）と左右（±z）に 5 段ずつ。外へ行くほど高い
func _build_stands(team: Color) -> void:
	var concrete := _material(Color(0.1, 0.11, 0.14), 1.0)
	var rows: Array[Dictionary] = []
	for step: int in range(5):
		var top: float = 1.2 + step * 1.6
		var inner: float = 1.2 * step
		rows.append({"low": Vector3(-9.2 - inner, 0.0, -34.0), "high": Vector3(-8.0 - inner, top, 34.0), "along": "z"})
		rows.append({"low": Vector3(-8.0, 0.0, 30.0 + inner), "high": Vector3(60.0, top, 31.2 + inner), "along": "x"})
		rows.append({"low": Vector3(-8.0, 0.0, -31.2 - inner), "high": Vector3(60.0, top, -30.0 - inner), "along": "x"})
	var crowd := MultiMesh.new()
	crowd.transform_format = MultiMesh.TRANSFORM_3D
	crowd.use_colors = true
	crowd.mesh = _box_mesh(Vector3(0.45, 0.6, 0.35))
	crowd.instance_count = CROWD_COUNT
	var random := RandomNumberGenerator.new()
	random.seed = 20261106
	var palette: Array[Color] = [team, team.lightened(0.2), Color(0.85, 0.85, 0.85), Color(0.25, 0.28, 0.35),
			Color(0.6, 0.15, 0.15), team.darkened(0.3)]
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		_add_box("Stand%d" % index, row["low"] as Vector3, row["high"] as Vector3, concrete)
	for index: int in range(CROWD_COUNT):
		var row: Dictionary = rows[index % rows.size()]
		var low: Vector3 = row["low"] as Vector3
		var high: Vector3 = row["high"] as Vector3
		var t: float = random.randf()
		var center: Vector3 = (low + high) / 2.0
		var position := Vector3(lerpf(low.x, high.x, t), high.y + 0.3, center.z)
		if row["along"] == "z":
			position = Vector3(center.x, high.y + 0.3, lerpf(low.z, high.z, t))
		crowd.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))
		crowd.set_instance_color(index, palette[random.randi_range(0, palette.size() - 1)])
	var crowd_node := MultiMeshInstance3D.new()
	crowd_node.name = "Crowd"
	crowd_node.multimesh = crowd
	var crowd_material := StandardMaterial3D.new()
	crowd_material.vertex_color_use_as_albedo = true
	crowd_material.roughness = 1.0
	crowd_node.material_override = crowd_material
	add_child(crowd_node)


## ゴール: ポスト・バー（白い円柱）、奥の支柱、網目のネット（奥・上・左右）
func _build_goal() -> void:
	var white := _material(Color(0.97, 0.97, 0.97), 0.4)
	var half: float = GoalCutInArt.GOAL_HALF_WIDTH
	var height: float = GoalCutInArt.GOAL_HEIGHT
	var depth: float = GoalCutInArt.GOAL_DEPTH
	for z: float in [-half, half]:
		_add_cylinder("Post%s" % z, Vector3(0.0, 0.0, z), Vector3(0.0, height, z), 0.06, white)
		_add_cylinder("BackPost%s" % z, Vector3(-depth, 0.0, z), Vector3(-depth, height * 0.8, z), 0.03, white)
		_add_cylinder("Stay%s" % z, Vector3(0.0, height, z), Vector3(-depth, height * 0.8, z), 0.03, white)
	_add_cylinder("Crossbar", Vector3(0.0, height, -half), Vector3(0.0, height, half), 0.06, white)
	_net_material = ShaderMaterial.new()
	var net_shader := Shader.new()
	net_shader.code = NET_SHADER
	_net_material.shader = net_shader
	_net_material.set_shader_parameter(&"depth", GoalCutInArt.NET_BULGE_DEPTH)
	# 奥のネット: x = -depth の面（面の法線は +x。ふくらみは -x へ）
	_back_net = _add_net("BackNet", Vector2(height * 0.8, half * 2.0), Vector3(-depth, height * 0.4, 0.0),
			Vector3(0.0, 0.0, 90.0), _net_material)
	_add_net("TopNet", Vector2(depth, half * 2.0), Vector3(-depth / 2.0, height * 0.9, 0.0), Vector3(0.0, 0.0, -5.7),
			_net_material.duplicate() as ShaderMaterial)
	for z: float in [-half, half]:
		_add_net("SideNet%s" % z, Vector2(depth, height * 0.9), Vector3(-depth / 2.0, height * 0.45, z),
				Vector3(90.0, 0.0, 0.0), _net_material.duplicate() as ShaderMaterial)


func _add_net(node_name: String, size: Vector2, position: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 32
	mesh.subdivide_depth = 24
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation_degrees = rotation
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 網目の大きさを面ごとにそろえる（約 NET_CELL m 四方）
	(material as ShaderMaterial).set_shader_parameter(&"cells", size / NET_CELL)
	add_child(node)
	return node


func _build_ball() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = GoalCutInArt.BALL_RADIUS
	mesh.height = GoalCutInArt.BALL_RADIUS * 2.0
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BALL_SHADER
	material.shader = shader
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	_ball.mesh = mesh
	_ball.material_override = material
	add_child(_ball)


func _add_cylinder(node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.transform = GoalCutInArt.bone_transform(from, to)
	add_child(node)


func _add_box(node_name: String, low: Vector3, high: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = _box_mesh((high - low).abs())
	node.material_override = material
	node.position = (low + high) / 2.0
	add_child(node)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

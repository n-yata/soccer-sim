## 得点のカットインの3Dの選手（screen-common.md の GoalCutIn。2026-11-07）。点を決める選手とゴールキーパーに使う。
## 体・髪・動きは Quaternius の素材（CC0。game/assets/LICENSES.md「3Dモデル」）を使う（シャビ「どこかからモデルをとってこれない？」）。
## ユニフォームは素材に無いので、体の基準の姿勢（T ポーズ）での位置で塗り分けるシェーダー（KIT_SHADER）で着せる。
## 動きは、素材の動き（Sprint・Yes など）を時刻で止めて置き、その上から手足の骨を GoalCutInArt の姿勢の向きに向ける
## （素材に無いシュートとキーパーの跳び方を作るため）。
class_name GoalPlayerModel
extends Node3D

const BODY_SCENE: PackedScene = preload("res://assets/models/goal_cut_in/Superhero_Male_FullBody.gltf")
const HAIR_SCENE: PackedScene = preload("res://assets/models/goal_cut_in/Hair_SimpleParted.gltf")
const ANIMATIONS: AnimationLibrary = preload("res://assets/models/goal_cut_in/animations.res")
const SKIN_TEXTURES: Dictionary = {
	"dark": preload("res://assets/models/goal_cut_in/T_Superhero_Male_Dark.png"),
	"light": preload("res://assets/models/goal_cut_in/T_Superhero_Male_Ligh.png"),
}
const NORMAL_TEXTURE: Texture2D = preload("res://assets/models/goal_cut_in/T_Superhero_Male_Normal.png")
const ROUGHNESS_TEXTURE: Texture2D = preload("res://assets/models/goal_cut_in/T_Superhero_Male_Roughness.png")
const BODY_MESH_NAME: String = "SuperHero_Male"

## 骨の向きを変える順（親から子へ）: [骨, 向きを測る子の骨, 姿勢のキー]。姿勢のキーは GoalCutInArt.directions と同じ名前
const AIMED_BONES: Array = [
	["spine_01", "neck_01", "torso"],
	["thigh_l", "calf_l", "stand_thigh"], ["calf_l", "foot_l", "stand_shin"], ["foot_l", "ball_l", "stand_foot"],
	["thigh_r", "calf_r", "kick_thigh"], ["calf_r", "foot_r", "kick_shin"], ["foot_r", "ball_r", "kick_foot"],
	["upperarm_l", "lowerarm_l", "lead_upper"], ["lowerarm_l", "hand_l", "lead_fore"],
	["upperarm_r", "lowerarm_r", "trail_upper"], ["lowerarm_r", "hand_r", "trail_fore"],
]
## 腰・胸を上から見て回す骨、首を倒す骨
const HIPS_BONE: String = "pelvis"
const CHEST_BONE: String = "spine_03"
const HEAD_BONE: String = "Head"
## 首を胸と逆へ回して前を見る割合（胸が回っても顔は進む向きに残る）
const HEAD_COUNTER_TURN: float = 0.6
## 地面に着ける足の骨（足首・指の付け根）と、軸足として留める骨
const FOOT_BONES: Array[String] = ["foot_l", "ball_l", "foot_r", "ball_r"]
const PLANT_FOOT_BONES: Array[String] = ["foot_l", "ball_l"]
const PLANT_BONE: String = "ball_l"

## ユニフォームの塗り分け。UV2 に頂点の基準の姿勢での位置（x = 左右、y = 高さ。m）を入れ、高さと横の位置で部位を決める
## （T ポーズ: 腕は水平で y ≈ 1.46、肩 |x| ≈ 0.21・肘 0.46・手 0.71、膝 y ≈ 0.54、足首 0.09）。
const KIT_SHADER: String = """
shader_type spatial;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform vec3 shirt_color : source_color = vec3(0.3, 0.76, 1.0);
uniform vec3 shorts_color : source_color = vec3(0.1, 0.3, 0.4);
uniform vec3 sock_color : source_color = vec3(0.3, 0.76, 1.0);
uniform vec3 trim_color : source_color = vec3(0.1, 0.3, 0.4);
uniform vec3 boot_color : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 glove_color : source_color = vec3(0.95);
uniform float stripes = 0.0;
uniform float long_sleeves = 0.0;
uniform float gloves = 0.0;
// 丸首の穴（基準の姿勢。首の付け根 y ≈ 1.52）: 高さ NECK_TOP を中心に、横の半径 NECK_HALF_WIDTH・縦の半径 NECK_DEPTH の
// 楕円の内と、その上の首を出す。襟（trim）は楕円の COLLAR_WIDTH 倍の内側まで
const float NECK_HALF_WIDTH = 0.08;
const float NECK_DEPTH = 0.09;
const float NECK_TOP = 1.6;
const float COLLAR_WIDTH = 1.3;
void fragment() {
	float ax = abs(UV2.x);
	float y = UV2.y;
	float boot = step(y, 0.115);
	float sock = (1.0 - boot) * step(y, 0.47);
	float band = sock * step(0.43, y);
	float shorts = step(0.66, y) * step(y, 0.995) * step(ax, 0.3);
	// 胴は肩の上（首の付け根と肩の間）まで覆い、首だけを出す（丸首。肩が出ないように）
	float neck_ring = length(vec2(ax / NECK_HALF_WIDTH, (y - NECK_TOP) / NECK_DEPTH));
	float neck = max(step(neck_ring, 1.0), step(NECK_TOP, y) * step(ax, NECK_HALF_WIDTH));
	float torso = step(0.97, y) * step(y, NECK_TOP) * step(ax, mix(0.235, 0.26, step(1.495, y))) * (1.0 - neck);
	float sleeve_end = mix(0.36, 0.69, long_sleeves);
	float sleeve = step(0.235, ax) * step(ax, sleeve_end) * step(1.3, y);
	float cuff = sleeve * step(sleeve_end - 0.025, ax);
	float collar = torso * step(neck_ring, COLLAR_WIDTH);
	float glove = gloves * step(0.68, ax) * step(1.3, y);
	float shirt = max(torso, sleeve);
	float stripe = stripes * torso * step(0.5, fract((UV2.x + 1.0) * 8.0));
	vec3 color = texture(skin_texture, UV).rgb;
	color = mix(color, mix(shirt_color, trim_color, stripe), shirt);
	color = mix(color, trim_color, max(collar, cuff));
	color = mix(color, shorts_color, shorts);
	color = mix(color, sock_color, sock);
	color = mix(color, trim_color, band);
	color = mix(color, boot_color, boot);
	color = mix(color, glove_color, glove);
	float cloth = clamp(shirt + shorts + sock + boot + glove, 0.0, 1.0);
	ALBEDO = color;
	ROUGHNESS = mix(texture(roughness_texture, UV).g, mix(0.75, 0.35, boot), cloth);
	NORMAL_MAP = mix(texture(normal_texture, UV).rgb, vec3(0.5, 0.5, 1.0), cloth * 0.75);
}
"""

## 基準の姿勢の位置を入れた体の形（素材は固定なので、1回作れば同じものを使い回す。初めての得点で作る分だけ待つ）
static var _dressed_meshes: Dictionary = {}

var _skeleton: Skeleton3D
var _body_material: ShaderMaterial
var _hair_material: StandardMaterial3D


## 選手を組む。kit は {"shirt", "shorts", "sock", "trim", "boot": Color, "glove": Color（透明ならグローブなし）, "stripes": bool,
## "long_sleeves": bool, "round_emblem": bool（自分のチームは丸、相手はひし形。NFR-20）, "number": int, "number_color": Color,
## "dark": Color（胸の印）, "hair": Color, "skin": "dark" か "light", "font": Font}
func build(kit: Dictionary) -> void:
	for child: Node in get_children():
		child.free()
	var body: Node3D = BODY_SCENE.instantiate()
	body.name = "Body"
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_dress(body, kit)
	_add_hair(kit.get("hair", Color(0.25, 0.17, 0.12)) as Color)
	_add_number_and_emblem(kit)


func skeleton() -> Skeleton3D:
	return _skeleton


func body_material() -> ShaderMaterial:
	return _body_material


## 素材の動き clip を時刻 time（秒）で止めて置き、その上から姿勢 pose へ、腰・胸を回し、手足・胴・足の骨を向け、
## 首を倒す（weight（0〜1）の割合で）。pose が空なら素材の動きのまま。pose は角度の辞書（GoalCutInArt.CELEBRATE_POSE
## と同じキー）か、体の空間の向きを持つ辞書（"directions"。GoalCutInArt.kick_frame の形）。
## 動きは AnimationPlayer を使わず、時刻の骨の値を動きの記録から取り出して置く（状態を持たず、同じ時刻なら同じ姿になる）。
func set_motion(clip: String, time: float, pose: Dictionary = {}, weight: float = 0.0) -> void:
	_skeleton.reset_bone_poses()
	var anim: Animation = ANIMATIONS.get_animation(clip)
	var at: float = clamp_time(clip, time)
	for track: int in range(anim.get_track_count()):
		var bone: int = _skeleton.find_bone(str(anim.track_get_path(track)).get_slice(":", 1))
		if bone < 0:
			continue
		match anim.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				_skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(track, at))
			Animation.TYPE_POSITION_3D:
				_skeleton.set_bone_pose_position(bone, anim.position_track_interpolate(track, at))
	if pose.is_empty() or weight <= 0.0:
		return
	var directions: Dictionary = pose["directions"] if pose.has("directions") else GoalCutInArt.model_directions(pose)
	var hips: float = deg_to_rad(pose.get("hips", 0.0) as float) * weight
	var chest: float = deg_to_rad(pose.get("chest", 0.0) as float) * weight
	_turn(HIPS_BONE, Basis(Vector3.UP, hips))
	for spec: Array in AIMED_BONES:
		_aim(spec[0] as String, spec[1] as String, directions[spec[2]] as Vector3, weight)
		if spec[0] == "spine_01":
			_turn(CHEST_BONE, Basis(Vector3.UP, chest))
	# 首: 胸と逆へ少し回して前を見て、体の左右の軸のまわりに前へ倒す
	var facing: float = (hips + chest) * (1.0 - HEAD_COUNTER_TURN)
	var nod: float = deg_to_rad(pose.get("head", 0.0) as float) * weight
	_turn(HEAD_BONE, Basis(Basis(Vector3.UP, facing) * Vector3.RIGHT, nod) * Basis(Vector3.UP, -(hips + chest) * HEAD_COUNTER_TURN))


## 足を地面へ合わせる。低いほうの足（足首・指の付け根の、基準の姿勢の高さからの差が最も小さい骨）が地面に着くまで、
## 体（腰の骨）を上下にずらす（ground の割合で）。軸足を留める間は、低いほうの足の代わりに軸足を地面に着ける
## （蹴り足のつま先が地面すれすれを通っても、軸足が浮かない）。さらに軸足（PLANT_BONE）が plant（体の空間）の真上に
## 来るまで、体を水平にずらす（plant_weight の割合で）。set_motion の後に呼ぶ。
func place_feet(ground: float, plant: Vector3, plant_weight: float) -> void:
	var shift := Vector3.ZERO
	if ground > 0.0:
		var lowest: float = _lowest_foot(FOOT_BONES)
		var planted: float = _lowest_foot(PLANT_FOOT_BONES)
		shift.y = -lerpf(lowest, planted, clampf(plant_weight, 0.0, 1.0)) * ground
	if plant_weight > 0.0:
		var foot: Vector3 = bone_position(PLANT_BONE)
		shift.x = (plant.x - foot.x) * plant_weight
		shift.z = (plant.z - foot.z) * plant_weight
	if shift.is_zero_approx():
		return
	var bone: int = _skeleton.find_bone(HIPS_BONE)
	var parent_basis: Basis = global_bone_pose(_skeleton.get_bone_parent(bone)).basis
	_skeleton.set_bone_pose_position(bone, _skeleton.get_bone_pose_position(bone) + parent_basis.inverse() * shift)


## 動きの長さに収めた時刻（くり返す動きは長さで割った余り）
func clamp_time(clip: String, time: float) -> float:
	var anim: Animation = ANIMATIONS.get_animation(clip)
	if anim.loop_mode != Animation.LOOP_NONE:
		return fposmod(time, anim.length)
	return clampf(time, 0.0, anim.length)


## 骨（体の空間での位置。骨の名前で）。テストと、足とボールの位置合わせに使う
func bone_position(bone_name: String) -> Vector3:
	return global_bone_pose(_skeleton.find_bone(bone_name)).origin


## 骨の体の空間での置き方。置いたばかりの骨の値から親をたどって求める（Skeleton3D.get_bone_global_pose は
## 次の更新まで古い値を返すため）
func global_bone_pose(bone: int) -> Transform3D:
	var pose: Transform3D = _skeleton.get_bone_pose(bone)
	var parent: int = _skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = _skeleton.get_bone_pose(parent) * pose
		parent = _skeleton.get_bone_parent(parent)
	return pose


## bones のうち、基準の姿勢の高さからの差が最も小さい値（m。負なら地面より下）
func _lowest_foot(bones: Array[String]) -> float:
	var lowest: float = INF
	for bone_name: String in bones:
		var bone: int = _skeleton.find_bone(bone_name)
		lowest = minf(lowest, global_bone_pose(bone).origin.y - _skeleton.get_bone_global_rest(bone).origin.y)
	return lowest


## bone を、体の空間で rotation だけ回す（骨の位置のまわりに）
func _turn(bone_name: String, rotation: Basis) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = global_bone_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var new_global: Basis = rotation * global_bone_pose(bone).basis
	_skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_global).get_rotation_quaternion())


## bone を、子の骨 child への向きが direction（体の空間）になるように回す（weight の割合で）。
func _aim(bone_name: String, child_name: String, direction: Vector3, weight: float) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	var child: int = _skeleton.find_bone(child_name)
	var global: Transform3D = global_bone_pose(bone)
	var current: Vector3 = (global_bone_pose(child).origin - global.origin).normalized()
	var target: Vector3 = direction.normalized()
	if current.is_zero_approx() or target.is_zero_approx() or current.dot(target) > 0.99999:
		return
	var turn: Quaternion = Quaternion(current, target) if current.dot(target) > -0.9999 else Quaternion(Vector3.UP, PI)
	turn = Quaternion.IDENTITY.slerp(turn, weight)
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = global_bone_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var new_global: Basis = Basis(turn) * global.basis
	_skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_global).get_rotation_quaternion())


# --- 着せる ---

## 体にユニフォームのシェーダーを着せる。頂点の基準の姿勢での位置を UV2 に入れた形に作り直す
func _dress(body: Node3D, kit: Dictionary) -> void:
	_body_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = KIT_SHADER
	_body_material.shader = shader
	_body_material.set_shader_parameter(&"skin_texture", SKIN_TEXTURES.get(kit.get("skin", "dark"), SKIN_TEXTURES["dark"]))
	_body_material.set_shader_parameter(&"normal_texture", NORMAL_TEXTURE)
	_body_material.set_shader_parameter(&"roughness_texture", ROUGHNESS_TEXTURE)
	for key: String in ["shirt", "shorts", "sock", "trim", "boot"]:
		_body_material.set_shader_parameter(StringName(key + "_color"), kit[key] as Color)
	var glove: Color = kit.get("glove", Color(0, 0, 0, 0)) as Color
	_body_material.set_shader_parameter(&"glove_color", glove)
	_body_material.set_shader_parameter(&"gloves", 1.0 if glove.a > 0.0 else 0.0)
	_body_material.set_shader_parameter(&"stripes", 1.0 if kit.get("stripes", false) else 0.0)
	_body_material.set_shader_parameter(&"long_sleeves", 1.0 if kit.get("long_sleeves", false) else 0.0)
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name == BODY_MESH_NAME:
			if not _dressed_meshes.has(mesh.mesh):
				_dressed_meshes[mesh.mesh] = with_rest_positions(mesh.mesh as ArrayMesh)
			mesh.mesh = _dressed_meshes[mesh.mesh]
			mesh.material_override = _body_material


## 面ごとに、頂点の基準の姿勢での位置（x, y）を UV2 に入れた形を返す（シェーダーがユニフォームの部位を決めるため）。
static func with_rest_positions(source: ArrayMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest: PackedVector2Array = []
		rest.resize(vertices.size())
		for index: int in range(vertices.size()):
			rest[index] = Vector2(vertices[index].x, vertices[index].y)
		arrays[Mesh.ARRAY_TEX_UV2] = rest
		# 骨の重みの数（4 か 8）は元の形に合わせる
		var flags: int = source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


## 髪（頭の骨に付いた形）を体の骨につなぎ、色を付ける
func _add_hair(color: Color) -> void:
	var hair: Node = HAIR_SCENE.instantiate()
	_hair_material = null
	for node: Node in hair.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.name = "Hair"
		copy.mesh = source.mesh
		copy.skin = source.skin
		var material := (source.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.albedo_color = color
		copy.material_override = material
		_hair_material = material
		_skeleton.add_child(copy)
		copy.skeleton = NodePath("..")
	hair.free()


## 背番号（背中）と胸の印（左胸。自分は丸、相手はひし形）を胸の骨に付ける
func _add_number_and_emblem(kit: Dictionary) -> void:
	var chest := BoneAttachment3D.new()
	chest.name = "Chest"
	chest.bone_name = "spine_03"
	_skeleton.add_child(chest)
	# 胸の骨の基準の姿勢から見た位置（体の空間の位置 → 骨の空間）
	var rest: Transform3D = _skeleton.get_bone_global_rest(_skeleton.find_bone("spine_03")).affine_inverse()
	var number := Label3D.new()
	number.name = "Number"
	number.text = str(kit.get("number", 9))
	number.font = kit.get("font") as Font
	number.font_size = 110
	number.pixel_size = 0.0022
	number.modulate = kit.get("number_color", Color.WHITE) as Color
	number.outline_size = 0
	number.double_sided = false
	# 背中（-z）に、後ろから読める向き（Label3D は +z の側から読めるので、y 軸で半回転）
	number.transform = rest * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.3, -0.135))
	chest.add_child(number)
	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	var round_emblem: bool = kit.get("round_emblem", true)
	if round_emblem:
		var dot := CylinderMesh.new()
		dot.top_radius = 0.028
		dot.bottom_radius = 0.028
		dot.height = 0.01
		emblem.mesh = dot
		emblem.transform = rest * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.09, 1.37, 0.125))
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, 0.01)
		emblem.mesh = box
		emblem.transform = rest * Transform3D(Basis(Vector3.FORWARD, PI / 4.0), Vector3(0.09, 1.37, 0.125))
	var material := StandardMaterial3D.new()
	material.albedo_color = kit.get("dark", Color(0.03, 0.05, 0.09)) as Color
	emblem.material_override = material
	chest.add_child(emblem)

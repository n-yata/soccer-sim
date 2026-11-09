## 得点のカットインの3Dの選手（screen-common.md の GoalCutIn。2026-11-07）。点を決める選手とゴールキーパーに使う。
## 骨と動きは Quaternius の素材（CC0。game/assets/LICENSES.md「3Dモデル」）を使う（シャビ「どこかからモデルをとってこれない？」）。
## 見た目は、素材の写実の体を出さず、同じ骨に丸い部品（大きな頭・カプセルの手足）を付けた人形にする
## （2026-11-10。シャビ「通常の盤面がそこまでリアリティないのでもう少しデフォルメしたキャラにしてほしい」）。
## 塗りは2階調（トゥーン）で、部品ごとに黒い輪郭を付ける。脚・腕の長さは骨のまま（足がボールに当たる位置を保つ）。
## 動きは、素材の動き（Sprint・Yes など）を時刻で止めて置き、その上から手足の骨を GoalCutInArt の姿勢の向きに向ける
## （素材に無いシュートとキーパーの跳び方を作るため）。
class_name GoalPlayerModel
extends Node3D

## 髪型（点を決める選手は横に流した前髪、奪いに来る選手はつんつん、キーパーはモヒカン。2026-11-10 シャビ選択）
enum HairStyle { FRINGE, SPIKY, MOHAWK }

const BODY_SCENE: PackedScene = preload("res://assets/models/goal_cut_in/Superhero_Male_FullBody.gltf")
const ANIMATIONS: AnimationLibrary = preload("res://assets/models/goal_cut_in/animations.res")

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

## 人形の大きさ（m）。頭の半径（大きな頭で人形らしくする）、胴・パンツ・手足の太さ
const HEAD_RADIUS: float = 0.3
const TORSO_RADIUS: float = 0.15
const HIPS_RADIUS: float = 0.165
const UPPER_ARM_RADIUS: float = 0.07
const FOREARM_RADIUS: float = 0.06
const HAND_RADIUS: float = 0.075
const THIGH_RADIUS: float = 0.09
const SHIN_RADIUS: float = 0.08
const BOOT_RADIUS: float = 0.065
## 輪郭の太さ（m。部品を外へ膨らませて裏を黒く塗る）と色
const OUTLINE_WIDTH: float = 0.018
const OUTLINE_COLOR: Color = Color(0.07, 0.07, 0.1)
## 肌の色（kit の "skin"）。顔の色
const SKIN_COLORS: Dictionary = {"dark": Color(0.72, 0.5, 0.36), "light": Color(0.98, 0.8, 0.64)}
const EYE_COLOR: Color = Color(0.08, 0.08, 0.1)
const MOUTH_COLOR: Color = Color(0.45, 0.12, 0.12)
const CHEEK_COLOR: Color = Color(1.0, 0.55, 0.55)
## 縦じまの本数（胴を一周して）
const STRIPE_COUNT: int = 8

var _skeleton: Skeleton3D
## 部品の色ごとの材質（"skin", "shirt", "sleeve", "shorts", "sock", "boot", "hand", "hair"）
var _materials: Dictionary = {}


## 選手を組む。kit は {"shirt", "shorts", "sock", "trim", "boot": Color, "glove": Color（透明ならグローブなし）, "stripes": bool,
## "long_sleeves": bool, "round_emblem": bool（自分のチームは丸、相手はひし形。NFR-20）, "number": int, "number_color": Color,
## "dark": Color（胸の印）, "hair": Color, "hair_style": HairStyle, "skin": "dark" か "light", "font": Font}
func build(kit: Dictionary) -> void:
	for child: Node in get_children():
		child.free()
	_materials.clear()
	var body: Node3D = BODY_SCENE.instantiate()
	body.name = "Body"
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# 素材の写実の体は出さない（骨だけを使う）
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		node.free()
	_make_materials(kit)
	_add_head(kit)
	_add_body()
	_add_number_and_emblem(kit)


func skeleton() -> Skeleton3D:
	return _skeleton


## 部品の材質（_materials の名前）。縦じまの胴は、色を albedo_texture に持つ
func part_material(part: String) -> StandardMaterial3D:
	return _materials[part]


## 胴の色。無地なら [シャツの色]、縦じまなら [シャツの色, しまの色]（縦じまは模様の画像から読む）
func shirt_colors() -> Array[Color]:
	var material: StandardMaterial3D = _materials["shirt"]
	if material.albedo_texture == null:
		return [material.albedo_color]
	var image: Image = material.albedo_texture.get_image()
	return [image.get_pixel(0, 0), image.get_pixel(1, 0)]


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


# --- 着せる（人形の部品） ---

## 部品の材質を作る。肌・ユニフォーム（相手は縦じまの胴）・長袖・グローブ・髪
func _make_materials(kit: Dictionary) -> void:
	var skin: Color = SKIN_COLORS.get(kit.get("skin", "dark"), SKIN_COLORS["dark"])
	var shirt: Color = kit["shirt"] as Color
	var glove: Color = kit.get("glove", Color(0, 0, 0, 0)) as Color
	_materials["skin"] = _toon(skin)
	_materials["shirt"] = _toon(shirt)
	# 袖（上腕）は縦じまにしない
	_materials["arm"] = _toon(shirt)
	if kit.get("stripes", false):
		# 胴の周りを一周する縦じま（CapsuleMesh の UV の u が周り）。色は模様のほうに持つ
		var image := Image.create(2, 1, false, Image.FORMAT_RGBF)
		image.set_pixel(0, 0, shirt)
		image.set_pixel(1, 0, kit["trim"] as Color)
		var shirt_material: StandardMaterial3D = _materials["shirt"]
		shirt_material.albedo_color = Color.WHITE
		shirt_material.albedo_texture = ImageTexture.create_from_image(image)
		shirt_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		shirt_material.uv1_scale = Vector3(STRIPE_COUNT, 1.0, 1.0)
	_materials["sleeve"] = _materials["arm"] if kit.get("long_sleeves", false) else _materials["skin"]
	_materials["shorts"] = _toon(kit["shorts"] as Color)
	_materials["sock"] = _toon(kit["sock"] as Color)
	_materials["boot"] = _toon(kit["boot"] as Color)
	_materials["hand"] = _toon(glove) if glove.a > 0.0 else _materials["skin"]
	_materials["hair"] = _toon(kit.get("hair", Color(0.25, 0.17, 0.12)) as Color)


## 頭・顔（大きい目と光・眉・口・ほっぺ）・髪
func _add_head(kit: Dictionary) -> void:
	var r: float = HEAD_RADIUS
	var center: Vector3 = _rest(HEAD_BONE) + Vector3(0.0, r * 0.45, 0.02)
	_add_part("Head", HEAD_BONE, _sphere_mesh(r), Transform3D(Basis.IDENTITY, center), _materials["skin"])
	var eye: float = r * 0.17
	var hair: StandardMaterial3D = _materials["hair"]
	for side: float in [-1.0, 1.0]:
		var at: Vector3 = center + Vector3(side * r * 0.36, -r * 0.08, r * 0.92)
		_add_face(HEAD_BONE, at, Vector3(eye, eye * 1.35, eye * 0.6), EYE_COLOR)
		_add_face(HEAD_BONE, at + Vector3(side * eye * 0.25, eye * 0.45, eye * 0.5), Vector3.ONE * eye * 0.35, Color.WHITE)
		_add_face(HEAD_BONE, center + Vector3(side * r * 0.38, r * 0.2, r * 0.9), Vector3(r * 0.14, r * 0.035, r * 0.05),
				hair.albedo_color)
		_add_face(HEAD_BONE, center + Vector3(side * r * 0.6, -r * 0.35, r * 0.74), Vector3(r * 0.14, r * 0.08, r * 0.05),
				CHEEK_COLOR)
	_add_face(HEAD_BONE, center + Vector3(0.0, -r * 0.42, r * 0.88), Vector3(r * 0.13, r * 0.05, r * 0.06), MOUTH_COLOR)
	_add_hair(kit.get("hair_style", HairStyle.FRINGE) as HairStyle, center, r)


## 髪の部品。どれも頭にかぶせた半球（キャップ）に、髪型ごとの房を足す
func _add_hair(style: HairStyle, center: Vector3, r: float) -> void:
	var hair: StandardMaterial3D = _materials["hair"]
	match style:
		HairStyle.FRINGE:
			_add_cap(center, r, 1.05, -0.2, 0.35, hair)
			# 額へ斜めに流した前髪
			_add_part("Fringe", HEAD_BONE, _sphere_mesh(1.0), Transform3D(Basis(Vector3.BACK, -0.35)
					* Basis.from_scale(Vector3(r * 0.62, r * 0.22, r * 0.25)), center + Vector3(r * 0.25, r * 0.5, r * 0.72)), hair)
			_add_part("Fringe", HEAD_BONE, _sphere_mesh(1.0), Transform3D(Basis(Vector3.BACK, 0.4)
					* Basis.from_scale(Vector3(r * 0.35, r * 0.2, r * 0.25)), center + Vector3(-r * 0.45, r * 0.55, r * 0.6)), hair)
		HairStyle.SPIKY:
			_add_cap(center, r, 1.03, -0.35, 0.3, hair)
			for direction: Vector3 in [Vector3(0, 1, 0.15), Vector3(0.45, 0.9, 0.2), Vector3(-0.45, 0.9, 0.2),
					Vector3(0.25, 0.8, -0.6), Vector3(-0.25, 0.8, -0.6), Vector3(0, 0.6, 0.75), Vector3(0.5, 0.55, 0.6),
					Vector3(-0.5, 0.55, 0.6)]:
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = r * 0.24
				cone.height = r * 0.75
				var along: Vector3 = direction.normalized()
				_add_part("Spike", HEAD_BONE, cone, Transform3D(_along(along), center + along * (r * 0.95 + cone.height * 0.4)), hair)
		HairStyle.MOHAWK:
			# 横は刈り上げ（髪と肌の間の色）、真ん中に前から後ろへ房を立てる
			var shaved := _toon(hair.albedo_color.lerp((_materials["skin"] as StandardMaterial3D).albedo_color, 0.3))
			_add_cap(center, r, 1.012, -0.55, 0.12, shaved)
			for index: int in range(5):
				var angle: float = lerpf(0.9, -0.9, index / 4.0)
				var along := Vector3(0.0, cos(angle), sin(angle))
				_add_part("Crest", HEAD_BONE, _sphere_mesh(1.0), Transform3D(_along(along)
						* Basis.from_scale(Vector3(r * 0.16, r * 0.5, r * 0.3)), center + along * r * 1.12), hair)


## 頭にかぶせる半球。scale は頭に対する大きさ、tilt は前を上げる角度（x 軸まわり）、lift は持ち上げる高さ（頭の半径に対して）
func _add_cap(center: Vector3, r: float, scale: float, tilt: float, lift: float, material: StandardMaterial3D) -> void:
	var cap := SphereMesh.new()
	cap.radius = r * scale
	cap.height = r * scale
	cap.is_hemisphere = true
	_add_part("Hair", HEAD_BONE, cap, Transform3D(Basis(Vector3.RIGHT, tilt), center + Vector3(0.0, r * lift, -r * 0.08)), material)


## 胴・パンツ・手足・スパイク。部品は骨（基準の姿勢）の間に置き、その骨に付けて一緒に動かす
func _add_body() -> void:
	var neck: Vector3 = _rest("neck_01")
	var hips: Vector3 = _rest(HIPS_BONE)
	_add_capsule("Torso", "spine_01", _rest("spine_01") + Vector3(0.0, 0.02, 0.0), neck - Vector3(0.0, 0.06, 0.0), TORSO_RADIUS,
			_materials["shirt"])
	_add_capsule("Shorts", HIPS_BONE, hips + Vector3(0.0, -0.06, 0.0), hips + Vector3(0.0, 0.08, 0.0), HIPS_RADIUS,
			_materials["shorts"])
	for side: String in ["l", "r"]:
		var upper: String = "upperarm_" + side
		var fore: String = "lowerarm_" + side
		var hand: String = "hand_" + side
		var foot: String = "foot_" + side
		_add_capsule("UpperArm", upper, _rest(upper), _rest(fore), UPPER_ARM_RADIUS, _materials["arm"])
		_add_capsule("Forearm", fore, _rest(fore), _rest(hand), FOREARM_RADIUS, _materials["sleeve"])
		var palm: Vector3 = _rest(hand) + (_rest(hand) - _rest(fore)).normalized() * 0.05
		_add_part("Hand", hand, _sphere_mesh(HAND_RADIUS), Transform3D(Basis.IDENTITY, palm), _materials["hand"])
		_add_capsule("Thigh", "thigh_" + side, _rest("thigh_" + side), _rest("calf_" + side), THIGH_RADIUS, _materials["shorts"])
		_add_capsule("Shin", "calf_" + side, _rest("calf_" + side), _rest(foot), SHIN_RADIUS, _materials["sock"])
		_add_capsule("Boot", foot, _rest(foot) + Vector3(0.0, -0.03, -0.03), _rest("ball_" + side) + Vector3(0.0, -0.01, 0.06),
				BOOT_RADIUS, _materials["boot"])


## 背番号（背中）と胸の印（左胸。自分は丸、相手はひし形）を胴の骨に付ける（胴の部品と同じ骨なので、面から離れない）
func _add_number_and_emblem(kit: Dictionary) -> void:
	var chest: Vector3 = _rest(CHEST_BONE)
	var number := Label3D.new()
	number.name = "Number"
	number.text = str(kit.get("number", 9))
	number.font = kit.get("font") as Font
	number.font_size = 110
	number.pixel_size = 0.0018
	number.modulate = kit.get("number_color", Color.WHITE) as Color
	number.outline_size = 0
	number.double_sided = false
	# 背中（-z）に、後ろから読める向き（Label3D は +z の側から読めるので、y 軸で半回転）
	_place("spine_01", number, Transform3D(Basis(Vector3.UP, PI), Vector3(chest.x, chest.y - 0.02, chest.z - TORSO_RADIUS - 0.01)))
	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	var front := Vector3(chest.x + 0.07, chest.y + 0.04, chest.z + TORSO_RADIUS - 0.005)
	if kit.get("round_emblem", true):
		var dot := CylinderMesh.new()
		dot.top_radius = 0.03
		dot.bottom_radius = 0.03
		dot.height = 0.02
		emblem.mesh = dot
		emblem.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), front)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.044, 0.044, 0.02)
		emblem.mesh = box
		emblem.transform = Transform3D(Basis(Vector3.FORWARD, PI / 4.0), front)
	var material := StandardMaterial3D.new()
	material.albedo_color = kit.get("dark", Color(0.03, 0.05, 0.09)) as Color
	emblem.material_override = material
	_place("spine_01", emblem, emblem.transform)


## 骨 bone の基準の姿勢での位置（体の空間）
func _rest(bone: String) -> Vector3:
	return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin


## node を、体の空間の基準の姿勢での置き方 at で、骨 bone に付ける（骨と一緒に動く）
func _place(bone: String, node: Node3D, at: Transform3D) -> void:
	var holder_name: String = "On_" + bone
	var attachment := _skeleton.get_node_or_null(holder_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = holder_name
		attachment.bone_name = bone
		_skeleton.add_child(attachment)
	node.transform = _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).affine_inverse() * at
	# 同じ骨に同じ名前の部品が並ぶときは、読める名前（Fringe2 など）にする
	attachment.add_child(node, true)


## 輪郭を持つ部品を付ける
func _add_part(part_name: String, bone: String, mesh: Mesh, at: Transform3D, material: StandardMaterial3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	# 頭の部品は影を落とさない（大きな頭と髪の影が顔にかかって暗くなるため）
	if bone == HEAD_BONE:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_place(bone, part, at)
	return part


## 顔の部品（目・眉・口・ほっぺ）。小さいので輪郭を付けない。radii は楕円の半径
func _add_face(bone: String, at: Vector3, radii: Vector3, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var part := MeshInstance3D.new()
	part.name = "Face"
	part.mesh = _sphere_mesh(1.0)
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_place(bone, part, Transform3D(Basis.from_scale(radii), at))


## from から to までのカプセル（両端は半球）
func _add_capsule(part_name: String, bone: String, from: Vector3, to: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(from.distance_to(to) + radius * 2.0, radius * 2.0)
	_add_part(part_name, bone, capsule, Transform3D(_along((to - from).normalized()), (from + to) * 0.5), material)


## y 軸が direction を向く向き
static func _along(direction: Vector3) -> Basis:
	var x: Vector3 = direction.cross(Vector3.FORWARD if absf(direction.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, direction, x.cross(direction))


static func _sphere_mesh(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	return sphere


## 2階調の塗りと黒い輪郭（部品を外へ膨らませ、裏面だけを塗る）の材質
static func _toon(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = OUTLINE_COLOR
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = OUTLINE_WIDTH
	material.next_pass = outline
	return material

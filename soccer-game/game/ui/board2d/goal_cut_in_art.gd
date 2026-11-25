## 得点のカットイン（GoalCutIn）の3Dの舞台の動きと時間割（screen-common.md の GoalCutIn。2026-11-06）。
## 夜のスタジアムで、選手が助走してボールを蹴り、ボールがゴールのネットに刺さり、選手が喜ぶ。カメラはカットを割って追う。
## 時刻ごとの値（frame）・選手の姿勢（striker_pose）・ボールの位置（ball_position）・カメラ（camera_at）を関数にし、
## 舞台（GoalStage3D）とテストで同じものを使う。時刻 p は、カットインの経過 / 時間（0〜1）。
## 座標はメートル。ゴールラインが x = 0（ゴールは x < 0 の側）、y が上、ゴールの幅は z の ±GOAL_HALF_WIDTH。
## 選手は -x の向きへ走って蹴る（右足で蹴る。右は -z の側）。
class_name GoalCutInArt
extends RefCounted

## 時間割（p）。白い閃光・映画の帯（上下の黒帯）
const FLASH_START: float = 0.49
const FLASH_END: float = 0.53
const BARS_IN_END: float = 0.06
const EXIT_START: float = 0.92
## インパクトと喜び始め（p）。蹴る動きは、本物の人の蹴りを測った記録（KICK_MOTION）を、インパクトを CONTACT_AT に
## 合わせて KICK_P_PER_SEC の速さで流す（助走の終わり → 踏み込み → インパクト → 振り抜き）
const CONTACT_AT: float = 0.40
const CELEBRATE_AT: float = 0.74
## 蹴る動きの記録の1秒を、p のいくつにするか（カットインの時間の初期値 3.6 秒で、実際の速さの約 0.9 倍）
const KICK_P_PER_SEC: float = 0.25
## 軸足を地面に留める間（インパクトからの秒。記録で軸足の指の付け根が止まっている間）。踏み込みで留め始め、
## 振り抜いて軸足で小さく跳ぶ前に放す
const PLANT_FROM_SEC: float = -0.15
const PLANT_HOLD_FROM_SEC: float = -0.08
const PLANT_HOLD_UNTIL_SEC: float = 0.1
const PLANT_UNTIL_SEC: float = 0.16
## ボール: 足を離れる → ゴールラインを越える → ネットに刺さる → 落ちる
const BALL_START: float = 0.40
const BALL_IN: float = 0.47
const BALL_NET: float = 0.50
const BALL_DROP_END: float = 0.64
## 「GOAL!」の叩きつけ、「得点」とスコアの出、揺れ、ネットのふくらみの戻り
const TITLE_START: float = 0.56
const TITLE_END: float = 0.64
const SUB_START: float = 0.64
const SUB_END: float = 0.72
const SHAKE_LEN: float = 0.08
const NET_SETTLE_END: float = 0.68
## 題の出始めの大きさ、映画の帯の太さ（高さの何倍か）、揺れの大きさ（高さの何倍か。相手の得点は控えめ）
const TITLE_START_SCALE: float = 2.6
const BAR_HEIGHT: float = 0.09
const SHAKE_USER: float = 0.016
const SHAKE_OPPONENT: float = 0.007

## ゴールの寸法（m）
const GOAL_HALF_WIDTH: float = 3.66
const GOAL_HEIGHT: float = 2.44
const GOAL_DEPTH: float = 2.0
## ボールの半径（m）と、置いてある場所（ペナルティマークの少し前）
const BALL_RADIUS: float = 0.11
const BALL_SPOT: Vector3 = Vector3(11.0, 0.11, 0.0)
## ボールが越えるゴールラインの点（左上の隅）、刺さるネットの点、落ちる点
const GOAL_LINE_POINT: Vector3 = Vector3(0.0, 1.9, -2.6)
const NET_POINT: Vector3 = Vector3(-1.89, 1.75, -2.75)
const DROP_POINT: Vector3 = Vector3(-1.5, 0.11, -2.3)
## ネットがふくらむ深さ（m）
const NET_BULGE_DEPTH: float = 0.5
## 助走の始まり（蹴る動きの記録の始まりの位置からの差）
const RUN_FROM: Vector3 = Vector3(2.6, 0.0, 0.8)
## インパクトの瞬間の体の置き場所（ボールからの差）と、軸足（左足の指の付け根）を踏む場所（ボールからの差。ボールの横）
const CONTACT_OFFSET: Vector3 = Vector3(0.014, 0.0, 0.505)
const PLANT_OFFSET: Vector3 = Vector3(-0.31, 0.0, 0.423)
## 蹴る動きの記録（CMU のモーションキャプチャ 11_01 から抜き出した。game/assets/LICENSES.md）。
## 60 fps の各時刻の、体の空間の手足の向き（"torso"・"stand_thigh" など。GoalPlayerModel.AIMED_BONES のキー）、
## 腰・胸のひねりと首の倒れ（度）、腰の水平の位置（インパクトからの差。[左, 前]。m）。"meta" に fps とインパクトの番号
const KICK_MOTION: JSON = preload("res://assets/models/goal_cut_in/kick_motion.json")

## 腕を横へ開く割合（腕の向きに足す横の成分）
const ARM_SPREAD: float = 0.35

## 姿勢の要。角度は度。脚と腕は真下を 0 とし、正なら後ろ（+x）へ回る。胴は真上を 0 とし、正なら後ろへ反る。
## lean は胴を横へ傾ける角度（正なら左 = 軸足の側）。hips・chest は腰・胸を上から見て回す角度（正なら右の側が前へ出る）。
## head は首を前へ倒す角度。stand_foot・kick_foot は足首の角度（すねの向きからの差。FOOT_NEUTRAL で普段の足首、
## 大きいほどつま先が下を向く）。spread は腕を横へ開く割合の上乗せ（lead_spread・trail_spread で腕ごとに決める）。
## 喜び: 両腕を突き上げ、少しかがむ
const CELEBRATE_POSE: Dictionary = {"torso": -4.0, "lean": 0.0, "hips": 0.0, "chest": 0.0, "head": -10.0,
		"stand_thigh": -20.0, "stand_shin": 15.0, "stand_foot": -68.0, "kick_thigh": -10.0, "kick_shin": 25.0, "kick_foot": -68.0,
		"lead_upper": -175.0, "lead_fore": -170.0, "lead_spread": 0.3, "trail_upper": 175.0, "trail_fore": 170.0, "trail_spread": 0.3}
## 普段の足首の角度（すねの向きからの差。素材の体の基準の姿勢で、足首 → 足の指の付け根の向き）
const FOOT_NEUTRAL: float = -68.0
## 足の裏が地面に平らなときの、足首 → 足の指の付け根の向き（真下からの角度。すねが真下なら FOOT_NEUTRAL に近い）
const FOOT_FLAT: float = -62.0
## 助走の1歩の長さ（p）
const RUN_STEP: float = 0.065

## ゴールキーパー（得点された側）。ゴールラインの少し前で構え、ボールの来る隅（-z の側）へ跳ぶが、指先が届かない。
## キーパーは +x を向く（姿勢の空間の向きを y 軸で半回転する）。跳ぶときは、向いている軸（x）のまわりに体を倒す
const KEEPER_SPOT: Vector3 = Vector3(0.6, 0.0, 0.0)
## 構えを深くする（跳ぶ前の踏み込み）・跳び始め・いちばん高い・地面に落ちる時刻（p）
const KEEPER_SET_AT: float = 0.40
const KEEPER_JUMP_AT: float = 0.44
const KEEPER_PEAK_AT: float = 0.53
const KEEPER_LAND_AT: float = 0.64
## 跳んだ先（足元の位置）と、倒れる角度（度。負なら -z の側へ倒れる）
const KEEPER_PEAK: Vector3 = Vector3(0.7, 0.75, -1.25)
const KEEPER_LAND: Vector3 = Vector3(0.7, 0.33, -1.55)
const KEEPER_PEAK_ROLL: float = -78.0
const KEEPER_LAND_ROLL: float = -84.0
## 構え: 膝を曲げて前かがみ、両腕を前で開く
## 足の裏は地面に平ら（足首の角度はすねからの差なので、すねが前へ傾くぶん足首を返す）
const KEEPER_READY_POSE: Dictionary = {"stand_thigh": -35.0, "stand_shin": 30.0, "kick_thigh": -35.0, "kick_shin": 30.0,
		"stand_foot": FOOT_FLAT - 30.0, "kick_foot": FOOT_FLAT - 30.0,
		"torso": -18.0, "lead_upper": -45.0, "lead_fore": -75.0, "trail_upper": -45.0, "trail_fore": -75.0, "spread": 0.55}
## 踏み込み: さらに沈む
const KEEPER_SET_POSE: Dictionary = {"stand_thigh": -55.0, "stand_shin": 45.0, "kick_thigh": -55.0, "kick_shin": 45.0,
		"stand_foot": FOOT_FLAT - 45.0, "kick_foot": FOOT_FLAT - 45.0,
		"torso": -25.0, "lead_upper": -60.0, "lead_fore": -90.0, "trail_upper": -60.0, "trail_fore": -90.0, "spread": 0.6}
## 跳ぶ: 体を伸ばし、両腕を頭の上へ伸ばす（つま先も伸ばす）
const KEEPER_DIVE_POSE: Dictionary = {"stand_thigh": 5.0, "stand_shin": 10.0, "kick_thigh": 20.0, "kick_shin": 35.0,
		"stand_foot": -30.0, "kick_foot": -30.0,
		"torso": 0.0, "lead_upper": -172.0, "lead_fore": -176.0, "trail_upper": -172.0, "trail_fore": -176.0, "spread": 0.05}


# --- 時間割 ---

## 時刻 p の画面の重ねの値。{"flash": 白い閃光の濃さ, "bars": 映画の帯の出（0〜1）, "title_alpha", "title_scale",
## "sub_alpha", "shake": 揺れ（高さの何倍か）, "net": ネットのふくらみ（0〜1）, "fade": 終わりの暗転（0〜1）}
static func frame(p: float, is_user: bool) -> Dictionary:
	var title_t: float = _span(p, TITLE_START, TITLE_END)
	return {
		"flash": _window(p, FLASH_START, FLASH_END) * (1.0 if is_user else 0.0),
		"bars": _ease_out(_span(p, 0.0, BARS_IN_END)),
		"title_alpha": 0.0 if p < TITLE_START else minf(1.0, title_t * 4.0),
		"title_scale": lerpf(TITLE_START_SCALE, 1.0, _ease_out_back(title_t)),
		"sub_alpha": _span(p, SUB_START, SUB_END),
		"shake": _shake(p, is_user),
		"net": net_bulge(p),
		"fade": _ease_in(_span(p, EXIT_START, 1.0)),
	}


## ネットのふくらみ（0〜1）。ボールがゴールラインを越えてから刺さるまでに 1 へ、その後ゆっくり戻る
static func net_bulge(p: float) -> float:
	if p < BALL_IN or p >= NET_SETTLE_END:
		return 0.0
	if p < BALL_NET:
		return _ease_in(_span(p, BALL_IN, BALL_NET))
	return 1.0 - _ease_out(_span(p, BALL_NET, NET_SETTLE_END))


static func _shake(p: float, is_user: bool) -> Vector2:
	if p < BALL_NET or p >= BALL_NET + SHAKE_LEN:
		return Vector2.ZERO
	var t: float = (p - BALL_NET) / SHAKE_LEN
	var amplitude: float = (SHAKE_USER if is_user else SHAKE_OPPONENT) * (1.0 - t)
	return Vector2(sin(t * 53.0), cos(t * 41.0)) * amplitude


## from〜to の間だけ 0 → 1 → 0 と山になる（三角）。外は 0
static func _window(p: float, from: float, to: float) -> float:
	if p <= from or p >= to:
		return 0.0
	return 1.0 - absf((p - from) / (to - from) * 2.0 - 1.0)


static func _span(p: float, from: float, to: float) -> float:
	return clampf((p - from) / (to - from), 0.0, 1.0)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_in(t: float) -> float:
	return t * t * t


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## 少し行き過ぎて戻る（題の叩きつけ）。t = 1 でちょうど 1
static func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


# --- 選手 ---

## 蹴る動きの記録の手足の向きのキー（GoalPlayerModel.AIMED_BONES のキー）
const KICK_KEYS: Array[String] = ["torso", "stand_thigh", "stand_shin", "stand_foot", "kick_thigh", "kick_shin", "kick_foot",
		"lead_upper", "lead_fore", "trail_upper", "trail_fore"]


## 時刻 p の、インパクトからの秒（蹴る動きの記録の時刻）
static func kick_sec(p: float) -> float:
	return (p - CONTACT_AT) / KICK_P_PER_SEC


## 蹴る動きの記録の始まりと終わり（p）
static func kick_start() -> float:
	var meta: Dictionary = KICK_MOTION.data["meta"]
	return CONTACT_AT - (meta["contact_index"] as float) / (meta["fps"] as float) * KICK_P_PER_SEC


static func kick_end() -> float:
	var meta: Dictionary = KICK_MOTION.data["meta"]
	var last: float = (KICK_MOTION.data["hips"] as Array).size() - 1.0
	return CONTACT_AT + (last - (meta["contact_index"] as float)) / (meta["fps"] as float) * KICK_P_PER_SEC


## 蹴る動きの記録の、インパクトから sec 秒の姿勢（前後の記録の間を補間する。記録の外は端の値）。
## {"directions": {KICK_KEYS: 体の空間の向き}, "hips", "chest", "head": 度, "root": 腰の水平の位置（体の空間。m）}
static func kick_frame(sec: float) -> Dictionary:
	var data: Dictionary = KICK_MOTION.data
	var meta: Dictionary = data["meta"]
	var count: int = (data["hips"] as Array).size()
	var at: float = clampf(sec * (meta["fps"] as float) + (meta["contact_index"] as float), 0.0, count - 1.0)
	var i: int = floori(at)
	var j: int = mini(i + 1, count - 1)
	var t: float = at - i
	var directions: Dictionary = {}
	for key: String in KICK_KEYS:
		directions[key] = _vec(data[key][i]).lerp(_vec(data[key][j]), t).normalized()
	var root: Vector2 = Vector2(data["root"][i][0], data["root"][i][1]).lerp(Vector2(data["root"][j][0], data["root"][j][1]), t)
	return {
		"directions": directions,
		"hips": lerpf(data["hips"][i], data["hips"][j], t),
		"chest": lerpf(data["chest"][i], data["chest"][j], t),
		"head": lerpf(data["head"][i], data["head"][j], t),
		"root": Vector3(root.x, 0.0, root.y),
	}


static func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


## 時刻 p の点を決める選手の姿勢（kick_frame と同じ形）。蹴る間は記録、その後は finish の姿勢（得点なら喜びの
## CELEBRATE_POSE、止められたら SaveCutInArt.DEJECTED_POSE）へ CELEBRATE_AT までに移る
static func striker_pose(p: float, finish: Dictionary = CELEBRATE_POSE) -> Dictionary:
	var end: float = kick_end()
	if p <= end:
		return kick_frame(kick_sec(p))
	return blend_frames(kick_frame(kick_sec(end)), pose_frame(finish), _smooth(_span(p, end, CELEBRATE_AT)))


## 喜びの姿勢を kick_frame と同じ形にしたもの
static func celebrate_frame() -> Dictionary:
	return pose_frame(CELEBRATE_POSE)


## 角度の姿勢 pose を kick_frame と同じ形にしたもの
static func pose_frame(pose: Dictionary) -> Dictionary:
	return {"directions": model_directions(pose), "hips": pose.get("hips", 0.0) as float, "chest": pose.get("chest", 0.0) as float,
			"head": pose.get("head", 0.0) as float, "root": Vector3.ZERO}


## kick_frame の形の姿勢どうしの補間（向きは正規化した線形補間。腰の位置は from のまま）
static func blend_frames(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var directions: Dictionary = {}
	for key: String in KICK_KEYS:
		directions[key] = ((from["directions"][key] as Vector3).lerp(to["directions"][key] as Vector3, t)).normalized()
	var frame: Dictionary = {"directions": directions, "root": from["root"]}
	for key: String in ["hips", "chest", "head"]:
		frame[key] = lerpf(from[key] as float, to[key] as float, t)
	return frame


## 角度の姿勢どうしの補間（キーパー）
static func _blend(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var pose: Dictionary = {}
	for key: String in from:
		pose[key] = lerpf(from[key] as float, to[key] as float, t)
	return pose


## 体の空間の水平の位置（[左, 前]）を、舞台の向きにする（選手は -x を向き、左が +z）
static func _striker_world(offset: Vector3) -> Vector3:
	return Vector3(-offset.z, 0.0, offset.x)


## 選手の体の置き場所（足元の地面）。蹴る間は、記録の腰の水平の動きのとおりに動く（インパクトで CONTACT_OFFSET の
## 場所）。助走の間は RUN_FROM の分だけ後ろから、記録の始まりの速さにつながるように近づく。喜ぶときは小さく跳ぶ。
static func striker_root(p: float) -> Vector3:
	var contact: Vector3 = BALL_SPOT * Vector3(1.0, 0.0, 1.0) + CONTACT_OFFSET
	var start: float = kick_start()
	var root: Vector3
	if p < start:
		var first: Vector3 = _striker_world(kick_frame(kick_sec(start))["root"] as Vector3)
		var step: float = 1.0 / 60.0
		var next: Vector3 = _striker_world(kick_frame(kick_sec(start) + step)["root"] as Vector3)
		# 記録の始まりの速さ（p あたり）を、助走の長さあたりにする
		var arrive: Vector3 = (next - first) / (step * KICK_P_PER_SEC) * start
		root = _hermite(contact + first + RUN_FROM, contact + first, -RUN_FROM, arrive, _span(p, 0.0, start))
	else:
		root = contact + _striker_world(kick_frame(kick_sec(minf(p, kick_end())))["root"] as Vector3)
	if p > CELEBRATE_AT:
		root.y += 0.28 * absf(sin(PI * 2.0 * _span(p, CELEBRATE_AT, 1.0)))
	return root


## from から to へ、始まりの速さ leave・終わりの速さ arrive（t あたり）でつなぐ曲線の t の位置
static func _hermite(from: Vector3, to: Vector3, leave: Vector3, arrive: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return from * (2.0 * t3 - 3.0 * t2 + 1.0) + leave * (t3 - 2.0 * t2 + t) + to * (3.0 * t2 - 2.0 * t3) + arrive * (t3 - t2)


## 軸足（左足の指の付け根）を踏む場所（地面の高さ）
static func plant_spot() -> Vector3:
	return BALL_SPOT * Vector3(1.0, 0.0, 1.0) + PLANT_OFFSET


## 軸足を地面に留める割合（0〜1）
static func plant_weight(p: float) -> float:
	var sec: float = kick_sec(p)
	return _smooth(_span(sec, PLANT_FROM_SEC, PLANT_HOLD_FROM_SEC)) * (1.0 - _smooth(_span(sec, PLANT_HOLD_UNTIL_SEC, PLANT_UNTIL_SEC)))


# --- ゴールキーパー ---

## 時刻 p のキーパーの姿勢（CELEBRATE_POSE と同じ角度のキー。無いキーは directions の決まり）。構え → 踏み込み → 跳ぶ（体を伸ばす）。
static func keeper_pose(p: float) -> Dictionary:
	if p <= KEEPER_SET_AT:
		var sway: Dictionary = KEEPER_READY_POSE.duplicate()
		# 構えの間は、膝で小さく弾む
		var bounce: float = sin(p * TAU * 6.0) * 4.0
		sway["stand_thigh"] = (sway["stand_thigh"] as float) - bounce
		sway["kick_thigh"] = (sway["kick_thigh"] as float) - bounce
		return sway
	if p <= KEEPER_JUMP_AT:
		return _blend(KEEPER_READY_POSE, KEEPER_SET_POSE, _smooth(_span(p, KEEPER_SET_AT, KEEPER_JUMP_AT)))
	return _blend(KEEPER_SET_POSE, KEEPER_DIVE_POSE, _ease_out(_span(p, KEEPER_JUMP_AT, KEEPER_PEAK_AT)))


## 時刻 p のキーパーの体の置き方（足元の位置と向き・倒れ方）。-x を向く姿勢の空間に掛ける（keeper_model_transform）。
static func keeper_transform(p: float) -> Transform3D:
	var facing := Basis(Vector3.UP, PI)
	var at: Vector3 = KEEPER_SPOT
	var roll: float = 0.0
	if p > KEEPER_JUMP_AT and p <= KEEPER_PEAK_AT:
		var t: float = _ease_out(_span(p, KEEPER_JUMP_AT, KEEPER_PEAK_AT))
		at = KEEPER_SPOT.lerp(KEEPER_PEAK, t)
		roll = KEEPER_PEAK_ROLL * t
	elif p > KEEPER_PEAK_AT:
		var t: float = _span(p, KEEPER_PEAK_AT, KEEPER_LAND_AT)
		at = KEEPER_PEAK.lerp(KEEPER_LAND, t)
		at.y = lerpf(KEEPER_PEAK.y, KEEPER_LAND.y, t * t)
		roll = lerpf(KEEPER_PEAK_ROLL, KEEPER_LAND_ROLL, t)
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(roll)) * facing, at)


## 姿勢 pose の手足・胴・足の向き（姿勢の空間: 前が -x、左が +z。長さ 1）。キーは姿勢の角度の名前
## （"torso", "stand_thigh", "stand_shin", "stand_foot", "kick_thigh", "kick_shin", "kick_foot", "lead_upper", "lead_fore",
##  "trail_upper", "trail_fore"）。無いキーは、横への傾き・足首は普段の向き、腕の開きは spread で決める。
static func directions(pose: Dictionary) -> Dictionary:
	var left := Vector3(0.0, 0.0, 1.0)
	var spread: float = pose.get("spread", 0.0) as float
	var lead_spread: float = ARM_SPREAD + (pose.get("lead_spread", spread) as float)
	var trail_spread: float = ARM_SPREAD + (pose.get("trail_spread", spread) as float)
	var stand_shin: float = pose["stand_shin"] as float
	var kick_shin: float = pose["kick_shin"] as float
	return {
		"torso": _up(pose["torso"] as float, pose.get("lean", 0.0) as float),
		"stand_thigh": _limb(pose["stand_thigh"] as float),
		"stand_shin": _limb(stand_shin),
		"stand_foot": _limb(stand_shin + (pose.get("stand_foot", FOOT_NEUTRAL) as float)),
		"kick_thigh": _limb(pose["kick_thigh"] as float),
		"kick_shin": _limb(kick_shin),
		"kick_foot": _limb(kick_shin + (pose.get("kick_foot", FOOT_NEUTRAL) as float)),
		"lead_upper": _arm(pose["lead_upper"] as float, left * lead_spread),
		"lead_fore": _arm(pose["lead_fore"] as float, left * lead_spread),
		"trail_upper": _arm(pose["trail_upper"] as float, -left * trail_spread),
		"trail_fore": _arm(pose["trail_fore"] as float, -left * trail_spread),
	}


## 真下を 0 とし、正なら後ろ（+x）へ回る向き（脚）
static func _limb(degrees: float) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	return Vector3(sin(angle), -cos(angle), 0.0)


## 腕: 脚と同じ回り方に、横へ開く成分 side を足して長さ 1 にした向き
static func _arm(degrees: float, side: Vector3) -> Vector3:
	return (_limb(degrees) + side).normalized()


## 真上を 0 とし、正なら後ろ（+x）へ反り、lean が正なら左（+z）へ傾く向き（胴）
static func _up(degrees: float, lean: float = 0.0) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	var side: float = deg_to_rad(lean)
	return Vector3(sin(angle) * cos(side), cos(angle) * cos(side), sin(side))


## a から b へ伸びる骨の置き方（中点に置き、Y 軸を骨の向きに合わせ、Y の大きさを骨の長さにする）。
## 長さ 1 のカプセル・円柱をこの変換で置くと、a と b を結ぶ。
static func bone_transform(a: Vector3, b: Vector3) -> Transform3D:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.0001:
		return Transform3D(Basis.IDENTITY, a)
	var y: Vector3 = along / length
	var helper: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Transform3D(Basis(x, y * length, z), (a + b) / 2.0)


# --- 3Dの選手の動き（GoalPlayerModel） ---

## 素材の動きの速さ（p が 1 進むと何秒分進めるか）。助走の Sprint は1歩 RUN_STEP ごとに半周する速さ、喜びの Yes は
## 喜び始めてから終わりまでで動きの終わりまで進む
const SPRINT_RATE: float = 0.66666 / (RUN_STEP * 2.0)
const CELEBRATE_RATE: float = 2.5 / (1.0 - CELEBRATE_AT)
## 骨の向きを姿勢へ切り替える長さ（p）
const MOTION_BLEND: float = 0.04


## 体の空間の向き（素材の体は +z を向き、左が +x）。姿勢の向き（姿勢の空間: 選手は -x を向き、左が +z）を写す
static func model_direction(skeleton_direction: Vector3) -> Vector3:
	return Vector3(skeleton_direction.z, skeleton_direction.y, -skeleton_direction.x)


## 姿勢 pose の手足・胴・足の向き（体の空間）。キーは directions と同じ（GoalPlayerModel.AIMED_BONES）
static func model_directions(pose: Dictionary) -> Dictionary:
	var along: Dictionary = directions(pose)
	for key: String in along:
		along[key] = model_direction(along[key] as Vector3)
	return along


## 時刻 p の点を決める選手の動き {"clip": 素材の動き, "time": その秒, "pose": 骨を向ける姿勢, "weight": 向ける割合,
## "ground": 低いほうの足を地面に着ける割合, "plant": 軸足を留める場所（舞台の座標）, "plant_weight": 留める割合}。
## 助走は Sprint、蹴る間は記録の手足の向き（Idle の上から）、喜ぶときは Yes。"pose" は striker_pose の形。
static func striker_motion(p: float) -> Dictionary:
	var start: float = kick_start()
	var motion: Dictionary = {"clip": "Sprint", "time": p * SPRINT_RATE, "pose": {}, "weight": 0.0,
			"ground": 0.0, "plant": plant_spot(), "plant_weight": plant_weight(p)}
	if p < start - MOTION_BLEND:
		return motion
	if p < CELEBRATE_AT:
		var weight: float = _smooth(_span(p, start - MOTION_BLEND, start))
		if weight >= 0.5:
			motion["clip"] = "Idle"
			motion["time"] = 0.0
		motion["pose"] = striker_pose(p)
		motion["weight"] = weight
		motion["ground"] = weight
		return motion
	var fade: float = 1.0 - _smooth(_span(p, CELEBRATE_AT, CELEBRATE_AT + MOTION_BLEND))
	motion.merge({"clip": "Yes", "time": (p - CELEBRATE_AT) * CELEBRATE_RATE, "pose": striker_pose(p), "weight": fade,
			"ground": fade}, true)
	return motion


## 時刻 p のキーパーの動き（striker_motion と同じ形）。構え・踏み込み・跳ぶ姿勢を、Idle の上から骨の向きで作る。
## 跳ぶまでは足を地面に着ける
static func keeper_motion(p: float) -> Dictionary:
	return {"clip": "Idle", "time": 0.0, "pose": keeper_pose(p), "weight": 1.0,
			"ground": 1.0 - _smooth(_span(p, KEEPER_JUMP_AT, KEEPER_JUMP_AT + MOTION_BLEND)),
			"plant": Vector3.ZERO, "plant_weight": 0.0}


## 3Dの選手の体の置き方（素材の体は +z を向くので、-x を向くよう y 軸で回す）
static func striker_model_transform(p: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI / 2.0), striker_root(p))


## キーパーの体の置き方（keeper_transform は -x を向く姿勢に掛けるので、体を -x へ向けてから掛ける）
static func keeper_model_transform(p: float) -> Transform3D:
	return keeper_transform(p) * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3.ZERO)


# --- ボール ---

## 時刻 p のボールの中心。蹴る前は置いた場所、蹴ったら曲がりながらゴールの隅へ、ネットに刺さってふくらみの分だけ奥へ、
## その後ゴールの中に落ちる。
static func ball_position(p: float) -> Vector3:
	if p < BALL_START:
		return BALL_SPOT
	if p < BALL_IN:
		var t: float = _ease_out(_span(p, BALL_START, BALL_IN)) * 0.85 + _span(p, BALL_START, BALL_IN) * 0.15
		var control := Vector3(5.0, 2.7, 0.4)
		return BALL_SPOT.lerp(control, t).lerp(control.lerp(GOAL_LINE_POINT, t), t)
	if p < BALL_NET:
		return GOAL_LINE_POINT.lerp(net_contact(p), _span(p, BALL_IN, BALL_NET))
	if p < BALL_DROP_END:
		var t: float = _span(p, BALL_NET, BALL_DROP_END)
		var from: Vector3 = net_contact(BALL_NET)
		var at: Vector3 = from.lerp(DROP_POINT, t)
		at.y = lerpf(from.y, DROP_POINT.y, t * t)
		return at
	return DROP_POINT


## ネットに当たっているボールの位置（ネットのふくらみの分だけ奥）
static func net_contact(p: float) -> Vector3:
	return NET_POINT + Vector3(-NET_BULGE_DEPTH * net_bulge(maxf(p, BALL_NET - 0.0001)), 0.0, 0.0)


## ボールの回転（度。進む向きに転がる）。飛んでいる間は速く回る
static func ball_spin(p: float) -> float:
	return 2400.0 * _span(p, BALL_START, BALL_DROP_END)


# --- カメラ ---

## カットの並び。各要素は {"until": このカットが終わる p, "from": 始まりの {"position", "target"}, "to": 終わりの値,
## "follow": 何を追うか（"striker"・"ball"・""。追うものの位置を from・to に足す）, "fov": 画角}
const SHOTS: Array[Dictionary] = [
	# 1. 助走を横から低く追う
	{"until": 0.30, "follow": "striker", "fov": 42.0,
			"from": {"position": Vector3(-1.2, 0.55, 4.6), "target": Vector3(0.0, 0.95, 0.0)},
			"to": {"position": Vector3(-1.9, 0.45, 3.6), "target": Vector3(0.0, 0.9, 0.0)}},
	# 2. 蹴る瞬間を、ボールの前から低く寄る（大きな頭の上まで全身が入る）
	{"until": 0.43, "follow": "", "fov": 50.0,
			"from": {"position": Vector3(8.2, 0.55, 2.4), "target": Vector3(11.5, 1.0, 0.1)},
			"to": {"position": Vector3(8.5, 0.5, 2.2), "target": Vector3(11.4, 0.95, 0.1)}},
	# 3. 飛ぶボールを望遠で追ってパンする
	{"until": 0.48, "follow": "ball", "fov": 26.0,
			"from": {"position": Vector3(8.0, 1.0, 3.0), "target": Vector3.ZERO},
			"to": {"position": Vector3(7.6, 1.1, 3.0), "target": Vector3.ZERO}},
	# 4. ゴールの裏から、ネットに刺さる瞬間
	{"until": 0.72, "follow": "", "fov": 44.0,
			"from": {"position": Vector3(-5.6, 1.5, -4.6), "target": Vector3(-1.0, 1.4, -2.4)},
			"to": {"position": Vector3(-5.0, 1.35, -4.2), "target": Vector3(-1.0, 1.3, -2.4)}},
	# 5. 喜ぶ選手を前から回り込む（全身が入る）
	{"until": 1.01, "follow": "striker", "fov": 40.0,
			"from": {"position": Vector3(-4.8, 1.3, 1.6), "target": Vector3(0.0, 1.15, 0.0)},
			"to": {"position": Vector3(-4.4, 1.1, -1.4), "target": Vector3(0.0, 1.15, 0.0)}},
]


## 時刻 p のカメラ {"position", "target", "fov", "shot": カットの番号}。カットの中では from → to へ滑らかに動き、
## カットの変わり目では切り替える（つながない）。
static func camera_at(p: float) -> Dictionary:
	var start: float = 0.0
	for index: int in range(SHOTS.size()):
		var shot: Dictionary = SHOTS[index]
		var until: float = shot["until"] as float
		if p < until or index == SHOTS.size() - 1:
			var t: float = _smooth(_span(p, start, minf(until, 1.0)))
			var from: Dictionary = shot["from"] as Dictionary
			var to: Dictionary = shot["to"] as Dictionary
			var base := Vector3.ZERO
			var look := Vector3.ZERO
			match shot["follow"] as String:
				"striker":
					base = striker_root(p)
					look = base
				"ball":
					base = Vector3.ZERO
					look = ball_position(p)
			return {
				"position": base + (from["position"] as Vector3).lerp(to["position"] as Vector3, t),
				"target": look + (from["target"] as Vector3).lerp(to["target"] as Vector3, t),
				"fov": shot["fov"] as float,
				"shot": index,
			}
		start = until
	return {}


# --- 文 ---

## カットインの文。{"title": 「GOAL!」（相手の得点は「GOAL」）, "sub": 「得点」か「失点」, "score": 「● 1 − 0 ◆」（新しいスコア）}
static func texts(is_user: bool, score_user: int, score_opponent: int) -> Dictionary:
	return {
		"title": "GOAL!" if is_user else "GOAL",
		"sub": "得点" if is_user else "失点",
		"score": "● %d %s %d ◆" % [score_user, MatchTexts.MINUS_SIGN, score_opponent],
	}

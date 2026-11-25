## ボールを奪った・奪われたときのカットイン（トランジションの始まり。2026-11-08）の3Dの舞台の動きと時間割。
## ドリブルしている選手（ボールを持つ側）に、相手の選手（奪う側）が横からスライディングでボールを奪い、ドリブルしていた選手は
## つまずいて前へ転がる。時刻 p は、カットインの経過 / 時間（0〜1）。舞台（GoalStage3D）とテストで同じ関数を使う。
## 座標はメートル（GoalCutInArt と同じ舞台。ゴールは x < 0 の側）。奪う場所はゴールから離れた CONTACT_POINT。
## ドリブルする選手は -x へ走り、奪う選手は +z の側から斜めに滑り込む。
class_name StealCutInArt
extends RefCounted

## 時間割（p）。映画の帯・白い閃光・題・文・暗転
const BARS_IN_END: float = 0.08
const SLIDE_AT: float = 0.24
const CONTACT_AT: float = 0.42
const TRIP_AT: float = 0.45
const FLASH_START: float = 0.42
const FLASH_END: float = 0.47
const TITLE_START: float = 0.46
const TITLE_END: float = 0.56
const SUB_START: float = 0.56
const SUB_END: float = 0.66
const SHAKE_LEN: float = 0.08
const EXIT_AT: float = 0.74
const FADE_START: float = 0.9
## 題の出始めの大きさ、揺れの大きさ（高さの何倍か。奪われたときは控えめ）
const TITLE_START_SCALE: float = 2.4
const SHAKE_USER: float = 0.012
const SHAKE_OPPONENT: float = 0.005

## ボールを奪う点（地面）。ゴールから離れた中盤
const CONTACT_POINT: Vector3 = Vector3(30.0, 0.0, 0.0)
## ドリブルする選手の走る向き（-x）と、体の前のボールまでの距離（m）、走る速さ（m / p）
const DRIBBLE_DIRECTION: Vector3 = Vector3(-1.0, 0.0, 0.0)
const BALL_AHEAD: float = 0.6
const DRIBBLE_SPEED: float = 11.0
## つまずいて前へ転がる距離（m）
const ROLL_DISTANCE: float = 2.6
## 奪う選手の滑り込む向き（+z の側から斜めに）と、近づく速さ（m / p）・ボールに触れた後に滑る距離（m）
const SLIDE_DIRECTION: Vector3 = Vector3(-0.42, 0.0, -0.91)
const TACKLE_SPEED: float = 13.0
const SLIDE_ON: float = 1.1
## 滑り込んだ姿勢で、体の空間の先に出る足（右足の指の付け根）の位置（素材の Slide の姿勢で測った値）
const TACKLE_FOOT: Vector3 = Vector3(-0.06, 0.0, 1.04)
## 奪われたボールが転がる向きと距離（m）、跳ねる高さ（m）
const BALL_AWAY: Vector3 = Vector3(-0.5, 0.0, -0.87)
const BALL_AWAY_DISTANCE: float = 3.2
const BALL_HOP: float = 0.35

## 素材の動きの速さ（p が 1 進むと何秒分進めるか）。Sprint は走る速さに合わせ、Slide_Start は滑り込んで触れる瞬間に
## 滑る姿勢になる速さ、Roll と Slide_Exit は終わりまでで動きの終わりになる速さ
const SPRINT_RATE: float = 2.2
const SLIDE_START_RATE: float = 0.48 / (CONTACT_AT - SLIDE_AT)
const ROLL_RATE: float = 1.4 / (FADE_START - TRIP_AT)
const EXIT_RATE: float = 0.5 / (FADE_START - EXIT_AT)
const BALL_RADIUS: float = GoalCutInArt.BALL_RADIUS


# --- 時間割 ---

## 時刻 p の画面の重ねの値（GoalCutInArt.frame と同じキー。ネットは使わないので 0）。is_user は利用者が奪った側か
static func frame(p: float, is_user: bool) -> Dictionary:
	var title_t: float = _span(p, TITLE_START, TITLE_END)
	return {
		"flash": _window(p, FLASH_START, FLASH_END) * (1.0 if is_user else 0.0),
		"bars": _ease_out(_span(p, 0.0, BARS_IN_END)),
		"title_alpha": 0.0 if p < TITLE_START else minf(1.0, title_t * 4.0),
		"title_scale": lerpf(TITLE_START_SCALE, 1.0, _ease_out_back(title_t)),
		"sub_alpha": _span(p, SUB_START, SUB_END),
		"shake": _shake(p, is_user),
		"net": 0.0,
		"fade": _ease_in(_span(p, FADE_START, 1.0)),
	}


## カットインの文。{"title": 奪った「BALL WON!」・奪われた「BALL LOST」, "sub": 始まる局面, "score": 下の帯の一言}
static func texts(is_user: bool) -> Dictionary:
	return {
		"title": "BALL WON!" if is_user else "BALL LOST",
		"sub": "ポジティブトランジション" if is_user else "ネガティブトランジション",
		"score": "● ボールを奪った" if is_user else "● ボールを失った",
	}


static func _shake(p: float, is_user: bool) -> Vector2:
	if p < CONTACT_AT or p >= CONTACT_AT + SHAKE_LEN:
		return Vector2.ZERO
	var t: float = (p - CONTACT_AT) / SHAKE_LEN
	var amplitude: float = (SHAKE_USER if is_user else SHAKE_OPPONENT) * (1.0 - t)
	return Vector2(sin(t * 53.0), cos(t * 41.0)) * amplitude


# --- ドリブルする選手（奪われる側） ---

## 時刻 p のドリブルする選手の足元。触れる瞬間まで一定の速さで走り、つまずいてから前へ転がって止まる
static func dribbler_root(p: float) -> Vector3:
	var at_contact: Vector3 = CONTACT_POINT - DRIBBLE_DIRECTION * BALL_AHEAD
	if p <= TRIP_AT:
		return at_contact - DRIBBLE_DIRECTION * DRIBBLE_SPEED * (CONTACT_AT - p)
	var trip: Vector3 = at_contact + DRIBBLE_DIRECTION * DRIBBLE_SPEED * (TRIP_AT - CONTACT_AT)
	return trip + DRIBBLE_DIRECTION * ROLL_DISTANCE * _ease_out(_span(p, TRIP_AT, FADE_START))


static func dribbler_transform(p: float) -> Transform3D:
	return Transform3D(_facing(DRIBBLE_DIRECTION), dribbler_root(p))


## 時刻 p のドリブルする選手の動き（GoalCutInArt.striker_motion と同じ形）。走って（Sprint）、つまずいて前へ転がる（Roll）
static func dribbler_motion(p: float) -> Dictionary:
	if p < TRIP_AT:
		return _clip("Sprint", p * SPRINT_RATE)
	return _clip("Roll", (p - TRIP_AT) * ROLL_RATE)


# --- 奪う選手 ---

## 時刻 p の奪う選手の足元。走って近づき、滑り込み、ボールに触れる瞬間に先に出した足がボールの所に来る。触れた後は
## SLIDE_ON だけ滑って止まる
static func tackler_root(p: float) -> Vector3:
	var along: Vector3 = SLIDE_DIRECTION.normalized()
	var at_contact: Vector3 = CONTACT_POINT - _facing(along) * TACKLE_FOOT
	if p <= CONTACT_AT:
		return at_contact - along * TACKLE_SPEED * (CONTACT_AT - p)
	return at_contact + along * SLIDE_ON * _ease_out(_span(p, CONTACT_AT, EXIT_AT))


static func tackler_transform(p: float) -> Transform3D:
	return Transform3D(_facing(SLIDE_DIRECTION), tackler_root(p))


## 時刻 p の奪う選手の動き。走って（Sprint）、滑り込み（Slide_Start。触れる瞬間に滑る姿勢）、立ち上がる（Slide_Exit）
static func tackler_motion(p: float) -> Dictionary:
	if p < SLIDE_AT:
		return _clip("Sprint", p * SPRINT_RATE)
	if p < EXIT_AT:
		return _clip("Slide_Start", (p - SLIDE_AT) * SLIDE_START_RATE)
	return _clip("Slide_Exit", (p - EXIT_AT) * EXIT_RATE)


## 素材の動きだけで動かす（骨を向けない。足は素材のまま）
static func _clip(clip: String, time: float) -> Dictionary:
	return {"clip": clip, "time": time, "pose": {}, "weight": 0.0, "ground": 0.0, "plant": Vector3.ZERO, "plant_weight": 0.0}


## 素材の体（+z を向く）を、舞台の向き direction へ向ける回転
static func _facing(direction: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(direction.x, direction.z))


# --- ボール ---

## 時刻 p のボールの中心。触れるまではドリブルする選手の前で小さく弾み、触れたら BALL_AWAY へ跳ねて転がる
static func ball_position(p: float) -> Vector3:
	var lift := Vector3(0.0, BALL_RADIUS, 0.0)
	if p <= CONTACT_AT:
		var touch: float = absf(sin(p * TAU * 5.0)) * 0.06
		return dribbler_root(p) + DRIBBLE_DIRECTION * BALL_AHEAD + lift + Vector3(0.0, touch, 0.0)
	var t: float = _span(p, CONTACT_AT, FADE_START)
	var along: Vector3 = BALL_AWAY.normalized() * BALL_AWAY_DISTANCE * _ease_out(t)
	var hop: float = BALL_HOP * maxf(0.0, sin(PI * _span(p, CONTACT_AT, CONTACT_AT + 0.12)))
	return CONTACT_POINT + lift + along + Vector3(0.0, hop, 0.0)


## ボールの回転（度）
static func ball_spin(p: float) -> float:
	return 900.0 * p + 1500.0 * _span(p, CONTACT_AT, FADE_START)


# --- カメラ ---

## 時刻 p のカメラ {"position", "target", "fov", "shot"}。低い位置から横に追い、触れる瞬間に寄る
static func camera_at(p: float) -> Dictionary:
	var follow: float = _smooth(_span(p, 0.0, CONTACT_AT))
	var target := Vector3(lerpf(CONTACT_POINT.x + 3.0, CONTACT_POINT.x - 0.3, follow), 0.55, CONTACT_POINT.z + 0.4)
	var push: float = _smooth(_span(p, CONTACT_AT - 0.08, CONTACT_AT + 0.1))
	var offset: Vector3 = Vector3(1.6, 0.75, -5.6).lerp(Vector3(1.1, 0.6, -4.2), push)
	return {"position": target + offset, "target": target, "fov": 42.0, "shot": 0}


# --- 補間 ---

static func _span(p: float, from: float, to: float) -> float:
	return clampf((p - from) / (to - from), 0.0, 1.0)


static func _window(p: float, from: float, to: float) -> float:
	if p <= from or p >= to:
		return 0.0
	return 1.0 - absf((p - from) / (to - from) * 2.0 - 1.0)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_in(t: float) -> float:
	return t * t * t


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

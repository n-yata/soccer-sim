## シュートを止めた・止められたときのカットイン（トランジションの始まり。2026-11-08）の3Dの舞台の動きと時間割。
## 得点のカットイン（GoalCutInArt）と同じ選手の蹴りを、蹴る直前から短く見せ、キーパーが跳んでボールをつかむ。
## 蹴った選手は、喜ぶ代わりにうなだれる。時刻 p は、カットインの経過 / 時間（0〜1）。
## 得点の時間割の goal_p（GoalCutInArt の時刻）へ goal_p = SAVE_FROM + p * SAVE_SPAN で写して、蹴り・キーパー・カメラを使う。
class_name SaveCutInArt
extends RefCounted

## 得点の時間割のどこから、どれだけを見せるか（初期値の 1.8 秒で、得点の 3.6 秒と同じ速さになる長さ）
const SAVE_FROM: float = 0.31
const SAVE_SPAN: float = 0.5
## キーパーがボールをつかむ時刻（得点の時間割で）
const CATCH_AT_GOAL: float = 0.5
## ボールをつかむ点（得点の時間割の CATCH_AT_GOAL での、キーパーの両手の間。素材の体で測った値）
const CATCH_POINT: Vector3 = Vector3(0.66, 1.17, -2.97)
## 時間割（p）。白い閃光・題・文・暗転。帯は得点と同じ
const BARS_IN_END: float = 0.08
const FLASH_LEN: float = 0.05
const TITLE_LEN: float = 0.1
const SUB_LEN: float = 0.1
const FADE_START: float = 0.9
const TITLE_START_SCALE: float = 2.4
const SHAKE_LEN: float = 0.08
const SHAKE_USER: float = 0.012
const SHAKE_OPPONENT: float = 0.005
## 止められた選手の姿勢: 胴を前へ倒し、首を垂れ、腕を下ろす（角度の決まりは GoalCutInArt の姿勢と同じ）
const DEJECTED_POSE: Dictionary = {"torso": -18.0, "lean": 0.0, "hips": 0.0, "chest": 0.0, "head": 45.0,
		"stand_thigh": -8.0, "stand_shin": 6.0, "stand_foot": GoalCutInArt.FOOT_FLAT - 6.0, "kick_thigh": 4.0, "kick_shin": 10.0,
		"kick_foot": GoalCutInArt.FOOT_FLAT - 10.0, "lead_upper": -8.0, "lead_fore": -25.0, "lead_spread": -0.15,
		"trail_upper": -8.0, "trail_fore": -25.0, "trail_spread": -0.15}


## 得点の時間割の時刻
static func goal_p(p: float) -> float:
	return SAVE_FROM + clampf(p, 0.0, 1.0) * SAVE_SPAN


## ボールをつかむ時刻（p）
static func catch_at() -> float:
	return (CATCH_AT_GOAL - SAVE_FROM) / SAVE_SPAN


# --- 時間割 ---

## 時刻 p の画面の重ねの値（GoalCutInArt.frame と同じキー）。is_user は利用者が止めた側か。題はボールをつかんでから
static func frame(p: float, is_user: bool) -> Dictionary:
	var caught: float = catch_at()
	var title_t: float = _span(p, caught + 0.02, caught + 0.02 + TITLE_LEN)
	var sub_start: float = caught + 0.02 + TITLE_LEN
	var shake := Vector2.ZERO
	if p >= caught and p < caught + SHAKE_LEN:
		var t: float = (p - caught) / SHAKE_LEN
		shake = Vector2(sin(t * 53.0), cos(t * 41.0)) * (SHAKE_USER if is_user else SHAKE_OPPONENT) * (1.0 - t)
	return {
		"flash": _window(p, caught, caught + FLASH_LEN) * (1.0 if is_user else 0.0),
		"bars": _ease_out(_span(p, 0.0, BARS_IN_END)),
		"title_alpha": 0.0 if p < caught + 0.02 else minf(1.0, title_t * 4.0),
		"title_scale": lerpf(TITLE_START_SCALE, 1.0, _ease_out_back(title_t)),
		"sub_alpha": _span(p, sub_start, sub_start + SUB_LEN),
		"shake": shake,
		"net": 0.0,
		"fade": _ease_in(_span(p, FADE_START, 1.0)),
	}


## カットインの文。{"title": 止めた「SAVE!」・止められた「SAVED」, "sub": 始まる局面, "score": 下の帯の一言}
static func texts(is_user: bool) -> Dictionary:
	return {
		"title": "SAVE!" if is_user else "SAVED",
		"sub": "ポジティブトランジション" if is_user else "ネガティブトランジション",
		"score": "● シュートを止めた" if is_user else "● シュートを止められた",
	}


# --- 蹴る選手（止められる側） ---

## 喜んで跳ばないよう、得点の時間割の喜び始めで止めた置き場所
static func striker_transform(p: float) -> Transform3D:
	return GoalCutInArt.striker_model_transform(minf(goal_p(p), GoalCutInArt.CELEBRATE_AT))


## 蹴るまでは得点と同じ。蹴った後は、喜ぶ代わりにうなだれる（DEJECTED_POSE。素材の Yes は使わない）
static func striker_motion(p: float) -> Dictionary:
	var g: float = goal_p(p)
	if g < GoalCutInArt.kick_end():
		return GoalCutInArt.striker_motion(g)
	var motion: Dictionary = GoalCutInArt.striker_motion(minf(g, GoalCutInArt.CELEBRATE_AT - 0.0001))
	motion.merge({"clip": "Idle", "time": 0.0, "pose": GoalCutInArt.striker_pose(g, DEJECTED_POSE), "weight": 1.0,
			"ground": 1.0}, true)
	return motion


# --- キーパー（止める側） ---

static func keeper_transform(p: float) -> Transform3D:
	return GoalCutInArt.keeper_model_transform(goal_p(p))


static func keeper_motion(p: float) -> Dictionary:
	return GoalCutInArt.keeper_motion(goal_p(p))


# --- ボール ---

## 時刻 p のボールの中心。蹴るまでは置いた場所、蹴ったら曲がりながら CATCH_POINT（キーパーの手）へ。つかんだ後は
## キーパーの両手の間（舞台が手の位置に置く。ball_in_hands）
static func ball_position(p: float) -> Vector3:
	var g: float = goal_p(p)
	if g < GoalCutInArt.BALL_START:
		return GoalCutInArt.BALL_SPOT
	var t: float = _span(g, GoalCutInArt.BALL_START, CATCH_AT_GOAL)
	var control := Vector3(5.5, 2.2, -0.6)
	return GoalCutInArt.BALL_SPOT.lerp(control, t).lerp(control.lerp(CATCH_POINT, t), t)


## キーパーがボールをつかんでいるか（舞台がボールを両手の間に置く）
static func ball_in_hands(p: float) -> bool:
	return goal_p(p) >= CATCH_AT_GOAL


static func ball_spin(p: float) -> float:
	return 2400.0 * _span(goal_p(p), GoalCutInArt.BALL_START, CATCH_AT_GOAL)


# --- カメラ ---

static func camera_at(p: float) -> Dictionary:
	return GoalCutInArt.camera_at(goal_p(p))


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


static func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

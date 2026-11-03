## 開示の1拍目（プレー）のボールの軌道（screen-common.md の TacticsBoard）。手の種類で、ボールの進み方と高さを変える。
## 見せ方だけの区分なので UI 層に置く（判定には使わない。2026-11-03）。
class_name BallFlight
extends RefCounted

## STRAIGHT はまっすぐ等速（手が無い・ボールを運ばない手、2拍目）。GROUND はグラウンダー（蹴り出しが速く、着くときに緩む）、
## LOFTED は浮き球（弧を描く）、CARRIED はドリブル（駒と同じ速さで、小さく弾む）、DRIVEN は強いシュート（はじめに一気に進む）
enum Kind { STRAIGHT, GROUND, LOFTED, CARRIED, DRIVEN }

const PLAY_KINDS: Dictionary = {
	GameEnums.PlayType.SHORT_PASS: Kind.GROUND,
	GameEnums.PlayType.THROUGH_PASS: Kind.GROUND,
	GameEnums.PlayType.LONG_BEHIND: Kind.LOFTED,
	GameEnums.PlayType.SWITCH: Kind.LOFTED,
	GameEnums.PlayType.DRIBBLE: Kind.CARRIED,
	GameEnums.PlayType.SHOT: Kind.DRIVEN,
}


## 手の軌道の種類。攻撃の手は表のとおり、カウンターはグラウンダー。ほか（守備・喪失側・保持）と null はまっすぐ。
static func kind_for(choice: TurnChoice) -> Kind:
	if choice == null:
		return Kind.STRAIGHT
	if choice.family == GameEnums.ChoiceFamily.ATTACK:
		return PLAY_KINDS.get(choice.action, Kind.STRAIGHT) as Kind
	if choice.family == GameEnums.ChoiceFamily.POS_TRANS and choice.action == GameEnums.PosTransAction.COUNTER:
		return Kind.GROUND
	return Kind.STRAIGHT


## ボールを持つ側の手（攻撃の手か、トランジションで奪った側の手）。どちらの手でもなければ null。
static func holder_choice(reveal: RevealView) -> TurnChoice:
	for choice: TurnChoice in [reveal.user_choice, reveal.opponent_choice]:
		if choice != null and choice.family in [GameEnums.ChoiceFamily.ATTACK, GameEnums.ChoiceFamily.POS_TRANS]:
			return choice
	return null


## 拍の進み具合 t（0〜1）のときの、道筋に沿った進み具合（0〜1）。範囲の外の t は端に留める（Tween の端数で道筋の外へ出ない）。
static func along(kind: Kind, t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	match kind:
		Kind.GROUND:
			return 1.0 - pow(1.0 - x, 2.0)
		Kind.DRIVEN:
			return 1.0 - pow(1.0 - x, 3.0)
	return x


## 拍の進み具合 t のときのボールの高さ（ボールの半径の何倍か。地面は 0）。style は {"loft", "touch", "touches"}
## （MatchController.ball_style()）。始めと終わりは地面。
static func lift(kind: Kind, t: float, style: Dictionary) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	match kind:
		Kind.LOFTED:
			return (style.get("loft", 0.0) as float) * 4.0 * x * (1.0 - x)
		Kind.CARRIED:
			var touches: int = style.get("touches", 1) as int
			return (style.get("touch", 0.0) as float) * absf(sin(touches * PI * x))
	return 0.0

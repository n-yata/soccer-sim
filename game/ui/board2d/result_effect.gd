## 開示の1拍目の終わりに盤面に出す、ターンの結果の演出（screen-common.md の TacticsBoard）。
## 見せ方だけの区分なので UI 層に置く（BallFlight と同じ考え方。2026-11-03）。
class_name ResultEffect
extends RefCounted

## GOAL はゴールが決めた側の色で光る、SAVE は GK の位置に止めた側の色の輪、WIN_BALL は奪った場所に奪った側の色の輪、
## OFFSIDE は受け手の場所に守備側の色の旗、STALL はボールの跳ね返り（盤面の印は出さない）
enum Kind { NONE, GOAL, SAVE, WIN_BALL, OFFSIDE, STALL }


## 開示の結果の演出 {"kind": Kind, "area": エリアのキー, "is_user": 色の側が利用者か, "toward": 跳ね返る運ぶ先のキー}。
## 色の側は、その結果で成功した側（MatchTexts.turn_winner）。演出の無い結果は kind が NONE で、area と toward は空。
static func for_reveal(reveal: RevealView) -> Dictionary:
	var is_user: bool = MatchTexts.turn_winner(reveal) == MatchTexts.TurnWinner.USER
	match reveal.outcome:
		GameEnums.TurnOutcome.GOAL:
			return _effect(Kind.GOAL, reveal.ball_after, is_user)
		GameEnums.TurnOutcome.SAVE:
			return _effect(Kind.SAVE, reveal.ball_after, is_user)
		GameEnums.TurnOutcome.LOSS, GameEnums.TurnOutcome.REGAIN:
			return _effect(Kind.WIN_BALL, reveal.ball_after, is_user)
		GameEnums.TurnOutcome.OFFSIDE:
			return _effect(Kind.OFFSIDE, reveal.compare_area, is_user)
		GameEnums.TurnOutcome.STALL:
			var holder: TurnChoice = BallFlight.holder_choice(reveal)
			if holder != null and holder.target != null:
				var effect: Dictionary = _effect(Kind.STALL, reveal.ball_after, is_user)
				effect["toward"] = holder.target.to_key()
				return effect
	return {"kind": Kind.NONE, "area": "", "is_user": false, "toward": ""}


## 結果に合わせて、拍のボールの道筋を変える（BoardShift.build_beats の直後、動きの無い拍を取り除く前に呼ぶ。beats は
## keyframes と同じ並び）。GOAL は1拍目をゴールの口への強いシュートにし、2拍目をゴールの口から始める（2拍目にボールの道筋が
## 無ければ、ゴールの口からいまの位置 ball_now への道筋を作る）。STALL は1拍目を運ぶ先の方への跳ね返りにする。
## ball_point はエリアのキー → ボールの位置、goal_mouth は is_top → ゴールの口（TacticsBoard の問い合わせ）。
static func shape_ball_paths(beats: Array[Dictionary], keyframes: Array[Dictionary], result: Dictionary,
		ball_now: String, ball_point: Callable, goal_mouth: Callable) -> void:
	if beats.is_empty() or result.is_empty():
		return
	var start_key: String = keyframes[0]["ball"] as String
	if PitchArea.from_key(start_key) == null:
		return
	var start: Vector2 = ball_point.call(start_key) as Vector2
	match result["kind"] as Kind:
		Kind.GOAL:
			var goal: Vector2 = goal_mouth.call(result["is_user"] as bool) as Vector2
			beats[0]["ball_path"] = {"from": start, "to": goal, "flight": BallFlight.Kind.DRIVEN}
			if beats.size() > 1:
				var kickoff: Dictionary = beats[1]["ball_path"] as Dictionary
				if not kickoff.is_empty():
					kickoff["from"] = goal
				elif PitchArea.from_key(ball_now) != null:
					beats[1]["ball_path"] = {"from": goal, "to": ball_point.call(ball_now) as Vector2}
		Kind.STALL:
			# 膠着ではボールは動かない（判定前と判定後が同じエリア）ので、跳ね返りは1拍目の始まりの位置から始めて同じ位置へ戻る
			var toward: String = result["toward"] as String
			if PitchArea.from_key(toward) != null:
				beats[0]["ball_path"] = {"from": start, "to": ball_point.call(toward) as Vector2,
						"flight": BallFlight.Kind.BOUNCE}


## 演出として盤面に印を描く種類か（STALL はボールの跳ね返りだけ、NONE は何も出さない）。
static func draws_mark(result: Dictionary) -> bool:
	return not result.is_empty() and (result["kind"] as Kind) in [Kind.GOAL, Kind.SAVE, Kind.WIN_BALL, Kind.OFFSIDE]


## 場所に印を描く種類で、場所が読めなければ演出を出さない（輪や旗が盤面の左上に出るのを防ぐ）。得点はゴールに描くので場所を問わない。
static func _effect(kind: Kind, area: String, is_user: bool) -> Dictionary:
	if kind != Kind.GOAL and PitchArea.from_key(area) == null:
		return {"kind": Kind.NONE, "area": "", "is_user": false, "toward": ""}
	return {"kind": kind, "area": area, "is_user": is_user, "toward": ""}

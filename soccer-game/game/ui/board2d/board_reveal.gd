## 作戦ボードの開示の進行（screen-common.md §5 の TacticsBoard）。拍を順に動かす Tween、1拍目の着地、結果の演出の
## 状態と Tween を持つ。ボード（TacticsBoard）の子ノードで、拍の組み立て（いまの盤面と位置の計算が要る）はボードが行い、
## 組み立てた拍を start で受け取る。Tween はノードが作るので、状態（BoardShift）と分けてここに置く（2026-11-03 にボードから分けた）。
class_name BoardReveal
extends Node

## 開示の1拍目（プレー）が終わった（1拍目が無ければ start の中ですぐ、途中で止めたらそのとき）。1回の開示で1回だけ
signal landed
## 描き直しが要る（拍・進み具合・演出が変わった）
signal changed

## 開示の動きの状態（拍の並び・いまの拍・進み具合・ボールの軌道の値）。ボードの問い合わせが読む
var shift := BoardShift.new()
## 出している結果の演出（ResultEffect.for_reveal の値。出していなければ空）と、その進み具合（0〜1）
var effect: Dictionary = {}
var effect_progress: float = 0.0

var _shift_tween: Tween
## 開示の結果と、1拍目がまだ着地していないか
var _result: Dictionary = {}
var _landing_pending: bool = false
## 結果の演出を出す時間（秒）。0 以下なら演出を出さない（時間を入れない盤面、振り返りなど）
var _result_sec: float = 0.0
var _effect_tween: Tween
## 拍と拍の間の小休止（秒）。0 なら置かない
var _beat_gap_sec: float = 0.0
## "wait" の拍の前で止まっているか、止まる前に再開を頼まれたか（得点のカットインの間。2026-11-06）
var _waiting: bool = false
var _resumed: bool = false


## 拍（BoardShift.build_beats の値。ResultEffect.shape_ball_paths で結果に合わせた後）を順に動かし、1拍目が終わったら
## 着地を知らせて結果の演出を出す。前の動き・演出は止める。
func start(beats: Array[Dictionary], result: Dictionary) -> void:
	stop()
	clear_effect()
	shift.start(beats)
	_result = result.duplicate()
	_landing_pending = true
	if not shift.is_active() or (shift.beats[0]["keyframe"] as int) != 0:
		_land()
	if not shift.is_active():
		return
	_shift_tween = create_tween()
	for index: int in range(shift.beats.size()):
		if shift.beats[index].get("wait", false) as bool:
			_shift_tween.tween_callback(_wait)
		_shift_tween.tween_callback(_begin_beat.bind(index))
		_shift_tween.tween_method(_set_progress, 0.0, 1.0, shift.beats[index]["sec"] as float)
		if (shift.beats[index]["keyframe"] as int) == 0:
			_shift_tween.tween_callback(_land)
		# 着地（テロップ・結果の演出）は小休止を待たない。小休止は拍と拍の間だけ（最後の拍の後には置かない）
		if index < shift.beats.size() - 1 and _beat_gap_sec > 0.0:
			_shift_tween.tween_interval(_beat_gap_sec)
	_shift_tween.finished.connect(stop)


## 動きを止める（次の盤面・重ね表示の消去で呼ぶ。前のターンの動きを残さない）。1拍目の前に止めたら、着地だけを知らせる
## （テロップを出し忘れない。演出は出さない）。
func stop() -> void:
	_waiting = false
	_resumed = false
	if _shift_tween != null:
		_shift_tween.kill()
		_shift_tween = null
	shift.clear()
	if _landing_pending:
		_landing_pending = false
		landed.emit()
	changed.emit()


## "wait" の拍の前で止めた動きを再開する。止まる前に呼ばれたら、止まらずに進む。動いていなければ何もしない。
func resume() -> void:
	if _shift_tween == null:
		return
	_resumed = true
	if _waiting:
		_waiting = false
		_shift_tween.play()


## "wait" の拍の前で止める（Tween の中から呼ぶ。再開を先に頼まれていれば止めない）。
func _wait() -> void:
	if _resumed:
		_resumed = false
		return
	_waiting = true
	_shift_tween.pause()


## 結果の演出を消す。
func clear_effect() -> void:
	if _effect_tween != null:
		_effect_tween.kill()
		_effect_tween = null
	effect = {}
	effect_progress = 0.0
	changed.emit()


## 結果の演出を出す時間（秒）。有限でない値は 0（演出を出さない）として扱う（無限大だと演出が消えなくなる）。
func set_result_sec(sec: float) -> void:
	_result_sec = sec if is_finite(sec) else 0.0


## 拍と拍の間の小休止（秒）。有限でない値・負の値は 0（置かない）として扱う。
func set_beat_gap_sec(sec: float) -> void:
	_beat_gap_sec = sec if is_finite(sec) and sec > 0.0 else 0.0


func beat_gap_sec() -> float:
	return _beat_gap_sec


## 1拍目の着地。結果の演出を始め、着地を知らせる（1回の開示で1回だけ）。
func _land() -> void:
	if not _landing_pending:
		return
	_landing_pending = false
	if ResultEffect.draws_mark(_result) and _result_sec > 0.0 and is_inside_tree():
		effect = _result.duplicate()
		effect_progress = 0.0
		_effect_tween = create_tween()
		_effect_tween.tween_method(_set_effect_progress, 0.0, 1.0, _result_sec)
		_effect_tween.finished.connect(clear_effect)
	landed.emit()


func _begin_beat(index: int) -> void:
	shift.begin_beat(index)
	changed.emit()


func _set_progress(progress: float) -> void:
	shift.progress = progress
	changed.emit()


func _set_effect_progress(progress: float) -> void:
	effect_progress = progress
	changed.emit()

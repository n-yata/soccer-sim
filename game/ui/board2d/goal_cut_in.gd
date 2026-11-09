## 試合のカットイン（screen-common.md の GoalCutIn）。盤面パネル（MatchBoardPanel）の上に重ね、開示の1拍目の着地で play する。
## 場面（Kind）は、得点（2026-11-06。選手が蹴り、ボールがネットに刺さり、選手が喜ぶ）と、ボールを奪った・奪われた（2026-11-08。
## トランジションの始まり。スライディングでボールを奪う）。3Dの舞台（GoalStage3D）を SubViewport に写し、その上に映画の帯・題・
## 上の帯の文・下の帯の文（得点はスコア）・白い閃光を重ねる。
## 自動で消え、押すとすぐ消える。終わり・飛ばし・止めのどれでも finished を1回出す（パネルが盤面の2拍目を再開する）。
## 舞台は play で組み、終わったら消す（出していない間に3Dを描かない。描く先の画も最小にして、全画面の分を持たない）。
## 動きと時間割は GoalCutInArt。色は TacticsBoard のテーマの色（得点した側のチームの色）と、GoalCutIn のテーマの色
## （髪・キーパーのユニフォーム・グローブ）。
class_name GoalCutIn
extends Control

## カットインが終わった（自動で消えた・押して飛ばした・止めた）。1回の play で1回だけ
signal finished

## 場面: 得点・シュートを止めた・ボールを奪った（トランジションの始まり）
enum Kind { GOAL, SAVE, STEAL }

const THEME_TYPE: StringName = &"TacticsBoard"
## 髪・キーパーのユニフォーム・グローブの色は、カットインだけのテーマの種類に置く（盤面の駒は顔を描かない）
const OWN_THEME_TYPE: StringName = &"GoalCutIn"
## 文字のフォントの種類（Barlow Condensed Bold）と大きさ（高さの何倍か）
const TITLE_FONT_TYPE: StringName = &"DisplayHeading"
const TITLE_SIZE_RATE: float = 0.24
const SUB_SIZE_RATE: float = 0.065
const SCORE_SIZE_RATE: float = 0.075
## 出していない間の描く先の画の大きさ（全画面の画を持ち続けない）
const IDLE_VIEWPORT_SIZE: Vector2i = Vector2i(2, 2)
## 文字の位置（高さの何倍か）
## 「GOAL!」は下の3分の1に置く（ネットに刺さるボールと、喜ぶ選手の顔を隠さない）。「得点」は上の帯、スコアは下の帯の中
## （映画の字幕のように、絵に重ねない）
const TITLE_Y_RATE: float = 0.7
## シュートを止めた場面は、ゴールの裏からキーパーを低く見るので、題は上の3分の1に置く（キーパーを隠さない）
const SAVE_TITLE_Y_RATE: float = 0.32
const SUB_Y_RATE: float = GoalCutInArt.BAR_HEIGHT / 2.0
const SCORE_Y_RATE: float = 1.0 - GoalCutInArt.BAR_HEIGHT / 2.0

var _tween: Tween
var _progress: float = 0.0
var _playing: bool = false
var _is_user: bool = true
var _kind: Kind = Kind.GOAL
var _texts: Dictionary = {}
var _viewport_box: SubViewportContainer
var _viewport: SubViewport
var _stage: GoalStage3D
var _overlay: Control


func _init() -> void:
	name = "GoalCutIn"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_box = SubViewportContainer.new()
	_viewport_box.name = "Stage"
	_viewport_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_viewport_box)
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.size = IDLE_VIEWPORT_SIZE
	_viewport_box.add_child(_viewport)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## カットインを始める（出していれば初めからやり直す。前の分の finished は出さない）。kind は場面、is_user は主役の側
## （得点した側・奪った側）が利用者か、score_* は開示の後のスコア（得点の文に使う）、sec は時間
## （MatchController.goal_cut_in_sec()・transition_cut_in_sec()）。0 以下・有限でない時間なら出さず、偽を返す。
func play(kind: Kind, is_user: bool, score_user: int, score_opponent: int, sec: float) -> bool:
	if not (is_finite(sec) and sec > 0.0):
		return false
	_kill_tween()
	_kind = kind
	_is_user = is_user
	match kind:
		Kind.STEAL:
			_texts = StealCutInArt.texts(is_user)
		Kind.SAVE:
			_texts = SaveCutInArt.texts(is_user)
		_:
			_texts = GoalCutInArt.texts(is_user, score_user, score_opponent)
	# 描く先の画を、カットインの大きさに広げる
	_viewport_box.stretch = true
	_build_stage()
	_playing = true
	visible = true
	_set_progress(0.0)
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, sec)
	_tween.finished.connect(_end)
	return true


## 出していれば止める（finished を出す）。出していなければ何もしない。
func stop() -> void:
	if _playing:
		_end()


func is_playing() -> bool:
	return _playing


## 進み具合（0〜1）。
func progress() -> float:
	return _progress


## 出している文（GoalCutInArt.texts の値）。
func texts() -> Dictionary:
	return _texts.duplicate()


## 主役の側（得点した側・奪った側）が利用者か
func is_user_goal() -> bool:
	return _is_user


func kind() -> Kind:
	return _kind


## 3Dの舞台（出していなければ null）。
func stage() -> GoalStage3D:
	return _stage


## 押す（クリック・タッチ）と飛ばす。
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed and _playing:
		accept_event()
		_end()


func _end() -> void:
	_kill_tween()
	_playing = false
	visible = false
	_free_stage()
	_viewport_box.stretch = false
	_viewport.size = IDLE_VIEWPORT_SIZE
	finished.emit()


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _set_progress(value: float) -> void:
	_progress = value
	if _stage != null:
		_stage.set_progress(value)
	_overlay.queue_redraw()


func _build_stage() -> void:
	_free_stage()
	_stage = GoalStage3D.new()
	_stage.name = "GoalStage"
	_viewport.add_child(_stage)
	_stage.build(_kind, _is_user, {
		"you": get_theme_color(&"you", THEME_TYPE),
		"opponent": get_theme_color(&"opponent", THEME_TYPE),
		"keeper_you": get_theme_color(&"keeper_you", OWN_THEME_TYPE),
		"keeper_opponent": get_theme_color(&"keeper_opponent", OWN_THEME_TYPE),
		"hair": get_theme_color(&"hair", OWN_THEME_TYPE),
		"glove": get_theme_color(&"glove", OWN_THEME_TYPE),
		"boot": get_theme_color(&"bg", THEME_TYPE),
		"dark": get_theme_color(&"bg", THEME_TYPE),
		"number_color": get_theme_color(&"bg", THEME_TYPE),
	}, get_theme_font(&"font", TITLE_FONT_TYPE))


func _free_stage() -> void:
	if _stage != null:
		_stage.queue_free()
		_stage = null


# --- 重ね ---

## 場面 kind の時刻 p の重ねの値（GoalCutInArt.frame と同じキー）
static func scene_frame(kind: Kind, p: float, is_user: bool) -> Dictionary:
	match kind:
		Kind.STEAL:
			return StealCutInArt.frame(p, is_user)
		Kind.SAVE:
			return SaveCutInArt.frame(p, is_user)
	return GoalCutInArt.frame(p, is_user)


## 映画の帯（上下の黒帯）・「GOAL!」（叩きつけて縮む）・「得点」・スコア・白い閃光・終わりの暗転
func _draw_overlay() -> void:
	if not _playing:
		return
	var frame: Dictionary = scene_frame(_kind, _progress, _is_user)
	var area: Vector2 = _overlay.size
	var team: Color = get_theme_color(&"you" if _is_user else &"opponent", THEME_TYPE)
	var bars: float = frame["bars"] as float
	var bar: float = area.y * GoalCutInArt.BAR_HEIGHT * bars
	_overlay.draw_rect(Rect2(0, 0, area.x, bar), Color.BLACK)
	_overlay.draw_rect(Rect2(0, area.y - bar, area.x, bar), Color.BLACK)
	# 帯の内側の縁に、得点した側のチームの色の細い線
	_overlay.draw_rect(Rect2(0, bar - 4.0, area.x, 4.0), Color(team, bars))
	_overlay.draw_rect(Rect2(0, area.y - bar, area.x, 4.0), Color(team, bars))
	var shake: Vector2 = (frame["shake"] as Vector2) * area.y
	var font: Font = get_theme_font(&"font", TITLE_FONT_TYPE)
	var outline_color: Color = team.darkened(0.65)
	var title_alpha: float = frame["title_alpha"] as float
	if title_alpha > 0.0:
		var scale: float = frame["title_scale"] as float
		var title_size: int = int(area.y * TITLE_SIZE_RATE)
		var fill: Color = get_theme_color(&"accent", THEME_TYPE) if _is_user else get_theme_color(&"text", THEME_TYPE)
		var title_y: float = SAVE_TITLE_Y_RATE if _kind == Kind.SAVE else TITLE_Y_RATE
		_overlay.draw_set_transform(Vector2(area.x / 2.0, area.y * title_y) + shake, deg_to_rad(-6.0), Vector2(scale, scale))
		_draw_centered(font, Vector2(6.0, 8.0), _texts["title"] as String, title_size, Color(0, 0, 0, 0.5 * title_alpha),
				Color(0, 0, 0, 0.0), 0)
		_draw_centered(font, Vector2.ZERO, _texts["title"] as String, title_size, Color(fill, title_alpha),
				Color(outline_color, title_alpha), int(title_size * 0.12))
		_overlay.draw_set_transform(Vector2.ZERO)
	var sub_alpha: float = frame["sub_alpha"] as float
	if sub_alpha > 0.0:
		var rise := Vector2(0.0, area.y * 0.015 * (1.0 - sub_alpha))
		var text_color := Color(get_theme_color(&"text", THEME_TYPE), sub_alpha)
		var outline := Color(outline_color, sub_alpha)
		var sub_size: int = int(area.y * SUB_SIZE_RATE)
		_draw_centered(font, Vector2(area.x / 2.0, area.y * SUB_Y_RATE) + rise, _texts["sub"] as String, sub_size,
				text_color, outline, int(sub_size * 0.16))
		var score_size: int = int(area.y * SCORE_SIZE_RATE)
		_draw_centered(font, Vector2(area.x / 2.0, area.y * SCORE_Y_RATE) + rise, _texts["score"] as String, score_size,
				text_color, outline, int(score_size * 0.14))
	if (frame["flash"] as float) > 0.0:
		_overlay.draw_rect(Rect2(Vector2.ZERO, area), Color(1, 1, 1, 0.6 * (frame["flash"] as float)))
	if (frame["fade"] as float) > 0.0:
		_overlay.draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, frame["fade"] as float))


func _draw_centered(font: Font, center: Vector2, text: String, font_size: int, fill: Color, outline: Color,
		outline_size: int) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: Vector2 = center + Vector2(-width / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	if outline_size > 0:
		_overlay.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline)
	_overlay.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)

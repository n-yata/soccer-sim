## 局面が変わったときに、画面の真ん中を横切る帯（中継のテロップ。2026-11-07）。英字の大見出しと日本語の一言を出し、
## DURATION で勝手に消える。タップは要らず、帯の下の操作も止めない（読み合いの手の選択を遅らせない）。
## 帯の色は、その局面でボールを持つ側のチームの色（盤面の駒と同じ `you`・`opponent`）。
## 試合画面（ターンごと）とチュートリアル（段階ごと）が、ターンの始めに follow で局面を渡す（2026-11-08 にチュートリアルへ広げた）。
class_name PhaseBanner
extends PanelContainer

## 出てから消えるまで（秒）。最初の FADE_IN で現れ、最後の FADE_OUT で消える
const DURATION: float = 1.2
const FADE_IN: float = 0.15
const FADE_OUT: float = 0.3
const HEIGHT: float = 160.0
const TITLE_FONT_SIZE: int = 64
const LINE_FONT_SIZE: int = 28
## 帯の上下の縁（チームの色）の太さ
const EDGE_WIDTH: int = 6
## 帯の地（盤面の背景の色）の不透明度
const BAND_ALPHA: float = 0.92

var _title: Label
var _line: Label
var _band: StyleBoxFlat
var _accent: Color
var _tween: Tween
## 前に follow で渡された局面（GameEnums.Phase）。まだ無ければ -1
var _last_phase: int = -1


func _init() -> void:
	name = "PhaseBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_top = -HEIGHT / 2.0
	offset_bottom = HEIGHT / 2.0
	visible = false
	_band = StyleBoxFlat.new()
	_band.border_width_top = EDGE_WIDTH
	_band.border_width_bottom = EDGE_WIDTH
	add_theme_stylebox_override("panel", _band)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = _label("Title", TITLE_FONT_SIZE)
	column.add_child(_title)
	_line = _label("Line", LINE_FONT_SIZE)
	column.add_child(_line)


## ターンの始めの局面を渡す。前と変わっていれば帯を出し、変わらなければ消す。最初の局面（forget の後）では出さない
## （試合のキックオフ・チュートリアルの最初の段階には、比べる前の局面が無い）
func follow(phase: GameEnums.Phase) -> void:
	if _last_phase != -1 and phase != _last_phase:
		show_phase(phase)
	else:
		dismiss()
	_last_phase = phase


## 前の局面を忘れて帯を消す（画面を開いたとき）
func forget() -> void:
	_last_phase = -1
	dismiss()


## phase の帯を出す。出ている途中なら、初めから出し直す
func show_phase(phase: GameEnums.Phase) -> void:
	var holds_ball: bool = phase in [GameEnums.Phase.ATTACK, GameEnums.Phase.POS_TRANSITION]
	_accent = get_theme_color("you" if holds_ball else "opponent", "TacticsBoard")
	var background: Color = get_theme_color("bg", "TacticsBoard")
	_band.bg_color = Color(background, BAND_ALPHA)
	_band.border_color = _accent
	_title.text = MatchTexts.phase_banner_title(phase)
	_title.add_theme_color_override("font_color", _accent)
	_title.add_theme_font_override("font", get_theme_font("font", &"TagLabel"))
	_line.text = MatchTexts.phase_banner_line(phase)
	_line.add_theme_color_override("font_color", get_theme_color("text", "TacticsBoard"))
	_stop()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(DURATION - FADE_IN - FADE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(hide)


## すぐに消す（局面の変わらないターン・開示の始まり）
func dismiss() -> void:
	_stop()
	visible = false


func is_showing() -> bool:
	return visible


func title_text() -> String:
	return _title.text


func line_text() -> String:
	return _line.text


func title_label() -> Label:
	return _title


func line_label() -> Label:
	return _line


func accent_color() -> Color:
	return _accent


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label

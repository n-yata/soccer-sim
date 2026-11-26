## メインシーン（component-design.md §5.1）。App.screen_requested を受けて画面を入れ替える。
## 受け持つのは、入力（Android の戻る操作・PC の Esc。screen-common.md §4.1）とセーフエリアの余白（§1.1）。
## 画面の入れ替えの手順は ScreenSwitcher に任せる。
class_name MainShell
extends Control

## 画面 ID → シーンのパス。画面を作ったらここに1行足す（タイトルのカードも自動で押せるようになる）
const SCREEN_SCENES: Dictionary = {
	AppScreens.Id.S01_TITLE: "res://ui/screens/s01_title/title_screen.tscn",
	AppScreens.Id.S02_MATCH_SETUP: "res://ui/screens/s02_match_setup/match_setup_screen.tscn",
	AppScreens.Id.S03_MATCH: "res://ui/screens/s03_match/match_screen.tscn",
	AppScreens.Id.S04_STYLE_CHANGE: "res://ui/screens/s04_style_change/style_change_screen.tscn",
	AppScreens.Id.S05_HALFTIME: "res://ui/screens/s05_halftime/halftime_screen.tscn",
	AppScreens.Id.S06_RESULT: "res://ui/screens/s06_result/result_screen.tscn",
	AppScreens.Id.S07_REVIEW: "res://ui/screens/s07_review/review_screen.tscn",
	AppScreens.Id.S08_TUTORIAL: "res://ui/screens/s08_tutorial/tutorial_screen.tscn",
	AppScreens.Id.S09_QUIZ: "res://ui/screens/s09_quiz/quiz_screen.tscn",
	AppScreens.Id.S10_SCOPE: "res://ui/screens/s10_scope/scope_screen.tscn",
	AppScreens.Id.S11_RECORDS: "res://ui/screens/s11_records/records_screen.tscn",
	AppScreens.Id.S12_SETTINGS: "res://ui/screens/s12_settings/settings_screen.tscn",
}

const LANDSCAPE_SIZE: Vector2i = Vector2i(1280, 720)
const PORTRAIT_SIZE: Vector2i = Vector2i(720, 1280)

@onready var _screen_root: MarginContainer = $ScreenRoot
var _switcher: ScreenSwitcher
var _toast: ToastView
## タイトルを開く前に出た保存のエラー（起動時の中断データの破損など）。タイトルを開いてから出す（component-design.md §5.1）
var _pending_errors: Array[int] = []
var _is_title_shown: bool = false


## 画面のシーンがあるか。タイトルが、カードを押せるかの判断に使う。
static func has_screen(screen: AppScreens.Id) -> bool:
	return SCREEN_SCENES.has(screen)


## 左右の余白（横。基準解像度の px。x が左、y が右）。keep_height なので倍率は viewport_height / window_size.y。
## safe_area はウィンドウの座標で表した安全な範囲。はみ出していても余白は負にしない。
static func side_margins(window_size: Vector2i, safe_area: Rect2i, viewport_height: float) -> Vector2:
	# 安全な範囲が大きさ 0 で返る端末・状態がある。そのまま計算すると右の余白が画面幅になるので、余白なしとする
	if window_size.y <= 0 or not safe_area.has_area():
		return Vector2.ZERO
	return _edge_margins(window_size.x, safe_area.position.x, safe_area.end.x, viewport_height / float(window_size.y))


## 上下の余白（縦。基準解像度の px。x が上、y が下）。keep_width なので倍率は viewport_width / window_size.x（2026-11-27）
static func top_bottom_margins(window_size: Vector2i, safe_area: Rect2i, viewport_width: float) -> Vector2:
	if window_size.x <= 0 or not safe_area.has_area():
		return Vector2.ZERO
	return _edge_margins(window_size.y, safe_area.position.y, safe_area.end.y, viewport_width / float(window_size.x))


## 1つの軸の両端の余白（安全な範囲の外の長さを基準解像度へ写す）。負にはしない
static func _edge_margins(window_length: int, safe_start: int, safe_end: int, scale_factor: float) -> Vector2:
	return Vector2(maxf(0.0, float(safe_start)) * scale_factor, maxf(0.0, float(window_length - safe_end)) * scale_factor)


## ウィンドウが縦長（高さ ＞ 幅）なら縦の配置にする（2026-11-27。正方形・大きさ 0 は横のまま）
static func is_portrait_window(window_size: Vector2i) -> bool:
	return window_size.y > window_size.x


## 基準の解像度。横は 1280×720、縦は 720×1280（screen-common.md §1.1）
static func base_size(portrait: bool) -> Vector2i:
	return PORTRAIT_SIZE if portrait else LANDSCAPE_SIZE


## 基準の解像度の合わせ方。横は高さに合わせて余った幅を、縦は幅に合わせて余った高さを画面に渡す
static func scale_aspect(portrait: bool) -> Window.ContentScaleAspect:
	return Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if portrait else Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT


func _ready() -> void:
	_switcher = ScreenSwitcher.new(_screen_root, SCREEN_SCENES)
	_toast = ToastView.new()
	add_child(_toast)
	App.screen_requested.connect(_on_screen_requested)
	App.storage_error.connect(_on_storage_error)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	# 起動時の後始末（UC-05）。中断データが壊れていれば、ここで出た通知をタイトルを開いた後に出す。
	# 設定を読んで音量をバスへ反映する。読み込みの失敗の通知も、タイトルを開いた後に出す
	App.match_controller.inspect_suspended()
	AudioBuses.apply(App.user_data.settings())
	App.request_screen(AppScreens.Id.S01_TITLE)


func _exit_tree() -> void:
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)
	if App.storage_error.is_connected(_on_storage_error):
		App.storage_error.disconnect(_on_storage_error)


## 表示中の通知の文（出していなければ空）。
func toast_message() -> String:
	return _toast.current_message()


func _on_storage_error(kind: AppScreens.StorageErrorKind) -> void:
	if not _is_title_shown:
		_pending_errors.append(kind)
		return
	_toast.show_message(ToastView.message_of(kind))


## 画面を開き、初めてタイトルを開いたら、それまでに出た通知を出す（続けて出たときは最後のものが残る）。
func _open_screen(screen: AppScreens.Id, params: Dictionary) -> void:
	_switcher.open(screen, params)
	if _is_title_shown or _switcher.current_id() != AppScreens.Id.S01_TITLE:
		return
	_is_title_shown = true
	for kind: int in _pending_errors:
		_toast.show_message(ToastView.message_of(kind as AppScreens.StorageErrorKind))
	_pending_errors.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_requested("android_back")


func _unhandled_input(event: InputEvent) -> void:
	# キーのリピートは受けない（is_action_pressed の既定）。長押しで画面を戻りすぎて閉じないように
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_requested("ui_cancel")


## 画面の入れ替えは、シグナルを受けたフレームの処理が終わってから行う。画面のボタンの pressed の中で
## App.request_screen() が呼ばれるため、その場で入れ替えると、押されたボタンを持つ画面ごと処理の途中で外すことになる。
func _on_screen_requested(screen: AppScreens.Id, params: Dictionary) -> void:
	_open_screen.call_deferred(screen, params)


func _on_back_requested(source: String) -> void:
	if should_quit_after_back(source):
		get_tree().quit()


## 戻る操作を表示中の画面へ渡し、アプリを閉じるべきか（画面が処理しなかったか）を返す。
## アプリを閉じる判断をテストできるよう、get_tree().quit() の呼び出しと分けている。
func should_quit_after_back(source: String) -> bool:
	var is_handled: bool = _switcher.route_back()
	if OS.is_debug_build():
		# エミュレーターで、戻る操作1回につき handle_back() が1回だけ呼ばれたことを確かめるためのログ
		print("MainShell: back(%s) -> %s handled=%s" % [
				source, AppScreens.Id.find_key(_switcher.current_id()), is_handled])
	return not is_handled


## 表示中の画面の ID（無ければ -1）。
func current_screen_id() -> int:
	return _switcher.current_id()


## 表示中の画面（無ければ null）。読むだけの問い合わせで、画面を差し替える手段は持たない
## （画面の切り替えは App.request_screen だけ）。通しの試合のテストが、表示中の画面を操作するのに使う。
func current_screen() -> AppScreen:
	return _switcher.current()


## ウィンドウの向きに合わせて基準の解像度と合わせ方を変え、表示中・この後に開く画面へ向きを伝える（2026-11-27）。
## 基準の解像度を変えると size_changed がもう一度来るが、向きは変わらないので余白だけを当て直す。
func _on_viewport_size_changed() -> void:
	var portrait: bool = is_portrait_window(get_window().size)
	if portrait != _switcher.is_portrait() or get_window().content_scale_size != base_size(portrait):
		# ウィンドウの大きさを変えている最中（size_changed の中）に基準の解像度を変えると、拡大縮小の変換が古い大きさのまま
		# 残り、ブラウザ版で画面が歪んだ（2026-11-27）。変更はこのフレームの処理が終わってから行う
		_apply_orientation.call_deferred(portrait)
	_apply_safe_area()


func _apply_orientation(portrait: bool) -> void:
	# 先に画面へ伝える（基準解像度を変えると size_changed がすぐ来るが、向きはもう同じなので、もう一度積まない）
	_switcher.set_portrait(portrait)
	get_window().content_scale_aspect = scale_aspect(portrait)
	get_window().content_scale_size = base_size(portrait)
	_apply_safe_area()


## セーフエリアの分を左右（横）・上下（縦）の余白に足す。PC の get_display_safe_area() は画面全体の範囲でウィンドウとは
## 関係ないため、モバイルのときだけ当てる。外周の余白 24px は各画面が自分の配置で持つ（screen-common.md §1.1）。
## 左右には同じ余白（大きい方）を当てる。横向きのまま 180° 回すと切り欠きは反対側へ移るが、ビューポートの大きさは
## 変わらないため size_changed が来ない。左右を同じにしておけば、どちら向きでも切り欠きに内容が重ならない。
func _apply_safe_area() -> void:
	var margin: float = 0.0
	var portrait: bool = _switcher.is_portrait()
	if OS.has_feature("mobile"):
		var window_size: Vector2i = DisplayServer.window_get_size()
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		var margins: Vector2
		if portrait:
			margins = top_bottom_margins(window_size, safe_area, get_viewport_rect().size.x)
		else:
			margins = side_margins(window_size, safe_area, get_viewport_rect().size.y)
		margin = maxf(margins.x, margins.y)
	# 縦も横の 180° と同じく、上下に同じ余白（大きい方）を当てる（さかさまの縦でも切り欠きに重ならない）
	for side: String in ["left", "right", "top", "bottom"]:
		var is_cutout_side: bool = (side in ["top", "bottom"]) == portrait
		_screen_root.add_theme_constant_override("margin_" + side, roundi(margin) if is_cutout_side else 0)

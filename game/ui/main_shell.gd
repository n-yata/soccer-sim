## メインシーン（component-design.md §5.1）。App.screen_requested を受けて画面を入れ替える。
## 受け持つのは、入力（Android の戻る操作・PC の Esc。screen-common.md §4.1）とセーフエリアの余白（§1.1）。
## 画面の入れ替えの手順は ScreenSwitcher に任せる。
class_name MainShell
extends Control

## 画面 ID → シーンのパス。画面を作ったらここに1行足す（タイトルのカードも自動で押せるようになる）
const SCREEN_SCENES: Dictionary = {
	AppScreens.Id.S01_TITLE: "res://ui/screens/s01_title/title_screen.tscn",
}

@onready var _screen_root: MarginContainer = $ScreenRoot
var _switcher: ScreenSwitcher


## 画面のシーンがあるか。タイトルが、カードを押せるかの判断に使う。
static func has_screen(screen: AppScreens.Id) -> bool:
	return SCREEN_SCENES.has(screen)


## 左右の余白（基準解像度の px。x が左、y が右）。keep_height なので倍率は viewport_height / window_size.y。
## safe_area はウィンドウの座標で表した安全な範囲。はみ出していても余白は負にしない。
static func side_margins(window_size: Vector2i, safe_area: Rect2i, viewport_height: float) -> Vector2:
	# 安全な範囲が大きさ 0 で返る端末・状態がある。そのまま計算すると右の余白が画面幅になるので、余白なしとする
	if window_size.y <= 0 or not safe_area.has_area():
		return Vector2.ZERO
	var scale_factor: float = viewport_height / float(window_size.y)
	var left: float = maxf(0.0, float(safe_area.position.x)) * scale_factor
	var right: float = maxf(0.0, float(window_size.x - safe_area.end.x)) * scale_factor
	return Vector2(left, right)


func _ready() -> void:
	_switcher = ScreenSwitcher.new(_screen_root, SCREEN_SCENES)
	App.screen_requested.connect(_on_screen_requested)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	# 起動時の中断データ・設定の確認（MatchController.inspect_suspended() など）は、サービスを作る作業で足す
	App.request_screen(AppScreens.Id.S01_TITLE)


func _exit_tree() -> void:
	if App.screen_requested.is_connected(_on_screen_requested):
		App.screen_requested.disconnect(_on_screen_requested)


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
	_switcher.open.call_deferred(screen, params)


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


## セーフエリアの分を左右の余白に足す。PC の get_display_safe_area() は画面全体の範囲でウィンドウとは
## 関係ないため、モバイルのときだけ当てる。外周の余白 24px は各画面が自分の配置で持つ（screen-common.md §1.1）。
## 左右には同じ余白（大きい方）を当てる。横向きのまま 180° 回すと切り欠きは反対側へ移るが、ビューポートの大きさは
## 変わらないため size_changed が来ない。左右を同じにしておけば、どちら向きでも切り欠きに内容が重ならない。
func _apply_safe_area() -> void:
	var margin: float = 0.0
	if OS.has_feature("mobile"):
		var margins: Vector2 = side_margins(DisplayServer.window_get_size(), DisplayServer.get_display_safe_area(),
				get_viewport_rect().size.y)
		margin = maxf(margins.x, margins.y)
	_screen_root.add_theme_constant_override("margin_left", roundi(margin))
	_screen_root.add_theme_constant_override("margin_right", roundi(margin))

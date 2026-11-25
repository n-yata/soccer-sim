## 試合中の画面（S-03〜S-05）の「≡」ボタンとメニュー（MatchMenu）の持ち方を1か所にまとめる（screen-03-match.md「メニュー」
## 「Android の戻る操作」。S-04・S-05 は S-03 と同じ）。画面は上部バーと「メニューを開いてよいか」を渡すだけにする。
## 「中断してタイトルへ」で MatchController.suspend_to_title() を呼ぶ。戻り値が false（保存をやり直して失敗した）でも
## タイトルへ進む（保存の失敗は最初の失敗のときに MainShell が通知済みで、中断の前の確認でも警告している）。
## 「設定」で SettingsOverlay をメニューの上に重ねて開く。閉じるとメニューに戻る。
class_name MatchMenuHost
extends RefCounted

const BUTTON_SIZE: Vector2 = Vector2(96, 96)

var _menu: MatchMenu
var _button: Button
var _can_open: Callable
var _settings: SettingsOverlay


## top_bar の先頭に「≡」を置き、screen の最後の子にメニューと設定を置く。can_open（引数なし → bool）が偽の間は開かない
## （決定の処理中・画面の切り替えを待つ間など）。on_hints_changed（bool → なし）は、重ねた設定でヒント表示を変えたときに呼ぶ
## （ヒントを出さない画面は渡さない）。
func _init(screen: Control, top_bar: HBoxContainer, can_open: Callable,
		on_hints_changed: Callable = Callable()) -> void:
	_can_open = can_open
	_button = Button.new()
	_button.name = "MenuButton"
	_button.text = "≡"
	_button.custom_minimum_size = BUTTON_SIZE
	_button.pressed.connect(open)
	top_bar.add_child(_button)
	top_bar.move_child(_button, 0)
	_menu = MatchMenu.new()
	_menu.suspend_requested.connect(_on_suspend_requested)
	screen.add_child(_menu)
	_settings = SettingsOverlay.new()
	_menu.settings_requested.connect(func() -> void: _settings.open(App.user_data.settings()))
	# 設定を閉じたら、下のメニューへキー操作のフォーカスを戻す（設定の中に残ったまま見えなくなるため）
	_settings.closed.connect(_menu.focus_first)
	if on_hints_changed.is_valid():
		_settings.hints_changed.connect(on_hints_changed)
	screen.add_child(_settings)


func open() -> void:
	if _menu.is_open() or not _can_open.call():
		return
	_menu.open(App.match_controller.has_unsaved_progress())


## 戻る操作: ライセンス・設定・確認・メニューが開いていれば、いちばん上を閉じる。閉じていれば開く（開けない状態なら何もしない）。
## どちらでも true（試合中の画面からアプリを閉じない）。
func handle_back() -> bool:
	if _settings.handle_back():
		return true
	if not _menu.handle_back():
		open()
	return true


func is_open() -> bool:
	return _menu.is_open()


func menu() -> MatchMenu:
	return _menu


func settings_overlay() -> SettingsOverlay:
	return _settings


func menu_button() -> Button:
	return _button


func _on_suspend_requested() -> void:
	App.match_controller.suspend_to_title()

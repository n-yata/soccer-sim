## 試合中の画面（S-03〜S-05）のメニュー（screen-common.md §5 の MatchMenu・screen-03-match.md「メニュー」）。
## 「設定」「中断してタイトルへ」「閉じる」。直前の保存に失敗していたら、中断の前に警告つきの確認を出す
## （その場合、続きから再開できないことがあるため）。保存に成功していれば確認なしで suspend_requested を出す
## （中断は試合を消さず、タイトルから再開できるため）。
## 「設定」は設定の保存（UserDataService）を作る作業まで「準備中」で押せない。
class_name MatchMenu
extends ModalOverlay

signal suspend_requested
signal closed

const UNSAVED_WARNING: String = "直前の途中経過を保存できていません。中断してアプリを閉じると、続きから再開できない場合があります。中断しますか？"

var _settings_button: Button
var _suspend_button: Button
var _close_button: Button
var _confirm: ConfirmDialog
var _has_unsaved: bool = false


func _init() -> void:
	super()
	name = "MatchMenu"
	MatchScreenLayout.text(body, "Title", &"SectionTitleLabel").text = "メニュー"
	_settings_button = ModalOverlay.make_button("SettingsButton", "設定（準備中）")
	_settings_button.disabled = true
	_suspend_button = ModalOverlay.make_button("SuspendButton", "中断してタイトルへ")
	_close_button = ModalOverlay.make_button("CloseButton", "閉じる", &"AccentCard")
	for button: Button in [_settings_button, _suspend_button, _close_button]:
		body.add_child(button)
	_suspend_button.pressed.connect(_on_suspend_pressed)
	_close_button.pressed.connect(close)
	_confirm = ConfirmDialog.new()
	_confirm.answered.connect(_on_confirm_answered)
	add_child(_confirm)


func open(has_unsaved_progress: bool) -> void:
	_has_unsaved = has_unsaved_progress
	_show_overlay()


func close() -> void:
	if not is_open():
		return
	_confirm.cancel()
	_hide_overlay()
	closed.emit()


## Android の戻る操作: 確認が開いていれば閉じ、メニューが開いていれば閉じる。どちらかを閉じたら true。
func handle_back() -> bool:
	if _confirm.is_open():
		_confirm.cancel()
		return true
	if is_open():
		close()
		return true
	return false


func suspend_button() -> Button:
	return _suspend_button


func settings_button() -> Button:
	return _settings_button


func close_button() -> Button:
	return _close_button


func confirm_dialog() -> ConfirmDialog:
	return _confirm


func _on_suspend_pressed() -> void:
	if _has_unsaved:
		_confirm.ask(UNSAVED_WARNING, "中断する", "やめる")
		return
	_suspend()


func _on_confirm_answered(ok: bool) -> void:
	if ok:
		_suspend()


func _suspend() -> void:
	_hide_overlay()
	suspend_requested.emit()

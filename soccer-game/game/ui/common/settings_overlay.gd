## 試合中のメニューから重ねて開く設定（screen-03-match.md「メニュー」の SettingsOverlay）。中身は設定の画面と同じ SettingsPanel。
## 保存の時点（committed）で App.user_data.save_settings() を呼ぶ。ヒント表示が変わったら hints_changed で知らせ、
## 試合画面が選んでいる手のまま描き直す。閉じると下のメニューに戻る（遷移しない）。
class_name SettingsOverlay
extends ModalOverlay

signal hints_changed(show_hints: bool)
signal closed

var _panel: SettingsPanel
var _close_button: Button
var _license: LicenseView
## 開いたときのヒント表示（変わったかを見る）
var _show_hints: bool = true


func _init() -> void:
	super()
	name = "SettingsOverlay"
	MatchScreenLayout.text(body, "Title", &"SectionTitleLabel").text = "設定"
	_panel = SettingsPanel.new()
	_panel.committed.connect(_on_committed)
	body.add_child(_panel)
	_close_button = ModalOverlay.make_button("CloseButton", "閉じる", &"AccentCard")
	_close_button.pressed.connect(close)
	# 「ライセンス」の横に並べる（縦に積むと 720px の高さに収まらない）
	_panel.add_to_footer(_close_button)
	_license = LicenseView.new()
	_panel.license_requested.connect(_license.open)
	add_child(_license)


func open(settings: UserSettings) -> void:
	_show_hints = settings.show_hints
	_panel.show_settings(settings)
	_show_overlay()


func close() -> void:
	if not is_open():
		return
	_license.close()
	_hide_overlay()
	closed.emit()


## 戻る操作: ライセンスが開いていれば閉じ、設定が開いていれば閉じる。どちらかを閉じたら true。
func handle_back() -> bool:
	if _license.is_open():
		_license.close()
		return true
	if is_open():
		close()
		return true
	return false


func panel() -> SettingsPanel:
	return _panel


func license_view() -> LicenseView:
	return _license


func close_button() -> Button:
	return _close_button


func _on_committed(settings: UserSettings) -> void:
	App.user_data.save_settings(settings)
	if settings.show_hints != _show_hints:
		_show_hints = settings.show_hints
		hints_changed.emit(_show_hints)

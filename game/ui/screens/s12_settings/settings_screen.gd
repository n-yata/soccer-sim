## S-12 設定（screen-12-settings.md）。BGM・効果音の音量とヒント表示を変え、App.user_data に保存する（FR-15）。
## 中身は SettingsPanel（試合中のメニューから重ねて開く設定と共用）。保存は SettingsPanel.committed の時点だけ。
## 保存に失敗しても画面上の値は保つ（通知は MainShell）。状態を持たない。
class_name SettingsScreen
extends AppScreen

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")

var _header: ScreenHeader
var _panel: SettingsPanel
var _license: LicenseView


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、画面名と戻るはここで付ける。
func _ready() -> void:
	_header.set_title("設定")
	_header.back_pressed.connect(_go_back)


func enter(_params: Dictionary) -> void:
	_license.close()
	_panel.show_settings(App.user_data.settings())


## 戻る操作: ライセンスが開いていれば閉じる。それ以外はタイトルへ。
func handle_back() -> bool:
	if _license.is_open():
		_license.close()
		return true
	_go_back()
	return true


func panel() -> SettingsPanel:
	return _panel


func license_view() -> LicenseView:
	return _license


func header() -> ScreenHeader:
	return _header


func _go_back() -> void:
	App.request_screen(AppScreens.Id.S01_TITLE)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	_header = HEADER_SCENE.instantiate() as ScreenHeader
	_header.name = "Header"
	layout.add_child(_header)
	var center := CenterContainer.new()
	center.name = "Center"
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	_panel = SettingsPanel.new()
	_panel.committed.connect(func(settings: UserSettings) -> void: App.user_data.save_settings(settings))
	center.add_child(_panel)
	_license = LicenseView.new()
	_panel.license_requested.connect(_license.open)
	add_child(_license)

## 設定の中身（screen-12-settings.md の SettingsPanel）。設定の画面（S-12）と、試合中のメニューから重ねて開く設定で共用する。
## BGM・効果音の音量（0〜100、刻み 5）とヒント表示の ON/OFF と「ライセンス」。音量は動かすたびにその場でバスへ反映する。
## 保存の時点は committed（スライダーを離したとき・ドラッグでない変更・トグルの切り替え）で知らせ、保存は持ち主が行う
## （動かしている間は保存しない。書き込みを減らすため）。詳細設計の .tscn ではなくスクリプトで組み立てる（.new() で作れる）。
class_name SettingsPanel
extends VBoxContainer

## 値が変わった（スライダーを動かしている間も出す）
signal changed(settings: UserSettings)
## 保存してよい時点（スライダーを離した・トグルを切り替えた）
signal committed(settings: UserSettings)
signal license_requested

const WIDTH: float = 720.0
## スライダー・トグルの押せる高さ（NFR-19。screen-12-settings.md）
const ROW_HEIGHT: float = 96.0
const VOLUME_STEP: float = 5.0
## 音量の行の名前の幅（「効果音音量」が1行に入る幅）
const TITLE_WIDTH: float = 160.0
const HINT_DESCRIPTION: String = "手を選ぶときに、各エリアの人数差とカバーの有無を表示します"

var _settings := UserSettings.new()
var _bgm_slider: HSlider
var _se_slider: HSlider
var _bgm_value: Label
var _se_value: Label
var _hint_toggle: CheckButton
var _license_button: Button
## スライダーをドラッグしている間か（その間は committed を出さない）
var _is_dragging: bool = false
## 最後の行（「ライセンス」。重ねて開く設定は、ここに「閉じる」を並べる）
var _footer: HBoxContainer


func _init() -> void:
	name = "SettingsPanel"
	custom_minimum_size = Vector2(WIDTH, 0)
	# 試合中に重ねて開く設定でも、閉じるボタンまで 720px の高さに収める（行の名前はスライダーと同じ行に置く）
	add_theme_constant_override("separation", 12)
	var bgm: Array = _volume_row("BgmRow", "BGM 音量")
	_bgm_slider = bgm[0] as HSlider
	_bgm_value = bgm[1] as Label
	var se: Array = _volume_row("SeRow", "効果音音量")
	_se_slider = se[0] as HSlider
	_se_value = se[1] as Label
	_bgm_slider.value_changed.connect(_on_volume_changed.bind(true))
	_se_slider.value_changed.connect(_on_volume_changed.bind(false))
	_build_hint_row()
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("separation", 16)
	add_child(_footer)
	_license_button = ModalOverlay.make_button("LicenseButton", "ライセンス")
	_license_button.pressed.connect(func() -> void: license_requested.emit())
	_footer.add_child(_license_button)


## 値を入れる（このときは changed・committed を出さない）。
func show_settings(settings: UserSettings) -> void:
	_settings = settings.duplicate_deep()
	_bgm_slider.set_value_no_signal(roundf(_settings.bgm_volume * 100.0))
	_se_slider.set_value_no_signal(roundf(_settings.se_volume * 100.0))
	_hint_toggle.set_pressed_no_signal(_settings.show_hints)
	_update_value_labels()


## 今の値の写し。
func current_settings() -> UserSettings:
	return _settings.duplicate_deep()


func bgm_slider() -> HSlider:
	return _bgm_slider


func se_slider() -> HSlider:
	return _se_slider


func hint_toggle() -> CheckButton:
	return _hint_toggle


func license_button() -> Button:
	return _license_button


## 最後の行に部品を足す（重ねて開く設定の「閉じる」）。
func add_to_footer(control: Control) -> void:
	_footer.add_child(control)


func value_texts() -> Array[String]:
	return [_bgm_value.text, _se_value.text]


func _on_volume_changed(value: float, is_bgm: bool) -> void:
	if is_bgm:
		_settings.bgm_volume = value / 100.0
	else:
		_settings.se_volume = value / 100.0
	_update_value_labels()
	AudioBuses.apply(_settings)
	changed.emit(current_settings())
	# ドラッグでない変更（キー操作・押した位置へ飛ぶ）は、その場で保存してよい
	if not _is_dragging:
		committed.emit(current_settings())


func _on_drag_ended(_value_changed: bool) -> void:
	_is_dragging = false
	committed.emit(current_settings())


func _on_hint_toggled(is_on: bool) -> void:
	_settings.show_hints = is_on
	changed.emit(current_settings())
	committed.emit(current_settings())


func _update_value_labels() -> void:
	_bgm_value.text = str(int(_bgm_slider.value))
	_se_value.text = str(int(_se_slider.value))


## 「BGM 音量」・スライダー・数値を1行に並べる。[HSlider, Label] を返す。
func _volume_row(node_name: String, title: String) -> Array:
	var line := HBoxContainer.new()
	line.name = node_name
	line.add_theme_constant_override("separation", 24)
	add_child(line)
	var title_label: Label = MatchScreenLayout.text(line, "Title", &"SectionTitleLabel")
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.custom_minimum_size = Vector2(TITLE_WIDTH, 0)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = VOLUME_STEP
	slider.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.drag_started.connect(func() -> void: _is_dragging = true)
	slider.drag_ended.connect(_on_drag_ended)
	line.add_child(slider)
	var value_label: Label = MatchScreenLayout.text(line, "Value", &"CardTitleLabel")
	value_label.custom_minimum_size = Vector2(72, 0)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return [slider, value_label]


func _build_hint_row() -> void:
	var row := VBoxContainer.new()
	row.name = "HintRow"
	add_child(row)
	_hint_toggle = CheckButton.new()
	_hint_toggle.name = "HintToggle"
	_hint_toggle.text = "ヒント表示"
	_hint_toggle.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_hint_toggle.toggled.connect(_on_hint_toggled)
	row.add_child(_hint_toggle)
	MatchScreenLayout.text(row, "Description", &"MutedLabel").text = HINT_DESCRIPTION

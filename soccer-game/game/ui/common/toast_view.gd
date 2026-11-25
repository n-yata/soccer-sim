## 短い通知（screen-common.md §5 の末尾）。MainShell が1つだけ持ち、App.storage_error を受けて画面の下に数秒出す。
## 押せない表示（下の画面の操作を止めない）。続けて出たときは新しい文に置き換え、表示の時間を数え直す。
## 文言の正本は functional-overview.md「エラーハンドリング」（ここはその書き写し。正本を変えたらここも合わせる）。
class_name ToastView
extends PanelContainer

## 表示する時間（秒）。長い文（保存の失敗）でも読み切れる長さ
const SHOW_SEC: float = 5.0
const BOTTOM_MARGIN: float = 32.0
const MESSAGES: Dictionary = {
	AppScreens.StorageErrorKind.SUSPEND_SAVE:
			"試合の途中経過を保存できませんでした。このまま続けられますが、アプリを閉じると続きから再開できない場合があります",
	AppScreens.StorageErrorKind.SUSPEND_LOAD: "中断していた試合を再開できませんでした。新しく試合を始めてください",
	AppScreens.StorageErrorKind.USER_DATA_SAVE: "保存できませんでした。端末の空き容量を確認してください",
	AppScreens.StorageErrorKind.USER_DATA_LOAD: "保存データを読み込めなかったため、初期状態で表示しています",
	AppScreens.StorageErrorKind.USER_DATA_NEWER: "このデータは新しい版のアプリで保存されています。アプリを更新してください",
}

var _label: Label
var _timer: Timer


func _init() -> void:
	name = "ToastView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"ToastPanel"
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(720, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(hide_message)
	add_child(_timer)


static func message_of(kind: AppScreens.StorageErrorKind) -> String:
	return MESSAGES[kind] as String


func show_message(text: String) -> void:
	_label.text = text
	visible = true
	# 文の長さで高さが変わるので、置き直してから下端に寄せる
	reset_size()
	position = Vector2((get_parent_area_size().x - size.x) / 2.0, get_parent_area_size().y - size.y - BOTTOM_MARGIN)
	_timer.start(SHOW_SEC)


func hide_message() -> void:
	visible = false
	_timer.stop()


## 表示中の文（出していなければ空）。
func current_message() -> String:
	return _label.text if visible else ""

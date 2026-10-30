## S-10 ゲームの表現範囲（screen-10-scope.md。FR-23）。ゲームが単純化している戦術要素と、実戦での扱いを一覧にする。
## 一覧は SimplificationList（チュートリアルの最後の段階と共用）。値は App.library.simplifications()（ID 順）。状態を持たない。
class_name ScopeScreen
extends AppScreen

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")
const LEAD_TITLE: String = "このゲームが表現していないこと"
const LEAD_TEXT: String = "読み合いに集中できるよう、実際のサッカーの次の要素を単純化しています。"

var _header: ScreenHeader
var _lead_title: Label
var _lead_text: Label
var _list: SimplificationList


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、画面名と戻るはここで付ける。
func _ready() -> void:
	_header.set_title("ゲームの表現範囲")
	_header.back_pressed.connect(_go_back)


func enter(_params: Dictionary) -> void:
	_list.show_items(App.library.simplifications())


## 戻る操作はタイトルへ（ヘッダーの「← 戻る」と同じ）。
func handle_back() -> bool:
	_go_back()
	return true


func lead_texts() -> Array[String]:
	return [_lead_title.text, _lead_text.text]


func simplification_list() -> SimplificationList:
	return _list


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
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name: String in ["left", "right", "bottom", "top"]:
		margin.add_theme_constant_override("margin_" + side_name, 24)
	scroll.add_child(margin)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	margin.add_child(body)
	_lead_title = MatchScreenLayout.text(body, "Lead", &"SectionTitleLabel")
	_lead_title.text = LEAD_TITLE
	_lead_text = MatchScreenLayout.text(body, "LeadText", &"MutedLabel")
	_lead_text.text = LEAD_TEXT
	_list = SimplificationList.new()
	body.add_child(_list)

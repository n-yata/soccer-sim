## S-07 振り返り（screen-07-review.md）。エリア別・局面別の勝ち／負け／膠着、得失点の流れ、時間帯ごとの陣形・方式を
## 4つのタブで見せる。値は MatchController.review()（利用者の視点。集計はアルゴリズム10）。戻ると S-06 へ。
## 局面別（ReviewPhasePage）と得失点（ReviewGoalsPage）のページは別のクラスに分けた（ファイルの目安 300 行。2026-10-29）。
## 「実戦では」（FR-23）は、RevealView.simplification_ids が入る単純化の作業で足す（今は常に空なので出さない）。
class_name ReviewScreen
extends AppScreen

enum Tab { AREA, PHASE, GOALS, TIMELINE }

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")
const TAB_NAMES: Array[String] = ["エリア別", "局面別", "得失点", "時間帯"]
const SIDE_WIDTH: float = 480.0
const TAB_HEIGHT: float = 96.0

var _tab: Tab = Tab.AREA

var _header: ScreenHeader
var _tabs: TabBar
var _pages: Control
var _page_nodes: Array[Control] = []
var _message_label: Label
var _area_board: TacticsBoard
var _phase_page: ReviewPhasePage
var _goals_page: ReviewGoalsPage
var _segment_list: VBoxContainer


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、画面名と戻るはここで付ける。
func _ready() -> void:
	_header.set_title("振り返り")
	_header.back_pressed.connect(_go_back)


## 開くたびに集計し直し、エリア別のタブに戻す（screen-07-review.md「画面の状態」）。
func enter(_params: Dictionary) -> void:
	var view: ReviewView = App.match_controller.review() if App.match_controller.is_match_started() else null
	var has_data: bool = view != null and view.turn_count > 0
	_message_label.visible = not has_data
	_tabs.visible = has_data
	_pages.visible = has_data
	if not has_data:
		_message_label.text = ReviewTexts.NO_DATA_TEXT
		return
	_fill_area_page(view)
	_phase_page.show_tallies(view.phase_tallies)
	_goals_page.show_goals(view.goals, view.turns_per_half)
	_fill_timeline_page(view)
	select_tab(Tab.AREA)


## 戻る操作は S-06 へ（ヘッダーの「← 戻る」と同じ）。
func handle_back() -> bool:
	_go_back()
	return true


## タブを切り替える（画面の中の表示だけ。アプリケーション層は呼ばない）。
func select_tab(tab: Tab) -> void:
	_tab = tab
	if _tabs.current_tab != tab:
		_tabs.current_tab = tab
	for index: int in range(_page_nodes.size()):
		_page_nodes[index].visible = index == tab


# --- テストが読む問い合わせ ---

func current_tab() -> Tab:
	return _tab


func message() -> String:
	return _message_label.text if _message_label.visible else ""


func area_board() -> TacticsBoard:
	return _area_board


func phase_page() -> ReviewPhasePage:
	return _phase_page


func goals_page() -> ReviewGoalsPage:
	return _goals_page


func segment_texts() -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _segment_list.get_children():
		texts.append((label as Label).text)
	return texts


func header() -> ScreenHeader:
	return _header


# --- ページを描く ---

func _fill_area_page(view: ReviewView) -> void:
	var tally: Dictionary = {}
	for key: String in view.area_tallies:
		tally[key] = ReviewTexts.tally_text(view.area_tallies[key] as Array)
	_area_board.clear_overlays()
	_area_board.show_tally(tally)


func _fill_timeline_page(view: ReviewView) -> void:
	MatchScreenLayout.clear(_segment_list)
	for index: int in range(view.segments.size()):
		MatchScreenLayout.text(_segment_list, "Segment%d" % index, &"").text = \
				ReviewTexts.segment_text(view.segments[index], view.turns_per_half)


func _go_back() -> void:
	App.request_screen(AppScreens.Id.S06_RESULT)


# --- 骨組み ---

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
	_tabs = TabBar.new()
	_tabs.name = "Tabs"
	_tabs.custom_minimum_size = Vector2(0, TAB_HEIGHT)
	# 既定ではタブを縮めて矢印で送る形になり、4つのタブが同時に見えない
	_tabs.clip_tabs = false
	for tab_name: String in TAB_NAMES:
		_tabs.add_tab(tab_name)
	_tabs.tab_changed.connect(func(tab: int) -> void: select_tab(tab as Tab))
	_header.add_to_right(_tabs)

	var body := MarginContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side_name: String in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + side_name, 24)
	body.add_theme_constant_override("margin_top", 0)
	layout.add_child(body)
	_message_label = MatchScreenLayout.text(body, "MessageLabel", &"SectionTitleLabel")
	_message_label.visible = false
	_pages = Control.new()
	_pages.name = "Pages"
	body.add_child(_pages)
	_phase_page = ReviewPhasePage.new()
	_goals_page = ReviewGoalsPage.new()
	_page_nodes = [_build_area_page(), _phase_page, _goals_page, _build_timeline_page()]
	for page: Control in _page_nodes:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.add_child(page)


func _build_area_page() -> Control:
	var page := HBoxContainer.new()
	page.name = "AreaPage"
	page.add_theme_constant_override("separation", 24)
	_area_board = TacticsBoard.new()
	_area_board.name = "AreaPitch"
	_area_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 押しても何も起きない表示（選べるエリアを持たない）
	_area_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_area_board)
	var legend: Label = MatchScreenLayout.text(page, "AreaLegend", &"")
	legend.text = ReviewTexts.AREA_LEGEND_TEXT
	legend.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	legend.size_flags_horizontal = Control.SIZE_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return page


func _build_timeline_page() -> Control:
	var page := ScrollContainer.new()
	page.name = "TimelinePage"
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_segment_list = VBoxContainer.new()
	_segment_list.name = "SegmentList"
	_segment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_segment_list.add_theme_constant_override("separation", 16)
	page.add_child(_segment_list)
	return page

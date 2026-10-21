## 試合の合間の画面（S-04・S-05・S-06）の共通の骨組み（screen-common.md §1.1）。
## 上部バー（ScoreBug）、左の本体（info）、右の操作の列（side。下端に主ボタン）を組み、部品を返す。
## 操作の列は、中身（side）を縦にスクロールする部分に置き、主ボタンは列の下端に固定する（入りきらないときも動かない）。
class_name MatchScreenLayout
extends RefCounted

const SIDE_WIDTH: float = 480.0
const PRIMARY_HEIGHT: float = 112.0


## 戻り値: {"score_bug": ScoreBug, "info": VBoxContainer, "side": VBoxContainer, "primary": Button}
static func build(root: Control, primary_name: String, primary_text: String) -> Dictionary:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side_name: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side_name, 24)
	root.add_child(margin)
	# 上部バーと本体の間に余白を置かない（試合画面と同じ寸法。screen-common.md §1.1）
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	margin.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, 96)
	layout.add_child(top_bar)
	var score_bug := ScoreBug.new()
	score_bug.name = "ScoreBug"
	top_bar.add_child(score_bug)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	layout.add_child(columns)
	var info_pane := ScrollContainer.new()
	info_pane.name = "InfoPane"
	info_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_pane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(info_pane)
	var info := VBoxContainer.new()
	info.name = "Body"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 24)
	info_pane.add_child(info)

	var column := VBoxContainer.new()
	column.name = "SideColumn"
	column.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	column.add_theme_constant_override("separation", 16)
	columns.add_child(column)
	var side_scroll := ScrollContainer.new()
	side_scroll.name = "SideScroll"
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.name = "SideBody"
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	side_scroll.add_child(side)
	var primary := Button.new()
	primary.name = primary_name
	primary.text = primary_text
	primary.custom_minimum_size = Vector2(0, PRIMARY_HEIGHT)
	primary.theme_type_variation = &"AccentCard"
	column.add_child(primary)
	return {"score_bug": score_bug, "info": info, "side": side, "primary": primary}


## 地の色つきのタグ（「GOAL」「HALF TIME」「FULL TIME」）。折り返さない（幅を詰めると1文字ずつ縦に並ぶため）。
static func tag(parent: Control, node_name: String, text_value: String) -> Label:
	var label := text(parent, node_name, &"OutcomeTagLabel")
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


static func text(parent: Control, node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

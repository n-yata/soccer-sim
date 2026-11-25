## S-07 振り返りの「局面別」のページ（screen-07-review.md の PhasePage）。4局面の行に、勝ち・負け・膠着の横棒と数を出す。
## 色見本つきの凡例を表の上に置く（色だけに頼らず、数も文字で出す）。
class_name ReviewPhasePage
extends VBoxContainer

## 横棒の高さと、勝ち・負け・膠着の色（テーマの型 TacticsBoard の色。膠着は地に溶けない明るい灰色）
const BAR_HEIGHT: float = 28.0
const BAR_COLORS: Array[StringName] = [&"you", &"opponent", &"lane_text"]
const BAR_LEGEND: Array[String] = ["勝ち（こちらの判断が通った）", "負け（相手の判断が通った）", "膠着"]
## 表の1行の列の数（局面名・横棒・数の文）
const COLUMNS: int = 3

var _rows: GridContainer


func _init() -> void:
	name = "PhasePage"
	add_theme_constant_override("separation", 16)
	add_child(_legend())
	_rows = GridContainer.new()
	_rows.name = "PhaseRows"
	_rows.columns = COLUMNS
	_rows.add_theme_constant_override("h_separation", 24)
	_rows.add_theme_constant_override("v_separation", 24)
	add_child(_rows)


## phase_tallies は GameEnums.Phase → [勝ち, 負け, 膠着]（ReviewView の形）。無い局面は 0 として出す。
func show_tallies(phase_tallies: Dictionary) -> void:
	MatchScreenLayout.clear(_rows)
	for phase: int in GameEnums.Phase.values():
		var counts: Array = phase_tallies.get(phase, [0, 0, 0])
		var name_label: Label = MatchScreenLayout.text(_rows, "PhaseName%d" % phase, &"SectionTitleLabel")
		name_label.text = ReviewTexts.phase_name(phase as GameEnums.Phase)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_FILL
		_rows.add_child(_bar(counts))
		var counts_label: Label = MatchScreenLayout.text(_rows, "PhaseCounts%d" % phase,
				&"MutedLabel" if ReviewTexts.is_empty(counts) else &"")
		counts_label.text = ReviewTexts.phase_counts_text(counts)
		counts_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		counts_label.size_flags_horizontal = Control.SIZE_FILL


## 各行の [局面名, 数の文]（局面の enum の順）。
func rows() -> Array[Array]:
	var result: Array[Array] = []
	var children: Array[Node] = _rows.get_children()
	for index: int in range(0, children.size(), COLUMNS):
		result.append([(children[index] as Label).text, (children[index + COLUMNS - 1] as Label).text])
	return result


## 勝ち・負け・膠着の横棒（数に比例した幅。判定が無ければ空の棒）。
func _bar(counts: Array) -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_constant_override("separation", 0)
	for tally: int in [GameEnums.JudgeTally.WIN, GameEnums.JudgeTally.LOSE, GameEnums.JudgeTally.STALL]:
		var count: int = counts[tally] as int
		if count <= 0:
			continue
		var part := ColorRect.new()
		part.color = get_theme_color(BAR_COLORS[tally], TacticsBoard.THEME_TYPE)
		part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		part.size_flags_stretch_ratio = count
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(part)
	return bar


## 横棒の凡例（色見本と名前）。色はテーマから引くので、木に入ってから色を入れる。
func _legend() -> Control:
	var legend := HBoxContainer.new()
	legend.name = "BarLegend"
	legend.add_theme_constant_override("separation", 12)
	for index: int in range(BAR_LEGEND.size()):
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(BAR_HEIGHT, BAR_HEIGHT)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.ready.connect(func() -> void: swatch.color = swatch.get_theme_color(BAR_COLORS[index], TacticsBoard.THEME_TYPE))
		legend.add_child(swatch)
		var label := Label.new()
		label.text = BAR_LEGEND[index]
		label.theme_type_variation = &"MutedLabel"
		legend.add_child(label)
	return legend

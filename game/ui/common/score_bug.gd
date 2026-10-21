## 中継風のスコア表示（screen-common.md §5 の ScoreBug）。「● YOU 1 – 0 CPU ◆」と時計。
## 試合画面・方式の選び直し・ハーフタイム・試合結果で使う。CanvasItem.show() とぶつかるため show_snapshot とする。
class_name ScoreBug
extends HBoxContainer

var _user_chip: Label
var _score_label: Label
var _opponent_chip: Label
var _clock_label: Label


func _init() -> void:
	add_theme_constant_override("separation", 0)
	_user_chip = _make_label("● YOU", &"YouChipLabel")
	_score_label = _make_label("0 – 0", &"ScoreLabel")
	_opponent_chip = _make_label("CPU ◆", &"OpponentChipLabel")
	_clock_label = _make_label("", &"ClockLabel")


## clock_override を渡すと時計の代わりに出す（ハーフタイムの「HT」・試合終了の「FT」）。
func show_snapshot(snapshot: BoardSnapshot, clock_override: String = "") -> void:
	_score_label.text = "%d – %d" % [snapshot.score_user, snapshot.score_opponent]
	_clock_label.text = clock_override if not clock_override.is_empty() else MatchTexts.clock_text(snapshot)


func score_text() -> String:
	return _score_label.text


func clock_text() -> String:
	return _clock_label.text


func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	add_child(label)
	return label

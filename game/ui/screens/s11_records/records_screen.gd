## S-11 戦績（screen-11-records.md）。左に通算の勝ち・引き分け・負け、右に新しい順の一覧。値は App.user_data（FR-13）。
## 一覧は最初に PAGE_SIZE 件だけ描き、下端までスクロールしたら次の PAGE_SIZE 件を足す（数千件に備える）。
## 0件なら「まだ試合の記録がありません」と「CPU 対戦」（NewMatchGate。手順はタイトルと共通）を出す。
class_name RecordsScreen
extends AppScreen

## IDLE: すべて押せる／BUSY: CPU 対戦の処理中／CONFIRMING: 確認ダイアログだけ押せる
enum State { IDLE, BUSY, CONFIRMING }

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")
const PAGE_SIZE: int = 50
const TOTALS_WIDTH: float = 440.0
const TOTAL_NUMBER_SIZE: int = 52
const KICK_OFF_HEIGHT: float = 136.0
## 勝敗のタグの幅（「引き分け」が入る幅にそろえ、スコアの書き出しを行ごとにずらさない）
const TAG_WIDTH: float = 136.0
## 下端からこの距離（px）以内までスクロールしたら次を足す
const LOAD_MORE_MARGIN: float = 48.0

var _state: State = State.IDLE
var _records: Array[MatchRecord] = []
var _shown_count: int = 0

var _header: ScreenHeader
var _columns: HBoxContainer
var _totals: Dictionary = {}
var _list: ScrollContainer
var _rows: VBoxContainer
var _empty_state: VBoxContainer
var _kick_off_button: Button
var _dialog: ConfirmDialog
var _gate: NewMatchGate


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、画面名と戻るはここで付ける。
func _ready() -> void:
	_header.set_title("戦績")
	_header.back_pressed.connect(_go_back)


func enter(_params: Dictionary) -> void:
	_gate = NewMatchGate.new(App.match_controller, App.request_screen)
	_gate.finished.connect(_on_gate_finished)
	var totals: Dictionary = App.user_data.totals()
	for key: String in _totals:
		(_totals[key] as Label).text = str(totals[key])
	_records = App.user_data.records()
	var is_empty: bool = _records.is_empty()
	_empty_state.visible = is_empty
	_columns.visible = not is_empty
	MatchScreenLayout.clear(_rows)
	_shown_count = 0
	show_more()
	_list.scroll_vertical = 0
	_state = State.IDLE


## 戻る操作（screen-11-records.md「戻る・Android の戻る操作」）。確認中は確認を閉じる。
func handle_back() -> bool:
	match _state:
		State.CONFIRMING:
			_dialog.cancel()
		State.IDLE:
			_go_back()
	return true


## 次の PAGE_SIZE 件を一覧に足す（まだ描いていない戦績が無ければ何もしない）。
func show_more() -> void:
	var end: int = mini(_shown_count + PAGE_SIZE, _records.size())
	for index: int in range(_shown_count, end):
		_rows.add_child(_row(_records[index], index))
	_shown_count = end


# --- テストが読む問い合わせ ---

func state() -> State:
	return _state


func total_text(key: String) -> String:
	return (_totals[key] as Label).text


func row_count() -> int:
	return _shown_count


## index 番目の行の文（勝敗・スコア・日時と、陣形と方式）
func row_texts(index: int) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _rows.get_child(index).find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func is_empty_shown() -> bool:
	return _empty_state.visible


func kick_off_button() -> Button:
	return _kick_off_button


func confirm_dialog() -> ConfirmDialog:
	return _dialog


func record_list() -> ScrollContainer:
	return _list


# --- 操作 ---

func _go_back() -> void:
	if _state != State.IDLE:
		return
	App.request_screen(AppScreens.Id.S01_TITLE)


func _on_kick_off_pressed() -> void:
	if _state != State.IDLE:
		return
	_state = State.BUSY
	_gate.begin(_dialog)
	# 確認を出したなら CONFIRMING（出さずに試合準備を頼んだなら、finished で戻っている）
	if _dialog.is_open():
		_state = State.CONFIRMING


func _on_gate_finished(started: bool) -> void:
	# 試合準備を頼んだなら、画面が替わるまで BUSY のまま
	_state = State.BUSY if started else State.IDLE


func _on_scrolled(_value: float) -> void:
	var bar: VScrollBar = _list.get_v_scroll_bar()
	if bar.value + bar.page >= bar.max_value - LOAD_MORE_MARGIN:
		show_more()


# --- 骨組み ---

## 1行: 勝敗のタグ・「2 – 1　10/17 19:42」・前半の両者の陣形と方式。
func _row(record: MatchRecord, index: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "RecordRow%d" % index
	row.add_theme_constant_override("separation", 16)
	var tag: Label = MatchScreenLayout.text(row, "ResultTag",
			&"YouTagLabel" if record.result == GameEnums.MatchResult.WIN else &"TagLabel")
	tag.text = RecordTexts.result_word(record.result)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(TAG_WIDTH, 0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lines)
	MatchScreenLayout.text(lines, "ScoreAndDate", &"CardTitleLabel").text = "%s　%s" % [
			RecordTexts.score_text(record), RecordTexts.date_text(record.finished_at)]
	MatchScreenLayout.text(lines, "Matchup", &"MutedLabel").text = RecordTexts.matchup_text(record.timeline[0])
	return row


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

	var body := MarginContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side_name: String in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + side_name, 24)
	body.add_theme_constant_override("margin_top", 0)
	layout.add_child(body)

	_columns = HBoxContainer.new()
	_columns.name = "Columns"
	_columns.add_theme_constant_override("separation", 24)
	body.add_child(_columns)
	_columns.add_child(_build_totals())
	_list = ScrollContainer.new()
	_list.name = "RecordList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_columns.add_child(_list)
	_rows = VBoxContainer.new()
	_rows.name = "RecordRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 20)
	_list.add_child(_rows)

	_empty_state = VBoxContainer.new()
	_empty_state.name = "EmptyState"
	_empty_state.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_state.add_theme_constant_override("separation", 32)
	body.add_child(_empty_state)
	var empty_text: Label = MatchScreenLayout.text(_empty_state, "EmptyText", &"SectionTitleLabel")
	empty_text.text = RecordTexts.EMPTY_TEXT
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kick_off_button = Button.new()
	_kick_off_button.name = "KickOffButton"
	_kick_off_button.text = "KICK OFF　CPU 対戦"
	_kick_off_button.theme_type_variation = &"AccentCard"
	_kick_off_button.custom_minimum_size = Vector2(TOTALS_WIDTH, KICK_OFF_HEIGHT)
	_kick_off_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_kick_off_button.pressed.connect(_on_kick_off_pressed)
	_empty_state.add_child(_kick_off_button)

	# 確認ダイアログは最後の子（上に重ねる。screen-11-records.md「ノード構成」）
	_dialog = ConfirmDialog.new()
	add_child(_dialog)


## 通算「勝ち 5」「引き分け 2」「負け 3」を縦に並べる（数字は大きく）。
func _build_totals() -> Control:
	var card := VBoxContainer.new()
	card.name = "TotalsCard"
	card.custom_minimum_size = Vector2(TOTALS_WIDTH, 0)
	card.add_theme_constant_override("separation", 16)
	for key: String in ["win", "draw", "lose"]:
		var line := HBoxContainer.new()
		line.name = "Total_" + key
		card.add_child(line)
		var word: Label = MatchScreenLayout.text(line, "Word", &"CardTitleLabel")
		word.text = RecordTexts.result_word(_result_of_key(key))
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number: Label = MatchScreenLayout.text(line, "Number", &"ResultLabel")
		number.add_theme_font_size_override("font_size", TOTAL_NUMBER_SIZE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_totals[key] = number
	return card


static func _result_of_key(key: String) -> GameEnums.MatchResult:
	match key:
		"win":
			return GameEnums.MatchResult.WIN
		"lose":
			return GameEnums.MatchResult.LOSE
	return GameEnums.MatchResult.DRAW

## S-06 試合結果（screen-06-result.md）。勝敗・最終スコア・陣形と方式の推移を出し、振り返り（S-07）かタイトルへ進む。
## 勝敗は色だけでなく文字で示す。タイトルへの切り替えは MatchController.leave_result が頼む（終了処理のやり直しを含む）。
## スコアの表示は snapshot()、勝敗と推移は final_record()（開くたびに呼ぶ。振り返りから戻ったときも同じ）。
class_name ResultScreen
extends AppScreen

enum State { IDLE, LEAVING }

var _state: State = State.IDLE
var _score_bug: ScoreBug
var _outcome_label: Label
var _title_button: Button
var _review_button: Button
var _history_list: VBoxContainer


func _init() -> void:
	_build()


func enter(_params: Dictionary) -> void:
	var snapshot: BoardSnapshot = App.match_controller.snapshot()
	if snapshot == null:
		return
	_score_bug.show_snapshot(snapshot, "FT")
	var record: MatchRecord = App.match_controller.final_record()
	_outcome_label.text = RecordTexts.result_word(record.result)
	MatchScreenLayout.clear(_history_list)
	var lines: Array[String] = RecordTexts.history_lines(record, snapshot.turns_per_half)
	for index: int in range(lines.size()):
		MatchScreenLayout.text(_history_list, "History%d" % index, &"").text = lines[index]
	_set_state(State.IDLE)


## 戻る操作は「タイトルへ」と同じ（screen-06-result.md）。
func handle_back() -> bool:
	_leave()
	return true


func state() -> State:
	return _state


func title_button() -> Button:
	return _title_button


func review_button() -> Button:
	return _review_button


func outcome() -> String:
	return _outcome_label.text


func history_texts() -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _history_list.get_children():
		if not label.is_queued_for_deletion():
			texts.append((label as Label).text)
	return texts


func score_bug() -> ScoreBug:
	return _score_bug


func _leave() -> void:
	if _state != State.IDLE:
		return
	_set_state(State.LEAVING)
	if not App.match_controller.leave_result():
		_set_state(State.IDLE)


## 振り返りは画面の中の遷移だけ（試合の状態は変えない。結果と振り返りは何度行き来してもよい。UC-04）。
func _open_review() -> void:
	if _state != State.IDLE:
		return
	App.request_screen(AppScreens.Id.S07_REVIEW)


func _set_state(next: State) -> void:
	_state = next
	_title_button.disabled = next != State.IDLE
	_review_button.disabled = next != State.IDLE


func _build() -> void:
	var parts: Dictionary = MatchScreenLayout.build(self, "TitleButton", "タイトルへ")
	_score_bug = parts["score_bug"] as ScoreBug
	_title_button = parts["primary"] as Button
	_title_button.theme_type_variation = &""
	_title_button.pressed.connect(_leave)
	# 「振り返り」は地 accent、「タイトルへ」は縁取りだけで列の下端（screen-06-result.md「ノード構成」）
	_review_button = Button.new()
	_review_button.name = "ReviewButton"
	_review_button.text = "振り返り"
	_review_button.custom_minimum_size = Vector2(0, MatchScreenLayout.PRIMARY_HEIGHT)
	_review_button.theme_type_variation = &"AccentCard"
	_review_button.pressed.connect(_open_review)
	_title_button.add_sibling(_review_button)
	_title_button.get_parent().move_child(_review_button, _title_button.get_index())
	var info: VBoxContainer = parts["info"] as VBoxContainer
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	MatchScreenLayout.tag(info, "FullTimeTag", "FULL TIME")
	_outcome_label = MatchScreenLayout.text(info, "OutcomeLabel", &"ResultLabel")
	# 陣形・方式の推移は操作の列の上（残りの高さ。screen-06-result.md「ノード構成」）
	var side: VBoxContainer = parts["side"] as VBoxContainer
	MatchScreenLayout.text(side, "HistoryTitle", &"SectionTitleLabel").text = "陣形・方式の推移"
	_history_list = VBoxContainer.new()
	_history_list.name = "HistoryList"
	_history_list.add_theme_constant_override("separation", 8)
	side.add_child(_history_list)

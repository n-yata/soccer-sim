## S-06 試合結果（screen-06-result.md）。勝敗と最終スコアを出し、タイトルへ戻る。
## 勝敗は色だけでなく文字で示す。タイトルへの切り替えは MatchController.leave_result が頼む。
##
## 今回の範囲で外しているもの（.steering/20261019-match-screen/design.md）: 陣形・方式の推移（final_record）と
## 「振り返り」（S-07）。勝敗とスコアは snapshot() から出す。
class_name ResultScreen
extends AppScreen

enum State { IDLE, LEAVING }

var _state: State = State.IDLE
var _score_bug: ScoreBug
var _outcome_label: Label
var _title_button: Button


func _init() -> void:
	_build()


func enter(_params: Dictionary) -> void:
	var snapshot: BoardSnapshot = App.match_controller.snapshot()
	if snapshot == null:
		return
	_score_bug.show_snapshot(snapshot, "FT")
	_outcome_label.text = outcome_text(snapshot.score_user, snapshot.score_opponent)
	_set_state(State.IDLE)


## 利用者から見た勝敗。
static func outcome_text(score_user: int, score_opponent: int) -> String:
	if score_user > score_opponent:
		return "勝ち"
	if score_user < score_opponent:
		return "負け"
	return "引き分け"


## 戻る操作は「タイトルへ」と同じ（screen-06-result.md）。
func handle_back() -> bool:
	_leave()
	return true


func state() -> State:
	return _state


func title_button() -> Button:
	return _title_button


func outcome() -> String:
	return _outcome_label.text


func score_bug() -> ScoreBug:
	return _score_bug


func _leave() -> void:
	if _state != State.IDLE:
		return
	_set_state(State.LEAVING)
	if not App.match_controller.leave_result():
		_set_state(State.IDLE)


func _set_state(next: State) -> void:
	_state = next
	_title_button.disabled = next != State.IDLE


func _build() -> void:
	var parts: Dictionary = MatchScreenLayout.build(self, "TitleButton", "タイトルへ")
	_score_bug = parts["score_bug"] as ScoreBug
	_title_button = parts["primary"] as Button
	_title_button.theme_type_variation = &""
	_title_button.pressed.connect(_leave)
	var info: VBoxContainer = parts["info"] as VBoxContainer
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	MatchScreenLayout.tag(info, "FullTimeTag", "FULL TIME")
	_outcome_label = MatchScreenLayout.text(info, "OutcomeLabel", &"ResultLabel")

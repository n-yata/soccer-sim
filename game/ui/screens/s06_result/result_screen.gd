## S-06 試合結果（screen-06-result.md）。勝敗と最終スコアを出し、振り返り（S-07）かタイトルへ進む。
## 勝敗は色だけでなく文字で示す。タイトルへの切り替えは MatchController.leave_result が頼む。
##
## 今回の範囲で外しているもの（.steering/20261019-match-screen/design.md）: 陣形・方式の推移（final_record。戦績の作業で足す）。
## 勝敗とスコアは snapshot() から出す。「振り返り」は 2026-10-29 に足した。
class_name ResultScreen
extends AppScreen

enum State { IDLE, LEAVING }

var _state: State = State.IDLE
var _score_bug: ScoreBug
var _outcome_label: Label
var _title_button: Button
var _review_button: Button


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


func review_button() -> Button:
	return _review_button


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

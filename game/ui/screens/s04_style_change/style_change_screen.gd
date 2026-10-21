## S-04 方式の選び直し（screen-04-style-change.md）。得点の後、キックオフの前に方式を選び直す。
## 初期値は現在の方式で、変えずにキックオフできる。S-03 への切り替えは MatchController が頼む。
##
## 今回の範囲で外しているもの（.steering/20261019-match-screen/design.md）: 噛み合わせ・方式の解説（NotesView）、
## 試合中のメニュー。メニューが無い間、戻る操作は何もしない。
class_name StyleChangeScreen
extends AppScreen

enum State { EDITING, SUBMITTING }

var _state: State = State.EDITING
var _score_bug: ScoreBug
var _goal_label: Label
var _opponent_label: Label
var _picker: StylePicker
var _kick_off_button: Button


func _init() -> void:
	_build()


func enter(_params: Dictionary) -> void:
	var controller: MatchController = App.match_controller
	var snapshot: BoardSnapshot = controller.snapshot()
	if snapshot == null:
		return
	_score_bug.show_snapshot(snapshot)
	_goal_label.text = goal_text(snapshot.last_goal_by)
	_opponent_label.text = "◆ CPU %s" % MatchTexts.setup_text(controller.opponent_setup())
	_picker.set_styles(snapshot.user_setup.styles)
	_set_state(State.EDITING)


## 得点の知らせ。last_goal_by は得点した側（利用者 = HOME）。
static func goal_text(last_goal_by: int) -> String:
	if last_goal_by == GameEnums.TeamSide.HOME:
		return "あなたが得点しました"
	if last_goal_by == GameEnums.TeamSide.AWAY:
		return "CPU が得点しました"
	return ""


func handle_back() -> bool:
	return true


func state() -> State:
	return _state


func picker() -> StylePicker:
	return _picker


func kick_off_button() -> Button:
	return _kick_off_button


func goal_message() -> String:
	return _goal_label.text


func opponent_text() -> String:
	return _opponent_label.text


func _on_kick_off_pressed() -> void:
	if _state != State.EDITING:
		return
	_set_state(State.SUBMITTING)
	if not App.match_controller.submit_style_change(_picker.styles()):
		_set_state(State.EDITING)


func _set_state(next: State) -> void:
	_state = next
	var editing: bool = next == State.EDITING
	_picker.set_enabled(editing)
	_kick_off_button.disabled = not editing


func _build() -> void:
	var parts: Dictionary = MatchScreenLayout.build(self, "KickOffButton", "KICK OFF キックオフ")
	_score_bug = parts["score_bug"] as ScoreBug
	_kick_off_button = parts["primary"] as Button
	_kick_off_button.pressed.connect(_on_kick_off_pressed)
	var info: VBoxContainer = parts["info"] as VBoxContainer
	MatchScreenLayout.tag(info, "GoalTag", "GOAL")
	_goal_label = MatchScreenLayout.text(info, "GoalBanner", &"CardTitleLabel")
	_opponent_label = MatchScreenLayout.text(info, "OpponentSetupLabel", &"PanelLabel")
	_picker = StylePicker.new()
	_picker.name = "StylePicker"
	(parts["side"] as VBoxContainer).add_child(_picker)
	(parts["side"] as VBoxContainer).move_child(_picker, 0)

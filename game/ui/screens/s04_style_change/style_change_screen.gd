## S-04 方式の選び直し（screen-04-style-change.md）。得点の後、キックオフの前に方式を選び直す。
## 初期値は現在の方式で、変えずにキックオフできる。S-03 への切り替えは MatchController が頼む。
## 本体に、直前の方式区間の両者の方式の噛み合わせ（MatchupNotes）と、変えた方式の単独の解説（PickedNotes）を出す（FR-17）。
## 試合中のメニュー（中断してタイトルへ）は MatchMenuHost が持つ（2026-10-29。S-03 と同じ）。
class_name StyleChangeScreen
extends AppScreen

enum State { EDITING, SUBMITTING }

var _state: State = State.EDITING
var _score_bug: ScoreBug
var _goal_label: Label
var _opponent_label: Label
var _picker: StylePicker
var _matchup_notes: NotesView
var _picked_notes: NotesView
## 直前の方式区間の自分の方式（初期値。変えた項目を見分ける）
var _current: TeamStyles
var _kick_off_button: Button
var _menu_host: MatchMenuHost


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
	_current = snapshot.user_setup.styles.duplicate_deep()
	_picker.set_styles(_current)
	_matchup_notes.show_notes(App.library.style_notes(_current, controller.opponent_setup().styles),
			App.library.simplifications())
	_refresh_picked_notes(_current)
	_set_state(State.EDITING)


## 得点の知らせ。last_goal_by は得点した側（利用者 = HOME）。
static func goal_text(last_goal_by: int) -> String:
	if last_goal_by == GameEnums.TeamSide.HOME:
		return "あなたが得点しました"
	if last_goal_by == GameEnums.TeamSide.AWAY:
		return "CPU が得点しました"
	return ""


## 戻る操作: メニュー・確認が開いていれば閉じ、EDITING ならメニューを開く（screen-04-style-change.md）。アプリは閉じない。
func handle_back() -> bool:
	return _menu_host.handle_back()


func state() -> State:
	return _state


func menu_host() -> MatchMenuHost:
	return _menu_host


func picker() -> StylePicker:
	return _picker


func kick_off_button() -> Button:
	return _kick_off_button


func matchup_notes() -> NotesView:
	return _matchup_notes


func picked_notes() -> NotesView:
	return _picked_notes


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


## 直前の方式と違う項目だけ、その単独の解説を出す。どれも同じなら隠す。
func _refresh_picked_notes(picked: TeamStyles) -> void:
	if _current == null:
		return
	var notes: Array[MatchupNote] = []
	if picked.defense != _current.defense:
		notes.append_array(App.library.defense_style_notes(picked.defense))
	if picked.attack != _current.attack:
		notes.append_array(App.library.attack_style_notes(picked.attack))
	_picked_notes.show_notes(notes, App.library.simplifications())
	_picked_notes.visible = not notes.is_empty()


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
	MatchScreenLayout.text(info, "MatchupTitle", &"SectionTitleLabel").text = "直前の噛み合わせ"
	_matchup_notes = NotesView.new()
	_matchup_notes.name = "MatchupNotes"
	info.add_child(_matchup_notes)
	_picked_notes = NotesView.new()
	_picked_notes.name = "PickedNotes"
	_picked_notes.visible = false
	info.add_child(_picked_notes)
	_picker = StylePicker.new()
	_picker.name = "StylePicker"
	_picker.changed.connect(_refresh_picked_notes)
	(parts["side"] as VBoxContainer).add_child(_picker)
	(parts["side"] as VBoxContainer).move_child(_picker, 0)
	_menu_host = MatchMenuHost.new(self, parts["top_bar"] as HBoxContainer, func() -> bool: return _state == State.EDITING)

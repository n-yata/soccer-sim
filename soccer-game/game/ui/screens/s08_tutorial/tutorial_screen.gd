## S-08 チュートリアル（screen-08-tutorial.md。FR-12・FR-23）。段階（App.library.tutorial_steps()）を順に進める。
## EXPLAIN は説明と操作できない盤面、OPERATE は選べる手を絞った盤面で1手決める（判定理由が出たら「次へ」）、
## 最後の SCOPE は単純化の一覧と「完了」。盤面は試合と同じ MatchBoardPanel で、コントローラーはチュートリアル用
## （App.new_tutorial_controller()。保存しない・画面の切り替えを頼まない）。画面を閉じたら捨てる。
## ファイルの目安（300行）を超えている分は、ノードを組むコード（_build_*）とテストが読む問い合わせ。段階を進める流れは
## 1つなので分けない（試合画面・振り返り・戦績の画面と同じ形）。
class_name TutorialScreen
extends AppScreen

const HEADER_SCENE: PackedScene = preload("res://ui/common/screen_header.tscn")
const QUIT_MESSAGE: String = "チュートリアルをやめますか？（最初からやり直せます）"
## 説明の吹き出しの高さ（操作の列に手のボタンと「次へ」を残すため。長い説明は吹き出しの中でスクロールする）
const COACH_HEIGHT: float = 200.0
const COACH_FONT_SIZE: int = 22
const NEXT_HEIGHT: float = 112.0
## 上下の余白（S-03 と同じ。6列の作戦ボードの最小の高さ 600px を入れるため。screen-common.md §1.1）
const VERTICAL_MARGIN: int = 12
const STAGE_HEIGHT: float = 600.0

var _controller: MatchController
var _steps: Array[TutorialStepDef] = []
var _index: int = 0
var _can_next: bool = false

var _header: ScreenHeader
var _progress: ProgressBar
var _phase_tag: Label
var _reveal_banner: Label
var _panel: MatchBoardPanel
var _coach: PanelContainer
var _coach_text: Label
var _next_button: Button
var _scope_view: HBoxContainer
var _scope_list: SimplificationList
var _scope_text: Label
var _complete_button: Button
var _dialog: ConfirmDialog
## 局面が変わったときの帯（S-03 と同じ。前の段階と局面が変わったら出す。2026-11-08）
var _phase_banner: PhaseBanner


func _init() -> void:
	_build()


## ヘッダーの部品（@onready）は木に入ってから決まるので、戻るの文字とつなぎはここで付ける。
func _ready() -> void:
	_header.set_back_label("← やめる")
	_header.back_pressed.connect(_ask_quit)


func enter(_params: Dictionary) -> void:
	# 画面は開くたびに作り直す（ScreenSwitcher）。同じ画面で2回呼ばれたら何もしない（パネルは最初のコントローラーにつながったままになり、
	# 新しいコントローラーで作った盤面と食い違うため）
	if _controller != null:
		return
	_controller = App.new_tutorial_controller()
	_steps = App.library.tutorial_steps()
	_index = 0
	_phase_banner.forget()
	_panel.bind(_controller, false)
	_panel.turn_started.connect(_on_turn_started)
	_panel.reveal_started.connect(_on_reveal_started)
	_panel.turn_ready_to_leave.connect(_on_turn_ready_to_leave)
	_panel.set_show_hints(App.user_data.settings().show_hints)
	if _steps.is_empty():
		# 静的データの誤り（ContentRepository が push_error 済み）。段階が無ければ、すぐ終われるようにする
		push_error("TutorialScreen: 段階が無い")
		_show_scope("")
		return
	_start_step()


func exit() -> void:
	for connection: Array in [[_panel.turn_started, _on_turn_started], [_panel.reveal_started, _on_reveal_started],
			[_panel.turn_ready_to_leave, _on_turn_ready_to_leave]]:
		var sig: Signal = connection[0] as Signal
		if sig.is_connected(connection[1] as Callable):
			sig.disconnect(connection[1] as Callable)
	_panel.unbind()
	_controller = null


## 戻る操作: 確認が開いていれば閉じる（「続ける」と同じ）。それ以外はやめるかを確かめる。どちらも true。
func handle_back() -> bool:
	if _dialog.is_open():
		_dialog.cancel()
	else:
		_ask_quit()
	return true


# --- テストが読む問い合わせ ---

func step_index() -> int:
	return _index


func step_count() -> int:
	return _steps.size()


func can_next() -> bool:
	return _can_next


func coach_text() -> String:
	return _coach_text.text if _coach.visible else ""


func title_text() -> String:
	return _header.title_text()


func board_panel() -> MatchBoardPanel:
	return _panel


func next_button() -> Button:
	return _next_button


func complete_button() -> Button:
	return _complete_button


func scope_list() -> SimplificationList:
	return _scope_list


func is_scope_shown() -> bool:
	return _scope_view.visible


func confirm_dialog() -> ConfirmDialog:
	return _dialog


func phase_banner() -> PhaseBanner:
	return _phase_banner


func phase_text() -> String:
	return _phase_tag.text if _phase_tag.visible else ""


func reveal_text() -> String:
	return _reveal_banner.text if _reveal_banner.visible else ""


# --- 段階 ---

## 段階を始める（screen-08-tutorial.md「段階を始める」）。
func _start_step() -> void:
	var step: TutorialStepDef = _steps[_index]
	_header.set_title("チュートリアル %d／%d" % [_index + 1, _steps.size()])
	_progress.value = float(_index + 1) / float(_steps.size()) * 100.0
	if not step.has_board():
		_show_scope(step.text)
		return
	_scope_view.visible = false
	_panel.visible = true
	_coach_text.text = step.text
	_coach.visible = true
	_controller.start_tutorial_step(step)
	_panel.set_options_filter(step.allowed_actions)
	_panel.set_interactive(step.kind == TutorialStepDef.Kind.OPERATE)
	# 前の段階で出したカットインは、この段階の局面と関係が無い（説明だけの段階をはさむと、印が残り続ける）
	_panel.forget_transition_cut_in()
	_panel.start_turn()
	_set_can_next(step.kind == TutorialStepDef.Kind.EXPLAIN)


## 最後の段階: 単純化の一覧と「完了」。
func _show_scope(text: String) -> void:
	_panel.visible = false
	_phase_tag.visible = false
	_reveal_banner.visible = false
	_phase_banner.dismiss()
	_scope_view.visible = true
	_scope_text.text = text
	_scope_list.show_items(App.library.simplifications())
	_set_can_next(false)


func _set_can_next(value: bool) -> void:
	_can_next = value
	# 押せない間は隠す（説明文と手のボタンを一度に見せるため）
	_next_button.visible = value


func _on_next_pressed() -> void:
	if not _can_next or _index >= _steps.size() - 1:
		return
	_index += 1
	_start_step()


## 完了: 完了フラグを保存してタイトルへ（保存に失敗しても完了の表示は行う。通知は MainShell）。
func _on_complete_pressed() -> void:
	# 段階が無い（静的データの誤り）ときは完了にしない（直した後に、体験していないチュートリアルが完了のまま残るため）
	if not _steps.is_empty():
		App.user_data.mark_tutorial_completed()
	_leave()


func _ask_quit() -> void:
	if _dialog.is_open():
		return
	_dialog.answered.connect(_on_quit_answered, CONNECT_ONE_SHOT)
	_dialog.ask(QUIT_MESSAGE, "やめる", "続ける")


func _on_quit_answered(ok: bool) -> void:
	if ok:
		_leave()


func _leave() -> void:
	_controller = null
	App.request_screen(AppScreens.Id.S01_TITLE)


func _on_turn_started(snapshot: BoardSnapshot) -> void:
	_phase_tag.text = MatchTexts.phase_tag(snapshot.turn_kind, snapshot.user_has_ball)
	_phase_tag.visible = true
	_reveal_banner.visible = false
	# 直前の開示でボールを奪った・奪われたカットインを出したなら、局面の変わり目はもう見せている（2026-11-08）
	_phase_banner.follow(MatchTexts.user_phase(snapshot.turn_kind, snapshot.user_has_ball),
			_panel.showed_transition_cut_in())


func _on_reveal_started(reveal: RevealView) -> void:
	_reveal_banner.text = "あなた: %s\nCPU: %s" % [MatchTexts.choice_summary(reveal.user_choice),
			MatchTexts.choice_summary(reveal.opponent_choice)]
	_phase_tag.visible = false
	_reveal_banner.visible = true
	_phase_banner.dismiss()


## 判定理由が出た（パネルは主ボタンを出さない）。チュートリアルは continue_after_reveal を呼ばず、次の段階で作り直す。
## 説明の吹き出しは畳む（操作の列の高さが限られ、判定理由のテロップが下で切れるため。説明は手を選ぶ前に読んでいる）。
func _on_turn_ready_to_leave() -> void:
	_coach.visible = false
	_set_can_next(true)


# --- 骨組み ---

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VERTICAL_MARGIN)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	margin.add_child(layout)
	_header = HEADER_SCENE.instantiate() as ScreenHeader
	_header.name = "Header"
	layout.add_child(_header)
	_header.add_to_right(_build_header_right())

	var stage := Control.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(stage)
	_panel = MatchBoardPanel.new()
	_panel.name = "MatchView"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_panel)
	_build_coach()
	_scope_view = _build_scope_view()
	stage.add_child(_scope_view)
	# 局面の帯は盤面と説明の上に重ね、確認のダイアログより下に置く
	_phase_banner = PhaseBanner.new()
	add_child(_phase_banner)
	_dialog = ConfirmDialog.new()
	add_child(_dialog)


## ヘッダーの右: 進み具合・局面のタグ・両者の選択の帯（開示から次の段階まで、タグの代わりに出す）。
func _build_header_right() -> Control:
	var row := HBoxContainer.new()
	row.name = "HeaderRight"
	row.add_theme_constant_override("separation", 16)
	_progress = ProgressBar.new()
	_progress.name = "StepProgress"
	_progress.custom_minimum_size = Vector2(200, 0)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.show_percentage = false
	row.add_child(_progress)
	_phase_tag = Label.new()
	_phase_tag.name = "PhaseTag"
	_phase_tag.theme_type_variation = &"TagLabel"
	_phase_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_phase_tag)
	_reveal_banner = Label.new()
	_reveal_banner.name = "RevealBanner"
	_reveal_banner.theme_type_variation = &"PanelLabel"
	_reveal_banner.add_theme_font_size_override("font_size", 20)
	_reveal_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reveal_banner.visible = false
	row.add_child(_reveal_banner)
	return row


## 説明の吹き出し（操作の列の上端）と「次へ」（操作の列の下端）。
func _build_coach() -> void:
	var coach := PanelContainer.new()
	_coach = coach
	coach.name = "Coach"
	coach.theme_type_variation = &"SurfaceCard"
	var scroll := ScrollContainer.new()
	scroll.name = "CoachScroll"
	scroll.custom_minimum_size = Vector2(0, COACH_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coach.add_child(scroll)
	_coach_text = MatchScreenLayout.text(scroll, "CoachText", &"")
	_coach_text.add_theme_font_size_override("font_size", COACH_FONT_SIZE)
	_panel.side_top_slot().add_child(coach)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "次へ"
	_next_button.theme_type_variation = &"AccentCard"
	_next_button.custom_minimum_size = Vector2(0, NEXT_HEIGHT)
	_next_button.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	_panel.side_bottom_slot().add_child(_next_button)


## 最後の段階: 本体に単純化の一覧（2列）、操作の列に説明と下端の「完了」。
func _build_scope_view() -> HBoxContainer:
	var view := HBoxContainer.new()
	view.name = "ScopeView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_theme_constant_override("separation", 24)
	view.visible = false
	var scroll := ScrollContainer.new()
	scroll.name = "ScopeList"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	view.add_child(scroll)
	_scope_list = SimplificationList.new()
	scroll.add_child(_scope_list)
	var side := VBoxContainer.new()
	side.name = "ScopeSide"
	side.custom_minimum_size = Vector2(MatchBoardPanel.SIDE_WIDTH, 0)
	view.add_child(side)
	_scope_text = MatchScreenLayout.text(side, "ScopeText", &"")
	_scope_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_complete_button = Button.new()
	_complete_button.name = "CompleteButton"
	_complete_button.text = "完了"
	_complete_button.theme_type_variation = &"AccentCard"
	_complete_button.custom_minimum_size = Vector2(0, NEXT_HEIGHT)
	_complete_button.pressed.connect(_on_complete_pressed)
	side.add_child(_complete_button)
	return view

## 試合画面の盤面と手の選択（screen-common.md §5 の MatchBoardPanel。手順の正本は screen-03-match.md）。
## 左に作戦ボード、右に操作の列（両チームの陣形・方式、手のボタン、運ぶ先の説明、判定理由、主ボタン）。
## 手の選択から判定理由の表示までの状態と、MatchController の turn_resolved の受信はこの部品が持つ。
##
## turn_resolved を受けたら、すぐ判定理由の表示へ進み、盤面の上で駒とボールを動かす（3D 演出は 2026-10-23 にやめた）。
## 今回の範囲で外しているもの（.steering/20261019-match-screen/design.md）: 「実戦では」。
## チュートリアル（S-08）のための口: bind の show_next・set_options_filter・set_interactive・side_top_slot／side_bottom_slot（2026-10-29）。
## 子のノードはコードで組む（部品を差し替えやすく、テストで名前を引けるよう、ノード名は screen-03-match.md に合わせる）。
## ファイルの目安（300行）を超えている分は、ノードを組むコード（_build_*）。手の選択から判定理由までの流れは1つの
## 状態機械なので分けない。部品が増えたときに、組む部分を .tscn へ移すかを見直す。
class_name MatchBoardPanel
extends Control

## 判定理由を確認し、主ボタン（次のターンへ）が押された
signal turn_ready_to_leave
## 手の選択を始めた（画面側が上部バーを描き直す）
signal turn_started(snapshot: BoardSnapshot)
## 開示を受けた（画面側が両者の選択の帯を出す）
signal reveal_started(reveal: RevealView)
## 判定理由を出した（画面側がスコアを描き直す。得点を開示より先に見せないため、ここで初めて新しい盤面を渡す）
signal result_shown(snapshot: BoardSnapshot)

enum State { IDLE, SELECT_ACTION, SELECT_TARGET, READY, SUBMITTING, SHOW_RESULT, LEAVING }

const SIDE_WIDTH: float = 480.0
const PRIMARY_HEIGHT: float = 112.0
const LOCK_IN: String = "LOCK IN"
const NEXT: String = "NEXT"
const NEXT_SUMMARY: String = "次のターンへ"

var _controller: MatchController
var _state: State = State.IDLE
var _snapshot: BoardSnapshot
var _options: MoveOptions
var _hints: Array[ChoiceHint] = []
## ヒント表示（設定。FR-19）。OFF の間は user_hints() を呼ばず、ヒントを空にする
var _show_hints: bool = true
## 判定理由の後に主ボタン（次のターンへ）を出すか。偽なら出さずに turn_ready_to_leave を出す（チュートリアルは画面の「次へ」を使う）
var _show_next: bool = true
## 選べる手を絞る区分値の名前（空なら絞らない。チュートリアルの段階）
var _options_filter: Array[String] = []
## 手のボタンと主ボタンを出すか（偽なら盤面を見せるだけ。チュートリアルの説明の段階）
var _is_interactive: bool = true
var _selected_family: GameEnums.ChoiceFamily = GameEnums.ChoiceFamily.ATTACK
var _selected_action: int = -1
var _selected_target: String = ""
var _reveal: RevealView

var _board: TacticsBoard
var _user_setup_label: Label
var _opponent_setup_label: Label
var _choice_panel: ChoicePanel
var _target_info: Label
## 操作の列の中ほど（手のボタン・運ぶ先の説明・判定理由）を縦にスクロールする入れ物
var _side_scroll: ScrollContainer
var _judge_telop: VBoxContainer
var _outcome_tag: Label
var _reason_label: Label
var _judge_detail: Label
var _primary_button: Button
var _button_summary: Label
var _button_action: Label
var _side_top_slot: VBoxContainer
var _side_bottom_slot: VBoxContainer


func _init() -> void:
	_build()


## コントローラーをつなぐ（画面の enter で1回だけ。2回目以降は何もしない）。show_next が偽なら、判定理由を出しても主ボタンを
## 出さず、すぐ turn_ready_to_leave を出す（チュートリアル。screen-08-tutorial.md）。
func bind(controller: MatchController, show_next: bool = true) -> void:
	if _controller != null:
		return
	_controller = controller
	_show_next = show_next
	_controller.turn_resolved.connect(_on_turn_resolved)
	_board.set_ball_style(_controller.ball_style())
	_board.set_result_sec(_controller.board_result_sec())


## コントローラーとのつながりを切る（画面の exit）。
func unbind() -> void:
	if _controller != null and _controller.turn_resolved.is_connected(_on_turn_resolved):
		_controller.turn_resolved.disconnect(_on_turn_resolved)
	_controller = null
	_state = State.IDLE


## ターンを始める（screen-03-match.md「ターンを始める」）。前のターンの選択・ヒント・矢印は残さない。
func start_turn() -> void:
	if _controller == null:
		push_error("MatchBoardPanel: bind の前に start_turn は呼べない")
		return
	_snapshot = _controller.snapshot()
	_options = _filtered(_controller.user_options())
	_hints = _current_hints()
	_selected_action = -1
	_selected_target = ""
	_reveal = null
	_board.clear_overlays()
	_board.show_snapshot(_snapshot)
	_choice_panel.show_options(_options, _snapshot.turn_kind, _snapshot.user_has_ball)
	# 選べる手が1つもないことは起きない（トランジション・守備の手は常に1つ以上選べる。アルゴリズム3）。
	# 起きたら開発時の誤りとして止める（screen-03-match.md「例外・エラー表示」）
	assert(_choice_panel.has_available(), "MatchBoardPanel: 選べる手が1つもない")
	_choice_panel.visible = _is_interactive
	_primary_button.visible = _is_interactive
	_choice_panel.set_enabled(true)
	_target_info.text = ""
	_target_info.visible = false
	_judge_telop.visible = false
	_user_setup_label.text = "● 自分 %s" % MatchTexts.setup_text(_snapshot.user_setup)
	_opponent_setup_label.text = "◆ CPU %s" % MatchTexts.setup_text(_snapshot.opponent_setup)
	_set_primary("", LOCK_IN, false)
	_state = State.SELECT_ACTION
	turn_started.emit(_snapshot)


func state() -> State:
	return _state


## 選べる手を区分値の名前で絞る（チュートリアルの段階。空なら絞らない）。次の start_turn から効く。
func set_options_filter(actions: Array[String]) -> void:
	_options_filter = actions.duplicate()


## 偽なら手のボタンと主ボタンを隠し、盤面を見せるだけにする（チュートリアルの説明の段階）。次の start_turn から効く。
func set_interactive(enabled: bool) -> void:
	_is_interactive = enabled


## 操作の列の上端（両チームの陣形・方式の下）に部品を置く入れ物（チュートリアルの説明の吹き出し）。
func side_top_slot() -> VBoxContainer:
	return _side_top_slot


## 操作の列の下端（主ボタンの上）に部品を置く入れ物（チュートリアルの「次へ」）。
func side_bottom_slot() -> VBoxContainer:
	return _side_bottom_slot


## ヒント表示を切り替える（試合中のメニューの設定から）。手を選んでいる間なら、選んだ手と運ぶ先のまま描き直す
## （screen-03-match.md「メニュー」の 2.）。
func set_show_hints(is_on: bool) -> void:
	if is_on == _show_hints:
		return
	_show_hints = is_on
	if _state not in [State.SELECT_ACTION, State.SELECT_TARGET, State.READY]:
		return
	_hints = _current_hints()
	if _state == State.SELECT_ACTION:
		return
	var target: String = _selected_target
	_on_action_selected(_selected_family, _selected_action)
	if not target.is_empty():
		_on_area_pressed(target)


# --- 部品（画面とテストが使う） ---

func board() -> TacticsBoard:
	return _board


func choice_panel() -> ChoicePanel:
	return _choice_panel


func primary_button() -> Button:
	return _primary_button


func primary_summary() -> String:
	return _button_summary.text


## 攻撃の手は6つあり、運ぶ先の説明が手のボタンの下ではみ出すので、説明が見える所までスクロールする（2026-10-25）。
## 折り返す説明の高さは、幅が決まってから次の並べ直しで決まるため、2フレーム待ってから位置を測る
## （遅らせて呼ぶだけでは、試合画面の入れ子の並べ直しより先に走り、スクロールしなかった）。
func _scroll_to_target_info() -> void:
	for _frame: int in range(2):
		if not is_inside_tree():
			return
		await get_tree().process_frame
	# 待つ間に画面を離れたら（ツリーから外れたら）何もしない
	if is_inside_tree() and is_instance_valid(_target_info) and _target_info.visible:
		_side_scroll.ensure_control_visible(_target_info)


func target_info_text() -> String:
	return _target_info.text if _target_info.visible else ""


func telop_visible() -> bool:
	return _judge_telop.visible


func outcome_text() -> String:
	return _outcome_tag.text


func outcome_variation() -> String:
	return _outcome_tag.theme_type_variation


## 結果の札のテーマの種類。成功した側の色（自分・相手）で、どちらでもなければ元の札。
static func outcome_variation_for(winner: MatchTexts.TurnWinner) -> StringName:
	match winner:
		MatchTexts.TurnWinner.USER:
			return &"YouOutcomeTagLabel"
		MatchTexts.TurnWinner.OPPONENT:
			return &"OpponentOutcomeTagLabel"
	return &"OutcomeTagLabel"


func reason_text() -> String:
	return _reason_label.text


func detail_text() -> String:
	return _judge_detail.text if _judge_detail.visible else ""


func setup_texts() -> Array[String]:
	return [_user_setup_label.text, _opponent_setup_label.text]


# --- 手の選択 ---

func _on_action_selected(family: GameEnums.ChoiceFamily, action: int) -> void:
	if _state not in [State.SELECT_ACTION, State.SELECT_TARGET, State.READY]:
		return
	_selected_family = family
	_selected_action = action
	_selected_target = ""
	_choice_panel.select_action(action)
	_board.set_selected("")
	_board.show_intent("", "")
	_board.show_preview([])
	if MoveOptions.needs_target(family, action):
		var keys: Array[String] = []
		for target: PitchArea in _options.targets(family, action):
			keys.append(target.to_key())
		var tags: Dictionary = {}
		var even_keys: Array[String] = []
		for hint: ChoiceHint in _hints_for(family, action):
			if hint.target != null:
				tags[hint.target.to_key()] = MatchTexts.hint_tag(hint)
				if MatchTexts.is_hint_muted(hint):
					even_keys.append(hint.target.to_key())
		_board.set_selectable(keys)
		_board.set_hints(tags, even_keys)
		_target_info.text = MatchTexts.target_rule(family, action)
		_target_info.visible = not _target_info.text.is_empty()
		if _target_info.visible:
			_scroll_to_target_info()
		_state = State.SELECT_TARGET
		_set_primary(MatchTexts.action_name(family, action), LOCK_IN, false)
		return
	# 運ぶ先を持たない手: その手のヒント（比べる人数）を説明に出し、すぐ決定できる
	_board.set_selectable([])
	_board.set_hints({})
	var info: String = ""
	for hint: ChoiceHint in _hints_for(family, action):
		# 人数を比べるヒントの最初の1件を出す（後の比べないヒントで空に上書きしない）
		var counts: String = MatchTexts.hint_counts(hint)
		if not counts.is_empty():
			info = "比べる人数 %s" % counts
			break
	_target_info.text = info
	_target_info.visible = not info.is_empty()
	_board.show_preview(_controller.user_preview(_current_choice()))
	_state = State.READY
	_set_primary(MatchTexts.action_name(family, action), LOCK_IN, true)


func _on_area_pressed(area_key: String) -> void:
	if _state not in [State.SELECT_TARGET, State.READY] or not _board.selectable_areas().has(area_key):
		return
	_selected_target = area_key
	_board.set_selected(area_key)
	# ボールから運ぶ先への矢印は、ボールを運ぶ手（攻撃・カウンター）だけ。守備の手で選ぶのは「相手が来ると読んだエリア」で、
	# ボールはそこへ動かない。動く選手はプレビューで見せる
	var carries_ball: bool = _selected_family in [GameEnums.ChoiceFamily.ATTACK, GameEnums.ChoiceFamily.POS_TRANS]
	_board.show_intent(_snapshot.ball_area if carries_ball else "", area_key if carries_ball else "")
	_board.show_preview(_controller.user_preview(_current_choice()))
	var info: String = MatchTexts.area_name(area_key)
	for hint: ChoiceHint in _hints_for(_selected_family, _selected_action):
		if hint.target != null and hint.target.to_key() == area_key:
			info = "%s　%s　%s" % [info, MatchTexts.hint_tag(hint), MatchTexts.hint_counts(hint)]
	_target_info.text = info.strip_edges()
	_target_info.visible = true
	_state = State.READY
	_set_primary(MatchTexts.choice_summary(_current_choice()), LOCK_IN, true)


func _on_primary_pressed() -> void:
	if _state == State.READY:
		_submit()
	elif _state == State.SHOW_RESULT:
		_state = State.LEAVING
		_primary_button.disabled = true
		turn_ready_to_leave.emit()


## 「決定」。結果は同じ呼び出しの中で turn_resolved として届く。false（選べない手。通常は起きない）なら選び直させる。
func _submit() -> void:
	_state = State.SUBMITTING
	_primary_button.disabled = true
	_board.show_preview([])
	_choice_panel.set_enabled(false)
	if not _controller.submit_turn(_current_choice()) and _state == State.SUBMITTING:
		start_turn()


func _current_choice() -> TurnChoice:
	var target: PitchArea = null if _selected_target.is_empty() else PitchArea.from_key(_selected_target)
	return TurnChoice.new(_selected_family, _selected_action, target)


## 絞り込み（set_options_filter）があれば、その局面の手のうち名前が合う手だけを残す（手を足すことはない）。
func _filtered(options: MoveOptions) -> MoveOptions:
	if _options_filter.is_empty():
		return options
	var family: GameEnums.ChoiceFamily = TurnChoice.family_for(_snapshot.turn_kind, _snapshot.user_has_ball)
	var names: Dictionary = TurnChoice.ACTION_ENUMS[family]
	var actions: Array[int] = []
	for action_name: String in _options_filter:
		if names.has(action_name):
			actions.append(names[action_name] as int)
	return options.restricted_to(family, actions)


## ヒント表示が ON なら利用者のヒント、OFF なら空（user_hints() を呼ばない）。
func _current_hints() -> Array[ChoiceHint]:
	if _show_hints:
		return _controller.user_hints()
	return []


func _hints_for(family: GameEnums.ChoiceFamily, action: int) -> Array[ChoiceHint]:
	var result: Array[ChoiceHint] = []
	for hint: ChoiceHint in _hints:
		if hint.family == family and hint.action == action:
			result.append(hint)
	return result


# --- 開示と判定理由 ---

## 開示（screen-03-match.md「開示」）。盤面の上で駒とボールを動かし、1拍目が着地したら判定理由を出す
## （1拍目が無ければすぐ。結果が分かる前の溜めを作る。2026-11-03）。「次へ」はすぐ押せる。
func _on_turn_resolved(reveal: RevealView, snapshot: BoardSnapshot) -> void:
	if _state != State.SUBMITTING:
		return
	_reveal = reveal
	_snapshot = snapshot
	reveal_started.emit(reveal)
	_board.clear_overlays()
	_board.show_snapshot(snapshot)
	_choice_panel.visible = false
	_target_info.visible = false
	_outcome_tag.text = MatchTexts.outcome_tag(reveal)
	_outcome_tag.theme_type_variation = outcome_variation_for(MatchTexts.turn_winner(reveal))
	_reason_label.text = JudgeReasonFormatter.format(reveal)
	_judge_detail.text = JudgeReasonFormatter.detail(reveal)
	_judge_detail.visible = not _judge_detail.text.is_empty()
	_judge_telop.visible = false
	_set_primary(NEXT_SUMMARY, NEXT, true)
	# 着地は start_shift の中ですぐ届くことがあるので、テロップの中身と状態は先に作っておく
	_state = State.SHOW_RESULT
	# 2拍で動かす。1拍目（プレー）は判定前 → 判定時、2拍目（詰め直し）は判定時 → 次のターン開始時。
	# どちらの拍も、位置が変わった全員を動かす（方式でずれた選手も。矢印はすぐ出す）。
	# 1拍目のボールは、ボールを持つ側の手の軌道で動き、1拍目の終わりに結果の演出を出す
	_board.start_shift([
		{"user": reveal.user_players_before, "opponent": reveal.opponent_players_before, "ball": reveal.ball_before,
				"sec": _controller.board_play_sec(), "flight": BallFlight.kind_for(BallFlight.holder_choice(reveal))},
		{"user": reveal.user_players_at_judgement, "opponent": reveal.opponent_players_at_judgement,
				"ball": reveal.ball_after, "sec": _controller.board_settle_sec()},
	], ResultEffect.for_reveal(reveal))
	_board.show_movements(reveal.movements)
	if reveal.has_detail:
		_board.show_compare(reveal.compare_area, reveal.user_count, reveal.opponent_count)
	result_shown.emit(snapshot)
	if not _show_next:
		_primary_button.visible = false
		turn_ready_to_leave.emit()


## 1拍目の着地で、開示のテロップを出す。開示中でなければ出さない（「ターンを始める」は _reveal を空にしてから盤面を消すので、
## 前のターンの動きを止めたときに届く着地では出ない）。
func _on_play_landed() -> void:
	if _reveal == null:
		return
	_judge_telop.visible = true


func _set_primary(summary: String, action: String, enabled: bool) -> void:
	_button_summary.text = summary
	_button_action.text = action
	_primary_button.disabled = not enabled


# --- ノードを組む ---

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)

	_board = TacticsBoard.new()
	_board.name = "TacticsBoard"
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.area_pressed.connect(_on_area_pressed)
	_board.play_landed.connect(_on_play_landed)
	columns.add_child(_board)

	var side := VBoxContainer.new()
	side.name = "SideColumn"
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	side.add_theme_constant_override("separation", 16)
	columns.add_child(side)
	_build_setup_card(side)
	_side_top_slot = VBoxContainer.new()
	_side_top_slot.name = "SideTopSlot"
	side.add_child(_side_top_slot)
	_build_side_body(side)
	_side_bottom_slot = VBoxContainer.new()
	_side_bottom_slot.name = "SideBottomSlot"
	side.add_child(_side_bottom_slot)
	_build_primary_button(side)


## 操作の列の上端: 両チームの陣形・方式（常に表示。FR-16・21）
func _build_setup_card(side: VBoxContainer) -> void:
	var setup_card := VBoxContainer.new()
	setup_card.name = "SetupCard"
	setup_card.add_theme_constant_override("separation", 4)
	side.add_child(setup_card)
	_user_setup_label = _label("UserSetupLabel", &"SetupLabel", setup_card)
	_opponent_setup_label = _label("OpponentSetupLabel", &"SetupLabel", setup_card)
	# 両チームの陣形・方式は1行ずつ（screen-03-match.md。各 24px、入りきらなければ ELLIPSIS）。全文は方式の選び直し・ハーフタイムの画面で読める
	for label: Label in [_user_setup_label, _opponent_setup_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true


## 操作の列の中ほど（縦にスクロール）: 手のボタン・運ぶ先の説明・判定理由のテロップ
func _build_side_body(side: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "SideScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_side_scroll = scroll
	var body := VBoxContainer.new()
	body.name = "SideBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)

	_choice_panel = ChoicePanel.new()
	_choice_panel.name = "ChoicePanel"
	_choice_panel.action_selected.connect(_on_action_selected)
	body.add_child(_choice_panel)
	_target_info = _label("TargetInfo", &"PanelLabel", body)
	_target_info.visible = false

	_judge_telop = VBoxContainer.new()
	_judge_telop.name = "JudgeTelop"
	_judge_telop.add_theme_constant_override("separation", 8)
	_judge_telop.visible = false
	body.add_child(_judge_telop)
	_outcome_tag = _label("OutcomeTag", &"OutcomeTagLabel", _judge_telop)
	# 折り返さない（幅を詰めると1文字ずつ縦に並ぶため）
	_outcome_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_outcome_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reason_label = _label("ReasonLabel", &"TelopLabel", _judge_telop)
	_judge_detail = _label("JudgeDetail", &"MutedLabel", _judge_telop)


## 操作の列の下端に固定する主ボタン（「決定」と「次のターンへ」。中に要約と操作の2行）
func _build_primary_button(side: VBoxContainer) -> void:
	_primary_button = Button.new()
	_primary_button.name = "PrimaryButton"
	_primary_button.custom_minimum_size = Vector2(0, PRIMARY_HEIGHT)
	_primary_button.theme_type_variation = &"AccentCard"
	_primary_button.pressed.connect(_on_primary_pressed)
	side.add_child(_primary_button)
	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primary_button.add_child(lines)
	_button_summary = _label("ButtonSummary", &"KickOffSubLabel", lines)
	_button_action = _label("ButtonAction", &"KickOffLabel", lines)
	for label: Label in [_button_summary, _button_action]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true


func _label(node_name: String, variation: StringName, parent: Control) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

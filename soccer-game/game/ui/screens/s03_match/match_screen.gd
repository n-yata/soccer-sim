## S-03 試合（screen-03-match.md）。上部バー（スコア・局面のタグ・両者の選択の帯）と、盤面と手の選択（MatchBoardPanel）。
## 手の選択から判定理由までの状態はパネルが持ち、この画面は上部バーと画面の進み方（continue_after_reveal）を持つ。
##
## 試合中のメニュー（中断してタイトルへ）は MatchMenuHost が持つ（2026-10-29）。メニューの「設定」は設定の作業で足す。
## 3D 演出は 2026-10-23 にやめた。
class_name MatchScreen
extends AppScreen

const TOP_BAR_HEIGHT: float = 96.0
## 画面の上下の外周の余白（左右は 24px）
const VERTICAL_MARGIN: int = 12
const SIDE_MARGIN: int = 24
## 縦の左右の外周の余白。幅 720px から作戦ボードの最小の幅（136px × 5レーン = 680px）を取るため、横より詰める（2026-11-27）
const PORTRAIT_SIDE_MARGIN: int = 16
## 縦の上部バーの2段目（保持・局面のタグ／両者の選択の帯）の高さ
const PORTRAIT_SECOND_ROW_HEIGHT: float = 72.0

var _controller: MatchController
var _score_bug: ScoreBug
## どちらのボールか。開示中も消さず、常に出す（2026-10-24）
var _possession_label: Label
var _phase_tag: Label
var _reveal_banner: VBoxContainer
var _user_choice_label: Label
var _opponent_choice_label: Label
var _board_panel: MatchBoardPanel
## 外周の余白と、上部バーの1段目・2段目（2段目は縦のときだけ使う。2026-11-27）
var _margin: MarginContainer
var _top_bar: HBoxContainer
var _top_second_row: HBoxContainer
var _menu_host: MatchMenuHost
## 開示中のターン（結果を出したときに、得点の音を選ぶ）
var _reveal: RevealView
## 局面が変わったときの帯（2026-11-07）。試合画面を開いた最初のターン（キックオフ・再開）では出さない
var _phase_banner: PhaseBanner


func _init() -> void:
	_build()


func enter(_params: Dictionary) -> void:
	_controller = App.match_controller
	_phase_banner.forget()
	if not _controller.is_match_started():
		push_error("MatchScreen: 試合が始まる前に試合画面は開けない")
		return
	_controller.state_changed.connect(_on_state_changed)
	_board_panel.turn_started.connect(_on_turn_started)
	_board_panel.reveal_started.connect(_on_reveal_started)
	_board_panel.result_shown.connect(_on_result_shown)
	_board_panel.turn_ready_to_leave.connect(_on_turn_ready_to_leave)
	_board_panel.bind(_controller)
	# ヒント表示が OFF なら、パネルは user_hints() を呼ばない（screen-03-match.md「ターンを始める」）
	_board_panel.set_show_hints(App.user_data.settings().show_hints)
	_board_panel.start_turn()


func exit() -> void:
	if _controller != null and _controller.state_changed.is_connected(_on_state_changed):
		_controller.state_changed.disconnect(_on_state_changed)
	for connection: Array in [[_board_panel.turn_started, _on_turn_started], [_board_panel.reveal_started, _on_reveal_started],
			[_board_panel.result_shown, _on_result_shown], [_board_panel.turn_ready_to_leave, _on_turn_ready_to_leave]]:
		var sig: Signal = connection[0] as Signal
		if sig.is_connected(connection[1] as Callable):
			sig.disconnect(connection[1] as Callable)
	_board_panel.unbind()


## 戻る操作: メニュー・確認が開いていれば閉じ、閉じていればメニューを開く。アプリは閉じない。
## 手の詳細のポップアップは盤面の上だけを覆うので、メニューが開いていなければ先に閉じる（2026-11-05）。
func handle_back() -> bool:
	if not _menu_host.is_open() and _board_panel.detail_view().is_open():
		_board_panel.close_detail()
		return true
	return _menu_host.handle_back()


func board_panel() -> MatchBoardPanel:
	return _board_panel


func phase_banner() -> PhaseBanner:
	return _phase_banner


func menu_host() -> MatchMenuHost:
	return _menu_host


func score_bug() -> ScoreBug:
	return _score_bug


func phase_text() -> String:
	return _phase_tag.text if _phase_tag.visible else ""


func possession_text() -> String:
	return _possession_label.text


func possession_variation() -> String:
	return _possession_label.theme_type_variation


func reveal_texts() -> Array[String]:
	if not _reveal_banner.visible:
		return []
	return [_user_choice_label.text, _opponent_choice_label.text]


## continue_after_reveal で段階が TURN のままなら、次のターンを始める（段階が変われば画面が切り替わる）。
func _on_state_changed(_snapshot: BoardSnapshot) -> void:
	if _controller.stage() == GameEnums.MatchStage.TURN and not _controller.is_match_over():
		_board_panel.start_turn()


func _on_turn_started(snapshot: BoardSnapshot) -> void:
	_score_bug.show_snapshot(snapshot)
	_show_possession(snapshot)
	_phase_tag.text = MatchTexts.phase_tag(snapshot.turn_kind, snapshot.user_has_ball)
	_phase_tag.visible = true
	_reveal_banner.visible = false
	_phase_banner.follow(MatchTexts.user_phase(snapshot.turn_kind, snapshot.user_has_ball))
	# 前半・後半のキックオフの笛（再開した試合の1ターン目でも鳴らす）
	if snapshot.turn_number == 1:
		Sfx.play(SoundCues.Cue.WHISTLE)


## 開示: 局面のタグを両者の選択の帯に替える。スコアはまだ描き直さない（得点を判定理由より先に見せない）。
func _on_reveal_started(reveal: RevealView) -> void:
	_reveal = reveal
	_user_choice_label.text = reveal_line(true, reveal.user_choice)
	_opponent_choice_label.text = reveal_line(false, reveal.opponent_choice)
	_phase_tag.visible = false
	_reveal_banner.visible = true
	_phase_banner.dismiss()


## 両者の選択の帯の1行「● ショートパス」。手の名前だけにし、チームは印で示す（スコア表示が「● YOU」「CPU ◆」）。
## 行き先は盤面の矢印と判定理由で読める。「あなた:」と行き先まで書くと、上部バーの残りの幅に入らなかった（2026-11-06）
static func reveal_line(is_user: bool, choice: TurnChoice) -> String:
	return ("● %s" if is_user else "◆ %s") % MatchTexts.action_name(choice.family, choice.action)


## 結果を出す: 得点なら得点した側の音、ハーフの終わり（前半の終わり・試合の終わり）なら笛。
func _on_result_shown(snapshot: BoardSnapshot) -> void:
	_score_bug.show_snapshot(snapshot)
	_show_possession(snapshot)
	if _reveal != null and _reveal.outcome == GameEnums.TurnOutcome.GOAL:
		var is_user_goal: bool = MatchTexts.turn_winner(_reveal) == MatchTexts.TurnWinner.USER
		Sfx.play(SoundCues.Cue.GOAL_FOR if is_user_goal else SoundCues.Cue.GOAL_AGAINST)
	if snapshot.is_half_over:
		Sfx.play(SoundCues.Cue.WHISTLE)


## 保持の表示を、保持している側のチームの色の帯で出す（記号も添え、色だけで示さない）。
func _show_possession(snapshot: BoardSnapshot) -> void:
	_possession_label.text = MatchTexts.possession_text(snapshot.user_has_ball)
	_possession_label.theme_type_variation = &"YouChipLabel" if snapshot.user_has_ball else &"OpponentChipLabel"


func _on_turn_ready_to_leave() -> void:
	_controller.continue_after_reveal()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 左右は 24px、上下は 12px（2026-10-25。6列の作戦ボードの高さ 600px を入れるため）
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, SIDE_MARGIN)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VERTICAL_MARGIN)
	add_child(margin)
	_margin = margin
	# 上部バー 96px ＋ 本体 600px ＋ 外周 12px × 2 = 720px（screen-common.md §1.1）。上部バーと本体の間に余白を置かない
	# （置くと本体が 600px を割り、作戦ボードの最小の高さ 600px が入らない）
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	margin.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, TOP_BAR_HEIGHT)
	top_bar.add_theme_constant_override("separation", 16)
	layout.add_child(top_bar)
	_top_bar = top_bar
	# 縦の2段目。横では空で隠す（保持・局面のタグ・両者の選択の帯は1段目に並べる）
	_top_second_row = HBoxContainer.new()
	_top_second_row.name = "TopSecondRow"
	_top_second_row.custom_minimum_size = Vector2(0, PORTRAIT_SECOND_ROW_HEIGHT)
	_top_second_row.add_theme_constant_override("separation", 16)
	_top_second_row.visible = false
	layout.add_child(_top_second_row)
	_score_bug = ScoreBug.new()
	_score_bug.name = "ScoreBug"
	top_bar.add_child(_score_bug)
	_possession_label = Label.new()
	_possession_label.name = "PossessionLabel"
	_possession_label.theme_type_variation = &"YouChipLabel"
	_possession_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_possession_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(_possession_label)
	_phase_tag = Label.new()
	_phase_tag.name = "PhaseTag"
	_phase_tag.theme_type_variation = &"TagLabel"
	# 英字と日本語の2行（MatchTexts.phase_tag）。行ごとに中央へそろえる
	_phase_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(_phase_tag)
	_reveal_banner = VBoxContainer.new()
	_reveal_banner.name = "RevealBanner"
	_reveal_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_banner.visible = false
	top_bar.add_child(_reveal_banner)
	_user_choice_label = _banner_label("UserChoiceLabel", &"YouChipLabel")
	_opponent_choice_label = _banner_label("OpponentChoiceLabel", &"OpponentChipLabel")

	_board_panel = MatchBoardPanel.new()
	_board_panel.name = "BoardPanel"
	_board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_board_panel)
	# 局面の帯は盤面と手の選択の上に重ね、メニューより下に置く
	_phase_banner = PhaseBanner.new()
	add_child(_phase_banner)
	# メニューは画面の最後の子（上に重ねる）
	_menu_host = MatchMenuHost.new(self, top_bar, _can_open_menu, _board_panel.set_show_hints)


## 縦（2026-11-27）: 上部バーを2段にし（1段目にメニュー・スコア、2段目に保持・局面のタグ・両者の選択の帯）、
## 盤面と手の選択を上下に積む。横に戻せば1段目へ戻す。並べ替えるのは配置だけで、出している文・状態は変えない
func _apply_orientation(portrait: bool) -> void:
	var row: HBoxContainer = _top_second_row if portrait else _top_bar
	for label: Control in [_possession_label, _phase_tag, _reveal_banner]:
		label.reparent(row, false)
	_top_second_row.visible = portrait
	for side: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + side, PORTRAIT_SIDE_MARGIN if portrait else SIDE_MARGIN)
	_board_panel.set_portrait(portrait)


## メニューを開けるのは、手を選んでいる間と判定理由を出している間（screen-03-match.md「メニュー」）。
## 決定の処理中（SUBMITTING）と画面の切り替えを待つ間（LEAVING）は開かない。試合を終えた後（最終ターンの判定理由）も
## 開かない（中断せず、結果画面と終了処理を通す。2026-10-29）。
func _can_open_menu() -> bool:
	if _controller.is_match_over():
		return false
	return _board_panel.state() in [MatchBoardPanel.State.SELECT_ACTION, MatchBoardPanel.State.READY,
			MatchBoardPanel.State.SHOW_RESULT]


func _banner_label(node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	# 帯は2段で上部バー（96px）に収める（screen-03-match.md。各段 24px）。地の色はテーマのまま、上下の余白だけ詰める
	label.add_theme_font_size_override("font_size", 24)
	var band: StyleBox = label.get_theme_stylebox("normal", variation).duplicate() as StyleBox
	band.content_margin_top = 2.0
	band.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", band)
	_reveal_banner.add_child(label)
	return label

## S-05 ハーフタイム（screen-05-halftime.md）。前半のスコアと相手の前半の陣形・方式を見て、陣形と方式を選び直す。
## 初期値は前半の陣形・方式で、変えずに後半を始められる。S-03 への切り替えは MatchController が頼む。
##
## 今回の範囲で外しているもの（.steering/20261019-match-screen/design.md）: 前半の噛み合わせ（ミニピッチ・解説）。
## 試合中のメニュー（中断してタイトルへ）は MatchMenuHost が持つ（2026-10-29。S-03 と同じ）。陣形のカードは小さい版を2列に並べる。
class_name HalftimeScreen
extends AppScreen

enum State { EDITING, SUBMITTING }

const FORMATION_CARD_SCENE: PackedScene = preload("res://ui/common/formation_card.tscn")

var _state: State = State.EDITING
var _formation_id: String = ""
var _score_bug: ScoreBug
var _opponent_label: Label
var _formation_grid: GridContainer
var _picker: StylePicker
var _second_half_button: Button
## 陣形 ID → カード
var _cards: Dictionary = {}
var _menu_host: MatchMenuHost


func _init() -> void:
	_build()


func enter(_params: Dictionary) -> void:
	var controller: MatchController = App.match_controller
	var snapshot: BoardSnapshot = controller.snapshot()
	if snapshot == null:
		return
	_score_bug.show_snapshot(snapshot, "HT")
	_opponent_label.text = "◆ CPU %s" % MatchTexts.setup_text(controller.opponent_setup())
	_formation_id = snapshot.user_setup.formation_id
	_picker.set_styles(snapshot.user_setup.styles)
	_build_cards()
	_set_state(State.EDITING)


## 戻る操作は S-04 と同じ（メニュー・確認が開いていれば閉じ、EDITING ならメニューを開く）。アプリは閉じない。
func handle_back() -> bool:
	return _menu_host.handle_back()


func menu_host() -> MatchMenuHost:
	return _menu_host


func state() -> State:
	return _state


func picker() -> StylePicker:
	return _picker


func second_half_button() -> Button:
	return _second_half_button


func selected_formation() -> String:
	return _formation_id


func opponent_text() -> String:
	return _opponent_label.text


## 陣形のカード（テストと画面の操作用）。無ければ null。
func card_for(formation_id: String) -> FormationCard:
	return _cards.get(formation_id) as FormationCard


func _build_cards() -> void:
	for child: Node in _formation_grid.get_children():
		_formation_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	for formation: FormationDef in App.library.formations():
		var card: FormationCard = FORMATION_CARD_SCENE.instantiate() as FormationCard
		_formation_grid.add_child(card)
		card.pressed.connect(_on_formation_selected)
		_cards[formation.id] = card
	_refresh_cards()


func _on_formation_selected(formation_id: String) -> void:
	if _state != State.EDITING:
		return
	_formation_id = formation_id
	_refresh_cards()


func _refresh_cards() -> void:
	for formation: FormationDef in App.library.formations():
		var card: FormationCard = _cards.get(formation.id) as FormationCard
		if card != null:
			card.show_formation(formation, {}, formation.id == _formation_id, true)


func _on_second_half_pressed() -> void:
	if _state != State.EDITING:
		return
	_set_state(State.SUBMITTING)
	if not App.match_controller.submit_halftime(TeamSetup.new(_formation_id, _picker.styles())):
		_set_state(State.EDITING)


func _set_state(next: State) -> void:
	_state = next
	var editing: bool = next == State.EDITING
	_picker.set_enabled(editing)
	_second_half_button.disabled = not editing


func _build() -> void:
	var parts: Dictionary = MatchScreenLayout.build(self, "SecondHalfButton", "SECOND HALF 後半開始")
	_score_bug = parts["score_bug"] as ScoreBug
	_second_half_button = parts["primary"] as Button
	_second_half_button.pressed.connect(_on_second_half_pressed)
	var info: VBoxContainer = parts["info"] as VBoxContainer
	MatchScreenLayout.tag(info, "HalftimeTag", "HALF TIME")
	MatchScreenLayout.text(info, "HalftimeBanner", &"CardTitleLabel").text = "前半終了"
	_opponent_label = MatchScreenLayout.text(info, "OpponentSetupLabel", &"PanelLabel")
	var side: VBoxContainer = parts["side"] as VBoxContainer
	var formation_title := MatchScreenLayout.text(side, "FormationTitle", &"SectionTitleLabel")
	formation_title.text = "陣形"
	side.move_child(formation_title, 0)
	_formation_grid = GridContainer.new()
	_formation_grid.name = "FormationGrid"
	_formation_grid.columns = 2
	_formation_grid.add_theme_constant_override("h_separation", 12)
	_formation_grid.add_theme_constant_override("v_separation", 12)
	side.add_child(_formation_grid)
	side.move_child(_formation_grid, 1)
	_picker = StylePicker.new()
	_picker.name = "StylePicker"
	side.add_child(_picker)
	side.move_child(_picker, 2)
	_menu_host = MatchMenuHost.new(self, parts["top_bar"] as HBoxContainer, func() -> bool: return _state == State.EDITING)

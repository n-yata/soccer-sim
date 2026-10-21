## S-02 試合準備（screen-02-match-setup.md）。陣形・守備方式・攻撃方式を、未選択から選ぶ。
## 解説欄の中身（方式の解説文・噛み合わせルール・解説の導出）は、それを作る作業で足す。今は解説欄に案内文と
## 「解説は準備中」を出す。開始ボタンは試合画面（S-03）があるときだけ押せ、MatchController.start_match で試合を作る
## （S-03 への切り替えは MatchController が頼む）。
class_name MatchSetupScreen
extends AppScreen

## EDITING: 選んでいる途中／READY: 3項目すべてを選んだ／STARTING: 開始ボタンを押し、画面の切り替えを待つ
enum State { EDITING, READY, STARTING }

const FORMATION_CARD_SCENE: PackedScene = preload("res://ui/common/formation_card.tscn")
const GUIDE_TEXT: String = "陣形と方式を選ぶと、ここに解説が出ます"
const PENDING_NOTES_TEXT: String = "解説は準備中"

@onready var _header: ScreenHeader = %Header
@onready var _formation_grid: GridContainer = %FormationGrid
@onready var _zone_button: Button = %ZoneButton
@onready var _man_button: Button = %ManButton
@onready var _possession_button: Button = %PossessionButton
@onready var _counter_button: Button = %CounterButton
@onready var _notes_label: Label = %NotesLabel
@onready var _start_button: Button = %StartButton
@onready var _start_pending_label: Label = %StartPendingLabel

var _state: State = State.EDITING
var _formation_id: String = ""
var _defense: int = -1
var _attack: int = -1
var _can_start: bool = false
## 陣形 ID → カード。カードと陣形は ID で結び付ける（並び順が同じであることに頼らない）
var _cards: Dictionary = {}
## 陣形 ID → 基本配置の人数。画面を開いたときに1回だけ求める
var _counts: Dictionary = {}


func _ready() -> void:
	_header.set_title("試合準備")
	_header.back_pressed.connect(_go_back)
	_zone_button.pressed.connect(_on_defense_selected.bind(GameEnums.DefenseStyle.ZONE))
	_man_button.pressed.connect(_on_defense_selected.bind(GameEnums.DefenseStyle.MAN))
	_possession_button.pressed.connect(_on_attack_selected.bind(GameEnums.AttackStyle.POSSESSION))
	_counter_button.pressed.connect(_on_attack_selected.bind(GameEnums.AttackStyle.COUNTER))
	_start_button.pressed.connect(_on_start_pressed)


## 3項目を未選択から始める（既定の組み合わせのまま始めず、自分で選ぶことを学習の出発点にするため。screen-design.md S-02）。
func enter(_params: Dictionary) -> void:
	_formation_id = ""
	_defense = -1
	_attack = -1
	_build_formation_cards()
	apply_start_availability(MainShell.SCREEN_SCENES)


## 開始ボタンの行き先（試合画面 S-03）が scene_paths にあるか。無ければ READY でも押せず「準備中」を出す。
func apply_start_availability(scene_paths: Dictionary) -> void:
	_can_start = scene_paths.has(AppScreens.Id.S03_MATCH)
	_refresh()


## 3項目すべてを選んだか（状態 READY）。
func is_ready() -> bool:
	return _state == State.READY


## 戻る操作は、選んでいる途中でもタイトルへ戻る。何も保存しない。STARTING なら何もしない（screen-02-match-setup.md）。
func handle_back() -> bool:
	if _state != State.STARTING:
		_go_back()
	return true


func state() -> State:
	return _state


func _build_formation_cards() -> void:
	for child: Node in _formation_grid.get_children():
		_formation_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	_counts.clear()
	for formation: FormationDef in App.library.formations():
		var card: FormationCard = FORMATION_CARD_SCENE.instantiate() as FormationCard
		_formation_grid.add_child(card)
		card.pressed.connect(_on_formation_selected)
		_cards[formation.id] = card
		_counts[formation.id] = App.library.base_counts(formation.id)


func _on_formation_selected(formation_id: String) -> void:
	if _state == State.STARTING:
		return
	_formation_id = formation_id
	_refresh()


func _on_defense_selected(style: GameEnums.DefenseStyle) -> void:
	if _state == State.STARTING:
		return
	_defense = style
	_refresh()


func _on_attack_selected(style: GameEnums.AttackStyle) -> void:
	if _state == State.STARTING:
		return
	_attack = style
	_refresh()


func _refresh() -> void:
	for formation: FormationDef in App.library.formations():
		if not _cards.has(formation.id):
			continue
		(_cards[formation.id] as FormationCard).show_formation(formation, _counts[formation.id] as Dictionary,
				formation.id == _formation_id, false)
	# 選択中の見た目は、押した状態（黄色の縁）で示す。ボタンが自分で切り替えた状態ではなく、記録した値から決め直す
	_zone_button.set_pressed_no_signal(_defense == GameEnums.DefenseStyle.ZONE)
	_man_button.set_pressed_no_signal(_defense == GameEnums.DefenseStyle.MAN)
	_possession_button.set_pressed_no_signal(_attack == GameEnums.AttackStyle.POSSESSION)
	_counter_button.set_pressed_no_signal(_attack == GameEnums.AttackStyle.COUNTER)
	var has_any: bool = not _formation_id.is_empty() or _defense >= 0 or _attack >= 0
	_notes_label.text = PENDING_NOTES_TEXT if has_any else GUIDE_TEXT
	var has_all: bool = not _formation_id.is_empty() and _defense >= 0 and _attack >= 0
	_state = State.READY if has_all else State.EDITING
	_start_button.disabled = not (is_ready() and _can_start)
	_start_pending_label.visible = not _can_start


## 試合を作る。二重に作らないよう STARTING にしてから呼ぶ。false（陣形が無い。開発時の誤り）なら選び直せる状態に戻す。
func _on_start_pressed() -> void:
	if _state != State.READY or not _can_start:
		return
	_state = State.STARTING
	_start_button.disabled = true
	var setup := TeamSetup.new(_formation_id, TeamStyles.new(_defense as GameEnums.DefenseStyle,
			_attack as GameEnums.AttackStyle))
	if not App.match_controller.start_match(setup):
		_refresh()


func _go_back() -> void:
	App.request_screen(AppScreens.Id.S01_TITLE)

## S-01 タイトル（screen-01-title.md）。各機能への入口と、中断した試合の再開カード。
## 「CPU 対戦」は NewMatchGate に任せる（中断中の試合・戦績を記録できていない試合があれば、ConfirmDialog で確かめる）。
## 小さなカードの一言は戦績だけ（2026-10-29）。理解度チェックの一言は理解度チェックの作業で足す。
## チュートリアルのカードは、未完了なら KICK OFF の直前の大きなカード、完了後は小さなカードの最後（設定の tutorial_completed）。
## プロダクト名は仮称（正式名は要件定義書 §7.1 #4）。
class_name TitleScreen
extends AppScreen

## IDLE: すべて押せる／BUSY: 再開・CPU 対戦の処理中（二度押しで2回遷移しない）／CONFIRMING: 確認ダイアログだけ押せる
enum State { IDLE, BUSY, CONFIRMING }

# カードの大きさ（screen-01-title.md「ノード構成」）
const LARGE_TUTORIAL_SIZE: Vector2 = Vector2(0, 104)
const SMALL_CARD_SIZE: Vector2 = Vector2(96, 96)
const KICK_OFF_SIZE: Vector2 = Vector2(0, 136)
const KICK_OFF_TALL_SIZE: Vector2 = Vector2(0, 200)
const SMALL_COLUMNS: int = 4
const SMALL_COLUMNS_WITH_TUTORIAL: int = 5

@onready var _resume_card: Button = %ResumeCard
@onready var _resume_summary: Label = %ResumeSummary
@onready var _resume_score: Label = %ResumeScore
@onready var _kick_off_card: Button = %KickOffCard
@onready var _records_sub: Label = %RecordsSub
@onready var _tutorial_card: Button = %TutorialCard
@onready var _small_cards: GridContainer = $Layout/CardsMargin/Cards/SmallCards
## 小さなカード → その一言。押せない間は一言を隠し「準備中」だけを出す（screen-01-title.md「作る順序」）
@onready var _card_subs: Dictionary = {
	%RecordsCard: %RecordsSub,
	%ScopeCard: %ScopeSub,
	%SettingsCard: %SettingsSub,
}
## カード → 行き先の画面（screen-01-title.md「画面遷移」）。「CPU 対戦」だけは NewMatchGate を通る
@onready var _destinations: Dictionary = {
	%TutorialCard: AppScreens.Id.S08_TUTORIAL,
	%KickOffCard: AppScreens.Id.S02_MATCH_SETUP,
	%QuizCard: AppScreens.Id.S09_QUIZ,
	%RecordsCard: AppScreens.Id.S11_RECORDS,
	%ScopeCard: AppScreens.Id.S10_SCOPE,
	%SettingsCard: AppScreens.Id.S12_SETTINGS,
}

var _state: State = State.IDLE
var _dialog: ConfirmDialog
var _gate: NewMatchGate


func _ready() -> void:
	for card: Button in _destinations:
		card.pressed.connect(_on_card_pressed.bind(card))
	_resume_card.pressed.connect(_on_resume_pressed)
	_dialog = ConfirmDialog.new()
	add_child(_dialog)


func enter(_params: Dictionary) -> void:
	_gate = NewMatchGate.new(App.match_controller, App.request_screen)
	_gate.finished.connect(_on_gate_finished)
	_show_resume_card(App.match_controller.suspended_snapshot()
			if App.match_controller.suspended_status() == AppScreens.SuspendedStatus.RESUMABLE else null)
	# 設定の読み込みに失敗したときは初期値（未完了）なので、未完了の位置になる（screen-01-title.md「例外・エラー表示」）
	place_tutorial_card(App.user_data.settings().tutorial_completed)
	apply_availability(MainShell.SCREEN_SCENES)
	# 戦績のカードの一言「5勝 2分 3敗」（0件なら「まだ記録がありません」）。押せない間は「準備中」だけを出す
	# 小さなカードは幅が狭く、1行に収まらない。数の途中で折り返さないよう、勝ち・引き分け・負けで行を分ける
	_records_sub.text = RecordTexts.totals_summary(App.user_data.totals()).replace(" ", "\n")
	_state = State.IDLE


## チュートリアルのカードを置く（screen-01-title.md「画面を開く」の 3.）。完了後は小さなカードの最後へ移し（5列）、
## 「はじめての方へ」と説明の行を隠す。未完了なら KICK OFF の直前の大きなカードに戻す。
## 再開カードもチュートリアルの大きなカードも無いときは、KICK OFF を高くする。
func place_tutorial_card(is_completed: bool) -> void:
	var cards: Node = _kick_off_card.get_parent()
	var title: Label = _tutorial_card.find_child("TutorialTitle", true, false) as Label
	if is_completed:
		if _tutorial_card.get_parent() != _small_cards:
			_tutorial_card.reparent(_small_cards, false)
		_small_cards.move_child(_tutorial_card, -1)
		_small_cards.columns = SMALL_COLUMNS_WITH_TUTORIAL
		_tutorial_card.custom_minimum_size = SMALL_CARD_SIZE
		_tutorial_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tutorial_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# 小さなカードの幅では名前が1行に入らないので、ほかの小さなカードと同じく折り返す
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		if _tutorial_card.get_parent() != cards:
			_tutorial_card.reparent(cards, false)
		# move_child の位置は動かした後の位置。KICK OFF より前にあれば、取り出すと KICK OFF が1つ前へ詰まる
		var target: int = _kick_off_card.get_index()
		if _tutorial_card.get_index() < target:
			target -= 1
		cards.move_child(_tutorial_card, target)
		_small_cards.columns = SMALL_COLUMNS
		_tutorial_card.custom_minimum_size = LARGE_TUTORIAL_SIZE
		_tutorial_card.size_flags_horizontal = Control.SIZE_FILL
		_tutorial_card.size_flags_vertical = Control.SIZE_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.size_flags_horizontal = Control.SIZE_FILL
	for node_name: String in ["FirstTimeBadge", "TutorialSub"]:
		(_tutorial_card.find_child(node_name, true, false) as Control).visible = not is_completed
	# 大きなカードは中央へ、小さなカードはほかの小さなカードと同じく上へそろえる
	var box: BoxContainer = _tutorial_card.get_node("Box") as BoxContainer
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if is_completed else BoxContainer.ALIGNMENT_CENTER
	var has_large_card: bool = _resume_card.visible or not is_completed
	_kick_off_card.custom_minimum_size = KICK_OFF_SIZE if has_large_card else KICK_OFF_TALL_SIZE


func tutorial_card() -> Button:
	return _tutorial_card


func small_cards() -> GridContainer:
	return _small_cards


## 行き先の画面が scene_paths（画面 ID → シーン）に無いカードは押せなくし、「準備中」を出す。
## 画面を作って MainShell.SCREEN_SCENES に足せば、自動で押せるようになる。
func apply_availability(scene_paths: Dictionary) -> void:
	for card: Button in _destinations:
		var is_available: bool = scene_paths.has(_destinations[card])
		card.disabled = not is_available
		var pending_label: Label = card.find_child("PendingLabel", true, false) as Label
		pending_label.visible = not is_available
		_apply_card_text_state(card, is_available)
		if _card_subs.has(card):
			(_card_subs[card] as Label).visible = is_available


## 再開カードの一言「前半 7／15・4-3-3 対 4-4-2」。
static func resume_summary(snapshot: BoardSnapshot) -> String:
	return "%s・%s 対 %s" % [MatchTexts.clock_text(snapshot), snapshot.user_setup.formation_id,
			snapshot.opponent_setup.formation_id]


## 状態ごとの戻る操作（screen-01-title.md「Android の戻る操作」）。IDLE だけ false（MainShell がアプリを閉じる）。
func handle_back() -> bool:
	match _state:
		State.CONFIRMING:
			_dialog.cancel()
			return true
		State.BUSY:
			return true
	return false


func state() -> State:
	return _state


func resume_card() -> Button:
	return _resume_card


func resume_summary_text() -> String:
	return _resume_summary.text


func resume_score_text() -> String:
	return _resume_score.text


## カードの一言（隠れていれば空）。
func card_sub_text(card_name: String) -> String:
	for card: Button in _card_subs:
		if card.name == card_name:
			var sub: Label = _card_subs[card] as Label
			return sub.text if sub.visible else ""
	return ""


func records_summary_text() -> String:
	return _records_sub.text if _records_sub.visible else ""


func confirm_dialog() -> ConfirmDialog:
	return _dialog


## snapshot が null なら隠す。スコアの色分けは ScoreBug と同じく、自分の数字・相手の数字の順（文字で示し、色は補助）。
func _show_resume_card(snapshot: BoardSnapshot) -> void:
	_resume_card.visible = snapshot != null
	if snapshot == null:
		return
	_resume_summary.text = resume_summary(snapshot)
	_resume_score.text = "%d – %d" % [snapshot.score_user, snapshot.score_opponent]


## カードの中の文字は Button 自身の文字ではないため、選択不可の文字色（Button の font_disabled_color）が効かない。
## 押せないカードでは、中の文字をテーマの選択不可の文字色にそろえる（黄色の地向けの暗い文字が、選択不可の地で読めなくなるため）。
## 「準備中」と、地の色を持つタグ（はじめての方へ）はそのままにする。
func _apply_card_text_state(card: Button, is_available: bool) -> void:
	var disabled_color: Color = card.get_theme_color("font_disabled_color", "Button")
	for node: Node in card.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.name == "PendingLabel" or label.theme_type_variation in [&"TagLabel", &"YouTagLabel"]:
			continue
		if is_available:
			label.remove_theme_color_override("font_color")
		else:
			label.add_theme_color_override("font_color", disabled_color)


func _on_card_pressed(card: Button) -> void:
	if _state != State.IDLE:
		return
	if card == _kick_off_card:
		_state = State.BUSY
		_gate.begin(_dialog)
		# 確認を出したなら CONFIRMING（出さずに試合準備を頼んだなら、finished で戻っている）
		if _dialog.is_open():
			_state = State.CONFIRMING
		return
	App.request_screen(_destinations[card] as AppScreens.Id)


## 再開する。画面の切り替えは MatchController が頼む。読めなかったときはタイトルを頼み直す（enter からやり直す）。
func _on_resume_pressed() -> void:
	if _state != State.IDLE:
		return
	_state = State.BUSY
	if not App.match_controller.resume():
		_state = State.IDLE


func _on_gate_finished(started: bool) -> void:
	# 試合準備を頼んだなら、画面が替わるまで BUSY のまま
	_state = State.BUSY if started else State.IDLE

## S-01 タイトル（screen-01-title.md）。各機能への入口と、中断した試合の再開カード。
## 「CPU 対戦」は NewMatchGate に任せる（中断中の試合があれば、破棄してよいかを ConfirmDialog で確かめる）。
## 戦績・設定（UserDataService）を作る作業で足すもの: 小さなカードの一言、チュートリアルの位置の切り替え、
## 戦績を記録できていない試合（FINALIZE_PENDING）の確認。
## プロダクト名は仮称（正式名は要件定義書 §7.1 #4）。
class_name TitleScreen
extends AppScreen

## IDLE: すべて押せる／BUSY: 再開・CPU 対戦の処理中（二度押しで2回遷移しない）／CONFIRMING: 確認ダイアログだけ押せる
enum State { IDLE, BUSY, CONFIRMING }

@onready var _resume_card: Button = %ResumeCard
@onready var _resume_summary: Label = %ResumeSummary
@onready var _resume_score: Label = %ResumeScore
@onready var _kick_off_card: Button = %KickOffCard
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
	# チュートリアルは未完了の位置（シーンの並びのまま）。設定の読み込みに失敗したときと同じ扱い（screen-01-title.md「例外・エラー表示」）
	apply_availability(MainShell.SCREEN_SCENES)
	_state = State.IDLE


## 行き先の画面が scene_paths（画面 ID → シーン）に無いカードは押せなくし、「準備中」を出す。
## 画面を作って MainShell.SCREEN_SCENES に足せば、自動で押せるようになる。
func apply_availability(scene_paths: Dictionary) -> void:
	for card: Button in _destinations:
		var is_available: bool = scene_paths.has(_destinations[card])
		card.disabled = not is_available
		var pending_label: Label = card.find_child("PendingLabel", true, false) as Label
		pending_label.visible = not is_available
		_apply_card_text_state(card, is_available)


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

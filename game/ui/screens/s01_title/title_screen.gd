## S-01 タイトル（screen-01-title.md）。動く骨格の段階では、サービスに頼らない部分だけを持つ。
## サービス（MatchController・UserDataService）を作る作業で足すもの:
##   再開カード（RESUMABLE のときだけ出す）、小さなカードの一言、チュートリアルの位置の切り替え、
##   「CPU 対戦」の確認の手順（NewMatchGate・ConfirmDialog）と、それに伴う状態（BUSY・CONFIRMING）。
## プロダクト名は仮称（正式名は要件定義書 §7.1 #4）。
class_name TitleScreen
extends AppScreen

@onready var _resume_card: Button = %ResumeCard
## カード → 行き先の画面（screen-01-title.md「画面遷移」）
@onready var _destinations: Dictionary = {
	%TutorialCard: AppScreens.Id.S08_TUTORIAL,
	%KickOffCard: AppScreens.Id.S02_MATCH_SETUP,
	%QuizCard: AppScreens.Id.S09_QUIZ,
	%RecordsCard: AppScreens.Id.S11_RECORDS,
	%ScopeCard: AppScreens.Id.S10_SCOPE,
	%SettingsCard: AppScreens.Id.S12_SETTINGS,
}


func _ready() -> void:
	for card: Button in _destinations:
		card.pressed.connect(_on_card_pressed.bind(card))


func enter(_params: Dictionary) -> void:
	# 中断データの状態は MatchController ができてから見る。それまでは「中断データなし」と同じ表示
	_resume_card.visible = false
	# チュートリアルは未完了の位置（シーンの並びのまま）。設定の読み込みに失敗したときと同じ扱い（screen-01-title.md「例外・エラー表示」）
	apply_availability(MainShell.SCREEN_SCENES)


## 行き先の画面が scene_paths（画面 ID → シーン）に無いカードは押せなくし、「準備中」を出す。
## 画面を作って MainShell.SCREEN_SCENES に足せば、自動で押せるようになる。
func apply_availability(scene_paths: Dictionary) -> void:
	for card: Button in _destinations:
		var is_available: bool = scene_paths.has(_destinations[card])
		card.disabled = not is_available
		var pending_label: Label = card.find_child("PendingLabel", true, false) as Label
		pending_label.visible = not is_available
		_apply_card_text_state(card, is_available)


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


## 状態が IDLE だけなので、常にアプリを閉じる側（false）。BUSY・CONFIRMING は NewMatchGate を作る作業で足す。
func handle_back() -> bool:
	return false


func _on_card_pressed(card: Button) -> void:
	App.request_screen(_destinations[card] as AppScreens.Id)

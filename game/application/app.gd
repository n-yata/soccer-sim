## アプリケーション層の入口（オートロード名 App。component-design.md §3.1）。
## オートロード名と衝突するため class_name は付けない。
## user_data は戦績・設定・理解度チェックの回答結果を持つ。
extends Node

## UI に開いてほしい画面を知らせる。UI のルート（MainShell）が受けて画面を切り替える
signal screen_requested(screen: AppScreens.Id, params: Dictionary)
## 保存・読み込みに失敗したことを知らせる。MainShell が通知（ToastView）で出す。文言の正本は functional-overview.md「エラーハンドリング」
signal storage_error(kind: AppScreens.StorageErrorKind)

## 端末内保存の置き場所。_ready より前に変えると、そこへ保存する（テストが一時ディレクトリを使い、開発用の PC の
## 保存データを読み書きしないため）。アプリは既定値を使う
var save_dir: String = "user://"
## 画面向けの参照（陣形の一覧・基本配置）
var library: LibraryService
## 戦績・設定・理解度チェックの回答結果
var user_data: UserDataService
## 本番の試合用（CPU 対戦）
var match_controller: MatchController
## チュートリアル用のコントローラーを作るために持っておく
var _catalog: ContentCatalog
var _config: ConfigRepository
var _rng: RandomNumberGenerator


func _ready() -> void:
	# 静的データの誤りは開発時の誤り。ContentRepository が push_error し、空のカタログを返す（陣形が0件で表示される）
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	_catalog = catalog
	library = LibraryService.new(catalog)
	# 乱数生成器はアプリで1つだけ作り、前半のキックオフ側と CPU の選択に注入する（ドメインでは作らない）
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_rng = rng
	var config := ConfigRepository.new()
	_config = config
	var store := SuspendedMatchStore.new(catalog, config.match_rules(), save_dir)
	user_data = UserDataService.new(RecordStore.new(config.match_rules(), save_dir), SettingsStore.new(save_dir),
			QuizAnswerStore.new(save_dir), library.quiz_questions())
	user_data.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: storage_error.emit(kind))
	match_controller = MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
			request_screen, OS.is_debug_build(), store, user_data)
	match_controller.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: storage_error.emit(kind))


## チュートリアル用に、本番とは別の MatchController を作る（component-design.md §3.1）。保存しない（中断データ・戦績の
## 保存先を渡さない）・画面の切り替えを頼まない（チュートリアルの画面が自分で進める）・相手は ScriptedOpponent。
## 本番の match_controller には触れない。チュートリアルを抜けたら捨てる。
func new_tutorial_controller() -> MatchController:
	return MatchController.new(_catalog, _config, _rng, ScriptedOpponent.new(),
			func(_screen: AppScreens.Id, _params: Dictionary) -> void: pass, OS.is_debug_build())


## UI が画面の切り替えを頼む入口（タイトル・戻る操作など、MatchController を経由しない遷移）。
func request_screen(screen: AppScreens.Id, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)

## アプリケーション層の入口（オートロード名 App。component-design.md §3.1）。
## オートロード名と衝突するため class_name は付けない。
## user_data は戦績と設定を持つ（理解度チェックの結果は、その作業で足す）。
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
## 戦績と設定（理解度チェックの結果は、その作業で足す）
var user_data: UserDataService
## 本番の試合用（CPU 対戦）
var match_controller: MatchController


func _ready() -> void:
	# 静的データの誤りは開発時の誤り。ContentRepository が push_error し、空のカタログを返す（陣形が0件で表示される）
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	library = LibraryService.new(catalog)
	# 乱数生成器はアプリで1つだけ作り、前半のキックオフ側と CPU の選択に注入する（ドメインでは作らない）
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var config := ConfigRepository.new()
	var store := SuspendedMatchStore.new(catalog, config.match_rules(), save_dir)
	user_data = UserDataService.new(RecordStore.new(config.match_rules(), save_dir), SettingsStore.new(save_dir))
	user_data.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: storage_error.emit(kind))
	match_controller = MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
			request_screen, OS.is_debug_build(), store, user_data)
	match_controller.storage_failed.connect(func(kind: AppScreens.StorageErrorKind) -> void: storage_error.emit(kind))


## UI が画面の切り替えを頼む入口（タイトル・戻る操作など、MatchController を経由しない遷移）。
func request_screen(screen: AppScreens.Id, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)

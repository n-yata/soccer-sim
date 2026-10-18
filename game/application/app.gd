## アプリケーション層の入口（オートロード名 App。component-design.md §3.1）。
## オートロード名と衝突するため class_name は付けない。
## サービスのうち user_data と storage_error は、それを作る作業（保存・戦績）で足す。
extends Node

## UI に開いてほしい画面を知らせる。UI のルート（MainShell）が受けて画面を切り替える
signal screen_requested(screen: AppScreens.Id, params: Dictionary)

## 画面向けの参照（陣形の一覧・基本配置）
var library: LibraryService
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
	match_controller = MatchController.new(catalog, config, rng, CpuOpponent.new(catalog, config.cpu(), rng),
			request_screen)


## UI が画面の切り替えを頼む入口（タイトル・戻る操作など、MatchController を経由しない遷移）。
func request_screen(screen: AppScreens.Id, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)

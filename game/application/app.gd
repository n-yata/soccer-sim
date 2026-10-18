## アプリケーション層の入口（オートロード名 App。component-design.md §3.1）。
## オートロード名と衝突するため class_name は付けない。
## サービス（match_controller・library・user_data）と storage_error は、それぞれを作る作業で足す。
extends Node

## UI に開いてほしい画面を知らせる。UI のルート（MainShell）が受けて画面を切り替える
signal screen_requested(screen: AppScreens.Id, params: Dictionary)


## UI が画面の切り替えを頼む入口（タイトル・戻る操作など、MatchController を経由しない遷移）。
func request_screen(screen: AppScreens.Id, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)

## 画面の共通の約束（screen-common.md §4）を型で表す親クラス。各画面のルートはこれを継承する。
## 型の警告をエラーにしているため、画面を Node のまま扱うと enter() などを呼べない。そのための型。
class_name AppScreen
extends Control


## 画面を開く。params は App.screen_requested の params（画面ごとの意味は各画面の設計書）
func enter(_params: Dictionary) -> void:
	pass


## 画面を閉じる直前に呼ぶ。enter でつないだシグナルをすべて切る
func exit() -> void:
	pass


## 戻る操作（Android の戻る操作・PC の Esc）を MainShell から受ける。処理したら true。
## false を返すと MainShell が既定の動き（アプリを閉じる）をする
func handle_back() -> bool:
	return false

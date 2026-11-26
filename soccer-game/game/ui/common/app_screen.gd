## 画面の共通の約束（screen-common.md §4）を型で表す親クラス。各画面のルートはこれを継承する。
## 型の警告をエラーにしているため、画面を Node のまま扱うと enter() などを呼べない。そのための型。
class_name AppScreen
extends Control

## 縦の配置で出しているか（2026-11-27。screen-common.md §1.1。MainShell がウィンドウの向きから決める）
var _portrait: bool = false


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


## 画面の向きを受ける（ScreenSwitcher が、開くときは enter の前に、向きが変わったら表示中の画面に渡す）。
## 変わったときだけ _apply_orientation で配置を組み替える。組み替えは配置だけで、画面の状態（選んだ手など）は変えない
func set_portrait(portrait: bool) -> void:
	if portrait == _portrait:
		return
	_portrait = portrait
	_apply_orientation(portrait)


func is_portrait() -> bool:
	return _portrait


## 縦（portrait が真）・横の配置に組み替える。横の配置はシーン・_build で組んだ配置のまま。縦の配置を持たない画面は何もしない
func _apply_orientation(_portrait_layout: bool) -> void:
	pass

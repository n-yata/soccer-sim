## 画面のシーンの入れ替えと、戻る操作の振り分け（screen-common.md §4）。
## 入れる先のノードと「画面 ID → シーンのパス」の対応は引数で受け取る。本番は MainShell.SCREEN_SCENES を渡し、
## テストはテスト用の対応を渡す。
class_name ScreenSwitcher
extends RefCounted

var _container: Node
var _scene_paths: Dictionary
var _current: AppScreen = null
var _current_id: int = -1
## 縦の配置で開くか（MainShell がウィンドウの向きから決める。2026-11-27）
var _portrait: bool = false


func _init(container: Node, scene_paths: Dictionary) -> void:
	_container = container
	_scene_paths = scene_paths.duplicate()


## 画面を開く。対応が無い・シーンを読めない・ルートが AppScreen でない場合は、今の画面のまま false を返す。
## 開くときは、古い画面の exit() を呼んで外してから、新しい画面を足して enter(params) を呼ぶ。
func open(screen: AppScreens.Id, params: Dictionary) -> bool:
	if not _scene_paths.has(screen):
		push_error("ScreenSwitcher: 画面のシーンが登録されていない: %s" % AppScreens.Id.find_key(screen))
		return false
	var scene: PackedScene = load(_scene_paths[screen] as String) as PackedScene
	if scene == null:
		push_error("ScreenSwitcher: 画面のシーンを読めない: %s" % _scene_paths[screen])
		return false
	var instance: Node = scene.instantiate()
	if instance == null:
		push_error("ScreenSwitcher: 画面のシーンを作れない: %s" % _scene_paths[screen])
		return false
	var next_screen: AppScreen = instance as AppScreen
	if next_screen == null:
		push_error("ScreenSwitcher: 画面のルートが AppScreen でない: %s" % _scene_paths[screen])
		instance.free()
		return false
	if _current != null:
		_current.exit()
		_container.remove_child(_current)
		_current.queue_free()
	_current = next_screen
	_current_id = screen
	_container.add_child(next_screen)
	# 配置を組んでから中身を出す（縦なら enter の前に組み替える）
	next_screen.set_portrait(_portrait)
	next_screen.enter(params)
	return true


## 向きを変える。表示中の画面があれば組み替え、その後に開く画面は初めからその向きで開く（2026-11-27）
func set_portrait(portrait: bool) -> void:
	_portrait = portrait
	if _current != null:
		_current.set_portrait(portrait)


func is_portrait() -> bool:
	return _portrait


## 表示中の画面。無ければ null。
func current() -> AppScreen:
	return _current


## 表示中の画面の ID。無ければ -1。
func current_id() -> int:
	return _current_id


## 表示中の画面の handle_back() を1回呼び、その値を返す。画面が無ければ false。
func route_back() -> bool:
	if _current == null:
		return false
	return _current.handle_back()

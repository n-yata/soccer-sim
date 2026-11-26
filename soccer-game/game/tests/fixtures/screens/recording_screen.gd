## 画面の入れ替えのテスト用の画面。呼ばれた順番を、enter の params["call_log"]（配列）に "名前:呼ばれた関数" で書き込む。
## params["name"] で名前を、params["back_result"] で handle_back() の戻り値を決める。
## グローバルなクラス名を増やさないため class_name は付けない。
extends AppScreen

var screen_name: String = ""
var back_result: bool = false
var call_log: Array = []
var received_params: Dictionary = {}
## _apply_orientation に渡された向き（呼ばれた順）
var orientation_calls: Array[bool] = []


func enter(params: Dictionary) -> void:
	received_params = params
	screen_name = params.get("name", "") as String
	back_result = params.get("back_result", false) as bool
	call_log = params.get("call_log", []) as Array
	call_log.append(screen_name + ":enter")


func exit() -> void:
	call_log.append(screen_name + ":exit")


func handle_back() -> bool:
	call_log.append(screen_name + ":back")
	return back_result


func _apply_orientation(portrait: bool) -> void:
	orientation_calls.append(portrait)

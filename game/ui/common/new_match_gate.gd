## 「CPU 対戦」を押したときの確認の手順（screen-01-title.md「CPU 対戦を押す」・screen-common.md §5 の NewMatchGate）。ノードを持たない。
## 中断中の試合が無ければそのまま試合準備へ、あれば破棄してよいかを確かめてから進む。どの経路でも中断データはここでは消さない
## （試合を作ったときに上書きされる。削除の時点①）。
## 戦績を記録できていない試合（FINALIZE_PENDING）の確認は、戦績の作業で足す。
class_name NewMatchGate
extends RefCounted

## started: 試合準備を頼んだか（やめたら false）
signal finished(started: bool)

const DISCARD_MESSAGE: String = "新しい試合を始めると、中断している試合は破棄されます"

var _controller: MatchController
var _request_screen: Callable
var _dialog: ConfirmDialog
var _is_busy: bool = false


## request_screen は画面の切り替えを頼む関数（App.request_screen）。
func _init(controller: MatchController, request_screen: Callable) -> void:
	_controller = controller
	_request_screen = request_screen


## 確認の途中で、もう一度押されても始め直さない。
func begin(dialog: ConfirmDialog) -> void:
	if _is_busy:
		return
	_is_busy = true
	# 画面を開いた後に変わっている可能性があるので、取り直す
	if _controller.suspended_status() == AppScreens.SuspendedStatus.NONE:
		_finish(true)
		return
	_dialog = dialog
	_dialog.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	_dialog.ask(DISCARD_MESSAGE, "始める", "やめる")


func is_busy() -> bool:
	return _is_busy


func _on_answered(ok: bool) -> void:
	_finish(ok)


func _finish(started: bool) -> void:
	_is_busy = false
	if started:
		_request_screen.call(AppScreens.Id.S02_MATCH_SETUP, {})
	finished.emit(started)

## 中断データの読み込みの結果（component-design.md §4.3）。NONE はファイルが無い、CORRUPTED は読めない・検証に外れた・新しい版。
class_name SuspendedLoad
extends RefCounted

enum Status { NONE, OK, CORRUPTED }

var status: Status
## OK のときだけ。それ以外は null
var state: MatchState


func _init(p_status: Status, p_state: MatchState = null) -> void:
	status = p_status
	state = p_state

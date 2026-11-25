## 1ターンを解決した結果（component-design.md §2.2）。次の試合の状態と、そのターンの記録。
class_name TurnResolution
extends RefCounted

var next_state: MatchState
var record: TurnRecord


func _init(p_next_state: MatchState, p_record: TurnRecord) -> void:
	next_state = p_next_state
	record = p_record

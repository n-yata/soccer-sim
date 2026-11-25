## 戦績の陣形と方式の推移の1区切り（data-definition.md §2.2 `records[].timeline[]`）。
## その陣形・方式になったハーフとターンと、そのときの両者の陣形・方式。利用者 = HOME、CPU = AWAY。
class_name RecordPeriod
extends RefCounted

var half: int
var from_turn: int
var user_setup: TeamSetup
var cpu_setup: TeamSetup


func _init(p_half: int, p_from_turn: int, p_user_setup: TeamSetup, p_cpu_setup: TeamSetup) -> void:
	half = p_half
	from_turn = p_from_turn
	user_setup = p_user_setup
	cpu_setup = p_cpu_setup

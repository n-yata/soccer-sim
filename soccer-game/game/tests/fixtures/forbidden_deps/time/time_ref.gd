# 禁止依存の検査の自己確認用（時刻）。ルールや書き方を足したら、ここにも「# expect」付きで足す
extends RefCounted


func now_values() -> Array[int]:
	return [Time.get_ticks_msec(), Engine.get_physics_frames()]  # expect


func clock() -> Object:
	return Time  # expect


func frames() -> int:
	return Engine.get_process_frames()  # expect

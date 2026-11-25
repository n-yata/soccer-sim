## 振り返りの1つの時間帯（アルゴリズム10「時間帯ごとの陣形・方式」。component-design.md §2.8）。
## 両チームの陣形・方式が同じだった、同じハーフ内の連続したターン。
class_name ReviewSegment
extends RefCounted

var half: int
## 時間帯の最初と最後のターン（TurnRecord.turn_number。アディショナルタイムはハーフのターン数より大きい）
var from_turn: int
var to_turn: int
var home_setup: TeamSetup
var away_setup: TeamSetup

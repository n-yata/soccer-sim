## 振り返りの1つの得点（アルゴリズム10「得失点の流れ」。component-design.md §2.8）。
## 得点のターンと、そこに至る直前のターン（同じハーフ・直前の得点より後・最大 lookback ターン）を通し番号で持つ。
class_name ReviewGoal
extends RefCounted

## 得点のターンの通し番号（TurnRecord.seq）
var seq: int
var half: int
var turn_number: int
var scorer: GameEnums.TeamSide
## 得点の後のスコア
var home_score: int
var away_score: int
## 直前のターンの通し番号（古い順。得点のターンは含めない）
var lead_up_seqs: Array[int] = []

## 振り返りの集計結果（アルゴリズム10。component-design.md §2.8）。ReviewAggregator が viewer の視点で作る。
## 数の配列は [勝ち, 負け, 膠着] の3要素（GameEnums.JudgeTally の WIN・LOSE・STALL の位置）。
class_name ReviewSummary
extends RefCounted

## エリアのキー（viewer の視点）→ [勝ち, 負け, 膠着]。判定の無かったエリアは入らない
var area_tallies: Dictionary = {}
## GameEnums.Phase → [勝ち, 負け, 膠着]。4局面とも必ず入る（起きなかった局面は [0, 0, 0]）
var phase_tallies: Dictionary = {}
## 得点の順
var goals: Array[ReviewGoal] = []
## 試合の順
var segments: Array[ReviewSegment] = []
## 集計したターン記録の数（判定なしを含む）
var turn_count: int = 0


## エリアの数（判定の無かったエリアは 0）。tally は WIN・LOSE・STALL のどれか。
func area_count(key: String, tally: GameEnums.JudgeTally) -> int:
	var counts: Array = area_tallies.get(key, [0, 0, 0])
	return counts[tally] as int


func phase_count(phase: GameEnums.Phase, tally: GameEnums.JudgeTally) -> int:
	var counts: Array = phase_tallies.get(phase, [0, 0, 0])
	return counts[tally] as int

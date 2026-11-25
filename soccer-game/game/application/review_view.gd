## 振り返り画面（S-07）に渡す値（component-design.md §3.5）。利用者の視点に揃えてある（§1.2）。
## ドメインの ReviewSummary を利用者（HOME）から集計した値に、得失点の流れの各ターンの RevealView を添えたもの。
## ViewConverter.review が作る。
class_name ReviewView
extends RefCounted

## エリアのキー（利用者の視点）→ [勝ち, 負け, 膠着]（GameEnums.JudgeTally の位置）。判定の無かったエリアは入らない
var area_tallies: Dictionary = {}
## GameEnums.Phase → [勝ち, 負け, 膠着]。4局面とも入る
var phase_tallies: Dictionary = {}
## 得点の順。各要素は {"is_user": 利用者の得点か, "half", "turn_number", "score_user", "score_opponent"（得点の後）,
## "turns": Array[RevealView]（直前のターン → 得点のターンの順）}
var goals: Array[Dictionary] = []
## 試合の順。各要素は {"half", "from_turn", "to_turn", "user_setup": TeamSetup, "opponent_setup": TeamSetup}
var segments: Array[Dictionary] = []
## 集計したターン記録の数（0 なら振り返るデータが無い）
var turn_count: int = 0
## 1ハーフのターン数（アディショナルタイムのターンを「前半 15＋1」と出すため。MatchRuleConfig）
var turns_per_half: int = 0

## 試合画面・ハーフタイム・方式の選び直しに渡す現在の状態（component-design.md §3.5）。利用者の視点に揃えてある
## （§1.2。UI は座標を変換しない）。ViewConverter.snapshot が作る。
class_name BoardSnapshot
extends RefCounted

## 選手ごとの現在の位置。各要素は {"player_id": String, "number": int, "area": String（エリアのキー）}
var user_players: Array[Dictionary] = []
var opponent_players: Array[Dictionary] = []
## 30エリアの人数（エリアのキー → 人数）。user_players / opponent_players をエリアごとに数えた値
var user_counts: Dictionary = {}
var opponent_counts: Dictionary = {}
## ボール位置（エリアのキー）
var ball_area: String = ""
var user_has_ball: bool = false
## 直前の得点の側（GameEnums.TeamSide）。まだ得点が無ければ -1
var last_goal_by: int = -1
var turn_kind: GameEnums.TurnKind = GameEnums.TurnKind.OPEN_PLAY
var half: int = 1
var turn_number: int = 1
var turns_per_half: int = 0
## ハーフを終えた後の盤面か（ハーフタイム・試合終了。turn_number は1つ先に進んでいる）。2026-10-24 のアディショナルタイムで足した
var is_half_over: bool = false
var score_user: int = 0
var score_opponent: int = 0
var user_setup: TeamSetup
var opponent_setup: TeamSetup
## 直前の判定で動いた選手（利用者の視点）。矢印の表示に使う
var movements: Array[Movement] = []
## 相手のオフサイドライン（利用者の視点の列。OffsideRule.line_row。2026-10-25）。利用者が保持する攻守ターンだけ出し、
## それ以外は -1（描かない）。ターン開始の配置で出すので、守備の手でラインは動きうる
var offside_line_zone: int = -1

## 1ターンの開示（両者の選択・開示の動き・判定理由）と振り返りの各ターンに渡す値（component-design.md §3.5）。
## 利用者の視点に揃えてある（§1.2）。ViewConverter.reveal が TurnRecord から作る。
class_name RevealView
extends RefCounted

## 利用者の役割（攻撃側 ATTACK／守備側 DEFENSE／喪失側 NEG_TRANSITION／奪取側 POS_TRANSITION）。判定理由の文の主語を決める
var user_role: GameEnums.Phase = GameEnums.Phase.ATTACK
var turn_kind: GameEnums.TurnKind = GameEnums.TurnKind.OPEN_PLAY
## 両者の手。運ぶ先は利用者の視点
var user_choice: TurnChoice
var opponent_choice: TurnChoice
var outcome: GameEnums.TurnOutcome = GameEnums.TurnOutcome.STALL
## 判定の内訳があるか（NO_CONTEST では無い）
var has_detail: bool = false
## 比較エリア（エリアのキー）。内訳が無ければ空文字
var compare_area: String = ""
var user_count: int = 0
var opponent_count: int = 0
var cover: GameEnums.CoverKind = GameEnums.CoverKind.NONE
## 守備の読みの段階（攻撃の運ぶ先、シュートはボール位置との近さ。アルゴリズム5）。内訳が無ければ NONE
var read: GameEnums.ReadKind = GameEnums.ReadKind.NONE
## 判定前後のボール位置（エリアのキー）
var ball_before: String = ""
var ball_after: String = ""
## 両チームの選手単位の配置（判定前・判定時）。各要素は BoardSnapshot.user_players と同じ形
var user_players_before: Array[Dictionary] = []
var opponent_players_before: Array[Dictionary] = []
var user_players_at_judgement: Array[Dictionary] = []
var opponent_players_at_judgement: Array[Dictionary] = []
## 選手の動き（方式の動き → 守備の手 → 攻撃の手の順。利用者の視点）
var movements: Array[Movement] = []
## 判定に関わる単純化 ID（「実戦では」の表示）。単純化カタログを扱う作業まで空
var simplification_ids: Array[String] = []

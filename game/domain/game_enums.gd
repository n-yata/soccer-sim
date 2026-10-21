## 区分値の集約（component-design.md §2.1）。
## 値の一覧と意味の正本は functional-overview.md「エンティティと区分値」。
##
## 保存データには数値ではなく名前（"ZONE" など）を書く。並びを変えても保存データが壊れないようにするため。
## ただし Lane と Zone の並びは PitchArea.mirrored() が鏡像の計算に使っている。並びを変えない。
class_name GameEnums
extends RefCounted

# functional-overview.md の区分値
enum Lane { L2, L1, C, R1, R2 }
enum Zone { D, M, A }
enum DefenseStyle { ZONE, MAN }
enum AttackStyle { POSSESSION, COUNTER }
enum TurnKind { OPEN_PLAY, TRANSITION }
enum PlayType { SHORT_PASS, DRIBBLE, LONG_BEHIND, SWITCH, SHOT }
enum DefenseAction { PRESS, COVER }
enum NegTransAction { COUNTER_PRESS, RETREAT }
enum PosTransAction { COUNTER, SECURE }
enum TurnOutcome { ADVANCE, STALL, LOSS, GOAL, SAVE, REGAIN, REGAIN_FAILED, NO_CONTEST }
enum MatchStatus { IN_PROGRESS, FINISHED }
enum MatchStage { TURN, STYLE_CHANGE, HALFTIME }
enum PrincipleStatus { UNVERIFIED, VERIFIED, NO_SOURCE }

# 実装のための区分値
enum TeamSide { HOME, AWAY }
## TurnChoice.action がどの enum の値か
enum ChoiceFamily { ATTACK, DEFENSE, NEG_TRANS, POS_TRANS }
## 同数時のカバー判定の内訳（判定理由の表示に使う）
enum CoverKind { NONE, DEFENDER, GOALKEEPER, OUT_OF_GK_REACH }
## 選手が動いた理由。DRIBBLE_STOPPED は膠着したドリブルの選手がボールのエリアへ戻る動き、
## BALL_HOLDER はボールのエリアに保持側がいないとき、いちばん近い選手が置かれる動き（末尾に足し、既存の値の番号を変えない）
enum MovementReason {
	SLIDE, MARK, POSSESSION_ADVANCE, COUNTER_BREAKOUT, RETREAT_RESET, PRESS, COVER, DRIBBLE, DRIBBLE_STOPPED, BALL_HOLDER,
}
## 戦績の勝敗（利用者から見た値）
enum MatchResult { WIN, DRAW, LOSE }
## 振り返りの局面別集計（アルゴリズム10）
enum Phase { ATTACK, NEG_TRANSITION, DEFENSE, POS_TRANSITION }
## 振り返りでの1ターンの数え方（アルゴリズム10）
enum JudgeTally { WIN, LOSE, STALL, EXCLUDED }

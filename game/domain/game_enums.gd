## 区分値の集約（component-design.md §2.1）。
## 値の一覧と意味の正本は functional-overview.md「エンティティと区分値」。
##
## 保存データには数値ではなく名前（"ZONE" など）を書く。並びを変えても保存データが壊れないようにするため。
## ただし Lane と Zone の並びは PitchArea.mirrored() が鏡像の計算に使っている。並びを変えない。
class_name GameEnums
extends RefCounted

# functional-overview.md の区分値
enum Lane { L2, L1, C, R1, R2 }
## 列（自陣のゴール側から）。D1 自陣ゴール前・D2 自陣・M1 中盤（自陣）・M2 中盤（敵陣）・A1 敵陣・A2 敵陣ゴール前。
## ハーフウェーラインは M1 と M2 の境（2026-10-25 に3列から6列にした）
enum Zone { D1, D2, M1, M2, A1, A2 }
enum DefenseStyle { ZONE, MAN }
enum AttackStyle { POSSESSION, COUNTER }
enum TurnKind { OPEN_PLAY, TRANSITION }
## 攻撃の手。並びは手のボタンの並び（THROUGH_PASS は 2026-10-25 に足した。保存は enum の名前で持つので、位置を変えても読み方は変わらない）
## BACK_PASS（2026-11-03。手の選択の簡素化）はボールより後ろの味方へ戻す手で、判定しない（末尾に足した）
enum PlayType { SHORT_PASS, DRIBBLE, THROUGH_PASS, LONG_BEHIND, SWITCH, SHOT, BACK_PASS }
## CLOSE_DOWN（ボールに寄せる）と BLOCK_SHOT（シュートコースを塞ぐ）は、ボールのエリアへのプレス。読みの扱いだけが PRESS と違う
## （2026-11-03。末尾に足した）
enum DefenseAction { PRESS, COVER, CLOSE_DOWN, BLOCK_SHOT }
enum NegTransAction { COUNTER_PRESS, RETREAT }
enum PosTransAction { COUNTER, SECURE }
## OFFSIDE は前へのパスの受け手がオフサイドで、守備側のボールになる（2026-10-25。末尾に足し、既存の値の番号を変えない）
enum TurnOutcome { ADVANCE, STALL, LOSS, GOAL, SAVE, REGAIN, REGAIN_FAILED, NO_CONTEST, OFFSIDE }
enum MatchStatus { IN_PROGRESS, FINISHED }
enum MatchStage { TURN, STYLE_CHANGE, HALFTIME }
enum PrincipleStatus { UNVERIFIED, VERIFIED, NO_SOURCE }

# 実装のための区分値
enum TeamSide { HOME, AWAY }
## TurnChoice.action がどの enum の値か
enum ChoiceFamily { ATTACK, DEFENSE, NEG_TRANS, POS_TRANS }
## 同数時のカバー判定の内訳（判定理由の表示に使う）。背後に守備側が多いときだけ DEFENDER。
## GK はカバーに数えない（2026-10-24 に GOALKEEPER・OUT_OF_GK_REACH を外した。functional-overview.md アルゴリズム5）
enum CoverKind { NONE, DEFENDER }
## 守備の読みの段階（functional-overview.md アルゴリズム5）。守備の手で制限したエリアが比較エリアと同じなら EXACT、
## 同じ列でレーンが1つ隣なら NEAR、それ以外は NONE。トランジション・ヒントでは NONE
enum ReadKind { NONE, NEAR, EXACT }
## 選手が動いた理由。DRIBBLE_STOPPED は膠着したドリブルの選手がボールのエリアへ戻る動き、
## BALL_HOLDER はボールのエリアに保持側がいないとき、いちばん近い選手が置かれる動き、
## RETURN は方式の動きの理由が無いまま、基本エリアへ1マス戻る動き、THROUGH_RUN はスルーパスの受け手が運ぶ先へ走り込む動き
## （末尾に足し、既存の値の番号を変えない）
enum MovementReason {
	SLIDE, MARK, POSSESSION_ADVANCE, COUNTER_BREAKOUT, RETREAT_RESET, PRESS, COVER, DRIBBLE, DRIBBLE_STOPPED, BALL_HOLDER,
	RETURN, THROUGH_RUN,
}
## 戦績の勝敗（利用者から見た値）
enum MatchResult { WIN, DRAW, LOSE }
## 振り返りの局面別集計（アルゴリズム10）
enum Phase { ATTACK, NEG_TRANSITION, DEFENSE, POS_TRANSITION }
## 振り返りでの1ターンの数え方（アルゴリズム10）
enum JudgeTally { WIN, LOSE, STALL, EXCLUDED }

## 噛み合わせルールの1件（data-definition.md §3.3 の matchup_rules.json。アルゴリズム9）。
## 陣形どうし（FORMATION）は特徴タグの条件、方式どうし（STYLE）は方式の条件で当たる。文は解説を見る側（viewer）から書き、
## 相手チームは「相手」と書く。
class_name MatchupRuleDef
extends RefCounted

const KIND_FORMATION: String = "FORMATION"
const KIND_STYLE: String = "STYLE"

var id: String
## KIND_FORMATION・KIND_STYLE
var kind: String
## FORMATION のとき: viewer・opponent がすべて持つべき特徴タグ
var viewer_tags: Array[String] = []
var opponent_tags: Array[String] = []
## STYLE のとき: viewer・opponent の方式（StyleDef.id）。片方が守備方式、もう片方が攻撃方式
var viewer_style: String = ""
var opponent_style: String = ""
var text: String
## 同じ噛み合わせで、同じテーマから採るのは配列で先の1件だけ
var theme: String
var principle_ids: Array[String] = []
var simplification_ids: Array[String] = []

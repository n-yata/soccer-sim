## 方式の1件（functional-overview.md の ER 図の「方式」。data-definition.md §3.2 の styles.json）。
## 単独の解説（特徴・強み・弱み。FR-17）の固定文を持つ。
class_name StyleDef
extends RefCounted

const KIND_DEFENSE: String = "DEFENSE"
const KIND_ATTACK: String = "ATTACK"

## 区分値の名前（ZONE・MAN・POSSESSION・COUNTER）
var id: String
## KIND_DEFENSE・KIND_ATTACK
var kind: String
var name: String
var summary: String
var strengths: String
var weaknesses: String
var principle_ids: Array[String] = []
var simplification_ids: Array[String] = []


## 守備方式の区分値の名前（GameEnums.DefenseStyle のキー）。
static func defense_id(style: GameEnums.DefenseStyle) -> String:
	return GameEnums.DefenseStyle.find_key(style) as String


## 攻撃方式の区分値の名前（GameEnums.AttackStyle のキー）。
static func attack_id(style: GameEnums.AttackStyle) -> String:
	return GameEnums.AttackStyle.find_key(style) as String

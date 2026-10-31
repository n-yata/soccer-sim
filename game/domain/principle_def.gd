## 戦術原則カタログの1件（functional-overview.md「戦術原則カタログ」。data-definition.md §3.4 の principles.json）。
class_name PrincipleDef
extends RefCounted

## TP-NN
var id: String
## 原則（例「チャレンジ＆カバー」）
var name: String
var content: String
## 出典（「未確定」を許す）
var source: String
var status: GameEnums.PrincipleStatus


func _init(p_id: String, p_name: String, p_content: String, p_source: String,
		p_status: GameEnums.PrincipleStatus) -> void:
	id = p_id
	name = p_name
	content = p_content
	source = p_source
	status = p_status

## 単純化カタログの1件（functional-overview.md「単純化カタログ」。FR-23。data-definition.md §3.4 の simplifications.json）。
class_name SimplificationDef
extends RefCounted

## SIM-NN
var id: String
## 単純化（例「オフサイドのタイミング」）
var name: String
## ゲームでの扱い
var in_game: String
## 実戦では
var in_real: String


func _init(p_id: String, p_name: String, p_in_game: String, p_in_real: String) -> void:
	id = p_id
	name = p_name
	in_game = p_in_game
	in_real = p_in_real

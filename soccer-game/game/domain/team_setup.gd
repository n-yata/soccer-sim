## 1チームの陣形と方式（component-design.md §2.2）。陣形はハーフ単位、方式は方式区間単位で変わる。
class_name TeamSetup
extends RefCounted

var formation_id: String
var styles: TeamStyles


func _init(p_formation_id: String, p_styles: TeamStyles) -> void:
	formation_id = p_formation_id
	styles = p_styles


## 方式まで写す。
func duplicate_deep() -> TeamSetup:
	return TeamSetup.new(formation_id, styles.duplicate_deep())

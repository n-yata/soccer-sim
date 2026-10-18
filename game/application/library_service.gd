## 画面向けの参照（component-design.md §3.4）。静的データ（ContentCatalog）から、画面が出す値を作る。
## 今は陣形の一覧と基本配置の人数だけ。matchup_counts・解説・単純化は、それを使う画面の作業で足す。
class_name LibraryService
extends RefCounted

var _catalog: ContentCatalog


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


## 陣形の一覧（静的データの順）。呼び出し側が並べ替えても影響しないよう、配列はコピーして返す。
func formations() -> Array[FormationDef]:
	return _catalog.formations.duplicate()


## 基本配置の人数（PitchArea のキー → 人数。そのチーム自身の視点。アルゴリズム1）。存在しない陣形なら空。
func base_counts(formation_id: String) -> Dictionary:
	var formation: FormationDef = _catalog.formation(formation_id)
	if formation == null:
		push_error("LibraryService: 陣形が無い: %s" % formation_id)
		return {}
	return BaseLayoutDeriver.derive(formation).counts()

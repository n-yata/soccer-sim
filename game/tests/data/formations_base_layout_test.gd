## 本物の formations.json から導いた4陣形の基本配置が、functional-overview.md アルゴリズム1の
## 「計算結果（MVP の4陣形）」の表と15エリアすべてで一致すること（NFR-14、data-definition.md §3.1 の検証）。
extends GdUnitTestSuite

const LANES: Array[String] = ["L2", "L1", "C", "R1", "R2"]

## functional-overview.md の表をそのまま写したもの。列は L2 / L1 / C / R1 / R2
## 2026-10-24 から、重なるゾーンを1マス1人に散らした値（シャビの指摘「空きマスがあるのに同じマスに固まる」）
const EXPECTED: Dictionary = {
	"4-4-2": {"A": [0, 1, 0, 1, 0], "M": [1, 1, 0, 1, 1], "D": [1, 1, 0, 1, 1]},
	"4-3-3": {"A": [1, 0, 1, 0, 1], "M": [0, 1, 1, 1, 0], "D": [1, 1, 0, 1, 1]},
	"4-2-3-1": {"A": [0, 0, 1, 0, 0], "M": [1, 1, 1, 1, 1], "D": [1, 1, 0, 1, 1]},
	"3-5-2": {"A": [0, 1, 0, 1, 0], "M": [1, 1, 1, 1, 1], "D": [0, 1, 1, 1, 0]},
}


func test_base_layouts_of_four_formations_match_the_algorithm_1_table() -> void:
	var repository := ContentRepository.new()
	var catalog: ContentCatalog = repository.load_catalog()
	assert_array(repository.validation_errors()).is_empty()
	for formation_id: String in EXPECTED:
		var formation: FormationDef = catalog.formation(formation_id)
		assert_object(formation).override_failure_message("陣形が無い: %s" % formation_id).is_not_null()
		if formation == null:
			continue
		var counts: Dictionary = BaseLayoutDeriver.derive(formation).counts()
		var rows: Dictionary = EXPECTED[formation_id]
		var total: int = 0
		for zone: String in rows:
			var row: Array = rows[zone]
			for i: int in LANES.size():
				var key: String = "%s-%s" % [zone, LANES[i]]
				assert_int(counts[key] as int).override_failure_message("%s の %s" % [formation_id, key]) \
						.is_equal(row[i] as int)
				total += counts[key] as int
		assert_int(total).override_failure_message("%s の合計" % formation_id).is_equal(10)

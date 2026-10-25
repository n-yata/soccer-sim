## 本物の formations.json から導いた4陣形の基本配置とキックオフの位置が、functional-overview.md アルゴリズム1の
## 「計算結果（MVP の4陣形）」の表・アルゴリズム7の例と30エリアすべてで一致すること（NFR-14、data-definition.md §3.1 の検証）。
extends GdUnitTestSuite

const LANES: Array[String] = ["L2", "L1", "C", "R1", "R2"]

## functional-overview.md の表をそのまま写したもの。列は L2 / L1 / C / R1 / R2。
## 2026-10-25 から6列（座標の y を6等分）。重なりは1マス1人に散らした値（2026-10-24）
const EXPECTED: Dictionary = {
	"4-4-2": {
		"A2": [0, 1, 0, 1, 0], "A1": [0, 0, 0, 0, 0], "M2": [1, 1, 0, 1, 1],
		"M1": [0, 0, 0, 0, 0], "D2": [1, 1, 0, 1, 1], "D1": [0, 0, 0, 0, 0],
	},
	"4-3-3": {
		"A2": [1, 0, 1, 0, 1], "A1": [0, 0, 0, 0, 0], "M2": [0, 1, 0, 1, 0],
		"M1": [0, 0, 1, 0, 0], "D2": [1, 1, 0, 1, 1], "D1": [0, 0, 0, 0, 0],
	},
	"4-2-3-1": {
		"A2": [0, 0, 1, 0, 0], "A1": [0, 0, 0, 0, 0], "M2": [1, 0, 1, 0, 1],
		"M1": [0, 1, 0, 1, 0], "D2": [1, 1, 0, 1, 1], "D1": [0, 0, 0, 0, 0],
	},
	"3-5-2": {
		"A2": [0, 1, 0, 1, 0], "A1": [0, 0, 0, 0, 0], "M2": [0, 1, 0, 1, 0],
		"M1": [1, 0, 1, 0, 1], "D2": [0, 1, 0, 1, 0], "D1": [0, 0, 1, 0, 0],
	},
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


## キックオフの位置（アルゴリズム7）。4陣形の表は手で計算した（列の番号を半分にする）。4陣形では、縮めても
## 同じエリアに重ならない（散らす規則は base_layout_deriver_test の作った配置で確かめる）
const KICKOFF_EXPECTED: Dictionary = {
	"4-4-2": {"M1": [0, 1, 0, 1, 0], "D2": [1, 1, 0, 1, 1], "D1": [1, 1, 0, 1, 1]},
	"4-3-3": {"M1": [1, 0, 1, 0, 1], "D2": [0, 1, 1, 1, 0], "D1": [1, 1, 0, 1, 1]},
	"4-2-3-1": {"M1": [0, 0, 1, 0, 0], "D2": [1, 1, 1, 1, 1], "D1": [1, 1, 0, 1, 1]},
	"3-5-2": {"M1": [0, 1, 0, 1, 0], "D2": [1, 1, 1, 1, 1], "D1": [0, 1, 1, 1, 0]},
}


func test_kickoff_positions_of_four_formations_are_one_per_area_in_the_own_half() -> void:
	var catalog: ContentCatalog = ContentRepository.new().load_catalog()
	for formation_id: String in KICKOFF_EXPECTED:
		var players: Array[PlayerState] = BaseLayoutDeriver.derive(catalog.formation(formation_id)).players
		var kickoff: Dictionary = BaseLayoutDeriver.kickoff_areas(players)
		var counts: Dictionary = {}
		for player_id: String in kickoff:
			var key: String = (kickoff[player_id] as PitchArea).to_key()
			counts[key] = (counts.get(key, 0) as int) + 1
		var rows: Dictionary = KICKOFF_EXPECTED[formation_id]
		var total: int = 0
		# 4〜6列目（M2・A1・A2）は表に無いので0人。表の列は手で計算した人数
		for zone: String in ["D1", "D2", "M1", "M2", "A1", "A2"]:
			var row: Array = rows.get(zone, [0, 0, 0, 0, 0])
			for i: int in LANES.size():
				var key: String = "%s-%s" % [zone, LANES[i]]
				assert_int(counts.get(key, 0) as int).override_failure_message("%s の %s" % [formation_id, key]) \
						.is_equal(row[i] as int)
				total += counts.get(key, 0) as int
		assert_int(total).override_failure_message("%s の合計" % formation_id).is_equal(10)

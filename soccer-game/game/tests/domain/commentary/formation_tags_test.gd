## FormationTags（アルゴリズム9の特徴タグの導出。移植元の formationTags.ts の deriveTags・getTags）のテスト。
extends GdUnitTestSuite


func _slot(slot_id: String, position_type: String, x: float, y: float) -> PlayerSlotDef:
	return PlayerSlotDef.new(slot_id, position_type, position_type, 1, x, y)


## GK と、spec の選手（[id, 種別, x, y]）だけの陣形（調べたいタグに関わる選手だけを置く）
func _formation(spec: Array, extra_tags: Array[String] = []) -> FormationDef:
	var slots: Array[PlayerSlotDef] = [_slot("gk", "GK", 50.0, 5.0)]
	for entry: Array in spec:
		slots.append(_slot(entry[0] as String, entry[1] as String, entry[2] as float, entry[3] as float))
	return FormationDef.new("t", "t", "テスト用", extra_tags, slots)


func _real(formation_id: String) -> FormationDef:
	return ContentRepository.new().load_catalog().formation(formation_id)


## 本物の4陣形のタグ（移植元の deriveTags に同じ座標を与えた結果。並びも移植元と同じ）
func test_real_formations_have_the_ported_tags() -> void:
	var expected: Dictionary = {
		"4-4-2": ["4バック", "2トップ", "中盤フラット4枚", "ライン間が空く"],
		"4-3-3": ["4バック", "3トップ", "ウイング有", "中盤3枚"],
		"4-2-3-1": ["4バック", "1トップ", "守備的MF2枚", "攻撃的MF3枚", "中盤実質5枚"],
		"3-5-2": ["3バック", "2トップ", "ウイングバック有", "中盤実質5枚"],
	}
	for formation_id: String in expected:
		assert_array(FormationTags.of(_real(formation_id))).override_failure_message(formation_id) \
				.is_equal(expected[formation_id] as Array)


func test_back_and_top_counts_come_from_position_types() -> void:
	var three_back := _formation([["d1", "DF", 30.0, 18.0], ["d2", "DF", 50.0, 15.0], ["d3", "DF", 70.0, 18.0],
			["f1", "FW", 50.0, 70.0]])
	assert_array(FormationTags.derive(three_back)).is_equal(["3バック", "1トップ"])
	var four_back := _formation([["d1", "DF", 15.0, 20.0], ["d2", "DF", 35.0, 18.0], ["d3", "DF", 65.0, 18.0],
			["d4", "DF", 85.0, 20.0], ["f1", "FW", 40.0, 70.0], ["f2", "FW", 60.0, 70.0], ["f3", "FW", 50.0, 70.0]])
	assert_array(FormationTags.derive(four_back)).is_equal(["4バック", "3トップ"])


## ウイング: 外側（x ≤ 25 か x ≥ 75）かつ高い（y ≥ 80）FW が2人以上
func test_wings_need_two_wide_and_high_forwards() -> void:
	var on_boundary := _formation([["lw", "FW", 25.0, 80.0], ["rw", "FW", 75.0, 80.0]])
	assert_array(FormationTags.derive(on_boundary)).contains(["ウイング有"])
	var too_narrow := _formation([["lw", "FW", 26.0, 85.0], ["rw", "FW", 75.0, 85.0]])
	assert_array(FormationTags.derive(too_narrow)).not_contains(["ウイング有"])
	var too_low := _formation([["lw", "FW", 20.0, 79.0], ["rw", "FW", 80.0, 85.0]])
	assert_array(FormationTags.derive(too_low)).not_contains(["ウイング有"])


## ウイングバック: さらに外側（x ≤ 15 か x ≥ 85）かつ低い（y ≤ 50）MF が2人以上
func test_wing_backs_need_two_wide_and_low_midfielders() -> void:
	var on_boundary := _formation([["lwb", "MF", 15.0, 50.0], ["rwb", "MF", 85.0, 50.0], ["cm", "MF", 50.0, 55.0]])
	assert_array(FormationTags.derive(on_boundary)).contains(["ウイングバック有"])
	# 4-4-2 のサイドMF（y = 55）はウイングバックにしない
	var too_high := _formation([["lm", "MF", 15.0, 51.0], ["rm", "MF", 85.0, 50.0], ["cm", "MF", 50.0, 55.0]])
	assert_array(FormationTags.derive(too_high)).not_contains(["ウイングバック有"])
	var too_narrow := _formation([["lm", "MF", 16.0, 45.0], ["rm", "MF", 85.0, 45.0], ["cm", "MF", 50.0, 55.0]])
	assert_array(FormationTags.derive(too_narrow)).not_contains(["ウイングバック有"])


## 守備的MF: y ≤ 42 の MF がちょうど2人。攻撃的MF: y ≥ 58 の MF が3人以上
func test_defensive_and_attacking_midfielders_use_height() -> void:
	var formation := _formation([["dm1", "MF", 35.0, 42.0], ["dm2", "MF", 65.0, 40.0], ["am1", "MF", 20.0, 58.0],
			["am2", "MF", 50.0, 60.0], ["am3", "MF", 80.0, 65.0]])
	var tags: Array[String] = FormationTags.derive(formation)
	assert_array(tags).contains(["守備的MF2枚", "攻撃的MF3枚", "中盤実質5枚"])
	var one_low := _formation([["dm1", "MF", 35.0, 43.0], ["dm2", "MF", 65.0, 40.0], ["am1", "MF", 20.0, 57.0],
			["am2", "MF", 50.0, 60.0], ["am3", "MF", 80.0, 65.0]])
	assert_array(FormationTags.derive(one_low)).not_contains(["守備的MF2枚", "攻撃的MF3枚"])


## 中盤4枚: y の幅が 10 以下ならフラット。それより広い4枚（ダイヤ・ボックス）は 4陣形に無いので、タグを付けない
func test_flat_four_needs_a_narrow_height_spread() -> void:
	var flat := _formation([["m1", "MF", 15.0, 45.0], ["m2", "MF", 35.0, 50.0], ["m3", "MF", 65.0, 50.0],
			["m4", "MF", 85.0, 55.0]])
	assert_array(FormationTags.derive(flat)).contains(["中盤フラット4枚"])
	var wide := _formation([["m1", "MF", 15.0, 44.0], ["m2", "MF", 35.0, 50.0], ["m3", "MF", 65.0, 50.0],
			["m4", "MF", 85.0, 55.0]])
	assert_array(FormationTags.derive(wide)).not_contains(["中盤フラット4枚"])


func test_three_midfielders_tag() -> void:
	var formation := _formation([["m1", "MF", 30.0, 50.0], ["m2", "MF", 50.0, 45.0], ["m3", "MF", 70.0, 50.0]])
	assert_array(FormationTags.derive(formation)).contains(["中盤3枚"])


func test_of_adds_extra_tags_after_derived_ones_without_duplicates() -> void:
	var formation := _formation([["m1", "MF", 30.0, 50.0], ["m2", "MF", 50.0, 45.0], ["m3", "MF", 70.0, 50.0]],
			["ライン間が空く", "中盤3枚"] as Array[String])
	assert_array(FormationTags.of(formation)).is_equal(["中盤3枚", "ライン間が空く"])


func test_known_tags_cover_every_derived_and_extra_tag_of_real_formations() -> void:
	for formation: FormationDef in ContentRepository.new().load_catalog().formations:
		for tag: String in FormationTags.of(formation):
			assert_bool(FormationTags.KNOWN.has(tag)).override_failure_message(tag).is_true()

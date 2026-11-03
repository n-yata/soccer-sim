## 本物の静的データ（formations.json・styles.json・matchup_rules.json）で導く解説（アルゴリズム9・FR-17）のテスト。
## 形と範囲は CommentaryContentReader・ContentRepository のテストで確かめる。ここでは組み合わせの網羅と、ルール表の性質を確かめる。
extends GdUnitTestSuite

## 移植元（soccer-sim の matchupRules.ts）の配列の順。4陣形どうしで当たるものだけ
const PORTED_RULE_IDS: Array[String] = ["R08", "R09", "R01", "R03", "R05", "R02", "R12", "R18", "R13", "R15", "R20", "R06",
		"R04", "R14", "R36", "R07", "R10", "R16"]

var _catalog: ContentCatalog


func before() -> void:
	_catalog = ContentRepository.new().load_catalog()


## 読み込みに失敗すると空のカタログになり、組み合わせを回すテストが0回のループで通ってしまう。回す前に確かめる
func _assert_loaded() -> void:
	assert_int(_catalog.formations.size()).is_equal(4)
	assert_int(_catalog.styles.size()).is_equal(4)
	assert_int(_catalog.matchup_rules.size()).is_equal(PORTED_RULE_IDS.size() + 8)
	assert_object(_catalog.matchup_fallback).is_not_null()


func _all_styles() -> Array[TeamStyles]:
	var result: Array[TeamStyles] = []
	for defense: GameEnums.DefenseStyle in GameEnums.DefenseStyle.values():
		for attack: GameEnums.AttackStyle in GameEnums.AttackStyle.values():
			result.append(TeamStyles.new(defense, attack))
	return result


func test_formation_rules_are_the_ported_rules_in_source_order() -> void:
	var ids: Array[String] = []
	for rule: MatchupRuleDef in _catalog.matchup_rules:
		if rule.kind == MatchupRuleDef.KIND_FORMATION:
			ids.append(rule.id)
	assert_array(ids).is_equal(PORTED_RULE_IDS)


## 16通りのどちらの側にも1件以上の解説が出る（FR-17）。当たるルールが無いのは 4-4-2 どうしだけで、そこは代わりの文
func test_every_formation_pair_has_notes_on_both_sides() -> void:
	_assert_loaded()
	for viewer: FormationDef in _catalog.formations:
		for opponent: FormationDef in _catalog.formations:
			var notes: Array[MatchupNote] = CommentaryGenerator.formation_matchup(viewer, opponent, _catalog)
			var pair: String = "%s vs %s" % [viewer.id, opponent.id]
			assert_bool(notes.is_empty()).override_failure_message(pair).is_false()
			var is_fallback: bool = notes.size() == 1 and notes[0].text == _catalog.matchup_fallback.text
			assert_bool(is_fallback).override_failure_message(pair) \
					.is_equal(viewer.id == "4-4-2" and opponent.id == "4-4-2")


## 移植したルールは、どれも4陣形のどこかで採用される（同じテーマの先のルールに吸収されて一度も出ないルールを残さない）
func test_every_formation_rule_is_used_by_some_pair() -> void:
	_assert_loaded()
	var used: Dictionary = {}
	for viewer: FormationDef in _catalog.formations:
		for opponent: FormationDef in _catalog.formations:
			for note: MatchupNote in CommentaryGenerator.formation_matchup(viewer, opponent, _catalog):
				used[note.text] = true
	for rule: MatchupRuleDef in _catalog.matchup_rules:
		if rule.kind == MatchupRuleDef.KIND_FORMATION:
			assert_bool(used.has(rule.text)).override_failure_message(rule.id).is_true()


## 方式の16通り（自分の守備・攻撃 × 相手の守備・攻撃）で、守備と攻撃の解説が1件ずつ出る
func test_every_style_pair_has_one_defense_and_one_attack_note() -> void:
	var used: Dictionary = {}
	for viewer: TeamStyles in _all_styles():
		for opponent: TeamStyles in _all_styles():
			var notes: Array[MatchupNote] = CommentaryGenerator.style_matchup(viewer, opponent, _catalog)
			assert_int(notes.size()).override_failure_message("%s vs %s" % [str(viewer), str(opponent)]).is_equal(2)
			for note: MatchupNote in notes:
				used[note.text] = true
	assert_int(used.size()).is_equal(8)


## 相手の狙いどころは「相手」を「こちら」に言い換えて出す（LibraryService）。元の文に「こちら」があると意味が崩れる
func test_rule_texts_never_use_the_own_side_word() -> void:
	for rule: MatchupRuleDef in _catalog.matchup_rules:
		assert_str(rule.text).override_failure_message(rule.id).not_contains(LibraryService.OWN_WORD)
	assert_str(_catalog.matchup_fallback.text).not_contains(LibraryService.OWN_WORD)


## 4陣形・4方式のすべてに、特徴・強み・弱みがある（FR-17）
func test_every_formation_and_style_has_a_profile() -> void:
	_assert_loaded()
	for formation: FormationDef in _catalog.formations:
		for note: MatchupNote in CommentaryGenerator.formation_profile(formation):
			assert_int(note.text.length()).override_failure_message(formation.id).is_greater(4)
			assert_array(note.principle_ids).override_failure_message(formation.id).is_not_empty()
	for style: StyleDef in _catalog.styles:
		assert_int(CommentaryGenerator.style_profile(style.id, _catalog).size()).is_equal(3)


## すべての解説の根拠の原則が、原則カタログにある（NFR-17 ①）
func test_every_note_cites_known_principles() -> void:
	_assert_loaded()
	var known: Array[String] = []
	for principle: PrincipleDef in _catalog.principles:
		known.append(principle.id)
	for rule: MatchupRuleDef in _catalog.matchup_rules:
		for principle_id: String in rule.principle_ids:
			assert_bool(known.has(principle_id)).override_failure_message(rule.id).is_true()
	for formation: FormationDef in _catalog.formations:
		for principle_id: String in formation.principle_ids:
			assert_bool(known.has(principle_id)).override_failure_message(formation.id).is_true()

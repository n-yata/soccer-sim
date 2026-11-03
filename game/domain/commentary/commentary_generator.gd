## 解説の導出（アルゴリズム9。component-design.md §2.7）。陣形どうしは「特徴タグ × 噛み合わせルール」から、方式どうしは
## 方式のルールから導く（組み合わせごとに手書きしない。FR-17）。ルールの適用はフォーメーションラボの matchupGenerator.ts の
## applicableRules を移植した: ルール表を配列の順に見て、同じテーマからは先に当たった1件だけを採る（同じ話を別の切り口で
## 書いたルールが同時に当たり、ほぼ同じ文が並ぶのを防ぐ）。
## 返す MatchupNote の label は空（見出しは画面向けの LibraryService が付ける）。
class_name CommentaryGenerator
extends RefCounted

const FEATURE_PREFIX: String = "特徴: "
const STRENGTHS_PREFIX: String = "強み: "
const WEAKNESSES_PREFIX: String = "弱み: "


## viewer から見た陣形どうしの解説（viewer の狙いどころ）。当たるルールが無ければ catalog.matchup_fallback の1件
## （それも無ければ空）。
static func formation_matchup(viewer: FormationDef, opponent: FormationDef,
		catalog: ContentCatalog) -> Array[MatchupNote]:
	var viewer_tags: Array[String] = FormationTags.of(viewer)
	var opponent_tags: Array[String] = FormationTags.of(opponent)
	var used_themes: Dictionary = {}
	var notes: Array[MatchupNote] = []
	for rule: MatchupRuleDef in catalog.matchup_rules:
		if rule.kind != MatchupRuleDef.KIND_FORMATION or used_themes.has(rule.theme):
			continue
		if _has_all(viewer_tags, rule.viewer_tags) and _has_all(opponent_tags, rule.opponent_tags):
			used_themes[rule.theme] = true
			notes.append(_note(rule))
	if notes.is_empty() and catalog.matchup_fallback != null:
		notes.append(catalog.matchup_fallback.relabeled(""))
	return notes


## viewer から見た方式どうしの解説。viewer の守備方式 × opponent の攻撃方式、viewer の攻撃方式 × opponent の守備方式の順。
static func style_matchup(viewer: TeamStyles, opponent: TeamStyles, catalog: ContentCatalog) -> Array[MatchupNote]:
	var notes: Array[MatchupNote] = []
	var used_themes: Dictionary = {}
	var pairs: Array = [[StyleDef.defense_id(viewer.defense), StyleDef.attack_id(opponent.attack)],
			[StyleDef.attack_id(viewer.attack), StyleDef.defense_id(opponent.defense)]]
	for pair: Array in pairs:
		for rule: MatchupRuleDef in catalog.matchup_rules:
			if rule.kind != MatchupRuleDef.KIND_STYLE or used_themes.has(rule.theme):
				continue
			if rule.viewer_style == pair[0] and rule.opponent_style == pair[1]:
				used_themes[rule.theme] = true
				notes.append(_note(rule))
	return notes


## 陣形の単独の解説（特徴・強み・弱みの3件。FR-17）。
static func formation_profile(formation: FormationDef) -> Array[MatchupNote]:
	var empty: Array[String] = []
	return _profile(formation.description, formation.strengths, formation.weaknesses, formation.principle_ids, empty)


## 方式の単独の解説（特徴・強み・弱みの3件）。style_id は区分値の名前（StyleDef.id）。無い方式なら空。
static func style_profile(style_id: String, catalog: ContentCatalog) -> Array[MatchupNote]:
	var style: StyleDef = catalog.style(style_id)
	if style == null:
		var empty: Array[MatchupNote] = []
		return empty
	return _profile(style.summary, style.strengths, style.weaknesses, style.principle_ids, style.simplification_ids)


static func _profile(feature: String, strengths: String, weaknesses: String, principle_ids: Array[String],
		simplification_ids: Array[String]) -> Array[MatchupNote]:
	var notes: Array[MatchupNote] = []
	for text: String in [FEATURE_PREFIX + feature, STRENGTHS_PREFIX + strengths, WEAKNESSES_PREFIX + weaknesses]:
		notes.append(MatchupNote.new(text, principle_ids, simplification_ids))
	return notes


static func _note(rule: MatchupRuleDef) -> MatchupNote:
	return MatchupNote.new(rule.text, rule.principle_ids, rule.simplification_ids)


static func _has_all(tags: Array[String], required: Array[String]) -> bool:
	for tag: String in required:
		if not tags.has(tag):
			return false
	return true

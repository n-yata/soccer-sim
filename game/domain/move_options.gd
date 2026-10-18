## 選べる手と、手ごとの運ぶ先の一覧（component-design.md §2.2。アルゴリズム3の結果）。
## 運ぶ先を持つ手は一覧が1件以上で選べる。運ぶ先を持たない手は、allow したものだけ選べる。
class_name MoveOptions
extends RefCounted

## "family:action" → Array[PitchArea]（運ぶ先を持つ手）
var _targets: Dictionary = {}
## "family:action" → true（運ぶ先を持たない手のうち、選べるもの）
var _allowed: Dictionary = {}


## 運ぶ先を伴う手か（screen-03-match.md「運ぶ先を持つ手」）。
static func needs_target(family: GameEnums.ChoiceFamily, action: int) -> bool:
	match family:
		GameEnums.ChoiceFamily.ATTACK:
			return action != GameEnums.PlayType.SHOT
		GameEnums.ChoiceFamily.DEFENSE:
			return true
		GameEnums.ChoiceFamily.POS_TRANS:
			return action == GameEnums.PosTransAction.COUNTER
	return false


## 運ぶ先を持つ手に、選べる運ぶ先を1つ足す。
func add_target(family: GameEnums.ChoiceFamily, action: int, area: PitchArea) -> void:
	var key: String = _key(family, action)
	if not _targets.has(key):
		var empty: Array[PitchArea] = []
		_targets[key] = empty
	(_targets[key] as Array[PitchArea]).append(area)


## 運ぶ先を持たない手を、選べるようにする。
func allow(family: GameEnums.ChoiceFamily, action: int) -> void:
	_allowed[_key(family, action)] = true


## 選べる手か。運ぶ先を持つ手は一覧が1件以上、持たない手は allow 済みのとき。
func is_available(family: GameEnums.ChoiceFamily, action: int) -> bool:
	if needs_target(family, action):
		return not targets(family, action).is_empty()
	return _allowed.has(_key(family, action))


## 運ぶ先の一覧の写し。無ければ空。配列は写しだが、要素の PitchArea は共有する（PitchArea は作成後に値を変えない約束のため）。
func targets(family: GameEnums.ChoiceFamily, action: int) -> Array[PitchArea]:
	var result: Array[PitchArea] = []
	var key: String = _key(family, action)
	if _targets.has(key):
		result.assign(_targets[key] as Array[PitchArea])
	return result


## 運ぶ先の PitchArea まで写す。
func duplicate_deep() -> MoveOptions:
	var copy := MoveOptions.new()
	for key: String in _targets:
		var areas: Array[PitchArea] = []
		for area: PitchArea in _targets[key] as Array[PitchArea]:
			areas.append(area.duplicate_deep())
		copy._targets[key] = areas
	copy._allowed = _allowed.duplicate()
	return copy


## enum の値は family ごとに 0 から始まるため、family と組にして区別する。
static func _key(family: GameEnums.ChoiceFamily, action: int) -> String:
	return "%d:%d" % [family, action]

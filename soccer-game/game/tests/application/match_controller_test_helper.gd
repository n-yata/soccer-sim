## MatchController のテストで使う、選べる手の選び方（テスト専用。本番のコードからは使わない）。
class_name MatchControllerTestHelper
extends RefCounted


## 選べる手の先頭（手の enum の順、運ぶ先は一覧の順）。選べる手が無ければ null。
static func first_choice(options: MoveOptions) -> TurnChoice:
	var action_counts: Array[int] = [GameEnums.PlayType.size(), GameEnums.DefenseAction.size(),
			GameEnums.NegTransAction.size(), GameEnums.PosTransAction.size()]
	for family: int in range(action_counts.size()):
		var family_value: GameEnums.ChoiceFamily = family as GameEnums.ChoiceFamily
		for action: int in range(action_counts[family]):
			if not options.is_available(family_value, action):
				continue
			if not MoveOptions.needs_target(family_value, action):
				return TurnChoice.new(family_value, action)
			return TurnChoice.new(family_value, action, options.targets(family_value, action)[0])
	return null


## シュートを選べればシュート、そうでなければ先頭。
static func shot_or_first(options: MoveOptions) -> TurnChoice:
	if options.is_available(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT):
		return TurnChoice.new(GameEnums.ChoiceFamily.ATTACK, GameEnums.PlayType.SHOT)
	return first_choice(options)

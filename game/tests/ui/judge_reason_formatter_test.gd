## JudgeReasonFormatter（判定理由の文。.steering/20261019-match-screen/design.md §2）のテスト。
## 形式の正本は functional-overview.md「表示仕様」の判定理由（比較エリア・人数・カバーの有無を必ず含める）。
extends GdUnitTestSuite


func _reveal(role: GameEnums.Phase, outcome: GameEnums.TurnOutcome, area: String, user_count: int,
		opponent_count: int, cover: GameEnums.CoverKind = GameEnums.CoverKind.NONE) -> RevealView:
	var reveal := RevealView.new()
	reveal.user_role = role
	reveal.outcome = outcome
	reveal.has_detail = true
	reveal.compare_area = area
	reveal.user_count = user_count
	reveal.opponent_count = opponent_count
	reveal.cover = cover
	return reveal


func test_advance_with_more_players() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M-C", 1, 0)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤・中央で 1対0。こちらが数的優位で前進")


func test_loss_with_fewer_players() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, "M-L1", 1, 2)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤・左HSで 1対2。相手が数的優位でロスト")


func test_stall_with_a_defender_covering() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.STALL, "M-L2", 1, 1,
			GameEnums.CoverKind.DEFENDER)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤・左大外で 1対1。同数で背後にカバーがいて膠着")


func test_stall_with_the_goalkeeper_covering_from_the_defending_side() -> void:
	# 利用者が守備側でも、人数は「自分 対 相手」の順
	var reveal: RevealView = _reveal(GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.STALL, "D-C", 2, 2,
			GameEnums.CoverKind.GOALKEEPER)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("自陣・中央で 2対2。同数でGKがカバーして膠着")


func test_advance_out_of_the_goalkeeper_reach() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "A-R2", 1, 1,
			GameEnums.CoverKind.OUT_OF_GK_REACH)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・右大外で 1対1。同数でGKのカバーが届かず前進")


func test_goal_and_save() -> void:
	var goal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.GOAL, "A-C", 2, 1)
	assert_str(JudgeReasonFormatter.format(goal)).is_equal("敵陣・中央で 2対1。こちらが数的優位で得点")
	var save: RevealView = _reveal(GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.SAVE, "D-C", 2, 2)
	assert_str(JudgeReasonFormatter.format(save)).is_equal("自陣・中央で 2対2。同数でカバーがいなくてシュート阻止")


func test_regain_and_regain_failed() -> void:
	var regain: RevealView = _reveal(GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.REGAIN, "M-C", 4, 2)
	assert_str(JudgeReasonFormatter.format(regain)).is_equal("中盤・中央で 4対2。こちらが数的優位で奪回成功")
	var failed: RevealView = _reveal(GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.REGAIN_FAILED, "M-C", 3, 3)
	assert_str(JudgeReasonFormatter.format(failed)).is_equal("中盤・中央で 3対3。同数でカバーがいなくて奪回失敗")


func test_no_contest_depends_on_the_user_role() -> void:
	var winner := RevealView.new()
	winner.user_role = GameEnums.Phase.POS_TRANSITION
	winner.outcome = GameEnums.TurnOutcome.NO_CONTEST
	winner.has_detail = false
	assert_str(JudgeReasonFormatter.format(winner)).is_equal("判定なし（相手は撤退、こちらは保持）")
	var loser := RevealView.new()
	loser.user_role = GameEnums.Phase.NEG_TRANSITION
	loser.outcome = GameEnums.TurnOutcome.NO_CONTEST
	loser.has_detail = false
	assert_str(JudgeReasonFormatter.format(loser)).is_equal("判定なし（こちらは撤退、相手は保持）")
	assert_str(JudgeReasonFormatter.detail(loser)).is_empty()


func test_detail_lists_the_area_both_counts_and_the_cover() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M-C", 1, 0)
	assert_str(JudgeReasonFormatter.detail(reveal)).is_equal("比較エリア 中盤・中央／● 自分 1 対 0 相手 ◆／カバー なし")
	reveal.cover = GameEnums.CoverKind.DEFENDER
	assert_str(JudgeReasonFormatter.detail(reveal)).ends_with("カバー あり")
	reveal.cover = GameEnums.CoverKind.GOALKEEPER
	assert_str(JudgeReasonFormatter.detail(reveal)).ends_with("カバー GK")
	reveal.cover = GameEnums.CoverKind.OUT_OF_GK_REACH
	assert_str(JudgeReasonFormatter.detail(reveal)).ends_with("カバー GK外")

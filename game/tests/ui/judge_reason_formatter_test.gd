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
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M1-C", 1, 0)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対0。こちらが数的優位で前進")


## 守備が運ぶ先を読んだ判定の開示（read はぴったり・隣）
func _read_reveal(role: GameEnums.Phase, outcome: GameEnums.TurnOutcome, area: String, user_count: int,
		opponent_count: int, read: GameEnums.ReadKind = GameEnums.ReadKind.EXACT) -> RevealView:
	var reveal: RevealView = _reveal(role, outcome, area, user_count, opponent_count)
	reveal.read = read
	return reveal


func test_loss_read_next_door_says_so() -> void:
	# 隣を読まれると、同数でも奪われる（アルゴリズム5）。人数の句ではなく、隣の読みを原因にする
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, "M1-C", 1, 1,
			GameEnums.ReadKind.NEAR)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対1。隣を読まれてロスト")
	reveal.user_role = GameEnums.Phase.DEFENSE
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対1。隣を読んでロスト")


func test_loss_with_fewer_attackers_blames_the_numbers_even_when_read() -> void:
	# 1人少なければ、読まれていなくてもロスト。原因は人数
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, "M1-C", 1, 2,
			GameEnums.ReadKind.NEAR)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対2。相手が数的優位でロスト")
	reveal.read = GameEnums.ReadKind.EXACT
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対2。相手が数的優位でロスト")


func test_level_shot_read_next_door_still_scores() -> void:
	# 隣の読みはシュートに効かない。守備は隣を読んでいたので「読まれず」とは言わない
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.GOAL, "A1-C", 1, 1,
			GameEnums.ReadKind.NEAR)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。隣を読まれたが同数で得点")
	reveal.user_role = GameEnums.Phase.DEFENSE
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。隣を読んだが同数で得点")


func test_advance_read_next_door_keeps_the_numbers_phrase() -> void:
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M1-C", 2, 1,
			GameEnums.ReadKind.NEAR)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 2対1。こちらが数的優位で前進")


func test_read_loss_says_the_move_was_read_even_with_more_players() -> void:
	# 読まれると、1人多いだけでは前進できない（アルゴリズム5）。人数の句ではなく、読まれたことを原因にする
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, "M1-C", 1, 0)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 1対0。読まれてロスト")


func test_read_save_says_the_shot_was_read() -> void:
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.SAVE, "A1-C", 1, 1)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。読まれてシュート阻止")


func test_read_loss_from_the_defending_side_says_the_defense_read_it() -> void:
	var reveal: RevealView = _read_reveal(GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.LOSS, "M1-C", 0, 1)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 0対1。読み切ってロスト")


func test_read_advance_with_a_two_player_advantage_keeps_the_numbers_phrase() -> void:
	# 2人以上多ければ、読まれても前進する。原因は人数
	var reveal: RevealView = _read_reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M1-C", 2, 0)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 2対0。こちらが数的優位で前進")


func test_unread_level_shot_scores_because_it_was_not_read() -> void:
	# シュートはカバー判定をしない。同数で得点した理由は、読まれなかったこと（アルゴリズム5）
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.GOAL, "A1-C", 1, 1)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。同数で読まれず得点")
	reveal.user_role = GameEnums.Phase.DEFENSE
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。同数で読めず得点")


func test_loss_with_fewer_players() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.LOSS, "M1-L1", 1, 2)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・左HSで 1対2。相手が数的優位でロスト")


func test_stall_with_a_defender_covering() -> void:
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.STALL, "M1-L2", 1, 1,
			GameEnums.CoverKind.DEFENDER)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・左大外で 1対1。同数で背後にカバーがいて膠着")


func test_stall_with_a_defender_covering_from_the_defending_side() -> void:
	# 利用者が守備側でも、人数は「自分 対 相手」の順
	var reveal: RevealView = _reveal(GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.STALL, "M1-C", 2, 2,
			GameEnums.CoverKind.DEFENDER)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("中盤（自陣）・中央で 2対2。同数で背後にカバーがいて膠着")


func test_level_numbers_in_the_final_third_advance_without_a_cover() -> void:
	# GK はカバーに数えない（2026-10-24）
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "A1-C", 1, 1)
	assert_str(JudgeReasonFormatter.format(reveal)).is_equal("敵陣・中央で 1対1。同数でカバーがいなくて前進")


func test_goal_and_save() -> void:
	var goal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.GOAL, "A1-C", 2, 1)
	assert_str(JudgeReasonFormatter.format(goal)).is_equal("敵陣・中央で 2対1。こちらが数的優位で得点")
	var save: RevealView = _reveal(GameEnums.Phase.DEFENSE, GameEnums.TurnOutcome.SAVE, "D2-C", 2, 2)
	assert_str(JudgeReasonFormatter.format(save)).is_equal("自陣・中央で 2対2。同数でカバーがいなくてシュート阻止")


func test_regain_and_regain_failed() -> void:
	var regain: RevealView = _reveal(GameEnums.Phase.NEG_TRANSITION, GameEnums.TurnOutcome.REGAIN, "M1-C", 4, 2)
	assert_str(JudgeReasonFormatter.format(regain)).is_equal("中盤（自陣）・中央で 4対2。こちらが数的優位で奪回成功")
	var failed: RevealView = _reveal(GameEnums.Phase.POS_TRANSITION, GameEnums.TurnOutcome.REGAIN_FAILED, "M1-C", 3, 3)
	assert_str(JudgeReasonFormatter.format(failed)).is_equal("中盤（自陣）・中央で 3対3。同数でカバーがいなくて奪回失敗")


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
	var reveal: RevealView = _reveal(GameEnums.Phase.ATTACK, GameEnums.TurnOutcome.ADVANCE, "M1-C", 1, 0)
	assert_str(JudgeReasonFormatter.detail(reveal)).is_equal("比較エリア 中盤（自陣）・中央／● 自分 1 対 0 相手 ◆／カバー なし")
	reveal.cover = GameEnums.CoverKind.DEFENDER
	assert_str(JudgeReasonFormatter.detail(reveal)).ends_with("カバー あり")


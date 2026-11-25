## RecordTexts（戦績の表示の文）のテスト。期待値は screen-01-title.md・screen-06-result.md・screen-11-records.md の例から書いた。
extends GdUnitTestSuite

const ZONE := GameEnums.DefenseStyle.ZONE
const MAN := GameEnums.DefenseStyle.MAN
const POSSESSION := GameEnums.AttackStyle.POSSESSION
const COUNTER := GameEnums.AttackStyle.COUNTER


func _setup(formation_id: String, defense: GameEnums.DefenseStyle, attack: GameEnums.AttackStyle) -> TeamSetup:
	return TeamSetup.new(formation_id, TeamStyles.new(defense, attack))


func test_totals_summary() -> void:
	assert_str(RecordTexts.totals_summary({"win": 5, "draw": 2, "lose": 3})).is_equal("5勝 2分 3敗")
	assert_str(RecordTexts.totals_summary({"win": 0, "draw": 0, "lose": 1})).is_equal("0勝 0分 1敗")
	assert_str(RecordTexts.totals_summary({"win": 0, "draw": 0, "lose": 0})).is_equal("まだ記録がありません")


func test_date_text_drops_the_year_and_leading_zeros_of_month_and_day() -> void:
	assert_str(RecordTexts.date_text("2026-10-17T19:42:05")).is_equal("10/17 19:42")
	assert_str(RecordTexts.date_text("2026-03-05T09:07:00")).is_equal("3/5 09:07")
	assert_str(RecordTexts.date_text("broken")).is_equal("broken")


## 前半の途中で CPU が守備方式を、後半のアディショナルタイムに自分が攻撃方式と守備方式を変えた試合
func test_history_lines_show_each_half_and_each_change() -> void:
	var record := MatchRecord.new()
	var user_first := _setup("4-3-3", ZONE, POSSESSION)
	var cpu_first := _setup("4-4-2", MAN, COUNTER)
	var cpu_zone := _setup("4-4-2", ZONE, COUNTER)
	var user_second := _setup("3-5-2", MAN, POSSESSION)
	var user_late := _setup("3-5-2", ZONE, COUNTER)
	record.timeline = [
		RecordPeriod.new(1, 1, user_first, cpu_first),
		RecordPeriod.new(1, 4, user_first, cpu_zone),
		RecordPeriod.new(2, 1, user_second, cpu_zone),
		RecordPeriod.new(2, 16, user_late, cpu_zone),
	]
	assert_array(RecordTexts.history_lines(record, 15)).is_equal([
		"前半: ● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型",
		"前半 4ターン目: CPU が守備方式をゾーンに変更",
		"後半: ● 3-5-2 マンツーマン・保持型 対 ◆ 4-4-2 ゾーン・カウンター型",
		"後半 15＋1ターン目: 自分が守備方式をゾーンに変更",
		"後半 15＋1ターン目: 自分が攻撃方式をカウンター型に変更",
	] as Array[String])

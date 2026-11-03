## MiniPitch（screen-common.md §5）のテスト。作戦ボードと同じ向き: 横 = レーン（L2〜R2 を左から）、縦 = 列（A2〜D1 を上から）。
## 利用者は上へ攻める。
extends GdUnitTestSuite

const CELL: Vector2 = Vector2(44, 30)


func _rect(key: String) -> Rect2:
	return MiniPitch.cell_rect(PitchArea.from_key(key), CELL)


func test_attack_left_wide_is_top_left() -> void:
	assert_object(_rect("A2-L2")).is_equal(Rect2(0, 0, 44, 30))


func test_defense_right_wide_is_bottom_right() -> void:
	assert_object(_rect("D1-R2")).is_equal(Rect2(176, 150, 44, 30))


func test_middle_center_is_just_above_the_halfway_line() -> void:
	assert_object(_rect("M2-C")).is_equal(Rect2(88, 60, 44, 30))


func test_attack_direction_is_upward() -> void:
	# 同じレーンで、D1 → M1 → A2 と上へ進む
	assert_float(_rect("D1-R1").position.y).is_greater(_rect("M1-R1").position.y)
	assert_float(_rect("M1-R1").position.y).is_greater(_rect("A2-R1").position.y)
	assert_float(_rect("D1-R1").position.x).is_equal(_rect("A2-R1").position.x)
	# 左大外は右大外より左
	assert_float(_rect("M1-L2").position.x).is_less(_rect("M1-R2").position.x)


func test_show_counts_keeps_the_counts() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	pitch.show_counts({"D2-C": 2, "A1-C": 1})
	assert_dict(pitch.counts()).is_equal({"D2-C": 2, "A1-C": 1})


func test_show_turn_keeps_both_teams_the_ball_and_only_the_drawn_movements() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new(Vector2(64, 40))) as MiniPitch
	var press := Movement.new(GameEnums.TeamSide.AWAY, "a", PitchArea.from_key("M1-L1"), PitchArea.from_key("M1-C"),
			GameEnums.MovementReason.PRESS)
	var slide := Movement.new(GameEnums.TeamSide.HOME, "b", PitchArea.from_key("D2-C"), PitchArea.from_key("D2-L1"),
			GameEnums.MovementReason.SLIDE)
	var dribble := Movement.new(GameEnums.TeamSide.HOME, "c", PitchArea.from_key("M1-C"), PitchArea.from_key("M2-C"),
			GameEnums.MovementReason.DRIBBLE)
	# 動いていない動きは矢印にしない
	var still := Movement.new(GameEnums.TeamSide.HOME, "d", PitchArea.from_key("M2-C"), PitchArea.from_key("M2-C"),
			GameEnums.MovementReason.COVER)
	pitch.show_turn({"M2-C": 2}, {"M1-C": 1, "M2-C": 1}, [press, slide, dribble, still] as Array[Movement], "M2-C")
	assert_dict(pitch.counts()).is_equal({"M2-C": 2})
	assert_dict(pitch.opponent_counts()).is_equal({"M1-C": 1, "M2-C": 1})
	assert_str(pitch.ball_area()).is_equal("M2-C")
	assert_array(pitch.drawn_movements()).is_equal([press, dribble])
	assert_object(pitch.custom_minimum_size).is_equal(Vector2(320, 240))
	# 「自分−相手」。どちらも 0 のマスは空
	assert_str(pitch.count_text("M2-C")).is_equal("2−1")
	assert_str(pitch.count_text("M1-C")).is_equal("0−1")
	assert_str(pitch.count_text("D1-C")).is_empty()


func test_one_team_count_text_is_the_number_or_empty() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	pitch.show_counts({"D2-C": 2, "A1-C": 0})
	assert_str(pitch.count_text("D2-C")).is_equal("2")
	assert_str(pitch.count_text("A1-C")).is_empty()


func test_show_counts_after_a_turn_goes_back_to_one_team() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	pitch.show_turn({"M2-C": 2}, {"M1-C": 1}, [Movement.new(GameEnums.TeamSide.HOME, "c", PitchArea.from_key("M1-C"),
			PitchArea.from_key("M2-C"), GameEnums.MovementReason.DRIBBLE)] as Array[Movement], "M2-C")
	pitch.show_counts({"D2-C": 3})
	assert_dict(pitch.opponent_counts()).is_empty()
	assert_array(pitch.drawn_movements()).is_empty()
	assert_str(pitch.ball_area()).is_empty()


## 噛み合わせ（S-05）: 「自分−相手」に優劣記号（▲ 自分が多い・＝ 同数・▼ 少ない）を続ける。どちらも 0 のマスは空
func test_show_matchup_adds_the_superiority_mark() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new(Vector2(76, 40))) as MiniPitch
	pitch.show_matchup({"M2-C": 2, "M1-C": 1, "A2-C": 0}, {"M2-C": 1, "M1-C": 1, "D1-C": 1})
	assert_str(pitch.count_text("M2-C")).is_equal("2−1▲")
	assert_str(pitch.count_text("M1-C")).is_equal("1−1＝")
	assert_str(pitch.count_text("D1-C")).is_equal("0−1▼")
	assert_str(pitch.count_text("A2-C")).is_empty()
	assert_str(pitch.ball_area()).is_empty()
	assert_array(pitch.drawn_movements()).is_empty()


func test_show_turn_after_a_matchup_has_no_marks() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new(Vector2(76, 40))) as MiniPitch
	pitch.show_matchup({"M2-C": 2}, {"M2-C": 1})
	pitch.show_turn({"M2-C": 2}, {"M2-C": 1}, [] as Array[Movement], "")
	assert_str(pitch.count_text("M2-C")).is_equal("2−1")


func test_minimum_size_fits_five_by_six_cells_of_one_team() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	assert_object(pitch.custom_minimum_size).is_equal(Vector2(220, 180))
	assert_int(pitch.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

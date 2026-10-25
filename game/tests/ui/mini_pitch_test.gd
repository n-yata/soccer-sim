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
	pitch.show_counts({"D2-C": 2, "A1-C": 1}, false)
	assert_dict(pitch.counts()).is_equal({"D2-C": 2, "A1-C": 1})


func test_minimum_size_fits_five_by_six_cells_of_one_team() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	assert_object(pitch.custom_minimum_size).is_equal(Vector2(220, 180))
	assert_int(pitch.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

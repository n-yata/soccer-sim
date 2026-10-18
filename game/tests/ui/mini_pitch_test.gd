## MiniPitch（screen-common.md §5）のテスト。作戦ボードと同じ向き: 列 = ゾーン（D・M・A を左から）、行 = レーン（L2〜R2 を上から）。
extends GdUnitTestSuite

const CELL: Vector2 = Vector2(72, 36)


func _rect(key: String) -> Rect2:
	return MiniPitch.cell_rect(PitchArea.from_key(key), CELL)


func test_defense_left_wide_is_top_left() -> void:
	assert_object(_rect("D-L2")).is_equal(Rect2(0, 0, 72, 36))


func test_attack_right_wide_is_bottom_right() -> void:
	assert_object(_rect("A-R2")).is_equal(Rect2(144, 144, 72, 36))


func test_middle_center_is_in_the_middle() -> void:
	assert_object(_rect("M-C")).is_equal(Rect2(72, 72, 72, 36))


func test_attack_direction_is_to_the_right() -> void:
	# 同じレーンで、D → M → A と右へ進む
	assert_float(_rect("D-R1").position.x).is_less(_rect("M-R1").position.x)
	assert_float(_rect("M-R1").position.x).is_less(_rect("A-R1").position.x)
	assert_float(_rect("D-R1").position.y).is_equal(_rect("A-R1").position.y)


func test_show_counts_keeps_the_counts() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	pitch.show_counts({"D-C": 2, "A-C": 1}, false)
	assert_dict(pitch.counts()).is_equal({"D-C": 2, "A-C": 1})


func test_minimum_size_fits_three_by_five_cells_of_one_team() -> void:
	var pitch: MiniPitch = auto_free(MiniPitch.new()) as MiniPitch
	assert_object(pitch.custom_minimum_size).is_equal(Vector2(216, 180))
	assert_int(pitch.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

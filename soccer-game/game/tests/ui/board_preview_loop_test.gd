## BoardPreviewLoop（決定前のプレビューで、半透明の駒を配置から配置へ動かしてくり返す）のテスト。
## 位置の決め方は、区間と進み具合を直接置いて確かめる（Tween の時刻に頼らない）。くり返しは tactics_board_test で確かめる。
extends GdUnitTestSuite

const A0 := Vector2(0, 300)
const A1 := Vector2(0, 200)
const A2 := Vector2(0, 100)


## mover は 3つの配置で A0 → A1 → A2 と動き、still は動かない
func _loop() -> BoardPreviewLoop:
	var loop: BoardPreviewLoop = auto_free(BoardPreviewLoop.new()) as BoardPreviewLoop
	loop.load_centers({"mover": [A0, A1, A2], "still": [Vector2(50, 50), Vector2(50, 50), Vector2(50, 50)]})
	return loop


func test_only_the_players_who_move_somewhere_get_a_ghost() -> void:
	var loop: BoardPreviewLoop = _loop()
	assert_array(loop.ghost_ids()).contains_exactly(["mover"])
	# 2つ目の配置で動いて3つ目で戻る選手も、動くので入る
	loop.load_centers({"back": [A0, A1, A0], "still": [A0, A0, A0]})
	assert_array(loop.ghost_ids()).contains_exactly(["back"])


func test_a_ghost_eases_from_one_arrangement_to_the_next() -> void:
	var loop: BoardPreviewLoop = _loop()
	loop.segment = 0
	loop.progress = 0.0
	assert_vector(loop.ghost_position("mover")).is_equal(A0)
	loop.progress = 1.0
	assert_vector(loop.ghost_position("mover")).is_equal_approx(A1, Vector2(0.001, 0.001))
	# 途中は開示と同じイージング（等速より遅く出る）
	loop.progress = 0.2
	var moved: float = A0.y - loop.ghost_position("mover").y
	assert_float(moved).is_between(0.1, 19.9)
	# 2つ目の区間は A1 → A2
	loop.segment = 1
	loop.progress = 1.0
	assert_vector(loop.ghost_position("mover")).is_equal_approx(A2, Vector2(0.001, 0.001))


func test_one_arrangement_or_no_movers_shows_nothing() -> void:
	var loop: BoardPreviewLoop = auto_free(BoardPreviewLoop.new()) as BoardPreviewLoop
	loop.load_centers({"p1": [A0]})
	assert_array(loop.ghost_ids()).is_empty()
	loop.load_centers({})
	assert_array(loop.ghost_ids()).is_empty()
	loop.load_centers({"mover": [A0, A1]})
	loop.clear()
	assert_array(loop.ghost_ids()).is_empty()

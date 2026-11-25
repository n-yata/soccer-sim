## PieceSprites（作戦ボードの駒の 3D の絵）のテスト。3D の描画そのものは画面が要るのでスクリーンショットで確かめた。
## ここでは、色分け（縦じま・首の輪）・輪郭・画面の無い実行で平面のポーンに戻ることを確かめる。
extends GdUnitTestSuite

const TEAM: Color = Color(1, 0.541176, 0.239216)
const BODY_Y: float = 1.0


## 縦じまは相手の胴の正面側だけ。自分の胴には無い
func test_only_the_opponent_body_has_stripes_on_the_front() -> void:
	var stripe: Color = BoardPainter.stripe_color(TEAM)
	var on_stripe: float = asin(PieceSprites.STRIPE_CENTER)
	assert_object(PieceSprites.color_at(TEAM, false, BODY_Y, on_stripe)).is_equal(stripe)
	assert_object(PieceSprites.color_at(TEAM, false, BODY_Y, -on_stripe)).is_equal(stripe)
	assert_object(PieceSprites.color_at(TEAM, true, BODY_Y, on_stripe)).is_equal(TEAM)
	# 正面の真ん中（縦じまの間）と、背中側は胴の色
	assert_object(PieceSprites.color_at(TEAM, false, BODY_Y, 0.0)).is_equal(TEAM)
	assert_object(PieceSprites.color_at(TEAM, false, BODY_Y, PI - on_stripe)).is_equal(TEAM)
	# 台座の高さには縦じまを付けない
	assert_object(PieceSprites.color_at(TEAM, false, 0.2, on_stripe)).is_equal(TEAM)


## 首の輪は暗い色で、両チームとも同じ
func test_the_ring_is_dark_for_both_teams() -> void:
	var ring_y: float = (PieceSprites.RING_RANGE.x + PieceSprites.RING_RANGE.y) / 2.0
	for is_user: bool in [true, false]:
		assert_object(PieceSprites.color_at(TEAM, is_user, ring_y, 0.0)).is_equal(TEAM.darkened(0.45))


## 輪郭は台座の半径 1 から始まり、頭の球の上端（HEAD_Y + HEAD_RADIUS）で閉じる。台座より外へ広がらない
func test_the_profile_runs_from_the_base_to_the_top_of_the_head() -> void:
	var points: PackedVector2Array = PieceSprites.profile_points()
	assert_vector(points[1]).is_equal(Vector2(1.0, 0.0))
	var last: Vector2 = points[points.size() - 1]
	assert_float(last.x).is_equal_approx(0.0, 0.001)
	assert_float(last.y).is_equal_approx(PieceSprites.HEAD_Y + PieceSprites.HEAD_RADIUS, 0.001)
	for index: int in range(1, points.size()):
		assert_float(points[index].x).is_less_equal(1.0)
		assert_float(points[index].y).is_greater_equal(points[index - 1].y - 0.001)


## 画面の無い実行（このテスト。tools/run-tests.sh は headless で流す）では 3D の絵を作らない。texture_for は null を返し（BoardPainter は平面のポーンで描く）、
## 描く係はボードに1つだけ付く
func test_without_a_display_the_board_falls_back_to_the_flat_pawn() -> void:
	var board: TacticsBoard = auto_free(TacticsBoard.new()) as TacticsBoard
	add_child(board)
	assert_object(PieceSprites.texture_for(board, true)).is_null()
	assert_object(PieceSprites.texture_for(board, false)).is_null()
	await await_idle_frame()
	var attached: int = 0
	for child: Node in board.get_children():
		if child is PieceSprites:
			attached += 1
	assert_int(attached).is_equal(1)
	assert_object(PieceSprites.texture_for(board, true)).is_null()


## 描く係を付ける前にボードが木から外れても、木に戻れば次に描くときに付く（外れたまま印だけ残り、ずっと平面の駒になる、を防ぐ）
func test_a_board_that_left_the_tree_before_attaching_gets_the_sprites_when_it_returns() -> void:
	var board: TacticsBoard = auto_free(TacticsBoard.new()) as TacticsBoard
	add_child(board)
	assert_object(PieceSprites.texture_for(board, true)).is_null()
	remove_child(board)
	await await_idle_frame()
	assert_object(board.get_node_or_null(NodePath(PieceSprites.NODE_NAME))).is_null()
	add_child(board)
	assert_object(PieceSprites.texture_for(board, true)).is_null()
	await await_idle_frame()
	assert_object(board.get_node_or_null(NodePath(PieceSprites.NODE_NAME))).is_not_null()


## サッカーボールの模様: 12の五角形の中心は黒、隣り合う中心の間（六角形の上）は白。
## 黒の面積は球の約 28%（切頂二十面体。五角形の外接の角度は約 20°で、1枚およそ 0.29 sr × 12 / 4π）
func test_the_ball_has_twelve_black_pentagons_on_white() -> void:
	for center: Vector3 in PieceSprites.PENTAGON_CENTERS:
		assert_bool(PieceSprites.on_pentagon(center)).override_failure_message("中心 %s が白" % center).is_true()
	var a: Vector3 = PieceSprites.PENTAGON_CENTERS[0].normalized()
	var b: Vector3 = PieceSprites.PENTAGON_CENTERS[4].normalized()
	assert_float(rad_to_deg(a.angle_to(b))).is_equal_approx(rad_to_deg(PieceSprites.NEIGHBOR_ANGLE), 0.01)
	assert_bool(PieceSprites.on_pentagon(a + b)).is_false()
	var black: int = 0
	var samples: int = 0
	for i: int in range(-10, 11):
		for j: int in range(-10, 11):
			for k: int in range(-10, 11):
				var direction := Vector3(i, j, k)
				if direction.length() < 5.0 or direction.length() > 10.0:
					continue
				samples += 1
				if PieceSprites.on_pentagon(direction):
					black += 1
	assert_float(float(black) / samples).is_between(0.22, 0.34)


## 模様は、最初の五角形がボールの中心からカメラへの向きに来るよう回す（正面に黒い五角形が1枚見える）
func test_the_ball_shows_a_pentagon_to_the_camera() -> void:
	var pitch: float = deg_to_rad(PieceSprites.PITCH_DEGREES)
	var toward_camera := Vector3(0, sin(pitch), cos(pitch))
	var pattern: Vector3 = PieceSprites.ball_pattern_rotation().inverse() * toward_camera
	assert_bool(PieceSprites.on_pentagon(pattern)).is_true()
	assert_vector(pattern.normalized()).is_equal_approx(PieceSprites.PENTAGON_CENTERS[0].normalized(), Vector3(0.001, 0.001, 0.001))

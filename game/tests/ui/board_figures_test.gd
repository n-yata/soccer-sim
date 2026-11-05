## 作戦ボードの選手の駒とサッカーボールの形（BoardPainter.player_parts・ball_patches）のテスト。
## 描画はこの形をそのまま塗るので、形の性質をここで確かめる（色はテーマで決まる。見え方はスクリーンショットで確かめた）。
extends GdUnitTestSuite

const GROUND: Vector2 = Vector2(200, 300)
const R: float = 16.0


func _all_points(parts: Array[Dictionary], skip_shadow: bool = true) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for part: Dictionary in parts:
		if skip_shadow and part["role"] == &"shadow":
			continue
		points.append_array(part["points"] as PackedVector2Array)
	return points


func _parts_of(parts: Array[Dictionary], role: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for part: Dictionary in parts:
		if part["role"] == role:
			found.append(part)
	return found


## 影のほかの部品は、足元から左右に台座の半径（r）の内側にある（台座はチェスの駒の台座と同じ幅。
## 駒の間隔が詰まる狭い盤面では、隣の台座の縁が 1px ほど重なるのもチェスの駒のときと同じ。2026-11-06）
func test_every_part_but_the_shadow_stays_within_the_piece_radius() -> void:
	for is_user: bool in [true, false]:
		var points: PackedVector2Array = _all_points(BoardPainter.player_parts(GROUND, R, is_user, 0.0))
		assert_int(points.size()).is_greater(0)
		for point: Vector2 in points:
			assert_float(absf(point.x - GROUND.x)).override_failure_message("%s がはみ出す" % point).is_less_equal(R)


## 駒らしく、地面に丸い台座（base）を置き、その上に選手が立つ（2026-11-06。シャビ「少し人っぽくしすぎた。もう少しコマっぽく」）。
## 台座は足元を中心に、駒の半径いっぱいの幅。頭がいちばん上で、高さはチェスの駒（ビショップの先まで 約3.25r）と同じくらい。
## 腕・スパイクのような細かい部品は持たない
func test_the_player_stands_on_a_round_base_with_the_head_on_top() -> void:
	for is_user: bool in [true, false]:
		var parts: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, is_user, 0.0)
		var bases: Array[Dictionary] = _parts_of(parts, &"base")
		assert_int(bases.size()).is_equal(1)
		var base: PackedVector2Array = bases[0]["points"]
		var left: float = INF
		var right: float = -INF
		for point: Vector2 in base:
			left = minf(left, point.x)
			right = maxf(right, point.x)
		assert_float(left).is_equal_approx(GROUND.x - R, 0.001)
		assert_float(right).is_equal_approx(GROUND.x + R, 0.001)
		# 台座の側面（暗い色）は足元を中心に、下端が地面のすぐ下（台座の楕円の縦の半径 0.34r）にある。台座の上面は地面より上
		var side: PackedVector2Array = _parts_of(parts, &"base_side")[0]["points"]
		assert_float(_center(side).x).is_equal_approx(GROUND.x, 0.001)
		var side_bottom: float = -INF
		for point: Vector2 in side:
			side_bottom = maxf(side_bottom, point.y)
		assert_float(side_bottom).is_between(GROUND.y, GROUND.y + 0.4 * R)
		assert_float(_center(base).y).is_less(GROUND.y)
		# 影も含めて、足元から台座の半径より下へは出ない（tactics_board_test のレーン名の位置は、この前提で駒の下端を見積もる）
		for point: Vector2 in _all_points(parts, false):
			assert_float(point.y).override_failure_message("%s が足元より下に出すぎる" % point).is_less_equal(GROUND.y + R)
		for role: StringName in [&"sleeve", &"boot"]:
			assert_array(_parts_of(parts, role)).is_empty()
		var highest: float = INF
		for point: Vector2 in _all_points(parts):
			highest = minf(highest, point.y)
		assert_float(GROUND.y - highest).is_between(2.8 * R, 3.4 * R)
		var hair_top: float = INF
		for point: Vector2 in _all_points(_parts_of(parts, &"hair")):
			hair_top = minf(hair_top, point.y)
		assert_float(hair_top).is_equal_approx(highest, 0.001)


## 持ち上げると（開示の弾み）、影のほかの部品が r × lift だけ上がる。影は地面に残る
func test_lifting_raises_everything_but_the_shadow() -> void:
	var resting: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, true, 0.0)
	var lifted: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, true, 0.5)
	assert_int(lifted.size()).is_equal(resting.size())
	for index: int in range(resting.size()):
		var before: PackedVector2Array = resting[index]["points"]
		var after: PackedVector2Array = lifted[index]["points"]
		if resting[index]["role"] == &"shadow":
			# 影は浮くほど小さくなるが、中心は地面の位置のまま
			var before_center: Vector2 = _center(before)
			assert_vector(_center(after)).is_equal_approx(before_center, Vector2(0.001, 0.001))
			continue
		for point_index: int in range(before.size()):
			assert_vector(after[point_index]).is_equal_approx(before[point_index] + Vector2(0, -R * 0.5), Vector2(0.001, 0.001))


func _center(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point: Vector2 in points:
		sum += point
	return sum / points.size()


## 色だけでなく形でもチームを見分ける（NFR-20）: 相手だけユニフォームが縦じま。胸の印は自分が丸（●）、相手がひし形（◆）
func test_the_teams_differ_in_shape_not_only_in_color() -> void:
	var user: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, true, 0.0)
	var opponent: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, false, 0.0)
	assert_array(_parts_of(user, &"stripe")).is_empty()
	assert_int(_parts_of(opponent, &"stripe").size()).is_equal(2)
	var user_emblem: Array[Dictionary] = _parts_of(user, &"emblem")
	var opponent_emblem: Array[Dictionary] = _parts_of(opponent, &"emblem")
	assert_int(user_emblem.size()).is_equal(1)
	assert_int(opponent_emblem.size()).is_equal(1)
	assert_int((opponent_emblem[0]["points"] as PackedVector2Array).size()).is_equal(4)
	assert_int((user_emblem[0]["points"] as PackedVector2Array).size()).is_greater(8)
	# 縦じまは胴（ユニフォームの胴。袖は sleeve）の内側に描く
	assert_int(_parts_of(opponent, &"shirt").size()).is_equal(1)
	var shirt: PackedVector2Array = _parts_of(opponent, &"shirt")[0]["points"]
	for stripe: Dictionary in _parts_of(opponent, &"stripe"):
		for point: Vector2 in stripe["points"] as PackedVector2Array:
			assert_bool(Geometry2D.is_point_in_polygon(point, shirt) or _on_edge(point, shirt)).override_failure_message(
					"縦じまの %s が胴の外" % point).is_true()


func _on_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	for index: int in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 0.001:
			return true
	return false


## 部品の役割はすべて色の決め方が決まっていて、テーマの色を使う役割は、テーマにその色がある
## （色を付け忘れた役割は、チームの色で黙って塗られてしまうため）
func test_every_part_role_has_a_color() -> void:
	var board: TacticsBoard = auto_free(TacticsBoard.new()) as TacticsBoard
	add_child(board)
	var computed: Array[StringName] = [&"shadow", &"team", &"team_dark"]
	for is_user: bool in [true, false]:
		for part: Dictionary in BoardPainter.player_parts(GROUND, R, is_user, 0.0):
			var role: StringName = part["role"]
			assert_bool(BoardPainter.PLAYER_ROLE_COLORS.has(role)).override_failure_message("色の無い役割 %s" % role).is_true()
			var source: StringName = BoardPainter.PLAYER_ROLE_COLORS.get(role, &"")
			if not computed.has(source):
				assert_bool(board.has_theme_color(source, TacticsBoard.THEME_TYPE)).override_failure_message(
						"テーマに色が無い %s" % source).is_true()


## サッカーボールの模様は、中央の五角形と縁の5枚。どれもボールの円の内側（縁の5枚は円で切り取る）
func test_the_ball_has_a_center_pentagon_and_five_rim_patches_inside_the_ball() -> void:
	var center := Vector2(50, 60)
	var radius: float = 12.0
	var patches: Array[PackedVector2Array] = BoardPainter.ball_patches(center, radius)
	assert_int(patches.size()).is_equal(6)
	assert_int(patches[0].size()).is_equal(5)
	assert_vector(_center(patches[0])).is_equal_approx(center, Vector2(0.001, 0.001))
	for patch: PackedVector2Array in patches:
		assert_int(patch.size()).is_greater_equal(3)
		for point: Vector2 in patch:
			assert_float(point.distance_to(center)).is_less_equal(radius + 0.001)
	# 縁の5枚は縁に触れている（切り取られている）
	for index: int in range(1, patches.size()):
		var farthest: float = 0.0
		for point: Vector2 in patches[index]:
			farthest = maxf(farthest, point.distance_to(center))
		assert_float(farthest).is_greater(radius * 0.95)

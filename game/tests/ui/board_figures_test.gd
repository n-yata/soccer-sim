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


## チェスのポーンの形（2026-11-06。シャビが案A「ポーン型」を選んだ。人の形の選手は「人間ぽさが残りすぎ」だった）:
## 地面に丸い台座（base）、その上に台座より細い胴（shirt。ユニフォーム）、首の輪（ring）、いちばん上に丸い頭（head）。
## 台座は足元を中心に駒の半径いっぱいの幅。高さはチェスの駒と同じくらい。顔・髪・脚・パンツのような人の部品は持たない
func test_the_piece_is_a_pawn_on_a_round_base() -> void:
	for is_user: bool in [true, false]:
		var parts: Array[Dictionary] = BoardPainter.player_parts(GROUND, R, is_user, 0.0)
		for role: StringName in [&"skin", &"hair", &"sock", &"shorts", &"sleeve", &"boot", &"collar"]:
			assert_array(_parts_of(parts, role)).override_failure_message("人の部品 %s がある" % role).is_empty()
		var bases: Array[Dictionary] = _parts_of(parts, &"base")
		assert_int(bases.size()).is_equal(1)
		var base: PackedVector2Array = bases[0]["points"]
		assert_float(_left(base)).is_equal_approx(GROUND.x - R, 0.001)
		assert_float(_right(base)).is_equal_approx(GROUND.x + R, 0.001)
		assert_float(_center(base).y).is_less(GROUND.y)
		# 台座の側面（暗い色）は足元を中心に、下端が地面のすぐ下（台座の楕円の縦の半径）にある
		var side: PackedVector2Array = _parts_of(parts, &"base_side")[0]["points"]
		assert_float(_center(side).x).is_equal_approx(GROUND.x, 0.001)
		assert_float(_bottom(side)).is_between(GROUND.y, GROUND.y + 0.4 * R)
		# 胴は台座より細く、上へ行くほど細い（ポーンの形）
		var body: PackedVector2Array = _parts_of(parts, &"shirt")[0]["points"]
		assert_float(_right(body) - _left(body)).is_less(2.0 * R * 0.7)
		assert_int(_parts_of(parts, &"ring").size()).is_equal(1)
		# 頭は丸く（頂点の多い円）、駒のいちばん上にある
		var heads: Array[Dictionary] = _parts_of(parts, &"head")
		assert_int(heads.size()).is_equal(1)
		var head: PackedVector2Array = heads[0]["points"]
		assert_int(head.size()).is_greater(16)
		assert_float(_right(head) - _left(head)).is_less(_right(body) - _left(body) + 0.001)
		var highest: float = INF
		for point: Vector2 in _all_points(parts):
			highest = minf(highest, point.y)
		assert_float(_top(head)).is_equal_approx(highest, 0.001)
		assert_float(GROUND.y - highest).is_between(2.8 * R, 3.4 * R)
		# 影も含めて、足元から台座の半径より下へは出ない（tactics_board_test のレーン名の位置は、この前提で駒の下端を見積もる）
		for point: Vector2 in _all_points(parts, false):
			assert_float(point.y).override_failure_message("%s が足元より下に出すぎる" % point).is_less_equal(GROUND.y + R)


func _left(points: PackedVector2Array) -> float:
	var value: float = INF
	for point: Vector2 in points:
		value = minf(value, point.x)
	return value


func _right(points: PackedVector2Array) -> float:
	var value: float = -INF
	for point: Vector2 in points:
		value = maxf(value, point.x)
	return value


func _top(points: PackedVector2Array) -> float:
	var value: float = INF
	for point: Vector2 in points:
		value = minf(value, point.y)
	return value


func _bottom(points: PackedVector2Array) -> float:
	var value: float = -INF
	for point: Vector2 in points:
		value = maxf(value, point.y)
	return value


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
	# 縦じまは胴（ユニフォーム）の内側に描く
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
	var computed: Array[StringName] = [&"shadow", &"team", &"team_light", &"team_dark", &"team_stripe"]
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


func _luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value: float in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## 縦じまは胴と 3:1 以上の差がある（形で見分ける部品なので、グレースケールでも見える明るさの差。
## 図形のコントラストの目安は screen-common.md「ピッチと駒」と同じ。0.45 暗くした色では相手のオレンジで約 2.8:1 だった）
func test_the_stripes_stand_out_from_the_shirt() -> void:
	var board: TacticsBoard = auto_free(TacticsBoard.new()) as TacticsBoard
	add_child(board)
	for name: StringName in [&"you", &"opponent"]:
		var team: Color = board.get_theme_color(name, TacticsBoard.THEME_TYPE)
		assert_float(_contrast(team, BoardPainter.stripe_color(team))).override_failure_message("%s の縦じま" % name) \
				.is_greater_equal(3.0)


## 3D の駒の絵は、絵の台座が駒の半径 r に、台座の中心が足元に来るよう縮めて置く。弾みの分だけ上へずらす。
## 絵の下端は足元から r より下に出ない（tactics_board_test のレーン名の位置は、この前提で駒の下端を見積もる）
func test_the_piece_sprite_sits_on_the_feet_at_the_piece_size() -> void:
	var rect: Rect2 = BoardPainter.sprite_rect(GROUND, R, 0.0)
	var rate: float = rect.size.x / PieceSprites.TEXTURE_SIZE.x
	assert_float(PieceSprites.BASE_RADIUS_PX * rate).is_equal_approx(R, 0.001)
	assert_vector(rect.position + PieceSprites.FOOT_PX * rate).is_equal_approx(GROUND, Vector2(0.001, 0.001))
	assert_float(rect.end.y).is_less_equal(GROUND.y + R)
	var lifted: Rect2 = BoardPainter.sprite_rect(GROUND, R, 0.5)
	assert_vector(lifted.position).is_equal_approx(rect.position + Vector2(0, -R * 0.5), Vector2(0.001, 0.001))
	assert_vector(lifted.size).is_equal_approx(rect.size, Vector2(0.001, 0.001))

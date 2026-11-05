## BoardShift（開示の動きの状態）のうち、ボールの軌道（flight）の位置と高さのテスト。
## 進み具合を直接置いて確かめる（Tween の時刻に頼らない）。拍の順に動くことは tactics_board_test で確かめる。
extends GdUnitTestSuite

const Kind := BallFlight.Kind
const STYLE: Dictionary = {"loft": 6.0, "touch": 1.0, "touches": 3}
const FROM := Vector2(0, 100)
const TO := Vector2(0, 0)


func _shift(first_flight: int, second_ball: bool = true) -> BoardShift:
	var shift := BoardShift.new()
	shift.ball_style = STYLE
	var second_path: Dictionary = {"from": TO, "to": Vector2(50, 0)} if second_ball else {}
	# 2拍目は駒も1人動かす（ボールが動かない2拍目でも、拍が取り除かれずに残るように）
	var second_pieces: Array[Dictionary] = [{"player_id": "p1", "is_user": true, "from": TO, "to": Vector2(10, 0)}]
	shift.start([
		{"piece_paths": [] as Array[Dictionary], "ball_path": {"from": FROM, "to": TO, "flight": first_flight}, "sec": 1.0},
		{"piece_paths": second_pieces, "ball_path": second_path, "sec": 1.0},
	])
	return shift


func test_a_lofted_ball_rises_in_the_middle_of_its_beat() -> void:
	var shift: BoardShift = _shift(Kind.LOFTED)
	assert_float(shift.ball_lift()).is_equal_approx(0.0, 0.0001)
	shift.progress = 0.5
	assert_float(shift.ball_lift()).is_equal_approx(6.0, 0.0001)
	# 浮いても、地面の位置（影の位置）は道筋の上を等速で進む
	assert_vector(shift.ball_position(Vector2.ZERO)).is_equal_approx(FROM.lerp(TO, 0.5), Vector2(0.001, 0.001))


func test_a_ground_ball_is_ahead_of_an_even_pace() -> void:
	var shift: BoardShift = _shift(Kind.GROUND)
	shift.progress = 0.5
	assert_float(shift.ball_lift()).is_equal(0.0)
	var expected: Vector2 = FROM.lerp(TO, BallFlight.along(Kind.GROUND, 0.5))
	assert_vector(shift.ball_position(Vector2.ZERO)).is_equal_approx(expected, Vector2(0.001, 0.001))
	# 等速なら y = 50。グラウンダーは先へ進んでいる（y が小さい）
	assert_float(shift.ball_position(Vector2.ZERO).y).is_less(50.0)


func test_a_beat_without_a_flight_moves_straight_and_on_the_ground() -> void:
	var shift: BoardShift = _shift(Kind.LOFTED)
	shift.begin_beat(1)
	shift.progress = 0.5
	assert_float(shift.ball_lift()).is_equal(0.0)
	assert_vector(shift.ball_position(Vector2.ZERO)).is_equal_approx(TO.lerp(Vector2(50, 0), 0.5), Vector2(0.001, 0.001))


func test_the_ball_is_on_the_ground_when_it_does_not_move_in_this_beat() -> void:
	# 2拍目でボールが動かないとき、2拍目の間は高さ 0（1拍目の弧の途中の高さを残さない）
	var shift: BoardShift = _shift(Kind.LOFTED, false)
	assert_int(shift.beats.size()).is_equal(2)
	shift.progress = 0.5
	shift.begin_beat(1)
	shift.progress = 0.5
	assert_float(shift.ball_lift()).is_equal(0.0)
	shift.clear()
	assert_float(shift.ball_lift()).is_equal(0.0)


func test_a_carried_ball_bounces_with_the_style_set_on_the_shift() -> void:
	var shift: BoardShift = _shift(Kind.CARRIED)
	shift.progress = 0.5
	assert_float(shift.ball_lift()).is_equal_approx(1.0, 0.0001)
	shift.ball_style = {"loft": 6.0, "touch": 2.0, "touches": 2}
	assert_float(shift.ball_lift()).is_equal_approx(0.0, 0.0001)
	shift.progress = 0.25
	assert_float(shift.ball_lift()).is_equal_approx(2.0, 0.0001)


# --- 駒の進み方（イージング・ずらし・弾み） ---

const NEAR_FROM := Vector2(0, 100)
const NEAR_TO := Vector2(0, 0)
const FAR_FROM := Vector2(200, 100)
const FAR_TO := Vector2(200, 0)


## ボールに近い駒 near（order 0）と遠い駒 far（order 1）が動く1拍
func _piece_shift(stagger: float, hop: float) -> BoardShift:
	var shift := BoardShift.new()
	shift.piece_style = {"stagger": stagger, "hop": hop}
	var paths: Array[Dictionary] = [
		{"player_id": "near", "is_user": true, "from": NEAR_FROM, "to": NEAR_TO, "order": 0.0},
		{"player_id": "far", "is_user": true, "from": FAR_FROM, "to": FAR_TO, "order": 1.0},
	]
	shift.start([{"piece_paths": paths, "ball_path": {} as Dictionary, "sec": 1.0, "keyframe": 0}])
	return shift


func test_pieces_near_the_ball_start_first_and_all_arrive_together() -> void:
	var shift: BoardShift = _piece_shift(0.4, 0.0)
	shift.progress = 0.3
	# 遠い駒はまだ動き出していない。近い駒は道筋の途中
	assert_vector(shift.piece_position("far", Vector2.ZERO)).is_equal(FAR_FROM)
	var near_y: float = shift.piece_position("near", Vector2.ZERO).y
	assert_float(near_y).is_between(NEAR_TO.y + 0.1, NEAR_FROM.y - 0.1)
	shift.progress = 1.0
	assert_vector(shift.piece_position("near", Vector2.ZERO)).is_equal_approx(NEAR_TO, Vector2(0.001, 0.001))
	assert_vector(shift.piece_position("far", Vector2.ZERO)).is_equal_approx(FAR_TO, Vector2(0.001, 0.001))


func test_pieces_ease_in_and_out_along_their_path() -> void:
	var shift: BoardShift = _piece_shift(0.0, 0.0)
	# 等速なら 1/5 の時点で 20 進む。イージングでは出だしが遅い
	shift.progress = 0.2
	var moved: float = NEAR_FROM.y - shift.piece_position("near", Vector2.ZERO).y
	assert_float(moved).is_between(0.1, 19.9)
	# ずらしが無ければ、近い駒も遠い駒も同じだけ進む
	assert_float(FAR_FROM.y - shift.piece_position("far", Vector2.ZERO).y).is_equal_approx(moved, 0.001)


func test_moving_pieces_hop_and_land() -> void:
	var shift: BoardShift = _piece_shift(0.4, 0.35)
	assert_float(shift.piece_lift("near")).is_equal_approx(0.0, 0.0001)
	shift.progress = 0.3
	# 近い駒は道筋の真ん中（自分の進み具合 0.5）で、いちばん高い
	assert_float(shift.piece_lift("near")).is_equal_approx(0.35, 0.0001)
	# まだ動き出していない遠い駒と、道筋の無い駒は浮かない
	assert_float(shift.piece_lift("far")).is_equal(0.0)
	assert_float(shift.piece_lift("nobody")).is_equal(0.0)
	shift.progress = 1.0
	assert_float(shift.piece_lift("near")).is_equal_approx(0.0, 0.0001)
	shift.clear()
	assert_float(shift.piece_lift("near")).is_equal(0.0)


func test_build_beats_orders_the_pieces_by_distance_from_the_ball() -> void:
	# ボールは M2-C。p_near は同じエリア、p_mid は1つ下、p_far は3つ下から動く
	var center: Callable = func(key: String, _is_user: bool, _slot: int) -> Vector2: return _row_point(key)
	var start: Array[Dictionary] = [
		{"player_id": "p_far", "number": 0, "area": "D2-C"},
		{"player_id": "p_near", "number": 0, "area": "M2-C"},
		{"player_id": "p_mid", "number": 0, "area": "M1-C"},
	]
	var finish: Array[Dictionary] = [
		{"player_id": "p_far", "number": 0, "area": "D1-C"},
		{"player_id": "p_near", "number": 0, "area": "A1-C"},
		{"player_id": "p_mid", "number": 0, "area": "M2-C"},
	]
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": start, "opponent": no_players, "ball": "M2-C", "sec": 1.0},
	], {"user": finish, "opponent": no_players, "ball": "M2-C"}, center, _row_point)
	var orders: Dictionary = {}
	for path: Dictionary in beats[0]["piece_paths"] as Array:
		orders[path["player_id"]] = path["order"]
	assert_float(orders["p_near"] as float).is_equal(0.0)
	assert_float(orders["p_mid"] as float).is_equal(0.5)
	assert_float(orders["p_far"] as float).is_equal(1.0)


func test_pieces_at_the_same_distance_share_their_order() -> void:
	# ボールは M2-C。p_a と p_b は同じ M1-C から（同じ距離）、p_c は D2-C から動く
	var center: Callable = func(key: String, _is_user: bool, _slot: int) -> Vector2: return _row_point(key)
	var start: Array[Dictionary] = [
		{"player_id": "p_a", "number": 0, "area": "M1-C"},
		{"player_id": "p_b", "number": 0, "area": "M1-C"},
		{"player_id": "p_c", "number": 0, "area": "D2-C"},
	]
	var finish: Array[Dictionary] = [
		{"player_id": "p_a", "number": 0, "area": "M2-C"},
		{"player_id": "p_b", "number": 0, "area": "M2-C"},
		{"player_id": "p_c", "number": 0, "area": "M1-C"},
	]
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": start, "opponent": no_players, "ball": "M2-C", "sec": 1.0},
	], {"user": finish, "opponent": no_players, "ball": "M2-C"}, center, _row_point)
	var orders: Dictionary = {}
	for path: Dictionary in beats[0]["piece_paths"] as Array:
		orders[path["player_id"]] = path["order"]
	assert_float(orders["p_a"] as float).is_equal(0.0)
	assert_float(orders["p_b"] as float).is_equal(0.0)
	assert_float(orders["p_c"] as float).is_equal(1.0)


func test_no_order_is_given_when_the_ball_area_cannot_be_read() -> void:
	# 2人が別の距離から動いても、ボールのエリアが読めなければ距離を測れないので、全員遅れずに動く
	var center: Callable = func(key: String, _is_user: bool, _slot: int) -> Vector2: return _row_point(key)
	var start: Array[Dictionary] = [
		{"player_id": "p_a", "number": 0, "area": "M1-C"},
		{"player_id": "p_b", "number": 0, "area": "D1-C"},
	]
	var finish: Array[Dictionary] = [
		{"player_id": "p_a", "number": 0, "area": "M2-C"},
		{"player_id": "p_b", "number": 0, "area": "D2-C"},
	]
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": start, "opponent": no_players, "ball": "X-9", "sec": 1.0},
	], {"user": finish, "opponent": no_players, "ball": "X-9"}, center, _row_point)
	for path: Dictionary in beats[0]["piece_paths"] as Array:
		assert_float(path["order"] as float).override_failure_message(path["player_id"] as String).is_equal(0.0)


func test_a_single_moving_piece_has_no_delay() -> void:
	var center: Callable = func(key: String, _is_user: bool, _slot: int) -> Vector2: return _row_point(key)
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": [{"player_id": "p1", "number": 0, "area": "D2-C"}] as Array[Dictionary], "opponent": no_players,
				"ball": "X-9", "sec": 1.0},
	], {"user": [{"player_id": "p1", "number": 0, "area": "D1-C"}] as Array[Dictionary], "opponent": no_players,
			"ball": "X-9"}, center, _row_point)
	# 1人だけ・ボールが読めない拍は、順を 0 にする（遅れずに動く）
	assert_float((beats[0]["piece_paths"] as Array)[0]["order"] as float).is_equal(0.0)


## 列ごとに 100 ずつ下がる点（A2 が 0、D1 が 500）。レーンは C だけを使う
func _row_point(key: String) -> Vector2:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return Vector2(-1, -1)
	return Vector2(0, (PitchArea.ZONE_COUNT - 1 - area.zone) * 100.0)


func test_build_beats_puts_the_flight_of_a_keyframe_on_its_ball_path() -> void:
	var center: Callable = func(_key: String, _is_user: bool, _slot: int) -> Vector2: return Vector2.ZERO
	var ball_point: Callable = func(key: String) -> Vector2: return Vector2(0, 10) if key == "M2-C" else Vector2(0, 0)
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": no_players, "opponent": no_players, "ball": "M2-C", "sec": 1.0, "flight": Kind.LOFTED},
		{"user": no_players, "opponent": no_players, "ball": "A1-C", "sec": 1.0},
	], {"user": no_players, "opponent": no_players, "ball": "A2-C"}, center, ball_point)
	assert_int((beats[0]["ball_path"] as Dictionary)["flight"] as int).is_equal(Kind.LOFTED)
	# flight の無い keyframe の拍は、まっすぐ
	assert_int((beats[1]["ball_path"] as Dictionary).get("flight", Kind.STRAIGHT) as int).is_equal(Kind.STRAIGHT)


## エリアのキーごとに違う点を返す（どのエリアから・どのエリアへの道筋かを、点で見分ける）
func _point_of(key: String) -> Vector2:
	return {"M2-C": Vector2(0, 30), "A1-C": Vector2(0, 20), "A2-C": Vector2(0, 10)}.get(key, Vector2(-1, -1)) as Vector2


func test_build_beats_ends_the_last_beat_at_the_board_now() -> void:
	var center: Callable = func(key: String, _is_user: bool, _slot: int) -> Vector2: return _point_of(key)
	var start: Array[Dictionary] = [{"player_id": "p1", "number": 0, "area": "M2-C"}]
	var middle: Array[Dictionary] = [{"player_id": "p1", "number": 0, "area": "A1-C"}]
	var finish: Array[Dictionary] = [{"player_id": "p1", "number": 0, "area": "A2-C"}]
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": start, "opponent": no_players, "ball": "M2-C", "sec": 1.0},
		{"user": middle, "opponent": no_players, "ball": "A1-C", "sec": 1.0},
	], {"user": finish, "opponent": no_players, "ball": "A2-C"}, center, _point_of)
	# 1拍目は次の keyframe へ、最後の拍はいまの盤面（end）へ
	var first_piece: Dictionary = (beats[0]["piece_paths"] as Array)[0]
	var last_piece: Dictionary = (beats[1]["piece_paths"] as Array)[0]
	assert_vector(first_piece["to"] as Vector2).is_equal(_point_of("A1-C"))
	assert_vector(last_piece["from"] as Vector2).is_equal(_point_of("A1-C"))
	assert_vector(last_piece["to"] as Vector2).is_equal(_point_of("A2-C"))
	assert_vector((beats[1]["ball_path"] as Dictionary)["to"] as Vector2).is_equal(_point_of("A2-C"))


func test_build_beats_gives_no_ball_path_or_flight_when_the_ball_stays() -> void:
	var center: Callable = func(_key: String, _is_user: bool, _slot: int) -> Vector2: return Vector2.ZERO
	var no_players: Array[Dictionary] = []
	var beats: Array[Dictionary] = BoardShift.build_beats([
		{"user": no_players, "opponent": no_players, "ball": "A1-C", "sec": 1.0, "flight": Kind.LOFTED},
	], {"user": no_players, "opponent": no_players, "ball": "A1-C"}, center, _point_of)
	# 同じエリアならボールは動かない。軌道だけが残る道筋を作らない
	assert_dict(beats[0]["ball_path"] as Dictionary).is_empty()
	assert_array(BoardShift.build_beats([], {"user": no_players, "opponent": no_players, "ball": "A1-C"},
			center, _point_of)).is_empty()

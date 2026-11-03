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

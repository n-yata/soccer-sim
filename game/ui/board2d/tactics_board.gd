## 作戦ボード（screen-common.md §5 の TacticsBoard）。15エリアの盤面を描き、エリアを押す操作を受ける。
## ピッチを横に置き、利用者の攻撃方向は常に右（列は左から D・M・A、行は上から L2〜R2）。受け取るエリアは
## すべて利用者の視点のキー（BoardSnapshot・RevealView の値）で、ボードはエリアを変換しない。
## このクラスは、外から渡す値と状態・位置の計算・表示している値の問い合わせ・入力・開示の動きの Tween を持つ。
## 描画は BoardPainter、開示の動きの状態は BoardShift に分けた（2026-10-23。ファイルの目安 300 行を超えていたため）。
## 描画もテストも、同じ公開の問い合わせ（area_rect・pieces_in・drawn_movements など）を読むので、
## 「表示している値と描いている値が同じ」ことが保たれる。色はテーマの型 TacticsBoard。
class_name TacticsBoard
extends Control

## 選べるエリアを押して、同じエリアの中で離した
signal area_pressed(area_key: String)

const THEME_TYPE: StringName = &"TacticsBoard"
## 1エリアの最小の大きさ（screen-common.md §1.1。押せる範囲 48dp 以上）
const MIN_CELL: Vector2 = Vector2(192, 112)
## 駒の直径と中心の間隔の上限。セルの幅が狭いときは、1チーム MAX_PIECES 個がエリアの半分に収まるよう縮める
const PIECE_DIAMETER: float = 26.0
const PIECE_STEP: float = 28.0
## エリアの中央から最初の駒までの余白（自分と相手の駒の列を分ける）と、エリアの端に残す余白
const PIECE_CENTER_GAP: float = 6.0
const PIECE_EDGE_MARGIN: float = 2.0
## 1チームで描く駒の上限。これを超えると、駒を (上限 - 1) つと「+N」の札にする
const MAX_PIECES: int = 4
## 盤面に描く動き（ドリブル・寄せ・カバー）。方式の動きと、保持者の動き（戻る・置かれる）は描かない
const DRAWN_REASONS: Array[GameEnums.MovementReason] = [
	GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER, GameEnums.MovementReason.DRIBBLE,
]
const HINT_HEIGHT: float = 26.0
## ボールの中心のエリアの上端からの距離と半径（エリアの上側の中央。駒の列と札に重ならない位置）
const BALL_TOP_OFFSET: float = 22.0
const BALL_RADIUS: float = 11.0

var _user_players: Array[Dictionary] = []
var _opponent_players: Array[Dictionary] = []
var _ball_area: String = ""
var _selectable: Array[String] = []
var _selected: String = ""
var _hints: Dictionary = {}
var _even_hints: Array[String] = []
var _intent_from: String = ""
var _intent_to: String = ""
var _movements: Array[Movement] = []
var _preview: Array[Movement] = []
var _compare_area: String = ""
var _compare_tag: String = ""
var _pressed_key: String = ""
## 開示の動きの状態（道筋と進み具合）と、それを進める Tween
var _shift := BoardShift.new()
var _shift_tween: Tween


func _init() -> void:
	custom_minimum_size = MIN_CELL * Vector2(PitchArea.ZONE_COUNT, PitchArea.LANE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


# --- 外から渡す値 ---

func show_snapshot(snapshot: BoardSnapshot) -> void:
	_stop_shift()
	_user_players = snapshot.user_players.duplicate()
	_opponent_players = snapshot.opponent_players.duplicate()
	_ball_area = snapshot.ball_area
	queue_redraw()


## 押せるエリア（点線の枠）。これ以外のエリアは押しても反応しない。
func set_selectable(keys: Array[String]) -> void:
	_selectable = keys.duplicate()
	queue_redraw()


## 選んだエリア（塗り）。空文字で外す。
func set_selected(key: String) -> void:
	_selected = key
	queue_redraw()


## エリアのキー → ヒントの札の文（`+1`・`±0 GK外`）。even_keys は人数差が ±0 の札のキーで、控えめな色で描く。
## 札は選べるエリアにだけ描く。
func set_hints(hints: Dictionary, even_keys: Array[String] = []) -> void:
	_hints = hints.duplicate()
	_even_hints = even_keys.duplicate()
	queue_redraw()


## ボールから運ぶ先への矢印（選んだ手の意図）。
func show_intent(from_key: String, to_key: String) -> void:
	_intent_from = from_key
	_intent_to = to_key
	queue_redraw()


## 動いた選手の矢印（利用者の視点の Movement）。
func show_movements(movements: Array[Movement]) -> void:
	_movements = movements.duplicate()
	queue_redraw()


## 決定前のプレビュー: 選んだ手で動く自分の選手（利用者の視点の Movement）。移動先の輪と点線の矢印を描く。
## 開示後の矢印（show_movements）と違い、理由で絞らない（その手で起きる自分の動きをすべて見せる）。
func show_preview(movements: Array[Movement]) -> void:
	_preview = movements.duplicate()
	queue_redraw()


## 比較エリアの光と人数の札（`自分対相手`）。
func show_compare(key: String, user_count: int, opponent_count: int) -> void:
	_compare_area = key
	_compare_tag = "%d対%d" % [user_count, opponent_count]
	queue_redraw()


## 盤面（駒・記号・ボール）以外の重ね表示をすべて消す。
func clear_overlays() -> void:
	_stop_shift()
	_selectable.clear()
	_selected = ""
	_hints.clear()
	_even_hints.clear()
	_intent_from = ""
	_intent_to = ""
	_movements.clear()
	_preview.clear()
	_compare_area = ""
	_compare_tag = ""
	_pressed_key = ""
	queue_redraw()


## 開示で、動く前の配置（user_before・opponent_before。RevealView の判定前）から、いまの盤面（show_snapshot の後の
## 次のターン開始時の配置）へ、位置が変わった選手の駒を duration_sec 秒で動かす。ルールの動き（手・方式・保持者）を
## 区別せず全員を動かし、チーム全体がボールに合わせて動いていることを、矢印を増やさずに見せる。0 以下なら動かさない。
## ボールも、動く前のエリア（ball_before。空文字・読めないキーなら動かさない）から、いまのエリアへ一緒に動かす。
func start_shift(user_before: Array[Dictionary], opponent_before: Array[Dictionary], ball_before: String,
		duration_sec: float) -> void:
	_stop_shift()
	if not duration_sec > 0.0:
		return
	var piece_paths: Array[Dictionary] = BoardShift.paths(user_before, _user_players, true, slot_center)
	piece_paths.append_array(BoardShift.paths(opponent_before, _opponent_players, false, slot_center))
	var ball_path: Dictionary = {}
	if PitchArea.from_key(ball_before) != null and PitchArea.from_key(_ball_area) != null and ball_before != _ball_area:
		ball_path = {"from": _ball_point(ball_before), "to": _ball_point(_ball_area)}
	_shift.start(piece_paths, ball_path)
	if not _shift.is_active():
		return
	_shift_tween = create_tween()
	_shift_tween.tween_method(_set_shift_progress, 0.0, 1.0, duration_sec)
	_shift_tween.finished.connect(_stop_shift)


## 開示で駒かボールを動かしている途中か。
func is_shifting() -> bool:
	return _shift.is_active()


## 開示で駒を動かしている途中か（このときだけ、駒を選手ごとに描く。ボールだけが動くときは、いつもの描き方のまま）。
func is_shifting_pieces() -> bool:
	return not _shift.piece_paths.is_empty()


## 動かしている駒の道筋（{"player_id", "is_user", "from", "to"}）。描画とテストで共有する。動いていなければ空。
func shift_paths() -> Array[Dictionary]:
	return _shift.piece_paths.duplicate()


## 動かしているボールの道筋（{"from", "to"}）。描画とテストで共有する。ボールが動いていなければ空。
func shift_ball_path() -> Dictionary:
	return _shift.ball_path.duplicate()


## player_id の駒を描く位置。開示で動いていれば道筋の途中、そうでなければ rest（駒の列の位置）。
func shifting_piece_center(player_id: String, rest: Vector2) -> Vector2:
	return _shift.piece_position(player_id, rest)


func _set_shift_progress(progress: float) -> void:
	_shift.progress = progress
	queue_redraw()


## 動きを止め、いまの盤面の描き方（エリアごとの列と「+N」）に戻す。次の盤面・重ね表示の消去で呼ぶ（前のターンの動きを残さない）。
func _stop_shift() -> void:
	if _shift_tween != null:
		_shift_tween.kill()
		_shift_tween = null
	_shift.clear()
	queue_redraw()


# --- 位置の計算 ---

func cell_size() -> Vector2:
	return size / Vector2(PitchArea.ZONE_COUNT, PitchArea.LANE_COUNT)


func area_rect(key: String) -> Rect2:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return Rect2()
	var cell: Vector2 = cell_size()
	return Rect2(Vector2(area.zone * cell.x, area.lane * cell.y), cell)


## 位置のエリアのキー。盤面の外なら空文字。
func area_at(point: Vector2) -> String:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return ""
	var cell: Vector2 = cell_size()
	var zone: int = clampi(floori(point.x / cell.x), 0, PitchArea.ZONE_COUNT - 1)
	var lane: int = clampi(floori(point.y / cell.y), 0, PitchArea.LANE_COUNT - 1)
	return PitchArea.new(lane as GameEnums.Lane, zone as GameEnums.Zone).to_key()


# --- 表示している値（テストと描画で使う） ---

## エリアの背番号（小さい順）。{"user": [...], "opponent": [...]}
func pieces_in(key: String) -> Dictionary:
	return {"user": _numbers_in(_user_players, key), "opponent": _numbers_in(_opponent_players, key)}


## 描く駒の数（上限を超えたら上限 - 1 つと「+N」）。
func visible_piece_count(key: String, is_user: bool) -> int:
	var count: int = (pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	return count if count <= MAX_PIECES else MAX_PIECES - 1


## 「+N」の札。上限以内なら空。
func overflow_tag(key: String, is_user: bool) -> String:
	var count: int = (pieces_in(key)["user" if is_user else "opponent"] as Array).size()
	return "" if count <= MAX_PIECES else "+%d" % (count - visible_piece_count(key, is_user))


func ball_area() -> String:
	return _ball_area


## ボールを描く位置。開示で動いていれば道筋の途中、そうでなければいまのエリアの位置。
func ball_center() -> Vector2:
	return _shift.ball_position(_ball_point(_ball_area))


## エリアのボールの位置。エリアの上側の中央（駒の列と札に重ならない位置）。
func _ball_point(key: String) -> Vector2:
	var rect: Rect2 = area_rect(key)
	return Vector2(rect.get_center().x, rect.position.y + BALL_TOP_OFFSET)


## is_user のチームの選手（BoardSnapshot.user_players と同じ形）。
func players(is_user: bool) -> Array[Dictionary]:
	return (_user_players if is_user else _opponent_players).duplicate()


func selectable_areas() -> Array[String]:
	return _selectable.duplicate()


func selected_area() -> String:
	return _selected


func hint_of(key: String) -> String:
	return _hints.get(key, "") as String


func is_hint_even(key: String) -> bool:
	return _even_hints.has(key)


## 駒の中心の間隔（描画とテストで共有）。中央の余白から MAX_PIECES 個ぶんがエリアの半分に収まるよう、PIECE_STEP を上限に縮める。
func piece_step() -> float:
	var half_width: float = cell_size().x / 2.0
	return minf(PIECE_STEP, (half_width - PIECE_EDGE_MARGIN - PIECE_CENTER_GAP) / MAX_PIECES)


## 駒の半径。隣の駒と重ならないよう、間隔に合わせて縮める。
func piece_radius() -> float:
	return minf(PIECE_DIAMETER / 2.0, piece_step() / 2.0 - 1.0)


## index 番目の駒（上限を超えたときの「+N」の札の位置を含む）の中心。自分は中央から左へ、相手は中央から右へ並べる。
func piece_center(key: String, is_user: bool, index: int) -> Vector2:
	var rect: Rect2 = area_rect(key)
	var direction: float = -1.0 if is_user else 1.0
	var offset: float = PIECE_CENTER_GAP + piece_step() * (index + 0.5)
	return Vector2(rect.get_center().x + direction * offset, rect.get_center().y)


## エリアの駒の列の slot 番目の中心。列に収まらない添字（1エリアに5人以上）は最後の位置（MAX_PIECES - 1）で止める。
## プレビューの輪・開示で動かす駒の道筋と描画で共有する（止め方を1か所で決める）。
func slot_center(key: String, is_user: bool, slot: int) -> Vector2:
	return piece_center(key, is_user, mini(slot, MAX_PIECES - 1))


## 札を描くエリア（札があり、選べるエリア）。選べるエリアの順。
func drawn_hint_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in _selectable:
		if not hint_of(key).is_empty():
			keys.append(key)
	return keys


## 矢印を描く動き（DRAWN_REASONS の理由のものだけ。受け取った順）。
func drawn_movements() -> Array[Movement]:
	var result: Array[Movement] = []
	for movement: Movement in _movements:
		if movement.reason in DRAWN_REASONS:
			result.append(movement)
	return result


func preview_movements() -> Array[Movement]:
	return _preview.duplicate()


## index 番目のプレビューの移動先の輪の中心。移動先のエリアの自分の駒の列の続き（そのエリアの自分の駒の数 ＋
## 同じエリアへの先の輪の数）に置く。1エリアに5人以上が集まるのはまれなので、最後の位置（MAX_PIECES - 1）で止める。
func preview_center(index: int) -> Vector2:
	var key: String = _preview[index].to.to_key()
	var slot: int = (pieces_in(key)["user"] as Array).size()
	for earlier: int in range(index):
		if _preview[earlier].to.to_key() == key:
			slot += 1
	return slot_center(key, true, slot)


## index 番目のプレビューの矢印の始点。動く選手の駒（移動元のエリアの自分の駒の列で、盤面の選手の順の位置）の中心。
## 駒は番号を描かないが、矢印がどの ● から出るかが分かるよう、駒の上から引く。見つからなければエリアの中央。
func preview_origin(index: int) -> Vector2:
	var key: String = _preview[index].from.to_key()
	var slot: int = 0
	for player: Dictionary in _user_players:
		if player["area"] != key:
			continue
		if player["player_id"] == _preview[index].player_id:
			return slot_center(key, true, slot)
		slot += 1
	return area_rect(key).get_center()


func has_intent() -> bool:
	return not _intent_to.is_empty()


## 意図の矢印の両端 [ボールのエリア, 運ぶ先]。無ければ空。
func intent_keys() -> Array[String]:
	if _intent_from.is_empty() or _intent_to.is_empty():
		return []
	return [_intent_from, _intent_to]


func movement_count() -> int:
	return _movements.size()


func compare_area() -> String:
	return _compare_area


func compare_tag() -> String:
	return _compare_tag


# --- 入力 ---

## 押した位置のエリアを覚え、同じエリアの中で離したときだけ選んだとみなす（screen-common.md §4.1）。
func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_pressed_key = area_at(button.position)
		return
	var released_key: String = area_at(button.position)
	var pressed_key: String = _pressed_key
	_pressed_key = ""
	if released_key.is_empty() or released_key != pressed_key or not _selectable.has(released_key):
		return
	accept_event()
	area_pressed.emit(released_key)


# --- 描画 ---

func _draw() -> void:
	BoardPainter.paint(self)


static func _numbers_in(players: Array[Dictionary], key: String) -> Array[int]:
	var numbers: Array[int] = []
	for player: Dictionary in players:
		if player["area"] == key:
			numbers.append(player["number"] as int)
	numbers.sort()
	return numbers

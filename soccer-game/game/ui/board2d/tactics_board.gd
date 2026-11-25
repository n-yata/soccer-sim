## 作戦ボード（screen-common.md §5 の TacticsBoard）。30エリアの盤面（5レーン×6列）を描き、エリアを押す操作を受ける。
## ピッチを縦に置いて斜めから見せ、利用者の攻撃方向は常に上（レーンは左から L2〜R2、列は上から A2〜D1）。受け取るエリアは
## すべて利用者の視点のキー（BoardSnapshot・RevealView の値）で、ボードはエリアを変換しない。
## 位置（エリア・駒・ボール・道筋）は平面図（縦向きのピッチを真上から見た図）の座標で持ち、描くときと押した点を読むときに
## BoardProjection の写し方を通す（2026-10-23）。
## このクラスは、外から渡す値と状態・表示している値の問い合わせ・入力を持つ。
## 描画は BoardPainter、開示の動きの状態は BoardShift（進行と Tween は子ノードの BoardReveal）、遠近の写し方は BoardProjection に分けた（2026-10-23）。
## 平面図での位置の計算は BoardGeometry に分けた（2026-11-03）。ここには描画・テストが読む公開の面として中継だけを残す。
## 描画もテストも、同じ公開の問い合わせ（area_rect・pieces_in・drawn_movements など）を読むので、
## 「表示している値と描いている値が同じ」ことが保たれる。色はテーマの型 TacticsBoard。
class_name TacticsBoard
extends Control

## 選べるエリアを押して、同じエリアの中で離した
signal area_pressed(area_key: String)
## 開示の1拍目（プレー）が終わった（1拍目が無ければ start_shift の中ですぐ、途中で止めたらそのとき）。1回の開示で1回だけ
signal play_landed

const THEME_TYPE: StringName = &"TacticsBoard"
## 平面図での1エリアの最小の大きさ（screen-common.md §1.1）。画面でいちばん小さい奥の行でも、押せる範囲が 48dp（96px）
## 以上になる値（幅 136 × 奥の縮み 0.72 ≒ 98px。6列の高さは 100 × 6 = 600 で、上の余白 4% を除いて1行 96px。
## 行の高さは奥でも詰めない（BoardProjection.NEAR_WEIGHT = 1.0。2026-10-25）
const MIN_CELL: Vector2 = Vector2(136, 100)
## 1チームで描く駒の上限（BoardGeometry.MAX_PIECES。描画とテストが TacticsBoard の名前で読む）
const MAX_PIECES: int = BoardGeometry.MAX_PIECES
## 盤面に描く動き（ドリブル・スルーパスの走り込み・寄せ・カバー）。方式の動きと、保持者の動き（戻る・置かれる）は描かない
const DRAWN_REASONS: Array[GameEnums.MovementReason] = [
	GameEnums.MovementReason.PRESS, GameEnums.MovementReason.COVER, GameEnums.MovementReason.DRIBBLE,
	GameEnums.MovementReason.THROUGH_RUN,
]
const HINT_HEIGHT: float = 26.0
## 駒のずらしの幅を押さえる上限（拍の時間の割合。1 に近づくほど動く時間が無くなるので、1 より小さく置く）
const MAX_PIECE_STAGGER_SAFE: float = 0.95
## ボールの半径（BoardGeometry.BALL_RADIUS。描画が TacticsBoard の名前で読む）
const BALL_RADIUS: float = BoardGeometry.BALL_RADIUS

var _user_players: Array[Dictionary] = []
var _opponent_players: Array[Dictionary] = []
var _ball_area: String = ""
## 相手のオフサイドライン（利用者の視点の列。-1 なら描かない。BoardSnapshot.offside_line_zone）
var _offside_line_zone: int = -1
var _selectable: Array[String] = []
var _selected: String = ""
var _hints: Dictionary = {}
var _even_hints: Array[String] = []
var _intent_from: String = ""
var _intent_to: String = ""
var _movements: Array[Movement] = []
var _compare_area: String = ""
var _compare_tag: String = ""
## 振り返りの集計の札（エリアのキー → 「勝3 負1 膠1」）。選べるエリアに関係なく、札があるエリアにだけ描く
var _tally: Dictionary = {}
var _pressed_key: String = ""
## 開示の進行（拍の Tween・着地・結果の演出）。子ノード
var _reveal := BoardReveal.new()
## 決定前のプレビューのくり返し（子ノード）と、渡された配置の並び
var _preview_loop := BoardPreviewLoop.new()
var _preview_frames: Array = []

func _init() -> void:
	assert(BoardGeometry.PIECE_COLUMNS * BoardGeometry.PIECE_ROW_RATES.size() >= MAX_PIECES, "TacticsBoard: 駒の列 × 段が MAX_PIECES に足りない")
	custom_minimum_size = MIN_CELL * Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_reveal.name = "Reveal"
	add_child(_reveal)
	_reveal.landed.connect(play_landed.emit)
	_reveal.changed.connect(queue_redraw)
	_preview_loop.name = "PreviewLoop"
	add_child(_preview_loop)
	_preview_loop.changed.connect(queue_redraw)


# --- 外から渡す値 ---

func show_snapshot(snapshot: BoardSnapshot) -> void:
	_reveal.stop()
	_reveal.clear_effect()
	_clear_preview()
	_user_players = snapshot.user_players.duplicate()
	_opponent_players = snapshot.opponent_players.duplicate()
	_ball_area = snapshot.ball_area
	_offside_line_zone = snapshot.offside_line_zone
	queue_redraw()


## 押せるエリア（点線の枠）。これ以外のエリアは押しても反応しない。
func set_selectable(keys: Array[String]) -> void:
	_selectable = keys.duplicate()
	queue_redraw()


## 選んだエリア（塗り）。空文字で外す。
func set_selected(key: String) -> void:
	_selected = key
	queue_redraw()


## エリアのキー → ヒントの札の文（`+1`・`±0 カバーあり`）。even_keys は人数差が ±0 の札のキーで、控えめな色で描く。
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


## 決定前のプレビュー（2026-11-05）: 自分の選手の配置の並び frames（MatchController.user_preview_frames。ターン開始時・
## 次のターン開始時。2026-11-06 に1拍にした。各要素は BoardSnapshot.user_players と同じ形）を、半透明の駒で順に動かし、止めて最初へ戻すのをくり返す。
## どこかの配置で位置が変わる選手だけを動かし、その選手のもとの駒は描かない（動かない駒はその場）。空なら消す。
func show_preview_motion(frames: Array) -> void:
	_preview_frames = frames.duplicate(true)
	var centers: Dictionary = {}
	for frame: Array in frames:
		var players: Array[Dictionary] = []
		players.assign(frame)
		var slots: Array[int] = BoardShift.slots(players)
		for index: int in range(players.size()):
			var player_id: String = players[index]["player_id"] as String
			if not centers.has(player_id):
				centers[player_id] = []
			(centers[player_id] as Array).append(slot_center(players[index]["area"] as String, true, slots[index]))
	_preview_loop.load_centers(centers)


## 決定前のプレビューの時間 {"move_sec", "hold_sec"}（MatchController.preview_style()）。パネルが bind で入れる。
func set_preview_style(style: Dictionary) -> void:
	_preview_loop.set_style(style)


func _clear_preview() -> void:
	_preview_frames = []
	_preview_loop.clear()


## 比較エリアの光と人数の札（`自分対相手`）。
func show_compare(key: String, user_count: int, opponent_count: int) -> void:
	_compare_area = key
	_compare_tag = "%d対%d" % [user_count, opponent_count]
	queue_redraw()


## 振り返り（S-07）の集計の札（エリアのキー → 札の文。空の文のエリアは描かない）。駒・ボールは描かない盤面として使う
## （show_snapshot を呼ばなければ駒もボールも無い）。札はエリアの中央に描く。
func show_tally(tally: Dictionary) -> void:
	_tally = tally.duplicate()
	queue_redraw()


## 盤面（駒・記号・ボール）以外の重ね表示をすべて消す。
func clear_overlays() -> void:
	_reveal.stop()
	_reveal.clear_effect()
	_clear_preview()
	_selectable.clear()
	_selected = ""
	_hints.clear()
	_even_hints.clear()
	_intent_from = ""
	_intent_to = ""
	_movements.clear()
	_compare_area = ""
	_compare_tag = ""
	_tally.clear()
	_pressed_key = ""
	queue_redraw()


## 開示で、駒とボールを拍に分けて順に動かす。keyframes の各要素は、拍の始まりの配置とその拍の時間
## {"user": Array[Dictionary], "opponent": Array[Dictionary], "ball": String, "sec": float}（配置は BoardSnapshot.user_players と
## 同じ形、ボールはエリアのキー）。i 番目の拍は keyframes[i] から keyframes[i + 1] へ、最後の拍はいまの盤面
## （show_snapshot の後の次のターン開始時の配置）へ動く。開示では、ふつうは判定前だけを渡し、得点のときは判定時も渡す（MatchBoardPanel.reveal_keyframes。2026-11-06）。
## 各拍では、位置が変わった選手の駒を、ルールの動き（手・方式・保持者）を区別せず同時に動かす。ボールは、拍の始まりと
## 終わりのエリアが違うときだけ動かす（空文字・読めないキーなら動かさない）。動きの無い拍・時間が 0 以下の拍は飛ばす。
## result（ResultEffect.for_reveal の値。省略可）があれば、ボールの道筋を結果に合わせ（得点はゴールへ・膠着は跳ね返り）、
## 1拍目が終わったとき（play_landed）から結果の演出を出す。
## keyframe に "wait": true があれば、その拍の前で止まり、resume_shift で進む（得点のカットインの間。2026-11-06）。
func start_shift(keyframes: Array[Dictionary], result: Dictionary = {}) -> void:
	# 前の開示を止めてから、いまの盤面で拍を組む（止めたときの着地の受け手が盤面を書き換えても、新しい状態で組むため）
	_reveal.stop()
	_reveal.clear_effect()
	var end: Dictionary = {"user": _user_players, "opponent": _opponent_players, "ball": _ball_area}
	var beats: Array[Dictionary] = BoardShift.build_beats(keyframes, end, slot_center, _ball_point)
	ResultEffect.shape_ball_paths(beats, keyframes, result, _ball_area, _ball_point, goal_mouth)
	_reveal.start(beats, result)


## "wait" の拍の前で止めた開示を進める。止まる前に呼べば止まらない。開示中でなければ何もしない。
func resume_shift() -> void:
	_reveal.resume()


## 出している結果の演出（ResultEffect.for_reveal の値）。出していなければ空。
func result_effect() -> Dictionary:
	return _reveal.effect.duplicate()


## 結果の演出の進み具合（0〜1。描画が薄くするのに使う）。
func result_progress() -> float:
	return _reveal.effect_progress


## 結果の演出を出す時間（秒。MatchController.board_result_sec()）。パネルが bind で入れる。0 以下・有限でない値なら出さない。
func set_result_sec(sec: float) -> void:
	_reveal.set_result_sec(sec)


## 開示で駒かボールを動かしている途中か。
func is_shifting() -> bool:
	return _reveal.shift.is_active()


## 開示で、どれかの拍で駒が動くか（このときだけ、駒を選手ごとに描く。ボールだけが動くときは、いつもの描き方のまま）。
func is_shifting_pieces() -> bool:
	return _reveal.shift.has_pieces()


## 動かす拍の数（動きの無い拍は数えない）。動いていなければ 0。
func shift_beat_count() -> int:
	return _reveal.shift.beats.size()


## いま動かしている拍の添字（0 始まり）。
func shift_beat_index() -> int:
	return _reveal.shift.beat_index


## いまの拍で動かしている駒の道筋（{"player_id", "is_user", "from", "to"}）。描画とテストで共有する。動いていなければ空。
func shift_paths() -> Array[Dictionary]:
	return _reveal.shift.piece_paths_of(_reveal.shift.beat_index)


## いまの拍で動かしているボールの道筋（{"from", "to"}）。ボールが動いていなければ空。
func shift_ball_path() -> Dictionary:
	return _reveal.shift.ball_path_of(_reveal.shift.beat_index).duplicate()


## beat 番目の拍の駒の道筋。範囲外なら空。
func shift_beat_paths(beat: int) -> Array[Dictionary]:
	return _reveal.shift.piece_paths_of(beat)


## beat 番目の拍のボールの道筋。範囲外か、その拍でボールが動かなければ空。
func shift_beat_ball_path(beat: int) -> Dictionary:
	return _reveal.shift.ball_path_of(beat).duplicate()


## is_user 側の player_id の駒を描く位置。開示で動いていれば道筋の途中、後の拍で動くならその拍の始まり、そうでなければ rest（駒の列の位置）。
func shifting_piece_center(player_id: String, is_user: bool, rest: Vector2) -> Vector2:
	return _reveal.shift.piece_position(player_id, is_user, rest)


## is_user 側の player_id の駒の高さ（駒の半径の何倍か。開示で動いている間の弾み）。動いていなければ 0。
func shifting_piece_lift(player_id: String, is_user: bool) -> float:
	return _reveal.shift.piece_lift(player_id, is_user)


# --- 位置の計算（BoardGeometry。描画・テスト・ResultEffect が読む公開の面として残す） ---

## ゴールの四角（平面図）。is_top なら上（利用者が攻めるゴール）。描画とボールの行き先で共有する。
func goal_rect(is_top: bool) -> Rect2:
	return BoardGeometry.goal_rect(is_top, size)


## ゴールの口の中央（平面図）。得点のボールの行き先。
func goal_mouth(is_top: bool) -> Vector2:
	return goal_rect(is_top).get_center()


## 平面図での1エリアの大きさ（横 = レーン 5、縦 = 列 6）。
func cell_size() -> Vector2:
	return BoardGeometry.cell_size(size)


## エリアの平面図の矩形。レーンは左から L2〜R2、列は上から A2〜D1。読めないキーなら空の矩形。
func area_rect(key: String) -> Rect2:
	return BoardGeometry.area_rect(key, size)


## 平面図の点 → 画面の点。
func to_screen(plan: Vector2) -> Vector2:
	return BoardProjection.to_screen(plan, size)


## エリアの中央の画面の点（押す位置の目安。テストで使う）。
func screen_center(key: String) -> Vector2:
	return to_screen(area_rect(key).get_center())


## 画面の点（押した位置）のエリアのキー。平面図へ戻して引く。ピッチの外なら空文字。
func area_at(point: Vector2) -> String:
	return plan_area_at(BoardProjection.to_plan(point, size))


## 平面図の点のエリアのキー（BoardGeometry.plan_area_at）。ピッチの外なら空文字。
func plan_area_at(plan: Vector2) -> String:
	return BoardGeometry.plan_area_at(plan, size)


## 同じ段の駒の中心の間隔（BoardGeometry.piece_step）。描画とテストで共有する。
func piece_step() -> float:
	return BoardGeometry.piece_step(size)


## 駒の半径（BoardGeometry.piece_radius）。
func piece_radius() -> float:
	return BoardGeometry.piece_radius(size)


## index 番目の駒の平面図の中心（BoardGeometry.piece_center）。
func piece_center(key: String, is_user: bool, index: int) -> Vector2:
	return BoardGeometry.piece_center(key, is_user, index, size)


## エリアの駒の列の slot 番目の中心（BoardGeometry.slot_center。5人目以降は最後の位置で止める）。
func slot_center(key: String, is_user: bool, slot: int) -> Vector2:
	return BoardGeometry.slot_center(key, is_user, slot, size)


## エリアのボールの位置（BoardGeometry.ball_point。エリアの上側の中央）。
func _ball_point(key: String) -> Vector2:
	return BoardGeometry.ball_point(key, size)


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


func offside_line_zone() -> int:
	return _offside_line_zone


## オフサイドラインを描くか。ラインが敵陣ゴール前の列（いちばん前）なら誰もオフサイドにならず、線がゴールラインに重なる
## だけなので描かない。
func is_offside_line_drawn() -> bool:
	return _offside_line_zone >= 0 and _offside_line_zone < PitchArea.ZONE_COUNT - 1


## オフサイドラインを引く平面図の y。ラインの列の上端（相手ゴール側の境界。これより前の列の受け手がオフサイド）。
func offside_line_plan_y() -> float:
	return (PitchArea.ZONE_COUNT - 1 - _offside_line_zone) * cell_size().y


func ball_area() -> String:
	return _ball_area


## ボールを描く位置。開示で動いていれば道筋の途中、そうでなければいまのエリアの位置。
func ball_center() -> Vector2:
	return _reveal.shift.ball_position(_ball_point(_ball_area))


## ボールの高さ（ボールの半径の何倍か。開示の1拍目の浮き球・ドリブルの弾み）。動いていなければ 0。
func ball_lift() -> float:
	return _reveal.shift.ball_lift()


## 開示の1拍目のボールの軌道の値 {"loft", "touch", "touches"}（MatchController.ball_style()）。パネルが bind で入れる。
func set_ball_style(style: Dictionary) -> void:
	_reveal.shift.ball_style = style.duplicate()


## 開示で駒が動くときの値 {"stagger", "hop"}（MatchController.piece_style()）。パネルが bind で入れる。
## 有限でない値・負の値は 0（ずらし・弾みなし）として扱う（NaN だと駒の位置が壊れ、負の弾みは駒が沈み影の計算が 0 で割れ、
## 負のずらしは拍の終わりに駒が着かない）。ずらしは MAX_PIECE_STAGGER_SAFE 以下に押さえる（1 以上だと動く時間が残らない。
## 調整値の範囲の正本はデータ層の検査。ここは画面を壊さないための守り）。
func set_piece_style(style: Dictionary) -> void:
	var stagger: float = style.get("stagger", 0.0) as float
	var hop: float = style.get("hop", 0.0) as float
	_reveal.shift.piece_style = {
		"stagger": clampf(stagger, 0.0, MAX_PIECE_STAGGER_SAFE) if is_finite(stagger) else 0.0,
		"hop": maxf(hop, 0.0) if is_finite(hop) else 0.0,
	}


## 開示の拍と拍の間の小休止（秒。MatchController.board_beat_gap_sec()）。パネルが bind で入れる。
func set_beat_gap_sec(sec: float) -> void:
	_reveal.set_beat_gap_sec(sec)


## いま入れている拍と拍の間の小休止（秒。0 以下・有限でない値を入れたら 0）。
func beat_gap_sec() -> float:
	return _reveal.beat_gap_sec()


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


func tally_of(key: String) -> String:
	return _tally.get(key, "") as String


## 集計の札を描くエリア（札の文が空でないエリア。PitchArea.all() の順）。
func drawn_tally_keys() -> Array[String]:
	var keys: Array[String] = []
	for area: PitchArea in PitchArea.all():
		if not tally_of(area.to_key()).is_empty():
			keys.append(area.to_key())
	return keys


## 立っているもの（駒・プレビューの駒・ボール・「+N」の札）を、奥（平面図の上）から手前の順に並べたもの。描画とテストで
## 共有する（手前の駒が奥の駒に重なって描かれる）。各要素は {"kind": "piece" | "tag" | "ball", "plan": Vector2（足元）, ...}。
## 駒は "is_user"・"is_preview"、札は "text" を持つ。開示で動いている間は、駒を選手ごとに道筋の途中に置く。
func standing_order() -> Array[Dictionary]:
	var things: Array[Dictionary] = []
	if is_shifting_pieces():
		for is_user: bool in [true, false]:
			var team: Array[Dictionary] = players(is_user)
			var slots: Array[int] = BoardShift.slots(team)
			for index: int in range(team.size()):
				var rest: Vector2 = slot_center(team[index]["area"] as String, is_user, slots[index])
				things.append({"kind": "piece", "is_user": is_user, "is_preview": false,
						"plan": shifting_piece_center(team[index]["player_id"] as String, is_user, rest),
						"lift": shifting_piece_lift(team[index]["player_id"] as String, is_user)})
	else:
		for area: PitchArea in PitchArea.all():
			for is_user: bool in [true, false]:
				_append_area_pieces(things, area.to_key(), is_user)
	for player_id: String in _preview_loop.ghost_ids():
		things.append({"kind": "piece", "is_user": true, "is_preview": true, "plan": _preview_loop.ghost_position(player_id)})
	if not _ball_area.is_empty():
		things.append({"kind": "ball", "plan": ball_center(), "lift": ball_lift()})
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["plan"] as Vector2).y < (b["plan"] as Vector2).y)
	return things


## エリアの1チームの駒（上限を超えたら駒 (上限 - 1) つと「+N」の札）を things に足す。決定前のプレビューで半透明の駒に
## なっている自分の選手は、もとの位置に駒を残さない（見づらいというシャビの指摘。2026-11-05）。他の駒は並びの位置のまま。
func _append_area_pieces(things: Array[Dictionary], key: String, is_user: bool) -> void:
	var shown: int = visible_piece_count(key, is_user)
	var ghosts: Array[String] = []
	if is_user:
		ghosts = _preview_loop.ghost_ids()
	var ids: Array[String] = []
	for player: Dictionary in players(is_user):
		if player["area"] == key:
			ids.append(player["player_id"] as String)
	for index: int in range(shown):
		if ids[index] in ghosts:
			continue
		things.append({"kind": "piece", "is_user": is_user, "is_preview": false, "plan": piece_center(key, is_user, index)})
	var tag: String = overflow_tag(key, is_user)
	if not tag.is_empty():
		things.append({"kind": "tag", "text": tag, "plan": piece_center(key, is_user, shown)})


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


## 決定前のプレビューの配置の並び（show_preview_motion に渡したもの）。プレビューしていなければ空。
func preview_frames() -> Array:
	return _preview_frames.duplicate(true)


## 決定前のプレビューで、半透明の駒で動かしている選手。
func preview_ghost_ids() -> Array[String]:
	return _preview_loop.ghost_ids()


## player_id の半透明の駒のいまの位置（平面図）。
func preview_ghost_center(player_id: String) -> Vector2:
	return _preview_loop.ghost_position(player_id)


## 決定前のプレビューを動かしているか。
func is_previewing() -> bool:
	return _preview_loop.is_active()


## いま使っている決定前のプレビューの時間 {"move_sec", "hold_sec"}。
func preview_style() -> Dictionary:
	return _preview_loop.style()


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

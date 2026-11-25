## 作戦ボードの平面図（縦向きのピッチを真上から見た図）での位置の計算（screen-common.md §5 の TacticsBoard）。
## 盤面の大きさ size だけから決まる計算なので、状態を持たず、呼ぶたびに大きさを受け取る（大きさが変わっても古い値を持たない）。
## エリアは利用者の視点のキー。レーンは左から L2〜R2、列は上から A2〜D1（利用者は上へ攻める）。2026-11-03 に TacticsBoard から分けた。
class_name BoardGeometry
extends RefCounted

## ゴールの幅（盤面の幅の何倍か）と奥行き（平面図の px）
const GOAL_WIDTH_RATE: float = 0.16
const GOAL_DEPTH: float = 8.0
## 駒の直径と、同じ段の2つの駒の中心の間隔の上限。1チームは 2列×2段。セルの幅が狭いときは、エリアの半分に収まるよう縮める
const PIECE_DIAMETER: float = 26.0
const PIECE_STEP: float = 36.0
## 2段の駒の縦の位置（エリアの高さに対する割合。上側はボール、下端はヒントの札）
const PIECE_ROW_RATES: Array[float] = [0.50, 0.72]
## 1チームの駒の列の数（段の数とは別に持つ。列 × 段 が MAX_PIECES 以上であること）
const PIECE_COLUMNS: int = 2
## エリアの中央から最初の駒までの余白（自分と相手の駒の列を分ける）と、エリアの端に残す余白
const PIECE_CENTER_GAP: float = 6.0
const PIECE_EDGE_MARGIN: float = 2.0
## 1チームで描く駒の上限。これを超えると、駒を (上限 - 1) つと「+N」の札にする
const MAX_PIECES: int = 4
## ボールの位置（エリアの上側の中央。エリアの高さに対する割合。駒の段と札に重ならない位置）と半径
const BALL_TOP_RATE: float = 0.26
const BALL_RADIUS: float = 11.0


## 1エリアの大きさ（横 = レーン 5、縦 = 列 6）。
static func cell_size(size: Vector2) -> Vector2:
	return size / Vector2(PitchArea.LANE_COUNT, PitchArea.ZONE_COUNT)


## エリアの矩形。読めないキーなら空の矩形。
static func area_rect(key: String, size: Vector2) -> Rect2:
	var area: PitchArea = PitchArea.from_key(key)
	if area == null:
		return Rect2()
	var cell: Vector2 = cell_size(size)
	return Rect2(Vector2(area.lane * cell.x, (PitchArea.ZONE_COUNT - 1 - area.zone) * cell.y), cell)


## 点のエリアのキー。ピッチの外なら空文字。
static func plan_area_at(plan: Vector2, size: Vector2) -> String:
	if not Rect2(Vector2.ZERO, size).has_point(plan):
		return ""
	var cell: Vector2 = cell_size(size)
	var lane: int = clampi(floori(plan.x / cell.x), 0, PitchArea.LANE_COUNT - 1)
	var row: int = clampi(floori(plan.y / cell.y), 0, PitchArea.ZONE_COUNT - 1)
	return PitchArea.new(lane as GameEnums.Lane, (PitchArea.ZONE_COUNT - 1 - row) as GameEnums.Zone).to_key()


## ゴールの四角。is_top なら上（利用者が攻めるゴール）、そうでなければ下。描画とボールの行き先で共有する。
static func goal_rect(is_top: bool, size: Vector2) -> Rect2:
	var goal := Vector2(size.x * GOAL_WIDTH_RATE, GOAL_DEPTH)
	var y: float = 0.0 if is_top else size.y - goal.y
	return Rect2(Vector2((size.x - goal.x) / 2.0, y), goal)


## エリアのボールの位置。エリアの上側の中央（駒の段と札に重ならない位置）。
static func ball_point(key: String, size: Vector2) -> Vector2:
	var rect: Rect2 = area_rect(key, size)
	return Vector2(rect.get_center().x, rect.position.y + rect.size.y * BALL_TOP_RATE)


## 同じ段の駒の中心の間隔。中央の余白から2列ぶんがエリアの半分に収まるよう、PIECE_STEP を上限に縮める。
static func piece_step(size: Vector2) -> float:
	var half_width: float = cell_size(size).x / 2.0
	return minf(PIECE_STEP, (half_width - PIECE_EDGE_MARGIN - PIECE_CENTER_GAP) / PIECE_COLUMNS)


## 駒の半径（台座の大きさ）。同じ段の隣の駒と重ならないよう、間隔に合わせて縮める。
static func piece_radius(size: Vector2) -> float:
	return minf(PIECE_DIAMETER / 2.0, piece_step(size) / 2.0 - 1.0)


## index 番目の駒（上限を超えたときの「+N」の札の位置を含む）の中心。1チーム 2列×2段で、添字 0・1 が奥の段、
## 2・3 が手前の段。自分はエリアの中央から左へ、相手は中央から右へ並べる。
static func piece_center(key: String, is_user: bool, index: int, size: Vector2) -> Vector2:
	var rect: Rect2 = area_rect(key, size)
	var direction: float = -1.0 if is_user else 1.0
	var offset: float = PIECE_CENTER_GAP + piece_step(size) * (index % PIECE_COLUMNS + 0.5)
	var row_rate: float = PIECE_ROW_RATES[mini(floori(float(index) / PIECE_COLUMNS), PIECE_ROW_RATES.size() - 1)]
	return Vector2(rect.get_center().x + direction * offset, rect.position.y + rect.size.y * row_rate)


## エリアの駒の列の slot 番目の中心。列に収まらない添字（1エリアに5人以上）は最後の位置（MAX_PIECES - 1）で止める。
## プレビューの輪・開示で動かす駒の道筋と描画で共有する（止め方を1か所で決める）。
static func slot_center(key: String, is_user: bool, slot: int, size: Vector2) -> Vector2:
	return piece_center(key, is_user, mini(slot, MAX_PIECES - 1), size)

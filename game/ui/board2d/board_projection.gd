## 作戦ボードの遠近の写し方（screen-common.md §5 の TacticsBoard）。平面図（縦向きのピッチを真上から見た図。上が敵陣）と
## 画面（斜めから見た図。奥 = 上を狭く・縦を詰める）の間を写す。描画・押す操作・テストが同じ写し方を使う。
## 遠近の強さは見た目の定数（判定・バランスに関わらないので、設定ファイルには出さない）。
class_name BoardProjection
extends RefCounted

## 上の余白（ボードの高さに対する割合）。奥の白線と駒の頭が、ボードの上端で切れないため
const TOP_MARGIN_RATE: float = 0.04
## 奥（上端）の横の縮み。手前（下端）は 1.0（幅いっぱい）
const FAR_SCALE: float = 0.72
## 奥行きの詰め方。画面の深さ d = NEAR_WEIGHT × t + (1 − NEAR_WEIGHT) × t²（t は平面図の上からの割合）。
## 1.0 なら詰めない。小さいほど奥の行が低くなる
const NEAR_WEIGHT: float = 0.6


## 平面図の点 → 画面の点。平面図の縦・横の線は直線のまま写る（横の縮みが画面の y に比例するため）。
## 斜めの線は曲がるので、点ごとに写して描くこと。
static func to_screen(plan: Vector2, size: Vector2) -> Vector2:
	var t: float = plan.y / size.y
	var depth: float = NEAR_WEIGHT * t + (1.0 - NEAR_WEIGHT) * t * t
	var top: float = size.y * TOP_MARGIN_RATE
	var y: float = top + (size.y - top) * depth
	return Vector2(size.x / 2.0 + (plan.x - size.x / 2.0) * scale_at(y, size), y)


## 画面の点 → 平面図の点（to_screen の逆）。ピッチより大きく外れた点（上の余白よりさらに上）は、平面図の上の外へ写す。
static func to_plan(screen: Vector2, size: Vector2) -> Vector2:
	var top: float = size.y * TOP_MARGIN_RATE
	var depth: float = (screen.y - top) / (size.y - top)
	var far_weight: float = 1.0 - NEAR_WEIGHT
	var discriminant: float = NEAR_WEIGHT * NEAR_WEIGHT + 4.0 * far_weight * depth
	var t: float = -1.0 if discriminant < 0.0 else (-NEAR_WEIGHT + sqrt(discriminant)) / (2.0 * far_weight)
	var scale: float = scale_at(screen.y, size)
	return Vector2(size.x / 2.0 + (screen.x - size.x / 2.0) / scale, t * size.y)


## 画面の高さ screen_y での横の縮み（奥 FAR_SCALE 〜 手前 1.0）。駒・ボールの大きさにも使う。
static func scale_at(screen_y: float, size: Vector2) -> float:
	var top: float = size.y * TOP_MARGIN_RATE
	return lerpf(FAR_SCALE, 1.0, (screen_y - top) / (size.y - top))

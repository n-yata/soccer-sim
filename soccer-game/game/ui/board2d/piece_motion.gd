## 開示で駒が動くときの進み方と高さ（screen-common.md の TacticsBoard）。見せ方だけの計算で、静的関数だけ（2026-11-05）。
## 駒は、拍の中でボールに近い順に少しずつ遅れて動き出し（ずらし）、加速して減速して止まり（イージング）、動いている間は小さく浮く（弾み）。
class_name PieceMotion
extends RefCounted


## 拍の進み具合 progress（0〜1）のときの、駒の進み具合（0〜1）。order はずらしの順（0 = ボールにいちばん近い 〜 1 = いちばん遠い）、
## stagger はずらしの幅（拍の時間の何割を遅れに使うか）。駒は stagger × order だけ遅れて出て、拍の終わりにそろって着く。
static func local_t(progress: float, order: float, stagger: float) -> float:
	var span: float = 1.0 - stagger
	if span <= 0.0:
		return 1.0 if progress >= 1.0 else 0.0
	return clampf((progress - stagger * order) / span, 0.0, 1.0)


## 加速して減速して止まる進み方（smoothstep。0 と 1 で速さが 0）。組み込みの ease() と名前を分ける。
static func smooth(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 駒の進み具合 t のときの高さ（駒の半径の何倍か）。道筋の途中で一度浮き、始めと終わりは地面。
static func hop(t: float, height: float) -> float:
	return height * sin(PI * clampf(t, 0.0, 1.0))

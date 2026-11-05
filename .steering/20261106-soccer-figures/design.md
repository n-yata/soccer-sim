# 設計（20261106-soccer-figures）

## 形を関数にして、描画とテストで同じ形を使う
- `BoardPainter.player_parts(ground, r, is_user, lift) -> Array[Dictionary]`
  - 部品 `{"role", "points"}` を、奥から手前へ塗る順に返す。
  - 部品の役割: shadow・skin（膝・前腕・首・顔）・sock・boot・shorts・sleeve・shirt・stripe（相手だけ）・emblem・hair。
  - 寸法（r は台座の半径）: 高さ約 3.24r（髪の上端。いままでのビショップの先と同じくらい）、幅は ±0.9r（手の先）。
  - lift は、影のほかを r × lift だけ持ち上げる。影は地面に残り、1 / (1 + lift) に縮んで薄くなる（いままでと同じ）。
- `BoardPainter.ball_patches(center, r) -> Array[PackedVector2Array]`
  - 中央の五角形（半径 0.36r）と、縁の5枚（中心を 0.98r に置いた半径 0.34r の五角形を、ボールの円と `Geometry2D.intersect_polygons` で切り取る）。
- 色は役割ごとに `_player_color` が決める。
  - ユニフォーム・袖・ソックスはチームの色。パンツは暗く、縦じまは明るくする。
  - スパイク・胸の印は `bg`。
  - 肌・髪は、テーマに足した `TacticsBoard/colors/skin`・`hair` を使う。

## チームの見分け（NFR-20）
- 色: ユニフォーム（水色・オレンジ。いままでと同じ）。
- 形: 相手のユニフォームの縦じま2本と、胸の印（自分は丸・相手はひし形）。文字で使う ●・◆ と同じ印。

## 変えないもの
- 並べ方（2列×2段）、駒の台座の半径、「+N」の札の位置、プレビューの半透明（0.38）、ボールの大きさ・影・浮き方。

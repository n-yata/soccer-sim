# 設計

## 分け方

| ファイル | 責務 | 中身 |
|---|---|---|
| `tactics_board.gd`（`TacticsBoard`） | 外から渡す値と盤面の状態、入力、問い合わせ（描画とテストの共通の面）、子の取りまとめ | いまの公開の関数はすべて残す。位置の計算と開示の動きは、下の2つへ委ねる（1〜3 行の中継） |
| `board_geometry.gd`（`BoardGeometry`、新規、RefCounted） | 位置の計算（盤面の大きさだけから決まる） | 駒・ボール・ゴールの定数、`cell_size`・`area_rect`・`to_screen`・`screen_center`・`area_at`・`plan_area_at`・`goal_rect`・`goal_mouth`・`piece_step`・`piece_radius`・`piece_center`・`slot_center`・`ball_point`。大きさは呼ぶたびに渡す（ボードの大きさが変わっても古い値を持たない） |
| `board_reveal.gd`（`BoardReveal`、新規、Node。ボードの子） | 開示の動きと結果の演出の進行 | `BoardShift`・拍の Tween・着地・結果・演出の状態と Tween。`landed` と `changed`（描き直し）のシグナル。拍の組み立てに要る値（いまの盤面・位置の計算）は `start` の引数で受け取る |
| `result_effect_painter.gd`（`ResultEffectPainter`、新規、静的関数） | 結果の演出の描画 | `BoardPainter` から `_draw_result_effect`・`_draw_ring`・`_draw_flag` を移す |

- `BoardShift`（拍の状態と道筋の計算）・`ResultEffect`（区分と道筋の書き換え）・`BallFlight` はいまのまま。
- 定数（`BALL_RADIUS`・`MAX_PIECES`・`THEME_TYPE` など）を外から `TacticsBoard.X` で参照している箇所（painter・テスト・パネル）は、`TacticsBoard` に同じ名前で残す（`BoardGeometry` の定数を指す `const` にする）。

## なぜ子ノードにするか

Tween はノードが作る（`create_tween`）。開示の進行を RefCounted にすると Tween を外から渡す形になり、止める・作り直すの責任が2か所に分かれる。子ノードなら、進行と Tween を1か所に置ける。

## 確かめ方
- 先に分割だけを行い、既存のテストを**変更なしで**流す（tactics_board 53 件ほか）。
- 一時的なシーンで、分割の前後のスクリーンショット（キックオフの盤面・開示の途中・結果の演出）を撮って見比べる。

## 変更するドキュメント
- component-design.md（§5.3 の部品の分け方）・screen-common.md（TacticsBoard の部品の注記があれば）・repository-structure.md（board2d/ の説明）。

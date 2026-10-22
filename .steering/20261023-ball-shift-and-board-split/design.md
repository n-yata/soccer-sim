# 設計

## 分割（先に行い、動作を変えない）

| ファイル | 責務 |
|---|---|
| `tactics_board.gd`（`TacticsBoard`） | 外から渡す値と状態、位置の計算（エリア・駒の列）、表示している値の問い合わせ、入力、開示の動きの Tween。`_draw` は `BoardPainter.paint(self)` を呼ぶだけ |
| `board_painter.gd`（`BoardPainter`、新規） | 描画のすべて（ピッチ・塗り・線・レーン名・駒・ボール・動きの矢印・プレビュー・意図の矢印・札・比較）。静的関数で、ボード（CanvasItem）に描く。値はボードの公開の問い合わせだけから読む |
| `board_shift.gd`（`BoardShift`） | 開示の動きの状態（駒の道筋・ボールの道筋・進み具合）と、道筋の計算。いまの静的関数（`slots`・`paths`）に、状態を持つインスタンスの部分を足す |

- 描画が読む値は、ボードの公開の問い合わせにする。
  - いまある: `pieces_in`・`drawn_movements`・`preview_center` など。
  - 足すもの: 選手の一覧、意図の矢印の両端、比較エリア、駒の描く位置・ボールの描く位置。
- 「表示している値と描いている値が同じ」ことは、描画もテストも同じ問い合わせを通ることで保つ。
  - いままでのファイル冒頭の注記（描画を切り出さない理由）は、この形にしたので書き換える。

## ボールの動き
- `TacticsBoard.start_shift(user_before, opponent_before, ball_before: String, duration_sec)`。引数にボールの判定前の位置を足す。
- ボールの描く位置は `ball_center()`。
  - 止まっているときは、エリアの上側の中央（いまの位置）。
  - 動いているときは、判定前のエリアの上側の中央から、いまの位置へ補間する。
- `shift_ball_path() -> Dictionary`: 動いていれば `{"from": Vector2, "to": Vector2}`、そうでなければ空。テストと描画で共有する。
- 動いているか（`is_shifting()`）は、駒かボールのどちらかが動いていれば真。
- `MatchBoardPanel` は `reveal.ball_before` を渡す（利用者の視点のキー）。

## テスト
- `tactics_board_test`
  - ボールの道筋の元と先（エリアの上側の中央）。
  - 同じ位置なら道筋が空。
  - ボールだけが動く場合も動く。
  - 止まった後の `ball_center()` がいまの位置。
  - 既存の `start_shift` の呼び出しに、ボールの引数を足す。
- `match_board_panel_test`: 開示で、ボールの道筋の元と先が `RevealView.ball_before` と `BoardSnapshot.ball_area` に対応する。

## 変更するドキュメント
- screen-common.md（TacticsBoard の `start_shift`・ボール）
- screen-03-match.md（開示の呼び出し）
- component-design.md（§5.3 の注記と、部品の分け方）
- repository-structure.md（該当があれば）

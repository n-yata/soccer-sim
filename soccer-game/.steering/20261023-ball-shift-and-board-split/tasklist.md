# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 分割（動作を変えない）

- [x] 描画を `BoardPainter` へ、開示の動きの状態を `BoardShift` へ移す。ボードには公開の問い合わせを足す（分割の時点で tactics_board.gd 597→376 行、board_painter.gd 253 行、board_shift.gd 63 行。ボールの対応とレビューの修正の後は 399・253・81 行。足した問い合わせ: players・shifting_piece_center・ball_center・intent_keys・compare_area）
- [x] UI のテスト（tactics_board_test・match_board_panel_test ほか）が、変更なしで通る（tests/ui の 14 スイート 137 件）

## フェーズ2: ボールの動き

- [x] テストを書き、失敗することを確かめる（tactics_board_test・match_board_panel_test）（関数が無く、引数の数も合わず構文エラーで落ちた）
- [x] `start_shift` のボールの引数、`ball_center`・`shift_ball_path`、パネルのつなぎ込みを実装し、テストを通す（tests/ui の 141 件）
- [x] 一時的なシーンでスクリーンショット（動きの途中と動き終わり）を撮り、ボールが駒と一緒に動くこと、見た目が分割の前と変わらないことを確かめる（駒が動かずボールだけが中盤・中央から敵陣・中央へ動く場面を確認。ピッチ・駒・札・比較の見た目は分割の前と同じ。一時的なシーンは消した）

## フェーズ3: 仕様書の更新

- [x] screen-common.md・screen-03-match.md・component-design.md（と該当する記述）（repository-structure.md の board2d/ の説明は変更不要）

## フェーズ4: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）（499件・39スイート、失敗0、終了コード0）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（ボールの変異7個すべて検出、19秒。分割は動作を変えない変更で、既存のテストが変更なしで通ることで確かめた）
- [x] 実装レビュー（review-implementation。規約は全文を渡す）を行い、指摘を直す（opus、4.5/5、[必須] 0件。[推奨] 5件と [提案] 2件を直した。testing の規約は要旨）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（第1回で Critical / High 0、Medium 1・Low 5件。Medium と Low 3件を直し、2件は直さない理由を記した。500件）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

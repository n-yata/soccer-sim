# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 設定値

- [x] テストを書き、失敗することを確かめる（config_repository_test・match_controller_test）（クラスと関数が無く構文エラーで落ちた）
- [x] `PresentationConfig`・`presentation_config.tres`・`ConfigRepository.presentation()`・`MatchController.board_shift_sec()` を実装し、テストを通す（コントローラーは使うときに初めて読む。試合を進めるだけのテストに表示の設定ファイルを求めないため）

## フェーズ2: 駒の動き

- [x] テストを書き、失敗することを確かめる（tactics_board_test・match_board_panel_test）（関数が無く構文エラーで落ちた）
- [x] `TacticsBoard.start_shift`・`shift_paths` と描画、`MatchBoardPanel` のつなぎ込みを実装し、テストを通す（道筋の計算は `BoardShift`（board_shift.gd）に分けた。tactics_board.gd が目安の 300 行を超えていて、前の作業のレビューで分割を勧められたため）
- [x] 一時的なシーンでスクリーンショット（動きの途中と動き終わり）を撮り、重なりが無いことを確かめる（ゾーンのスライドで全員がボールの側へずれることを確認。動きの途中は両チームの駒がすれ違って重なるが、0.6 秒で、動き終わりは正しい列に並ぶ。一時的なシーンは消した）

## フェーズ3: 仕様書の更新

- [x] functional-overview.md・component-design.md・screen-03-match.md・screen-common.md（と該当する記述）（repository-structure.md の配置ファイルとディレクトリの説明も直した）

## フェーズ4: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）（493件・39スイート、失敗0、終了コード0）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（8個すべて検出、20秒。途中、変異スクリプトをヒアドキュメントの Python で作ってタブが化けた（7回目。対象のソースは無傷）→ Write ツールで書き直し、メモリに追記）
- [x] 実装レビュー（review-implementation。規約は全文を渡す）を行い、指摘を直す（opus、4.3/5、[必須] 0件。[推奨] 3件・[提案] 2件を直した。testing の規約は GDScript に該当しない例などを要旨にした）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（第1回で Critical / High / Medium 0、Low 3件。1件を直し、2件は既知の制約として記した。495件）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

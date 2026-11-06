# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）

---

## フェーズ1: オフサイド

- [x] テストを書き、失敗を確かめる（open_play_judge_test・transition_judge_test・move_hints_test・view_converter_test）（4件が落ちた）
- [x] OffsideRule・OpenPlayJudge・TransitionJudge・MoveHints・ViewConverter を直し、テストを通す（前のラインに頼っていた場面のテスト4件を、オンサイドになる場面に直した）

## フェーズ2: 試合準備の解説ポップアップ

- [x] テストを書き、失敗を確かめる（match_setup_screen_test）（NotesPopup が無く構文エラー）
- [x] 解説の欄を消し、「解説を見る」ボタンとポップアップ（NotesPopup）を置く。テストを通す（21件）

## フェーズ3: 1拍（team-preview のコミット後）

- [x] 開示を1拍にする（テスト先行。match_board_panel_test が拍の数で落ちた）
- [x] プレビューを1拍にする（テスト先行。move_preview_test・match_controller_test が配置の数で落ちた）

## フェーズ4: 仕様書・品質チェック・コミット

- [x] 仕様書を更新する（docs/specs 全体を検索し .drawio も見る）（usecase-sequences.drawio と wireframes.drawio も直した）
- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（1187 件成功・141 秒）
- [x] 変異で重要なテストが落ちることを確かめる（狙ったスイートだけ）（11件すべて検出。2件はバッチの中で隠れ、単独で検出）
- [x] シャビが遊んで判定する（OK）
- [x] コミット前レビュー（review-pre-commit）（2回で収束。Critical・High なし）
- [x] 振り返りを retrospective.md に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

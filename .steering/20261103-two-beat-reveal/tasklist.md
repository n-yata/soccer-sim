# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 調整値

- [x] テストを書き、失敗することを確かめる（config_repository_test・match_controller_test）（プロパティ・関数が無く構文エラーで落ちた）
- [x] `PresentationConfig.board_play_sec`・データ層の範囲の確認・`MatchController.board_play_sec()`・`presentation_config.tres` を実装し、テストを通す（2スイート 61 件）

## フェーズ2: 2拍の動き

- [x] テストを書き、失敗することを確かめる（tactics_board_test・match_board_panel_test）（関数が無く、start_shift の引数も合わず構文エラーで落ちた）
- [x] `BoardShift` を拍の並びにし、`TacticsBoard.start_shift` と Tween、描画の問い合わせを直す（start_shift は拍の始まりの配置の並び（keyframes）を受け取る形にした。shift_paths・shift_ball_path はいまの拍、shift_beat_* は拍ごと）
- [x] `MatchBoardPanel._on_turn_resolved` から判定時の配置と2つの長さを渡し、テストを通す（2スイート 62 件。並行セッションの新しいクラスでキャッシュが古く、取り込み直しが要った）
- [x] 一時的なシーンかゲームの実行でスクリーンショット（1拍目の途中・2拍目の途中・動き終わり）を撮り、2拍に分かれていることを確かめる（保持型・ショートパスの場面で、1拍目 9 人・2拍目 10 人が順に動いた。1拍目に相手のマンツーマンの MARK が 7 人入り、プレーが目立たない。シャビに判定を仰ぐ。一時的なシーンは消した）

## フェーズ3: 仕様書の更新

- [x] functional-overview.md・component-design.md・screen-design.md・screen-common.md・screen-03-match.md（docs/specs 全体を拡張子で絞らず検索し、.drawio も見る）（ほかに requirements-definition.md・glossary.md・architecture-overview.md・repository-structure.md・non-functional-requirements.md・usecase.md・usecase-sequences.drawio の 12 ファイル）

## フェーズ4: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）（全件を2回回し、1021件・1033件。どちらも、並行セッションの書き換え・実行と重なったスイートで失敗した（1回目は match_setup・main_shell・match_flow・match_menu、2回目は保存の finalize・suspend）。落ちたスイートは単独ではすべて通った（52件・37件）。この作業の4スイートは 123 件すべて通る）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（12個すべて検出、60秒）
- [x] シャビが遊んで、2拍の見え方を判定する（長さの調整があれば設定ファイルで直す）（2026-11-03「2拍でいいんじゃない」。3拍・薄く見せる案は採らない。長さは 0.6 秒ずつのまま）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（sonnet、4.6/5、[必須] 0件。[推奨] board_shift_sec の改名（board_settle_sec へ。MAX_BOARD_BEAT_SEC も）とパネルのテストの分岐の固定を直した。[提案] NaN の時間のテストと仕様書の古い注記への一言を足した。tactics_board.gd の行数（551 行）は次の作業の前に検討する積み残し、keyframe の型は呼び出し元が1か所なので見送り。規約は coding-gdscript・coding-common を要点で渡し、testing は要旨。4スイート 123 件）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（opus、第1回で Critical / High / Medium 0、Low 2件。2件とも直した）
- [x] 振り返りを `retrospective.md` に記録する
- [ ] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

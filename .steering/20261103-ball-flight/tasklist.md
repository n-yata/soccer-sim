# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 拍の組み立てを BoardShift へ移す（動作を変えない）

- [x] `TacticsBoard.start_shift` の拍の組み立てを `BoardShift.build_beats` へ移す。tactics_board のテストが変更なしで通る（2スイート 62 件。tactics_board.gd 551→528 行、board_shift.gd 129→157 行）

## フェーズ2: 調整値

- [x] テストを書き、失敗することを確かめる（config_repository_test・match_controller_test）（プロパティ・関数が無く構文エラーで落ちた）
- [x] `PresentationConfig` の3つの値・データ層の範囲の確認・`MatchController.ball_style()`・`presentation_config.tres` を実装し、テストを通す（2スイート 67 件。1回目は並行セッションの実行と重なったとみられる失敗が出て、流し直すと通った）

## フェーズ3: 軌道

- [x] テストを書き、失敗することを確かめる（ball_flight_test・tactics_board_test・match_board_panel_test）（board_shift_test も新しく作った。進み具合を直接置いて確かめるため。クラス・関数が無く構文エラーで落ちた）
- [x] `BallFlight` を実装する
- [x] `BoardShift` の flight・`ball_lift`、`TacticsBoard.set_ball_style`・`ball_lift`・`standing_order`、`BoardPainter` の持ち上げを実装する
- [x] `MatchBoardPanel` の bind と開示から渡し、テストを通す（4スイート 78 件）
- [x] 一時的なシーンでスクリーンショット（浮き球の頂点・グラウンダーの途中・ドリブルの途中）を撮り、見え方を確かめる（浮き球は影を地面に残して頂点で 6 倍の高さ。キックオフではロングボール・サイドチェンジを選べないので、盤面だけのシーンで撮った。ドリブルは高さ 0.7〜1.0 で弾み、グラウンダーは 0。一時的なシーンは消した）

## フェーズ4: 仕様書の更新

- [x] functional-overview.md・component-design.md・screen-common.md・screen-03-match.md・screen-design.md（docs/specs 全体を検索し .drawio も見る）（ほかに repository-structure.md。drawio・glossary は変更不要）

## フェーズ5: 品質チェックとコミット

- [x] ~~`bash tools/run-tests.sh` が成功する~~（シャビの判断で省いた（2026-11-03「こっちはテスト不要。コミットに進めて」）。1回目は3分を超えて止め、短縮は並行セッションが進めている。この作業の関係スイート（ball_flight・board_shift・tactics_board・match_board_panel・config_repository・match_controller）は通り、変異20個はすべて検出）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（18個。1回目は描くボールの高さを 0 にする変異が残った（高さを動き始めにしか確かめていなかった）。浮いている途中で確かめる形に直し、18個すべて検出。59秒＋9秒）
- [x] シャビが遊んで、軌道の見え方を判定する（高さ・回数の調整があれば設定ファイルで直す）（2026-11-03「いいね。進めて。」。値は初期値のまま）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（sonnet、4.4/5、[必須] 0件。[推奨]1 ボールと駒の位置の決め方を `_point_on` の1か所にまとめた、[推奨]2 build_beats の最後の拍・ボールが動かない拍・空の keyframes のテストを足した。[推奨]3 時間に頼るテスト（500ms 待ち・拍 1.0 秒）は余裕が2倍あるので見送り。[提案] NaN の進み具合（Tween 由来で外部データではない）と浮き球の頂点のはみ出し（シャビが遊んで確認済み）は対応不要。4スイート 80 件）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（opus、第1回で Critical / High 0、Medium 1・Low 4。M-1（bind で高さを渡すテスト）と L-1 を直し、変異で確かめた。L-3 は全体テスト待ち、L-2・L-4 は見た目だけで積み残し）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする。前の作業の tasklist.md の最後のチェックも一緒に入れる）（共有の4ファイルは HEAD に hunk を当てた内容をインデックスへ入れた。前のコミットでずれた component-design.md の注記も正しい位置へ移した）

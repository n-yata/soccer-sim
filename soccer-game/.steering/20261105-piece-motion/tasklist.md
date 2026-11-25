# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 調整値

- [x] テストを書き、失敗することを確かめる（config_repository_test・match_controller_test）（プロパティが無く構文エラーで落ちた）
- [x] `PresentationConfig` の3つの値・データ層の範囲・`MatchController.piece_style()`・`board_beat_gap_sec()`・`.tres` を実装し、テストを通す（2スイート 77 件）

## フェーズ2: 駒の進み方

- [x] テストを書き、失敗することを確かめる（piece_motion_test・board_shift_test）（クラスが無く構文エラーで落ちた。組み込みの ease() と名前がぶつかるので smooth にした）
- [x] `PieceMotion`、`BoardShift` の order・piece_style・piece_position・piece_lift を実装し、テストを通す（piece_motion・board_shift・tactics_board の3スイート 74 件）

## フェーズ3: ボード・描画・パネル

- [x] テストを書き、失敗することを確かめる（tactics_board_test・match_board_panel_test）（tactics_board_test は関数が無く構文エラーで落ちた。match_board_panel_test は、パネルを別セッションが書き換え中なので、bind の2行と一緒に後で足す）
- [x] `BoardReveal` の小休止、`TacticsBoard` の set_piece_style・set_beat_gap_sec・shifting_piece_lift・standing_order、`BoardPainter` の持ち上げ、パネルの bind を実装し、テストを通す（ボードまわり 76 件。パネルの bind の2行は別セッションのコミット c82fe7f の後に足し、panel のテスト（先に落ちることを確かめた）を含めて 24 件。screen-03-match.md の bind の記述も足した）
- [x] 一時的なシーンでスクリーンショット（2拍目の途中でずらしと弾みが分かる場面）を撮り、見え方を確かめる（前線が先に詰め、最終ラインが遅れて追う。動いている駒は浮いて影が足元に残る。一時的なシーンは消した）

## フェーズ4: 仕様書の更新

- [x] functional-overview.md・component-design.md・screen-common.md・screen-design.md・repository-structure.md（docs/specs 全体を検索し .drawio も見る）（drawio のラベルは引数の並びだけで変更不要。パネルの bind の2行は別セッションのコミット待ちなので、screen-03-match.md の bind の記述はその2行と一緒に足す）

## フェーズ5: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（3分を超えたら失敗として止め、シャビに報告する）（2026-11-05 の1回目: 120 秒で終わり、落ちたのは CLOSE_DOWN のテスト（open_play_judge_test・match_rules_test）だけ。別セッションが「ドリブルのコースを切る」へ作り替え中の部分。向こうのコミットの後に流し直す）。2回目は 81 スイート 1146 件・失敗 0・127 秒
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（12個すべて検出、44秒）
- [x] シャビが遊んで、手触りを判定する（2026-11-05「OK。進めて」。値は初期値のまま）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（sonnet、4/5、[必須] 0件。同じ距離の駒を同じずらしの順にした、パネルのテストの小休止を時間待ちでなく値で確かめる形にした（TacticsBoard.beat_gap_sec を足した）、ずらしの幅 1 以上・小休止の悪い値・最後の拍の後に小休止を置かない・駒の値の NaN のテストを足した、set_piece_style で有限でない値を 0 にした、design.md の関数名を smooth に直した。4スイート 104 件）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（opus、第1回で Critical / High / Medium 0、Low 3。L1（負の値・範囲外の駒の値）はテストを先に足して直した、L2（ボールが読めない拍の順のテストの空振り）はテストを足した。L3（実時間待ち）は余裕があるので記録だけ）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）（別セッションの「ドリブルのコースを切る」と混ざった4ファイルは、自分の hunk を名指しで HEAD に当ててインデックスへ入れた）

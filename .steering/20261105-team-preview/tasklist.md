# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: ドメイン

- [x] テストを書き、失敗することを確かめる（move_preview_test・match_rules_test）（関数が無く構文エラーで落ちた。preview_next が resolve_turn と同じ次の状態を作るテストは move_preview_test に置いた）
- [x] `MatchRules.preview_next`（resolve_turn もこれを使う）と `MovePreview.team_steps` を実装し、テストを通す（共有部分は `_apply_judged` に切り出した。2スイート 79 件）

## フェーズ2: アプリケーションと調整値

- [x] テストを書き、失敗することを確かめる（match_controller_test・config_repository_test）（プロパティ・関数が無く構文エラーで落ちた）
- [x] `ViewConverter.user_players_of`・`MatchController.user_preview_frames`・`preview_style`、`PresentationConfig` の2つの値を実装し、テストを通す（2スイート 81 件）

## フェーズ3: ボードとパネル

- [x] テストを書き、失敗することを確かめる（board_preview_loop_test・tactics_board_test・match_board_panel_test）（**Red を流して確かめずに実装へ進んでしまった**。関数・クラスが無いので構文エラーになる状態だった。Red の代わりは変異で確かめる）
- [x] `BoardPreviewLoop`・`TacticsBoard.show_preview_motion`・描画を実装し、`show_preview`（矢印と静止した半透明の駒）を消す。パネルをつなぎ替え、テストを通す（3スイート 86 件。painter の点線の曲線の矢印も消した）
- [x] 一時的なシーンでスクリーンショット（プレビューの途中）を撮り、見え方を確かめる（キックオフのショートパスで、自分の駒 9 人が半透明で動き、パスの後に全体が押し上げた位置まで進む。いまの駒はその場に残る。一時的なシーンは消した）

## フェーズ4: 仕様書の更新

- [x] functional-overview.md・component-design.md・screen-common.md・screen-03-match.md・screen-design.md・repository-structure.md（docs/specs 全体を検索し .drawio も見る）（drawio にプレビューの記述は無い）

## フェーズ5: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` を timeout 180 秒で流す（3分を超えたら失敗として止め、シャビに報告する）（1158 件成功・127 秒）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）（19 件中 10 件が落ち、残りは穴が5件（止める時間・くり返し・動く時間の検証・オフサイド・パネルからの時間）、同じ挙動が4件（配置1つの条件は消した・守備の代わりの手・決定時の消去・is_finite）。穴を埋めて再実行し、5件とも落ちた）
- [x] シャビが遊んで判定する（「動いて戻るの駒が、もとの駒と重なって見づらい」→ 動く選手のもとの駒を描かない。「開示で自分と相手の駒が重なって動く」→ 開示の道筋を自分・相手の別と id の組で探す（630fe05 より前からのバグ）。別セッションの報告で、自分で運ぶカウンターの膠着で運んだ選手を戻す（シャビ「直して」）。直した後「バグはなくなった」）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（review-report.md）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（指摘なし）
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

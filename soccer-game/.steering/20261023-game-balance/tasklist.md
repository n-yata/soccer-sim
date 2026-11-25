# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 判定のルール

- [x] テストを書き、失敗することを確かめる（open_play_judge_test の新しい規則・読みの有無・GK のカバーが無いこと。transition_judge_test のカウンターの同数）
- [x] `JudgeDetail.is_read`、`OpenPlayJudge` の判定とカバーの判定、`CoverKind` から GK を外すことを実装し、既存のテストの期待値を新しい規則に合わせて、テストを通す

## フェーズ2: CPU の評価値

- [x] テストを書き、失敗することを確かめる（cpu_planner_test の goal_bonus・config_repository_test の forward_bonus / shot_bonus）
- [x] `CpuConfig.forward_bonus` / `shot_bonus`、`CpuPlanner.goal_bonus`、`ConfigRepository` の検査を実装し、テストを通す

## フェーズ3: 表示

- [x] テストを書き、失敗することを確かめる（judge_reason_formatter_test の「読まれて」、match_texts_test のカバーの表記、view_converter_test の is_read）
- [x] `RevealView.is_read`・`ViewConverter`・`JudgeReasonFormatter`・`MatchTexts.cover_short` を直し、テストを通す

## フェーズ4: 計測と初期値

- [x] 計測のテスト（match_balance_test と MatchBalanceProbe）を書く
- [x] 初期値（forward_bonus・shot_bonus）を計測で決めて `cpu_config.tres` に入れ、計測のテストを通す

## フェーズ5: 仕様書の更新

- [x] functional-overview.md（アルゴリズム5・8、判定例、設定値、表示仕様）・glossary.md・component-design.md・screen-03-match.md ほか（.drawio を含めて検索する）

## フェーズ6: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）
- [x] 実装レビュー（review-implementation。規約は全文を渡す）を行い、指摘を直す
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

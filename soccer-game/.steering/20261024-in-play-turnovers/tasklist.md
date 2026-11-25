# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 読みの段階（判定）

- [x] テストを書き、失敗することを確かめる（open_play_judge_test の隣の読み・段階の境界、judge_values_test の read）
- [x] `GameEnums.ReadKind`・`JudgeDetail.read`（is_read を置き換え）・`OpenPlayJudge.read_of` と `outcome_of` を実装し、呼び出し側を直してテストを通す

## フェーズ2: CPU の先読み

- [x] テストを書き、失敗することを確かめる（cpu_planner_test の守備の加点、config_repository_test の anticipation_bonus）
- [x] `CpuConfig.anticipation_bonus`・`CpuPlanner.situation_bonus`（goal_bonus を改名）・`ConfigRepository` の検査を実装し、テストを通す

## フェーズ3: 表示

- [x] テストを書き、失敗することを確かめる（judge_reason_formatter_test の隣の読み、view_converter_test の read）
- [x] `RevealView.read`・`ViewConverter`・`JudgeReasonFormatter` を直し、テストを通す

## フェーズ4: 計測と初期値

- [x] `MatchBalanceProbe` を複数シードに対応させ、`match_balance_test` をプレー中の入れ替わりで判定する形にする
- [x] 初期値（anticipation_bonus・forward_bonus・shot_bonus）を計測で決めて `cpu_config.tres` に入れ、計測のテストを通す

## フェーズ5: 仕様書の更新

- [x] requirements-definition.md・functional-overview.md・glossary.md・component-design.md・data-definition.md・repository-structure.md ほか（.drawio を含めて検索する）

## フェーズ6: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）
- [x] 実装レビュー（review-implementation。規約は全文を渡す）を行い、指摘を直す
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

# タスクリスト

**このファイルの全タスクが完了するまで作業を継続すること。** スキップは技術的理由がある場合のみ理由を明記する。

## フェーズ1: テスト実装

- [x] 画面6 No.10〜14（`src/pages/LearningListPage.test.ts`）
- [x] 画面7 No.17〜19（`src/pages/FormationLearningPage.test.ts`）
- [x] 画面7 No.27・28・30〜33（`src/components/TacticalReplay.test.ts`）
- [x] 画面8 No.40・41（`src/pages/FreeLayoutBoardPage.test.ts`）

## フェーズ2: 変異注入

- [x] 各テストに対応する実装を壊して落ちることを確認し、元に戻したことを `git status` で確認

## フェーズ3: ドキュメント

- [x] 仕様書3本の完了欄を `[x]` にし、備考を更新

## フェーズ4: 品質チェック

- [x] `npm test` / `npm run lint` / `npm run typecheck` / `npm run build`
- [x] テストが実際に実行されたことを確認（実行件数・スキップ数）: 36ファイル・543件成功（+15件。画面6の No.10・11 は1テストで検証）、スキップ0

## フェーズ5: レビューと振り返り

- [x] review-implementation を実施し指摘を反映（5/5。[必須]なし、[推奨]は tasklist 更新のみ）
- [x] review-pre-commit を実施し review-report.md を出力（Critical/High 収束まで）: 第1回で Critical/High 0件、Low 3件対応
- [x] retrospective.md を作成

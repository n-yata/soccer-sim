# タスクリスト

**このファイルの全タスクが完了するまで作業を継続すること。** スキップは技術的理由がある場合のみ理由を明記する。

## フェーズ1: 画面詳細設計書（1ファイルずつ承認）

- [x] screen-06-learning-list.md 作成 → 承認
- [x] screen-07-formation-learning.md 作成 → 承認
- [x] screen-08-free-layout-board.md 作成 → 承認

## フェーズ2: 単体テスト仕様書（1ファイルずつ承認）

- [x] test-screen-06-learning-list.md 作成 → 承認
- [x] test-screen-07-formation-learning.md 作成 → 承認
- [x] test-screen-08-free-layout-board.md 作成 → 承認

## フェーズ3: 関連ドキュメント

- [x] screen-design.md「詳細設計への申し送り」の未作成記述を更新

## フェーズ4: 品質チェック

- [x] `npm test` / `npm run lint` / `npm run typecheck` / `npm run build`
- [x] テストが実際に実行されたことを確認（実行件数・スキップ数）: 36ファイル・528件成功、スキップ0（コード無変更）

## フェーズ5: レビューと振り返り

- [x] review-pre-commit を実施し review-report.md を出力（Critical/High 収束まで）: 第1回で Critical/High 0件、Low 5件対応
- [x] retrospective.md を作成

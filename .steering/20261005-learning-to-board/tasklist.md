# タスクリスト

**このファイルの全タスクが完了するまで作業を継続すること。** スキップは技術的理由がある場合のみ理由を明記する。

## フェーズ1: ボードの初期陣形指定

- [x] `src/router/index.ts`: `/board` に props 関数（`query.blue` → `initialBlueFormationId`）
- [x] `FreeLayoutBoardPage.vue`: props `initialBlueFormationId` で青の初期陣形を決める
- [x] テスト: ルートの props 変換、ボードの初期陣形（実在・非実在・空・未指定・保存復元・赤とボール不変）

## フェーズ2: 学習画面の導線

- [x] `FormationLearningPage.vue`: 概要欄と教材の後に「この陣形をボードで試す →」
- [x] テスト: 全8陣形のリンク先、不明 ID で非表示、実ルーターでクリックしてボードが学習中の陣形で開く

## フェーズ3: ドキュメント

- [x] `functional-overview.md`（画面一覧・遷移図・確定事項）
- [x] `wireframes.drawio`（`wireframe-formation-learning` に導線2か所）
- [x] `screen-design.md`（画面7・画面8）
- [x] `component-design.md`（FormationLearningPage・FreeLayoutBoardPage・ルート定義）
- [x] `screen-07` / `screen-08` 詳細設計書
- [x] `test-screen-07` / `test-screen-08` 単体テスト仕様書（追加ケースを `[x]` で）

## フェーズ4: 品質チェック

- [x] `npm test` / `npm run lint` / `npm run typecheck` / `npm run build`
- [x] テストが実際に実行されたことを確認（実行件数・スキップ数）: 36ファイル・560件成功（+17件）、スキップ0
- [x] 変異注入（追加テストが落ちるべきときに落ちる）: 6通りすべて狙いのテストが失敗

## フェーズ5: レビューと振り返り

- [x] review-implementation を実施し指摘を反映（4.8/5。[必須]なし、[推奨]2件反映）
- [x] review-pre-commit を実施し review-report.md を出力（Critical/High 収束まで）: 第1回で Critical/High 0件、Medium 1件を仕様確定＋テストで対応
- [x] retrospective.md を作成

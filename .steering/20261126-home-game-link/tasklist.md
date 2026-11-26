# タスクリスト

## フェーズ1: 実装

- [x] テストを先に書く（Red を確認。Vitest では BASE_URL が "/" なので、テストで "/soccer-sim/" に差し替えた）
- [x] `FormationListPage.vue` にリンクとスタイルを追加（Green）
- [x] 表示を確認（`vite preview` ＋ 手元で書き出したゲーム。1280px で見出しの右、390px で説明文の下。押すと `/soccer-sim/game/index.html` でゲームが起動）

## フェーズ2: ドキュメント

- [x] `wireframes.drawio` の `wireframe-formation-list` にリンクを追加
- [x] `screen-design.md`（画面1のレイアウト・画面項目・画面イベント）
- [x] `component-design.md`（FormationListPage の責務）
- [x] `functional-overview.md`（画面一覧の主な要素）
- [x] `repository-structure.md`（「ラボの画面からの導線はまだ無い」を更新）
- [x] `test-screen-01-formation-list.md`（単体テスト仕様にケースを追加）

## フェーズ3: 品質チェック

- [x] `npm test`（36ファイル・562件成功。追加2件を含む）
- [x] `npm run lint`
- [x] `npm run typecheck`
- [x] `npm run build`
- [x] コミット前レビュー（`review-pre-commit`）→ `review-report.md`（Critical / High なし）
- [x] 振り返り（`retrospective.md`）

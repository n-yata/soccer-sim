# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: ルーティングとページ実装

- [x] `src/router/index.ts`に`/matrix`ルート（`name: "matrix"`, `component: MatrixPage`）を追加
- [x] `src/pages/MatrixPage.vue`を新規作成
  - [x] `formations`配列からN×Nの`<table>`を描画（`<th scope="col">`/`<th scope="row">`で見出し）
  - [x] 対角線セルは非リンクのプレースホルダ（グレー、クリック不可）
  - [x] 対角線以外のセルは`getMatchup(row.id, col.id)`の`overallEdge`に応じた
        色クラス（row有利=team-a色、col有利=team-b色、互角=グレー）を持つ
        `<router-link :to="/compare/{row.id}/{col.id}">`
  - [x] `getMatchup`が`undefined`を返す場合は互角と同じグレー表示にフォールバック

## フェーズ2: 一覧画面からの導線

- [x] `src/pages/FormationListPage.vue`のヘッダーに「相性表を見る」ボタンを追加し、
      クリックで`router.push("/matrix")`する

## フェーズ3: テスト

- [x] `src/pages/MatrixPage.test.ts`を新規作成
  - [x] フォーメーション件数×件数のセルが描画されることを検証
  - [x] 対角線セルが`<router-link>`でない（クリック不可）ことを検証
  - [x] 既知の組み合わせ（"4-4-2"×"4-2-3-1" → overallEdge "B"）で、
        行=4-4-2/列=4-2-3-1のセルがcol有利の色クラスを持つことを検証
  - [x] 各セルの`to`属性が`/compare/{row.id}/{col.id}`であることを検証
- [x] `src/pages/FormationListPage.test.ts`に、ヘッダーボタンクリックで
      `router.push("/matrix")`が呼ばれることを検証するテストを追加

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npx vitest run`（8ファイル・71件全て成功、スキップ0件）
- [x] リントエラーがないことを確認
  - [x] `npx eslint src --max-warnings=0`
- [x] 型エラーがないことを確認
  - [x] `npx vue-tsc --noEmit`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] テストが実際に実行されたことを確認（実行件数・スキップ数を確認）

## フェーズ5: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md`: FR-07として
      相性マトリクス表を機能一覧・機能詳細に追加し、§6.1(MVP対象範囲)へ移動、
      §6.2(スコープ外)から相性マトリクス表の行を削除、§7.1の該当未決事項を
      「実装完了」に更新
- [x] `docs/specs/1_requirements/architecture-overview.md`: 「将来の拡張候補」から
      相性マトリクス表を実装済みとして分離・記載
- [x] `docs/specs/1_requirements/functional-overview.md`: 画面一覧・画面遷移図・
      ユースケース一覧に相性マトリクス画面（UC-02）を追加
- [x] `docs/specs/1_requirements/repository-structure.md`: `pages/`の配置ファイル
      一覧に`MatrixPage.vue`を追加
- [x] 実装後の振り返りを記録（別ファイル`retrospective.md`に記録）

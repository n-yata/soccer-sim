# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

---

## フェーズ1: 公開URLの確定

- [x] `gh auth status`でログイン中のGitHubユーザーを確認（`n-yata`）
- [x] `gh repo view`でリポジトリ`soccer-sim`が既存か確認（未作成・新規作成予定と確認）
- [x] 公開URL `https://n-yata.github.io/soccer-sim/` をユーザーに確認

## フェーズ2: OGP画像・アイコン作成

- [x] `@resvg/resvg-js`を`--no-save`で一時インストール
- [x] OGP画像用SVG（1200x630、サッカーボールモチーフ+タイトル+サブタイトル）を作成
- [x] PNGへラスタライズし、テキストが枠内に収まるよう調整（1回目は右端がはみ出したため
      サブタイトルの文言短縮・フォントサイズ調整で対応）
- [x] apple-touch-icon用SVG（180x180）を作成しPNGへラスタライズ
- [x] `public/og-image.png`・`public/apple-touch-icon.png`に配置
- [x] 一時ファイル（SVGソース・変換スクリプト）を削除、`@resvg/resvg-js`をアンインストール

## フェーズ3: メタタグ・ビルド設定

- [x] `index.html`に`og:url`・canonical・`og:image`（width/height付き）・`og:locale`・
      `twitter:image`を追加、`twitter:card`を`summary_large_image`に変更
- [x] `index.html`のfavicon/apple-touch-icon hrefを`%BASE_URL%`プレースホルダに変更
- [x] `vite.config.ts`に`base: "/soccer-sim/"`を追加
- [x] `src/router/index.ts`の`createWebHistory()`に`import.meta.env.BASE_URL`を渡す
- [x] `src/vite-env.d.ts`を新規追加（`import.meta.env`の型解決）

## フェーズ4: 検索エンジン向けファイル

- [x] `public/robots.txt`を作成
- [x] `public/sitemap.xml`を作成（静的4画面のみ）

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npx vitest run`（34ファイル・531件全てパス）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（`vite-env.d.ts`追加前は`ImportMeta.env`エラーが発生、追加後に解消）
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] ビルド後の`dist/index.html`を目視確認し、`%BASE_URL%`が`/soccer-sim/`へ
      正しく置換されていることを確認
- [x] `npx vite preview`でビルド成果物を実際にサーブし、以下を確認
  - [x] `curl http://localhost:5557/soccer-sim/` が200
  - [x] `curl http://localhost:5557/soccer-sim/matrix` が200
  - [x] `curl http://localhost:5557/soccer-sim/favicon.svg` が200
  - [x] `curl http://localhost:5557/soccer-sim/og-image.png` が200
  - [x] Chrome操作で一覧画面→比較画面への遷移が`/soccer-sim/compare/4-4-2/4-3-3`で
        正常動作することを確認（スクリーンショット取得済み）

## フェーズ6: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` §7.1の未決事項を解決済みに更新
- [x] `docs/specs/1_requirements/architecture-overview.md`にデプロイ先（GitHub Pages）と
      base path設定の記載を追加
- [x] `docs/specs/1_requirements/repository-structure.md`に新規ファイル
      （`public/og-image.png`等・`src/vite-env.d.ts`）を追加

## フェーズ7: コミット前レビュー対応（2026-09-28追加）

> コミット前レビュー（opus、`.steering/20260927-seo-ogp/review-report.md`参照）で
> High 1件・Medium 3件・Low 3件の指摘を受け、以下を追加対応した。

- [x] **[High]** GitHub PagesはSPAのHTML5 historyモードにフォールバックを持たないため、
      `/matrix`等への直接アクセス・リロード・クローラー巡回が全て404になる問題を修正
  - [x] `package.json`の`build`スクリプトに`dist/index.html`→`dist/404.html`コピーを追加
  - [x] `npm run build`で`dist/404.html`が生成され`index.html`と同一であることを確認
  - [x] `npx serve dist`（SPAリライト無し。GitHub Pages相当の挙動）で`/soccer-sim/matrix`に
        アクセスし、HTTPステータス404かつ`404.html`の内容が返ることをcurlで確認
        （`vite preview`は内蔵のSPAフォールバックを持つため検証の根拠にならないという
        レビュー指摘を踏まえ、フォールバックを持たないサーバーで再検証した）
- [x] **[Medium]** `robots.txt`はGitHub Pagesのプロジェクトページ配信では
      オリジン直下でないと有効にならない制約を、ファイル内コメントと
      `architecture-overview.md`に明記
- [x] **[Medium]** 独自ドメイン移行時の修正箇所が2箇所ではなく実際は9箇所（`index.html`4・
      `sitemap.xml`4・`robots.txt`1）であることを`architecture-overview.md`に正確に記載
- [x] **[Medium]** `sitemap.xml`に`<lastmod>`を追加
- [x] **[Low]** `og:image:alt`・`twitter:image:alt`・`og:site_name`を追加
- [x] 修正後、`npx vitest run`（531件）/ `npm run lint` / `npm run typecheck` / `npm run build`を
      再実行しすべて成功を確認
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3、フェーズ7末尾）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

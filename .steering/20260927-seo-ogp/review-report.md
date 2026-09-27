# コミット前レビューレポート

## 第1回（2026-09-28）
- 対象: SEO/OGP対応の全差分（`index.html`/`vite.config.ts`/`src/router/index.ts`/
  `docs/specs/`3件 + 新規: `public/apple-touch-icon.png`, `public/og-image.png`,
  `public/robots.txt`, `public/sitemap.xml`, `src/vite-env.d.ts`）
- 結果: Critical 0件 / High 1件 / Medium 3件 / Low 3件

## コミット前レビュー結果

対象: `soccer-sim` 未コミット差分。GitHub Pages（`https://n-yata.github.io/soccer-sim/`）公開に
向けたSEO/OGP対応一式。

### Critical（即時対応必須）
なし

### High（優先対応）
- **[バグ/運用] GitHub Pagesに SPA フォールバック（`404.html`）が無く、トップ以外のURLが
  すべて404になる**: `createWebHistory`（HTML5 historyモード）とGitHub Pagesの静的配信の
  組み合わせで、`/soccer-sim/matrix`等への直接アクセス・リロード・クローラー巡回が404になる。
  今回追加した`sitemap.xml`が`/matrix`/`glossary`/`quiz`をクローラーに申告しているため、
  SEO対応という目的自体を損なう。共有URL`/compare/:a/:b`も開けない。`vite preview`での
  200確認は、`vite preview`が内蔵のSPAフォールバックを持つため根拠にならない。

### Medium（対応推奨）
- **[運用] `robots.txt`はGitHub Pagesのプロジェクトページ配信では有効にならない**: robots.txt
  はオリジン直下でのみ有効という仕様のため、`.../soccer-sim/robots.txt`はクローラーに
  参照されない可能性が高い。
- **[運用/保守性] 独自ドメイン移行時の修正箇所の記載が不正確**: `architecture-overview.md`は
  「2箇所を`/`に戻す」としていたが、実際は公開URLが`index.html`4箇所・`sitemap.xml`4箇所・
  `robots.txt`1箇所の計9箇所に散在している。
- **[運用] `sitemap.xml`に`<lastmod>`が無い**: クローラーの再訪問判断材料が減る。

### Low / 改善提案
- `og:image:alt`・`og:site_name`が未設定
- canonicalがSPAのため全ルートでトップページ固定（構成上避けがたく現状で妥当と判断）
- `.steering/20260927-seo-ogp/retrospective.md`が未作成（この時点では正常な状態）

### 問題なし
- **URLハードコーディングは妥当と判断**: サイト自身の公開URLであり秘匿値ではない。
  SNSクローラー・検索エンジンがJS実行前の静的HTMLから読む必要があり、環境変数からの
  注入が原理的に取れない。Nuxt/Next/Astro等でもサイトURLは設定ファイルに平文で置くのが
  標準プラクティス。
- 一時依存`@resvg/resvg-js`の残留なし（`package.json`/`package-lock.json`とも記載0件、
  未追跡ファイルも意図した6件のみ）
- base path 3箇所（`vite.config.ts`/`index.html`の`%BASE_URL%`/`router/index.ts`の
  `BASE_URL`）の整合性を実際に`npm run build`で確認し、`dist/index.html`のアセット参照が
  すべて`/soccer-sim/`配下に解決されていることを確認済み
- `src/vite-env.d.ts`が正しく機能し、`npm run typecheck`がエラー0で通過
- 既存テスト531件に影響なし
- OGP画像・apple-touch-iconの寸法・ファイルサイズは妥当。JSバンドルに含まれず静的配信

### 未検証
- GitHub Pages実環境での挙動（リポジトリ未作成のため）。ただしHigh指摘はGitHub Pagesの
  仕様（SPAフォールバックを持たない純静的配信）と`404.html`不在という事実からの演繹であり、
  再現性のある指摘

### 総合評価
Critical/Highの計1件を要修正としてコミット前対応。

### 対応
- **High（404.html不在）**: `package.json`の`build`スクリプトへ
  `dist/index.html`→`dist/404.html`コピーを追加。`npx serve dist`
  （SPAリライト無しの静的サーバー。GitHub Pages相当の挙動）で`/soccer-sim/matrix`に
  アクセスし、HTTPステータス404かつ`404.html`（`index.html`と同一内容）が返ることを
  curlで実証確認した（`vite preview`ではなく、フォールバックを持たないサーバーで
  レビュー指摘どおりの再検証を実施）
- **Medium3件**: `robots.txt`にコメントで制約を明記、`architecture-overview.md`に
  9箇所の正確な一覧と`robots.txt`の制約を追記、`sitemap.xml`に`<lastmod>`を追加
- **Low2件**: `og:image:alt`・`twitter:image:alt`・`og:site_name`を追加。
  canonical固定は現状の静的SPA構成では妥当と判断し対応不要

修正後、`npm run test`（531件）/ `npm run lint` / `npm run typecheck` / `npm run build`を
再実行し全てパスすることを確認済み。

## レビュー完了（2026-09-28）
- 最終ラウンド: 第1回（High対応はビルドスクリプト1行の追加＋実サーバーでの再検証のみで、
  既存ロジックの構造変更を伴わないため再レビューは不要と判断）
- 新たな Critical / High: なし
- 積み残し: なし（Low「canonicalの固定」は静的SPA構成上の制約として許容）

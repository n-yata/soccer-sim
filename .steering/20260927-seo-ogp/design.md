# 設計書

## アーキテクチャ概要

バックエンド無しの静的SPAというアーキテクチャは変更しない。今回の変更は
(a) `index.html`の静的メタタグ拡充、(b) `public/`への静的アセット追加、
(c) GitHub Pagesのサブパス配信に対応するビルド設定、の3点に閉じる。

## コンポーネント設計

### 1. `index.html`のメタタグ

**責務**: SNSクローラー・検索エンジンが解釈する静的メタ情報を提供する。

**実装の要点**:
- `og:url`/canonicalは`https://n-yata.github.io/soccer-sim/`を直接記載する
  （バックエンドが無く、ビルド時に注入する仕組みも無いため。環境変数化しない理由は
  index.html内のコメントに明記した）
- favicon/apple-touch-iconは`%BASE_URL%`プレースホルダを使う（Viteのindex.html
  env置換機能で、開発・本番どちらのbaseでも自動的に正しいパスになる）
- `og:image`/`twitter:image`はドメイン込みの絶対URL（`%BASE_URL%`では
  ドメイン部分が得られないため、こちらは直接記載）

### 2. OGP画像・apple-touch-icon（`public/og-image.png`, `public/apple-touch-icon.png`）

**責務**: SNSシェア時のカード画像・iOSホーム画面アイコン。

**実装の要点**:
- 外部デザインツール・画像素材は使わず、`favicon.svg`と同じサッカーボールの
  幾何学モチーフでSVGを新規作成し、`@resvg/resvg-js`（一時的に`--no-save`で
  インストールし、生成後にアンインストール。プロジェクトの永続依存には加えない）で
  PNGへラスタライズした
- 日本語テキストの描画はOSのシステムフォント（Yu Gothic等）を`loadSystemFonts: true`で
  読み込ませることで実現した。Webフォントの同梱は不要
- OGP画像は1200x630（Open Graphの推奨サイズ）、apple-touch-iconは180x180

### 3. GitHub Pagesのbase path対応

**責務**: プロジェクトページ配信（`https://n-yata.github.io/soccer-sim/`）で
アセット・ルーティングが正しく機能するようにする。

**実装の要点**:
- `vite.config.ts`に`base: "/soccer-sim/"`を設定
- `src/router/index.ts`の`createWebHistory()`に`import.meta.env.BASE_URL`を渡す
- `import.meta.env`の型を解決するため`src/vite-env.d.ts`（`/// <reference types="vite/client" />`）
  を新規追加（このプロジェクトは`import.meta.env`を今回初めて使うため、型参照が
  存在していなかった）

### 4. `robots.txt`/`sitemap.xml`

**責務**: 検索エンジンのクロール・インデックスを補助する。

**実装の要点**:
- `robots.txt`は全許可 + sitemapへのポインタのみ
- `sitemap.xml`は静的4画面（`/`, `/matrix`, `/glossary`, `/quiz`）のみを列挙する。
  `/compare/:a/:b`は組み合わせ数が多く動的なため対象外（requirements.mdのスコープ外参照）

## データフロー

該当なし（静的ファイル・ビルド設定の変更のみで、実行時のデータフローに変更はない）

## テスト戦略

### 統合的な検証（自動テストではなく手動+ビルド検証）
- `npm run build`後の`dist/index.html`を目視確認し、`%BASE_URL%`が正しく
  `/soccer-sim/`へ置換されていることを確認する
- `vite preview`でビルド成果物を実際にサーブし、トップページ・比較画面遷移・
  静的アセット（favicon/og-image/apple-touch-icon）がすべて`/soccer-sim/`配下で
  200を返すことをcurl+ブラウザで確認する

既存のVitestテストへの影響は無い（`router/index.ts`の`history`初期化は
`vue-router`のモック化により既存テストで直接検証されない箇所であり、
`import.meta.env.BASE_URL`はdev/testいずれも`"/"`にフォールバックするため
既存の相対パス前提のテストは影響を受けない）。

## 依存ライブラリ

一時的な開発時ツールとして`@resvg/resvg-js`を使用したが、`--no-save`で
インストールし画像生成後にアンインストール済み。`package.json`に変更はない。

## ディレクトリ構造

```
soccer-sim/
├── index.html              (変更: OGP/favicon/canonical タグ拡充)
├── vite.config.ts           (変更: base追加)
├── src/
│   ├── router/index.ts      (変更: history base対応)
│   └── vite-env.d.ts        (新規: vite/client型参照)
└── public/
    ├── favicon.svg          (既存)
    ├── apple-touch-icon.png (新規)
    ├── og-image.png         (新規)
    ├── robots.txt           (新規)
    └── sitemap.xml          (新規)
```

## 実装の順序

1. GitHub Pages公開URLの確定（`gh`コマンドでユーザー名・リポジトリ名を確認）
2. OGP画像・apple-touch-iconのSVGデザイン→PNGラスタライズ（`@resvg/resvg-js`一時導入）
3. `public/`への配置、一時依存のアンインストール
4. `index.html`のメタタグ拡充
5. `vite.config.ts`の`base`設定、`router/index.ts`のhistory対応、`vite-env.d.ts`追加
6. `robots.txt`/`sitemap.xml`の追加
7. ビルド+プレビューサーバーでの動作確認（curl・ブラウザ）
8. コミット前レビュー→振り返り→コミット

## セキュリティ考慮事項

- `og:url`/canonical/`og:image`のURLハードコーディングは、公開サイトの
  メタデータという性質上、秘匿性が無く環境変数化の実益が無いため意図的な設計判断
  （index.html内のコメントで明記）
- 一時依存`@resvg/resvg-js`はビルド成果物・`package.json`のいずれにも残らない
  （画像生成後にアンインストール済み）

## パフォーマンス考慮事項

- OGP画像は約94KB、apple-touch-iconは約5KBで、いずれもSNSクローラー・
  ブラウザのみが取得する（アプリ本体のバンドルには含まれない）

## 将来の拡張性

- 独自ドメインへの移行時は、`index.html`内の`n-yata.github.io/soccer-sim`を
  一括置換し、`vite.config.ts`の`base`を`/`に戻す（ルートページ配信になるため）
- `/compare/:a/:b`のsitemap化が必要になった場合、`data/formations.ts`から
  ビルド時にsitemap.xmlを生成するNodeスクリプトを追加する案がある（今回は未実装）

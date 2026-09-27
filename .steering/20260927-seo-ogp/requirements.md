# 要求内容

## 概要

サイト公開準備の第二弾として、SEO/OGP対応（メタタグ整備・OGP画像・favicon類・
GitHub Pagesデプロイに必要なbase path設定）を行う。

## 背景

`requirements-definition.md` §7.1に「一般公開するかどうかは未定だが、公開前提での
アクセシビリティ・SEO/OGP対応を先行して着手する方針とした（2026-09-12）」という
未決事項があった。今回、公開先をGitHub Pages（`https://n-yata.github.io/soccer-sim/`）
とすることが確定したため、この方針を実行に移す。

## 実装対象の機能

### 1. メタタグ整備
- 既存の`index.html`にはtitle/description/OGP/Twitter Cardの基本タグは
  2026-09-12時点で用意済みだったが、`og:image`（SNSシェア時のカード画像）・
  `og:url`・canonicalタグが欠けていた
- OGP画像を新規に用意し、`og:image`/`twitter:image`を追加する
- `twitter:card`を`summary`から`summary_large_image`へ変更する（画像ありのカード）

### 2. favicon・アイコン類の拡充
- 既存の`favicon.svg`に加え、iOSホーム画面用の`apple-touch-icon.png`を追加する

### 3. GitHub Pagesデプロイに必要な設定
- GitHub Pagesのプロジェクトページ配信はサブパス（`/soccer-sim/`）になるため、
  `vite.config.ts`の`base`とVue Routerの`history`ベースパスを設定する
  （これを設定しないとOGP/canonicalの絶対URLがサイト自体が動かないURLを指してしまう）

### 4. 検索エンジン向けファイル
- `robots.txt`・`sitemap.xml`を新規に用意する（静的な5画面のうちルート遷移で
  完結する4画面を対象。`/compare/:a/:b`は組み合わせが多く動的なため対象外とする）

## 受け入れ条件

- [x] `og:image`/`twitter:image`が設定され、1200x630のOGP画像が`public/`に存在する
- [x] `og:url`・canonicalタグが実際の公開URL（`https://n-yata.github.io/soccer-sim/`）を指す
- [x] `apple-touch-icon.png`が用意され、`index.html`から参照されている
- [x] `vite.config.ts`の`base`が`/soccer-sim/`に設定されている
- [x] Vue Routerの`history`が`import.meta.env.BASE_URL`を使い、base pathと整合する
- [x] `npm run build`後、`dist/index.html`のアセット参照がすべて`/soccer-sim/`配下になっている
- [x] ビルド後のプレビューサーバーで、トップページ・比較画面遷移・静的アセット取得が
      すべて`/soccer-sim/`配下で200を返す
- [x] `robots.txt`/`sitemap.xml`が`public/`に存在する

## 成功指標

- SNS（X/Twitter, Facebook, LINE等）でURLを共有した際に、タイトル・説明文・画像付きの
  カードが表示されること（実際のシェアでの見た目確認はGitHub Pages公開後に行う）

## スコープ外

- GitHub ActionsによるGitHub Pagesへの自動デプロイworkflowの作成
  （デプロイ手順の整備自体は別タスクとして扱う）
- `/compare/:formationAId/:formationBId`の全28組み合わせをsitemapに含めること
  （動的ルートであり、`formations.ts`変更時にsitemapが追随しない静的ファイルのため、
  今回は静的4画面のみとした。将来ビルド時生成スクリプトにする案は申し送り）
- 構造化データ（JSON-LD等）の追加

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` §7.1（本タスクの起点となった未決事項）
- `docs/specs/1_requirements/architecture-overview.md`

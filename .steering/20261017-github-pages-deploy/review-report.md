# コミット前レビュー（代替実施）

> ⚠️ kit-mcp（spec-kit）に接続できず `review-pre-commit` の本文を取得できなかったため、
> 同スキルの4観点（セキュリティ・バグ・性能・運用）で作業者が自己レビューした代替記録である。
> 接続復旧後、`review-pre-commit` による正式レビューを実施すること。

- 実施日: 2026-10-17
- 対象: `.github/workflows/deploy-pages.yml`、`docs/specs/1_requirements/` の3ファイル、本ステアリング

## 結果: Critical 0件 / High 0件 / Medium 1件 / Low 2件

### セキュリティ
- ハードコーディング: シークレット・アカウント情報なし。公開URL `https://n-yata.github.io/soccer-sim/` は
  コメントのみで、既に永続ドキュメントに記載済みの公開値。`VITE_JLEAGUE_URL` は `vars` から注入
- スクリプトインジェクション: `vars` は `env:` 経由で渡しており `run:` に直接展開していない。問題なし
- 権限: `contents: read` / `pages: write` / `id-token: write`。GitHub 公式テンプレートと同等
- **[Low] Actions をメジャータグ参照（`@v4` 等）**: SHA 固定ではない。いずれも GitHub 公式（actions/*）のため受容

### バグ
- base `/soccer-sim/` と 404.html コピーは既存の `npm run build` で担保。ローカルで build 成功・`dist/404.html` 生成を確認
- **[Low] `pages: write` / `id-token: write` が build ジョブにも付与される**: deploy ジョブのみで足りるが、
  公式テンプレートと同じ構成で、build ジョブは信頼できるコードのみ実行するため受容

### 性能
- `setup-node` の npm キャッシュを有効化。問題なし

### 運用
- **[Medium] Node 20 は 2026-04 に EOL**: 開発環境表（20系）に合わせたが、22系への移行を推奨。積み残しへ記録
- 失敗時はデプロイされず前回の公開版が残る。`concurrency` で連続 push の競合を回避
- 初回は Settings → Pages の Source を「GitHub Actions」にする必要あり（ドキュメント記載済み）

## 追記（再レビュー）
- **[High] 起動条件のブランチ名誤り**（PR 作成時に発覚）: `branches: [main]` だが、デフォルトブランチは
  `master`。マージしてもデプロイが一度も動かない。→ `master` に修正済み。
  修正後の差分（ブランチ名のみ）を再確認し、新たな Critical / High なし

## 第3回（2026-10-17）— 既定ブランチ改名（master → main）への追従
- 対象: `.github/workflows/deploy-pages.yml`、`docs/specs/1_requirements/architecture-overview.md`、
  `docs/specs/1_requirements/repository-structure.md`、`.steering/20261017-github-pages-deploy/tasklist.md`
- 実施: `review-pre-commit`（kit-mcp 接続済み、サブエージェントによる正式レビュー）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

### Critical / High / Medium
なし

### Low / 改善提案
- [運用] `github-pages` 環境のデプロイ許可ブランチに `master` が残っている。`main` へのデプロイ成功を
  確認したら削除する（tasklist の残タスクと同じ）。今回の差分が持ち込んだ問題ではない
- [運用/ドキュメント] repository-structure.md の見出し「初回のみ必要なリポジトリ設定」に、ブランチ改名時の
  手順を追記したため見出しと内容がずれている

### 問題なし
- セキュリティ①: シークレット・キー・トークン・クラウドアカウント情報なし。URL は既存ドキュメントで公開前提の
  Pages URL のみ。`VITE_JLEAGUE_URL` は `vars.` 経由で渡し、フォールバック値なし（公開の公式 URL）。
  `.gitignore` に `.env` / `.env.*` あり
- セキュリティ②〜④: 該当箇所なし。ワークフローの permissions は変更なし
- バグ: 起動条件 `main` は実際の既定ブランチと一致。ワークフローと docs 2ファイルに `master` の残存なし。
  環境の許可ブランチに `main` が入っていることを確認
- 性能: 該当なし
- 運用: ドキュメントとワークフローの記述が一致。revert で戻せる変更

### 未検証
- `main` への push で実際にワークフローが起動しデプロイまで成功するか（push 後に確認）
- Pages の Source 設定と Variables の値はレビュー役では読み取り確認していない（依頼元が別途確認済み）

### 対応
- Low 1件目: デプロイ成功確認後に許可ブランチから `master` を削除する（tasklist で管理）
- Low 2件目: 見出しを「必要なリポジトリ設定」に変更した

## レビュー完了（2026-10-17）
- 最終ラウンド: 第3回
- 新たな Critical / High: なし
- 積み残し: なし（Low 1件目はマージ後の作業として tasklist で管理）

## 第4回（2026-10-17）— tasklist の残タスク完了記録
- 対象: `.steering/20261017-github-pages-deploy/tasklist.md`
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 1件
- 確認内容: `main` の最新 run（38997806201、push、PR #18 のマージコミット）が build・deploy とも success。
  `github-pages` 環境のデプロイ許可ブランチは `main` の1件のみ。記述は事実と一致。機密情報なし
- 未検証: 許可ブランチ削除とデプロイ成功確認の時系列（API では現在状態のみ確認可能）
- Low: 根拠として run ID を併記するとよい → 追記して対応

## レビュー完了（2026-10-17）
- 最終ラウンド: 第4回
- 新たな Critical / High: なし
- 積み残し: なし

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

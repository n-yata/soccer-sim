# 実装アプローチ

- GitHub 公式の Pages 用 Actions（configure-pages / upload-pages-artifact / deploy-pages）を使う。
  `gh-pages` ブランチ方式は履歴が増え、追加の書き込み権限も要るため採らない
- build ジョブで `npm ci` → lint → typecheck → test → build、deploy ジョブで公開する
- 権限は `contents: read` / `pages: write` / `id-token: write` の最小構成
- `concurrency: pages`（cancel-in-progress: false）で、連続 push 時のデプロイ競合を防ぐ
- `VITE_JLEAGUE_URL` は `vars.VITE_JLEAGUE_URL`（リポジトリ Variables。公開値なので Secrets ではない）
- Node は `repository-structure.md` の開発環境表に合わせて 20 系
- ドキュメント更新: architecture-overview（自動デプロイ）、repository-structure（CI/CD）、
  requirements-definition（未決事項の解決記録）

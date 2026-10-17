# タスクリスト

- [x] ワークフロー `.github/workflows/deploy-pages.yml` を作成
- [x] ローカルで lint / typecheck / test / build が通ることを確認
- [x] 永続ドキュメントの更新（architecture-overview / repository-structure / requirements-definition）
- [x] コミット前レビュー（kit-mcp 未接続のため代替の自己レビュー）
- [x] 振り返り（retrospective.md）
- [x] コミット・push
- [x] リポジトリ設定: Settings → Pages の Source を「GitHub Actions」にする
      → API で有効化（2026-10-17）。初回デプロイは Pages 未有効で失敗していたため再実行し成功
- [x] リポジトリ Variables に `VITE_JLEAGUE_URL` を設定し、再デプロイして公開バンドルへの反映を確認
- [x] 既定ブランチを `master` → `main` に改名（2026-10-17）
      → `github-pages` 環境のデプロイ許可ブランチに `main` を追加、ワークフロー起動条件と
      docs（architecture-overview / repository-structure）を `main` に更新
- [ ] 改名後、`main` への push でデプロイが成功することを確認
- [ ] 確認後、`github-pages` 環境のデプロイ許可ブランチから `master` を削除

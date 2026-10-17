# 要求内容

## 背景
公開先は GitHub Pages（`https://n-yata.github.io/soccer-sim/`）に確定済みで、base path と
404.html フォールバックも整備済み。ただし公開する仕組み（自動デプロイ）が未整備だった。

## 要求
- `master` へ push したら GitHub Pages へ自動で公開されるようにする
- 壊れたビルドを公開しないよう、lint・型チェック・テストが通ったときだけ公開する
- 公開リンク先 `VITE_JLEAGUE_URL` をハードコードせず、リポジトリ設定から渡せるようにする

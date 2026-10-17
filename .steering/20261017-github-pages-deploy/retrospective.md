# 実装後の振り返り

## 作業概要
`master` への push で lint・型チェック・テスト・ビルドを通し、成功時のみ GitHub Pages へ公開する
GitHub Actions ワークフローを追加した。関連する永続ドキュメントの「自動デプロイ未整備」記述を更新した。

## 実装完了日
2026-10-17

## コミット前レビュー（review-pre-commit）の結果
- **kit-mcp 未接続のため代替の自己レビュー**（4観点）。正式レビューは接続復旧後に要実施
- 結果: Critical 0件 / High 1件（修正済み・再レビューで収束） / Medium 1件 / Low 2件
- Critical / High への対応: 起動ブランチ名の誤り（main→master）を修正し再レビューで収束
- Medium（Node 20 EOL）: 積み残し
- レポート全文: [review-report.md](./review-report.md)

## 積み残し
- Node を 22 系へ上げる（開発環境表とワークフローを同時に更新）
- `review-pre-commit` による正式レビュー
- 実際の Actions 実行での動作確認（master マージ後）

## 学んだこと
- kit-mcp に接続できないクラウドセッションでは必須レビューが実施できない。接続不可時の代替手順を
  kit 側に定義しておくとよい（改善提案）

## 追加修正（PR 作成時に発覚）
- デフォルトブランチは `main` ではなく `master` だった。ワークフローの起動条件が `main` のままだと
  一度も実行されないため、`master` に修正した（ワークフロー・ドキュメント・ステアリング）
- 学び: ブランチ名を前提にする設定は、`git remote show origin` で実際のデフォルトブランチを確認してから書く

## 追加作業: 既定ブランチの改名（2026-10-17）
- GitHub の既定ブランチを `master` → `main` に改名し、ワークフロー起動条件と docs を追従させた
- Pages の有効化（Source を GitHub Actions に）と `VITE_JLEAGUE_URL` の Variables 設定も API で実施
- コミット前レビュー: `review-pre-commit` 第3回で Critical 0 / High 0 / Low 2（[review-report.md](./review-report.md)）
- 学び: `github-pages` 環境はデプロイ許可ブランチを持つため、既定ブランチを改名するときはワークフローの
  起動条件だけでなく環境の許可ブランチも先に更新する。更新しないと deploy ジョブが環境保護ルールで止まる

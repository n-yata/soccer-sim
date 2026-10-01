# 振り返り

## 作業概要

Codex から Claude Code の既存スキルを読めるよう、`.agents/skills` を `.claude/skills` への相対シンボリックリンクにした。`spec-kit` と `drawio` の Codex 用 MCP 接続を追加した。

## コミット前レビュー

[review-report.md](review-report.md) を参照。Critical / High はともに0件。Medium は2件（`drawio-mcp-server` のバージョン未固定、Windows の別環境でのシンボリックリンク設定）。初回コミット後に指定の独立レビューを実施したため、レポートを更新してコミットを修正する。

## 学び

`.claude/skills` は kit の本文ではなく MCP を呼ぶスタブ。複製ではなくリンクを使うことで、更新元を一つに保てる。Windows では Git の `core.symlinks` 設定がリンクのチェックアウト結果に影響する。

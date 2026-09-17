---
name: review-implementation
description: 実装コードの品質を検証し、スペック(PRD・機能設計書・アーキテクチャ設計書)との整合性を確認する。スペック準拠・コード品質・テストカバレッジ・セキュリティ・パフォーマンスの5観点で評価し、優先度付きの検証結果を返す。機能実装の完了後、スペックどおりに実装できているか確認したいときに使用する。
allowed-tools: Read, Grep, Glob, Bash, Task, mcp__spec-kit__list_rules, mcp__spec-kit__get_rule, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# review-implementation（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/review-implementation/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/review-implementation/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

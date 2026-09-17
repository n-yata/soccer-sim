---
name: review-docs
description: ドキュメント(PRD・機能設計書・アーキテクチャ設計書・リポジトリ構造定義書・開発ガイドライン・用語集など)の品質を完全性・明確性・一貫性・実装可能性・測定可能性・簡潔性(重複記載と記述量)の6観点で評価し、優先度付きの改善提案を返す。ドキュメントのレビュー・品質チェックを依頼されたときに使用する。
allowed-tools: Read, Grep, Glob, Task, mcp__spec-kit__list_rules, mcp__spec-kit__get_rule, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# review-docs（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/review-docs/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/review-docs/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

---
name: flow-add-feature
description: 新機能を追加するワークフロー。引数ありなら要求書(requirements.md)を尊重して設計→実装→検証→テスト→コミット前レビュー→振り返りまで無停止で自動実行。引数なしなら planモードで要求を対話的に練り requirements.md を作成して停止する。新機能の実装・機能追加を依頼されたときに使用する。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, mcp__spec-kit__get_distribution_file, Skill, mcp__spec-kit__list_distribution
---

# flow-add-feature（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/flow-add-feature/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/flow-add-feature/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

---
name: flow-archive-retrospectives
description: .steering/ 配下の振り返り(retrospective.md)を走査し、永続ドキュメント(docs/)へ反映すべき学びを反映したうえで、処理済みディレクトリを .steering/archives/ へアーカイブするスキル。振り返りの棚卸し・ドキュメント反映・アーカイブ整理を行うときに使用する。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# flow-archive-retrospectives（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/flow-archive-retrospectives/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/flow-archive-retrospectives/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

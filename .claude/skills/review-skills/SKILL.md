---
name: review-skills
description: distribution/skills/配下のスキル(SKILL.md・付随ファイル)を、修正履歴の混入・冗長な言い回し・記述のシンプルさ・命名規則の4観点でレビューする。スキルの新規作成・改訂後の品質チェックに使う。kit リポジトリ専用(distribution/skills/ は kit にしか存在しない)。
allowed-tools: Read, Grep, Glob, Task, Write, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# review-skills（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/review-skills/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/review-skills/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

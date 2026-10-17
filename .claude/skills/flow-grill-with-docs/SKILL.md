---
name: flow-grill-with-docs
description: 永続ドキュメント(docs/)を作成する前のアイデアを、インタビュー形式の壁打ちで掘り下げ docs/ideas/ に書き出すためのスキル。PRD やその他の正式ドキュメント作成の前段として使用。
allowed-tools: Read, Write, Glob, Grep, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# flow-grill-with-docs（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/flow-grill-with-docs/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/flow-grill-with-docs/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

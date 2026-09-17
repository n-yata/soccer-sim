---
name: kit-sync
description: kit(spec-kit)から配布された .claude/skills/（薄型スタブ）と .claude/hooks/（実体）を最新の kit へ追随させるスキル。kit-mcp サーバーの配信内容と突き合わせて改変を検知し、退避してから書き直す。配布物を更新したいとき、kit 側の変更を取り込みたいときに使用する。
allowed-tools: Read, Write, Edit, Glob, Bash, mcp__spec-kit__get_server_info, mcp__spec-kit__get_stubs, mcp__spec-kit__list_distribution, mcp__spec-kit__get_distribution_file
---

# kit-sync（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/kit-sync/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/kit-sync/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

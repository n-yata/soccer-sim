---
name: kit-contribute
description: 受け渡し場所(inbox)に集まったプロジェクトの振り返りを読み、汎用の学びを spec-kit の規約・スキルへ反映して PR にするスキル。kit のセッションで、還元をまとめて処理したいときに使用する。【重要】spec-kit リポジトリのセッションでのみ使用する。受け渡し場所には他プロジェクトの振り返りも入っており、読み込むと無関係なプロジェクトの未修正脆弱性情報がセッションへ流れ込むため、利用側プロジェクトでは絶対に使用しない。
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# kit-contribute（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/kit-contribute/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/kit-contribute/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

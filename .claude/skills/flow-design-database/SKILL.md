---
name: flow-design-database
description: ゼロからテーブルを設計するワークフロー。要件・PRDを起点に、概念設計(functional-overview.mdのデータモデル)→論理設計(logical-data-model.md。キー設計・正規化・削除方針などの判断と理由)→物理設計(table-definition.md)→検証(CRUDマトリクス・レビュー)→実装への申し送り までを順に進める。データベース・テーブル・スキーマをゼロから設計するとき、または既存テーブルへの変更を上流から順に反映したいときに使用する。
allowed-tools: Read, Write, Edit, Glob, Task, mcp__spec-kit__get_distribution_file, Skill, mcp__spec-kit__list_distribution
---

# flow-design-database（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/flow-design-database/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/flow-design-database/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

---
name: kit-guidelines
description: プロジェクト非依存の汎用開発規約(コーディング規約・ロギング・図版管理・依存関係管理・Git運用・テスト戦略・コードレビュー基準・命名/配置規則・ステアリング運用)の正本。規約を確認したいとき、実装やレビューの判断基準が必要なとき、各プロジェクトの repository-structure.md に書くべきか迷ったときに参照する。
allowed-tools: Read, Grep, Glob, mcp__spec-kit__list_rules, mcp__spec-kit__get_rule, mcp__spec-kit__search_rules, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# kit-guidelines（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/kit-guidelines/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/kit-guidelines/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

---
name: specs-requirements
description: 要件定義工程の成果物（docs/specs/1_requirements/ の6ドキュメント）を作成・更新するための詳細ガイドとテンプレート。プロダクトビジョン・KPI・機能一覧・データモデル・技術選定・非機能要件・リポジトリ構造・用語集を、FR/NFRを採番して顧客提出レベルに体系化する。要件定義工程の成果物の作成・改訂時にのみ使用。
allowed-tools: Read, Write, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# specs-requirements（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/specs-requirements/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/specs-requirements/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

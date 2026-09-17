---
name: flow-setup-project
description: 初回セットアップのワークフロー。docs/ideas/ を入力に、要件定義工程の6ドキュメント(要件定義書・非機能要件定義書・機能概要・アーキテクチャ概要・リポジトリ構造・用語集)を specs-requirements スキルで対話的に作成する。プロジェクトの初期立ち上げ・永続ドキュメント一式の新規作成時に使用する。
allowed-tools: Read, Write, Edit, Glob, Bash, mcp__spec-kit__get_distribution_file, Skill, mcp__spec-kit__list_distribution
---

# flow-setup-project（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/flow-setup-project/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/flow-setup-project/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

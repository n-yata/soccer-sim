---
name: advise-devops
description: CI/CDパイプライン、コンテナ化(Docker/Kubernetes)、IaC(Terraform/CloudFormation)、デプロイ構成、監視・オブザーバビリティ、クラウドインフラ構築の相談に乗り、設定ファイルを作成する。GitHub Actions を設定したいとき、Dockerfile を書きたいとき、インフラをコード管理したいとき、デプロイやロールバックの手順を決めたいときに使用する。
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# advise-devops（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/advise-devops/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/advise-devops/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

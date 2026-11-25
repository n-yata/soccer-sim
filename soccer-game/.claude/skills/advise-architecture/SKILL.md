---
name: advise-architecture
description: システム設計・技術選定・スケーラビリティ・保守性・セキュリティアーキテクチャの相談に乗り、複数の設計案とトレードオフを示したうえで推奨案を提示する。新機能の設計方針を決めるとき、サービス分割やリファクタリング戦略を検討するとき、技術スタックを選定するとき、スケーラビリティの懸念があるときに使用する。アーキテクチャ概要そのものの作成・改訂は specs-requirements スキルを使う。
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# advise-architecture（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/advise-architecture/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/advise-architecture/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

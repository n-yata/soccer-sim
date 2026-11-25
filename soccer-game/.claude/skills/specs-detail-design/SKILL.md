---
name: specs-detail-design
description: 詳細設計工程の成果物(docs/specs/3_detail-design/ のテーブル定義書・API詳細設計書・画面詳細設計書)を作成・更新するための詳細ガイドとテンプレート。functional-overview.mdと2_basic-designの実装詳細を正本として、物理レベル・API単位・画面単位まで詳細化する。詳細設計工程の成果物の作成・改訂時にのみ使用。テストケース仕様書は specs-unit-test / specs-integration-test スキルが担当。
allowed-tools: Read, Write, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# specs-detail-design（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/specs-detail-design/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/specs-detail-design/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

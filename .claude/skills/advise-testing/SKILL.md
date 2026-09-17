---
name: advise-testing
description: テスト戦略の設計から実装まで、ソフトウェア品質全般の相談に乗る。ユニット/統合/E2Eの分担、テスト設計技法(境界値分析・同値分割)、モックの使い分け、カバレッジの考え方、フレーキーテストの診断を扱う。テストをどう設計するか迷ったとき、テストを書いてほしいとき、テストが壊れやすいときに使用する。テスト仕様書の作成は specs-unit-test / specs-integration-test スキルを使う。
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# advise-testing（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/advise-testing/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/advise-testing/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

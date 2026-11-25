---
name: specs-unit-test
description: 単体テスト仕様書(docs/specs/4_unit-test/ のAPI/画面ごとの実DB不要なテストケース一覧)を作成・更新するための詳細ガイドとテンプレート。specs-detail-designのAPI/画面詳細設計とreference/rules/testing.mdのテスト戦略を正本として、Domain/Service/Handler層(またはコンポーネント)の具体的な入力値・期待結果を列挙する。単体テスト仕様書の作成・改訂時にのみ使用。
allowed-tools: Read, Write, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# specs-unit-test（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/specs-unit-test/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/specs-unit-test/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

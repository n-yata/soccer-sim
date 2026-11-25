---
name: specs-basic-design
description: 基本設計工程の実装詳細(docs/specs/2_basic-design/ のコンポーネント設計・ユースケースのシーケンス図・画面設計・API設計)を作成・更新するための詳細ガイドとテンプレート。functional-overview.mdを正本として、レイヤー別インターフェース・画面のレイアウト/項目/イベント・APIの入出力を実装レベルまで詳細化する。基本設計工程の実装詳細の作成・改訂時にのみ使用。
allowed-tools: Read, Write, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# specs-basic-design（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/specs-basic-design/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/specs-basic-design/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

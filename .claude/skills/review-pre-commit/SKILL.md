---
name: review-pre-commit
description: コミット前の変更差分を、セキュリティ・バグ・性能・運用の4観点でレビューする。ハードコーディング検出、OWASP Top 10、静かに誤る欠陥、N+1やループ内I/O、ログ・設定・失敗時の挙動を検査し、Critical/High/Medium/Low に優先度分けした指摘を返す。コミット前の必須レビュー、認証・認可コードの実装後、新規エンドポイントの追加後、シークレットの取り扱いに迷ったときに使用する。
allowed-tools: Read, Grep, Glob, Bash, Task, Write, Edit, mcp__spec-kit__get_distribution_file, mcp__spec-kit__list_distribution
---

# review-pre-commit（薄型スタブ）

このスキルの正本は kit（spec-kit）にあり、本文は kit-mcp サーバーが配信する。
このファイルは本文を持たない薄型スタブである。**ここに手順は書かれていない。**

1. `mcp__spec-kit__get_distribution_file` で `distribution/skills/review-pre-commit/SKILL.md` を取得する
2. 取得した本文をこのスキルの指示として読み込み、それに従って実行する
3. 本文中の相対パス参照（`templates/...` `guides/...` 等）は
   `distribution/skills/review-pre-commit/` 配下のパスとして同ツールで取得する

> 🚨 **本文を取得できない場合は、推測や記憶で代替せずに停止する。**
> 「kit-mcp サーバー（spec-kit）に接続できない」と報告し、`.mcp.json` の
> 接続設定とサーバーの稼働をユーザーに確認してもらうこと。

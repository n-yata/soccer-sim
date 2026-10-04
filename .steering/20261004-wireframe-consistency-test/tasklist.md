# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**
- 未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ、理由を明記する

---

## フェーズ1: テスト実装

- [x] `src/router/wireframeConsistency.test.ts` を作成
  - [x] drawio の読み込みと XML 解析（parsererror で失敗）
  - [x] ルート名集合と `wireframe-*` slug 集合の一致
  - [x] 全ページの主ナビラベル列（絵文字除去）と AppHeader の一致
  - [x] 各ページの現在地（強調セルがちょうど1つ）と AppHeader の `aria-current` の一致
  - [x] 0件ガード
- [x] Red の確認（現在地を1か所ずらした drawio で落ちる）→ 元に戻して Green（変異3で兼ねて確認）

## フェーズ2: 検証機構の検証（変異注入）

- [x] 変異1: drawio のページ1枚を改名 → 落ちる
- [x] 変異2: drawio の主ナビラベル変更 → 落ちる
- [x] 変異3: drawio の現在地を別項目へ → 落ちる
- [x] 変異4: drawio の XML 破損 → 落ちる
- [x] 変異5: AppHeader.vue の主ナビ順序入れ替え → 落ちる
- [x] 各変異で、変異が実際に入ったこと・失敗メッセージにページ名が出ることを確認し、元に戻したことを `git status` で確認

## フェーズ3: ドキュメント

- [x] repository-structure.md の同時更新ルール「確認方法」に本テストを追記

## フェーズ4: 品質チェックと修正

- [x] `npm test`
- [x] `npm run lint`
- [x] `npm run typecheck`
- [x] `npm run build`
- [x] テストが実際に実行されたことを確認（実行件数・スキップ数）: 36ファイル・528件成功（追加18件）、スキップ0

## フェーズ5: レビューと振り返り

- [x] review-implementation を実施し指摘を反映（総合4.3/5。[必須]名前の無いルートの素通り→失敗させる検査を追加し変異で確認、[推奨]0件ガードのモジュール先頭化・検査の限界の明記・design.md 更新・強調色の大小文字を反映）
- [x] review-pre-commit を実施し review-report.md を出力（Critical/High 収束まで）: 第1回で Critical/High 0件
- [x] retrospective.md を作成

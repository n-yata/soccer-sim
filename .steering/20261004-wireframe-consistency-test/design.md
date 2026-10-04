# 設計書

## アーキテクチャ概要

テストのみの追加。本番コードは変更しない。テストは `src/router/` に置き、
正本（`router`・`AppHeader.vue`）と書き写し（`wireframes.drawio`）を突き合わせる。

```
wireframes.drawio ──(?raw で読む + DOMParser)─┐
src/router/index.ts ──(router.getRoutes())───┼──> wireframeConsistency.test.ts
AppHeader.vue ──(mount、ルート名を差し替え)──┘
```

## コンポーネント設計

### 1. `src/router/wireframeConsistency.test.ts`

**責務**:
- drawio を読み、ページ名 `wireframe-[slug]` と各ページの主ナビセル（id に `app-header-nav-` を含む）を抽出する
- ルート名集合・主ナビのラベル列・現在地を、実装から取得した値と比較する

**実装の要点**:
- drawio は Vite の `?raw` インポートで文字列として読む（当初は `node:fs` を予定したが、jsdom 環境で `import.meta.url` が file: にならないこと、プロジェクトに Node の型定義が無く typecheck が通らないことから変更）。
- XML の解析は jsdom の `DOMParser`（`application/xml`）。`parsererror` 要素があれば失敗させる。
- 主ナビの並びは drawio の x 座標順ではなく id の番号順（`app-header-nav-1`〜）で取る。生成時の id 規約に揃える。
- 現在地は drawio 上の強調色（`fontColor=#15803D`。大文字・小文字は区別しない）を持つセル。強調セルがちょうど1つであることも検査する。
- 主ナビの順序は id の番号で取るため、id を保ったまま見た目の位置だけ入れ替えた図は検出しない（テスト冒頭に限界として明記）。
- 絵文字の除去は「先頭の文字・数字以外を除去」（`/^[^\p{L}\p{N}]+/u`）とする。
- AppHeader の現在地は、`vue-router` の `useRoute` だけを差し替えてルート名ごとにマウントし、
  `aria-current` を持つリンクのテキストで取る（既存 `AppHeader.test.ts` と同じ手法）。
  `router/index.ts` は実物を使うため、`vi.mock` では実モジュールを展開して `useRoute` のみ上書きする。
- 0件ガード: ルート数・ページ数が0ならモジュール読み込み時に例外で止める（`it.each` が0件で空振りしないため）。各ページのナビ項目は、AppHeader 側の件数が1以上であることと `toEqual` で担保する。
- 名前の無いルートは `wireframe-[ルート名]` と対応づけられず検査から外れるため、存在すれば失敗させる。

## データフロー

1. drawio を読み、ページごとに `{ slug, navLabels, activeLabels }` を作る
2. `router.getRoutes()` からルート名集合を作る
3. AppHeader を各ルート名でマウントし `{ navLabels, activeLabel }` を得る
4. 比較

## エラーハンドリング戦略

- ファイル読み込み失敗・XML 破損は例外またはアサーション失敗としてテストを落とす（fail closed）。
- 失敗メッセージにページ名を含める（`expect(..., "wireframe-xxx の主ナビ")`）。

## テスト戦略

### ユニットテスト
- 本テスト自体が検査機構。testing 規約「検証機構そのものを検証する」に従い、次の変異を注入して落ちることと、
  失敗メッセージが読めることを確認する（変異が入ったことも出力で確認）:
  1. drawio のページ1枚を削除（または改名）
  2. drawio の主ナビ1項目のラベル変更
  3. drawio の現在地の強調を別項目へ移動
  4. drawio の XML を壊す
  5. AppHeader.vue の主ナビ順序を入れ替え

## 依存ライブラリ

追加なし（jsdom・@vue/test-utils は既存）。

## ディレクトリ構造

```
src/router/wireframeConsistency.test.ts             （新規）
docs/specs/1_requirements/repository-structure.md   （確認方法に本テストを追記）
```

## 実装の順序

1. テスト作成（Red を確認するため、まず drawio の現在地を1か所ずらした状態で落ちることを確認）
2. 正常系で Green
3. 変異注入5種
4. repository-structure.md 追記
5. 検証・レビュー・振り返り

## セキュリティ考慮事項

- テストは読み取りのみ。外部通信なし。

## パフォーマンス考慮事項

- drawio は約100KB。1回読むだけで、テスト時間への影響は軽微。

## 将来の拡張性

- タイトル・サブタイトル照合も同じ抽出関数に追加できる（今回は対象外）。

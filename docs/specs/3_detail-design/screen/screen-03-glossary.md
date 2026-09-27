# 画面詳細設計書: 用語集画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 用語集画面 |
| ルート(FE) | `/glossary` |
| 対応コンポーネント | `GlossaryPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-10 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面3: 用語集画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
GlossaryPage（単独。子コンポーネントは持たない）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `GlossaryPage` | — | なし（`data/soccerTerms.ts` を直接参照する `computed`: `groupedTerms`。カテゴリと該当用語配列の組を、該当0件のカテゴリを除外して保持する） |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/soccerTerms.ts`）を
直接インポートして参照する。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時）

1. `data/soccerTerms.ts` の `soccerTerms` をカテゴリ別（`SoccerTermCategory`）に
   グルーピングする。
2. カテゴリの表示順は、データ配列の登場順ではなく固定の `categoryOrder`
   （`["ポジション", "陣形・戦術", "攻守の考え方"]`）に従う。
3. 該当する用語が1件も無いカテゴリは、見出しごと表示しない。
4. カテゴリごとに、`<dl>`（定義リスト）直下へ用語1件ごとの`<div class="glossary-page__entry">`
   を配置し、その中に「用語（読み方）」を `<dt>`、説明を `<dd>` として描画する
   （2026-09-27追加。画面幅769px以上でのCSS `columns: 2` 段組み時に、`<dt>`/`<dd>`のペアが
   カラムの境目で分断されないよう`.glossary-page__entry`に`break-inside: avoid`を指定するための
   構造）。

### 一覧画面への遷移

1. ユーザーが`PageHeader`が表示する「← 戻る」（`BackButton`）をクリックする
   （2026-09-27より前は`router-link`による静的遷移だったが、他画面とヘッダーを統一する際に
   `BackButton`へ置き換えた）。
2. アプリ内遷移の履歴があれば`router.back()`で遷移元へ戻り、無ければ`fallback-to="/"`へ
   `router.push()`する（`ComparisonPage`/`MatrixPage`/`QuizPage`の「← 戻る」と同じ挙動）。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「← 戻る」をクリック | 履歴があれば遷移元、無ければ`/`（`FormationListPage`） | `BackButton`（`PageHeader`経由）による遷移 |

## 例外・エラー表示

**該当なし**: 本画面は静的データのみを参照し、APIエラー・ローディングは発生しない
（`screen-design.md`「画面共通の状態表現」参照）。`soccerTerms` が空配列の場合、
カテゴリ見出し・用語ともに1件も表示されないが、画面自体は正常に描画される
（エラー表示には切り替わらない）。

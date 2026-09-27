# 画面: 用語集画面 単体テスト仕様書

> 対象画面の詳細設計は
> [`screen-03-glossary.md`](../3_detail-design/screen/screen-03-glossary.md)。
> テスト方針全体は `<kit>/reference/rules/testing.md`「テストの種類と目安比率」を正本とする。
> 本書はコンポーネント単位のユニットテスト、および `data/soccerTerms.ts` のデータ整合性
> テストケースを列挙する。

## テスト対象

| コンポーネント / データ | テスト種別 |
|---|---|
| `soccerTerms`（`data/soccerTerms.ts`） | ユニットテスト（Vitest）。外部依存なしの静的データ |
| `GlossaryPage` | ユニットテスト（Vitest + Testing Library） |

## テストケース一覧

### soccerTerms（`data/soccerTerms.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 1 | 不変条件 | `soccerTerms` の全件の `id` を集める | `id` が一意である（重複が無い） | [x] |
| 2 | 不変条件 | `soccerTerms` の全件を検査する | `term`/`reading`/`description`/`category` がいずれも空でない文字列である | [x] |

### GlossaryPage

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 3 | 正常系 | マウントする | `soccerTerms` の全件について、`term` と `description` のテキストが表示される | [x] |
| 4 | 異常系 | `soccerTerms` を空配列にモックしてマウントする | `<dt>` が1件も描画されない。エラーにならず画面自体は正常に描画される | [x] |
| 5 | 正常系 | 「戻る」（アイコン: ArrowLeft）をクリックする（履歴が無い場合） | `router.push('/')` が1回呼ばれる | [x] |
| 6 | 正常系 | 「戻る」（アイコン: ArrowLeft）をクリックする（アプリ内遷移の履歴がある場合） | `router.back()` が1回呼ばれる | [x] |
| 7 | 正常系 | マウントする | 画面幅769px以上向けのCSSルールとして、`.glossary-page__list`に2カラム段組み（`columns`に`"2"`を含む）が定義されている（2026-09-27追加） | [x] |

## 備考

- `soccerTerms` は他エンティティと関連を持たない独立した静的データのため、単体テストは
  データ整合性の検証（id一意性・必須項目の非空）に限定する。
- `GlossaryPage` はデータ取得を伴わない単純な表示コンポーネントのため、正常系・空データ時の
  堅牢性・戻り導線の3観点でカバーする。

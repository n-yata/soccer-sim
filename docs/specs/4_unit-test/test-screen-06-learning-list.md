# 画面: 戦術学習一覧画面 単体テスト仕様書

> 対象画面の詳細設計は
> [`screen-06-learning-list.md`](../3_detail-design/screen/screen-06-learning-list.md)。
> テスト方針全体は `<kit>/reference/rules/testing.md`「テストの種類と目安比率」を正本とする。
> 本書はコンポーネント単位のユニットテスト（本画面はAPIを持たない）と、本画面が最初に参照する
> 教材の検索関数（`data/formationLessons.ts` の `getFormationLesson`）のテストケースを列挙する。
> 教材の中身（場面の選手・座標・解説の一貫性）は再生を扱う
> [`test-screen-07-formation-learning.md`](./test-screen-07-formation-learning.md) に置く。

## テスト対象

| コンポーネント / 関数 | テスト種別 |
|---|---|
| `getFormationLesson` / `formationLessons`（`data/formationLessons.ts`） | ユニットテスト（Vitest）。外部依存なしの静的データと検索関数 |
| `LearningListPage` | ユニットテスト（Vitest + Vue Test Utils。`createMemoryHistory` の実ルーターで `LearningListPage` と `FormationLearningPage` を登録して遷移を検証） |

## 前提データ（全テストケース共通）

`data/formations.ts` の実データ（8陣形）と `data/formationLessons.ts` の実データ（8教材）を使う。
No.13 のみ、教材の無い陣形を再現するため `getFormationLesson` をモックする。

## テストケース一覧

### getFormationLesson / formationLessons（`data/formationLessons.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 1 | 不変条件 | `formationLessons` の `formationId` を並べ替えて、`formations` の ID 一覧と比べる | 全8陣形の ID と過不足なく一致する（陣形ごとに教材が1件ずつある） | [x] |
| 2 | 不変条件 | 全教材の場面タイトル、各場面の全解説の座標（`frame`）を集める | タイトルも座標の並びも8種類すべて異なる（他陣形の教材の使い回しが無い） | [x] |
| 3 | 異常系 | `getFormationLesson("unknown")` を呼ぶ | `undefined` を返す | [x] |
| 4 | 境界値 | `getFormationLesson("")` を呼ぶ | `undefined` を返す | [x] |

### LearningListPage

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 5 | 正常系 | `/learn` を表示する | 学習カード（`.learning-list-page__card`）が8枚描画される | [x] |
| 6 | 正常系 | 各陣形のカードを確認する | カードは `/formations/{陣形ID}/learn` へのリンクで、陣形名と教材の目的（`lesson.objective`）を含む | [x] |
| 7 | 正常系 | 各カードの中を確認する | `button` 要素が無い（比較の選択操作を置かない） | [x] |
| 8 | 正常系 | 3-4-3 のカードをクリックする | 陣形学習画面へ遷移し、見出し（`h1`）が「3-4-3を学ぶ」になる | [x] |
| 9 | 正常系 | No.8 の後に「← 学習一覧へ」をクリックする | 学習一覧へ戻り、見出し（`h1`）が「戦術を学ぶ」になる | [x] |
| 10 | 正常系 | 各陣形のカードを確認する | 場面タイトル（`lesson.scene.title`）が `h3` に表示される（例: 4-3-3 のカードに「サイドの2対1」） | [ ] |
| 11 | 正常系 | 各陣形のカードの `aria-label` を確認する | 「{陣形名}を学ぶ：{場面タイトル}」になる（例: 「4-3-3を学ぶ：サイドの2対1」） | [ ] |
| 12 | 正常系 | 各カードを確認する | ミニピッチ図（`FormationMiniPitch` の `svg`）が1つずつ描画される | [ ] |
| 13 | 異常系 | `getFormationLesson` が 4-4-2 だけ `undefined` を返すようモックして表示する | カードが7枚になり、4-4-2 のカード（`/formations/4-4-2/learn` へのリンク）は描画されない。エラー表示は出ない | [ ] |
| 14 | 正常系 | `/learn` を表示する | ヘッダーに戻るボタン（`BackButton`）が無い（主ナビから開くトップレベル画面のため） | [ ] |

## 備考

- No.1〜4、5〜9 は既存テストに対応する（`src/data/formationLessons.test.ts`「全8陣形にそれぞれ異なる教材を用意する」
  「不明IDは教材を返さない」、`src/pages/LearningListPage.test.ts`「8陣形の目的を示し、実ルーターで教材へ進み
  学習一覧へ戻れる」）。
- No.10〜14 は詳細設計書に記載した振る舞いのうち、現時点で対応するテストが無いもの。完了欄は `[ ]` のまま
  残し、テストを追加した時点で `[x]` にする（未実装を実装済みに見せないため）。
- No.13 は現在の静的データでは発生しない（No.1 が全陣形分の教材の存在を保証する）が、
  `flatMap` による除外の分岐を独立に検証する防御的なケースである。

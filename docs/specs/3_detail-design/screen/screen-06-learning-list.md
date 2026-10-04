# 画面詳細設計書: 戦術学習一覧画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 戦術学習一覧画面 |
| ルート(FE) | `/learn` |
| 対応コンポーネント | `LearningListPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-20 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面6: 戦術学習一覧画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
LearningListPage
├── PageHeader（タイトル・サブタイトル。戻るボタンなし）
└── 学習カード × 教材のある陣形の数（router-link）
    └── FormationMiniPitch（カード内のミニピッチ図）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `LearningListPage` | — | なし。`learningFormations`（`{ formation, lesson }[]`）はマウント時（`<script setup>` の実行時）に1回組み立てる非リアクティブな定数で、リアクティブな state を持たない |
| `PageHeader` | `title="戦術を学ぶ"`, `subtitle`（固定文言） | — |
| `FormationMiniPitch` | `formation: Formation` | — |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`,
`data/formationLessons.ts`）を直接参照する。静的データは実行中に変化しないため、`ref` / `computed`
も使わない。

## 画面遷移・イベント処理の詳細フロー

### 画面表示

1. `data/formations.ts` の `formations` を配列の順に走査する。
2. 各陣形について `getFormationLesson(formation.id)` を呼び、教材が見つかった陣形だけを
   `{ formation, lesson }` として `learningFormations` に残す（`flatMap` で教材の無い陣形を除く）。
3. `learningFormations` の順にカードを描画する。カードには、ミニピッチ図・陣形名（`h2`）・
   場面タイトル（`lesson.scene.title`、`h3`）・教材の目的（`lesson.objective`）・
   「この陣形を学ぶ →」を表示する。
4. カード全体を `router-link` 1つにし、`aria-label` を
   「{陣形名}を学ぶ：{場面タイトル}」とする（カード内の複数のテキストを読み上げで1文にまとめるため）。
   カード内にボタン等の操作要素は置かない（比較の選択操作と混同させないため）。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 学習カードをクリック | `/formations/:formationId/learn`（`FormationLearningPage`） | `router-link` による静的遷移 |
| 主ナビの各項目をクリック | 各画面 | `AppHeader` の責務（本画面は関与しない） |

## 例外・エラー表示

- **教材の無い陣形**: カードを表示しない（`getFormationLesson` が `undefined` の陣形を除外する）。
  エラー表示は出さない。現在は全8陣形に教材があり、`formationLessons.test.ts` が全陣形分の教材の
  存在を検証している。
- **陣形が0件・教材が0件**: カードが1枚も描画されない（グリッドが空になる）。静的データでは
  発生しないため、空状態の専用表示は持たない（`screen-design.md`「画面共通の状態表現」の「空」）。

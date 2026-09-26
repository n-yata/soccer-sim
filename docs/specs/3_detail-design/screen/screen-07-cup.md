# 画面詳細設計書: カップ戦画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | カップ戦画面 |
| ルート(FE) | `/cup` |
| 対応コンポーネント | `CupPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-17 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面7: カップ戦画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
CupPage
└── BackButton（fallback-to="/" を渡す。共有コンポーネント）
    ※ブラケットはテンプレート内で直接描画する（他に子コンポーネントは持たない）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `CupPage` | — | `cup: CupSimulationResult \| null`（`runCupSimulation(formations, getMatchup)`を`computed`で1回だけ実行した結果。`formations.length !== 8`・マッチアップ欠落時は`catch`して`null`）。`rounds: { title, matches }[]`（`cup`から準々決勝/準決勝/決勝の3セクションを組み立てる算出プロパティ） |
| `BackButton` | `fallback-to="/"` | なし（表示専用。共有コンポーネント。`component-design.md`参照） |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、`formations`（静的データ）と
`composables/cupSimulation.ts`の`runCupSimulation`を直接呼び出して参照する。`LeaguePage`と
同じ方針で、結果は`computed`で実質1回しか計算されない。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時）

1. `computed`が`runCupSimulation(formations, getMatchup)`を呼ぶ。
2. 成功した場合、`cup`に`{ quarterfinals, semifinals, final, championId, championName }`が
   設定される。テンプレート側は「🏆 優勝: {{cup.championName}}」の見出しと、
   `rounds`（準々決勝・準決勝・決勝の3セクション）を表示する。各対戦カードは
   フォーメーションA名・スコア（PK戦の場合`(PK {{penaltyScoreA}}-{{penaltyScoreB}})`を付記）・
   フォーメーションB名を表示し、`match.winnerId`と一致する側に`cup-page__winner`クラス・
   🏆アイコン（`aria-hidden`）・視覚的に隠した「（勝者）」テキストを付与する。
3. `runCupSimulation`が`formations.length !== 8`、またはマッチアップ欠落で`Error`を投げた
   場合、`console.error`でログを残したうえで`catch`して`cup`を`null`にする。テンプレート側は
   エラー表示に切り替える。

### 対戦カードからの比較画面遷移

1. ユーザーが対戦カード（`router-link`）をクリックする。
2. `/compare/:formationAId/:formationBId`（`ComparisonPage`）へ遷移する。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 対戦カードをクリック | `/compare/:formationAId/:formationBId`（`ComparisonPage`） | `router-link`による静的遷移。準々決勝・準決勝・決勝いずれのカードからも遷移できる |
| 「← 戻る」をクリック | 履歴があれば遷移元（`FormationListPage`）、無ければ`/` | 共有コンポーネント`BackButton`（`fallback-to="/"`）による |
| エラー表示中のリンクをクリック | `/`（`FormationListPage`） | — |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| `formations.length !== 8`（データ追加等でカップ戦の前提である8件固定が崩れた場合） | 「カップ戦を集計できませんでした」のメッセージと一覧画面へのリンクを表示し、ブラケットは表示しない。`console.error`にエラー内容を残す |
| `runCupSimulation`がマッチアップ欠落で`Error`を投げる（開発時に用意する静的データが不完全な場合。通常発生しない） | 上記と同じエラー表示。`console.error`にエラー内容を残す |

> **`FormationListPage`側の導線制御**: `formations.length === 8`のときのみ「🥇 カップ戦」
> ボタンを表示する（`CUP_REQUIRED_FORMATION_COUNT`定数で判定）。これにより、8件以外の状態で
> 本画面へ遷移し必ずエラー表示になる導線を、一覧画面側で未然に防ぐ。

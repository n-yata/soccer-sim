# 画面詳細設計書: リーグ戦画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | リーグ戦画面 |
| ルート(FE) | `/league` |
| 対応コンポーネント | `LeaguePage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-16 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面6: リーグ戦画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
LeaguePage
└── BackButton（fallback-to="/" を渡す。共有コンポーネント）
    ※順位表・全対戦結果一覧はテンプレート内で直接描画する（他に子コンポーネントは持たない）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `LeaguePage` | — | `league: LeagueSimulationResult \| null`（`runLeagueSimulation(formations, getMatchup)`を`computed`で1回だけ実行した結果。マッチアップ欠落時は`catch`して`null`） |
| `BackButton` | `fallback-to="/"` | なし（表示専用。共有コンポーネント。`component-design.md`参照） |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、`formations`（静的データ）と
`composables/leagueSimulation.ts`の`runLeagueSimulation`を直接呼び出して参照する。
`formations`は実行中に変化しないため、`computed`の依存が変わらず実質1回しか再計算されない
（`ComparisonPage`の`matchup`と同じ方針）。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時）

1. `computed`が`runLeagueSimulation(formations, getMatchup)`を呼ぶ。
2. 成功した場合、`league`に`{ standings, matches }`が設定される。テンプレート側は
   `standings`を順位表（順位・フォーメーション名・試合数・勝/分/敗・得点/失点・得失点差
   （符号付き。`formatSigned`で組み立て）・勝ち点の列）として、`matches`を「全対戦結果」の
   見出し付きリストとして表示する。
3. `runLeagueSimulation`がマッチアップ欠落（データ不整合）で`Error`を投げた場合、
   `catch`して`league`を`null`にする。テンプレート側はエラー表示に切り替える。

### 全対戦結果からの比較画面遷移

1. ユーザーが全対戦結果一覧の1件（`router-link`）をクリックする。
2. `/compare/:formationAId/:formationBId`（`ComparisonPage`）へ遷移する。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 全対戦結果の行をクリック | `/compare/:formationAId/:formationBId`（`ComparisonPage`） | `router-link`による静的遷移 |
| 「← 戻る」をクリック | 履歴があれば遷移元（`FormationListPage`）、無ければ`/` | 共有コンポーネント`BackButton`（`fallback-to="/"`）による（`router.back()`/`router.push('/')`の判定はBackButton側に集約されている） |
| エラー表示中のリンクをクリック | `/`（`FormationListPage`） | — |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| `runLeagueSimulation`がマッチアップ欠落で`Error`を投げる（開発時に用意する静的データが不完全な場合。通常発生しない） | 「リーグ戦を集計できませんでした」のメッセージと一覧画面へのリンクを表示し、順位表・全対戦結果一覧は表示しない |

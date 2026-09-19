# 設計書

## アーキテクチャ概要

既存の2層構成（UIレイヤー ⇄ 静的データ）と、`composables/` は `data/` に依存しないという既存方針
（`src/composables/matchSimulation.ts` 冒頭コメント）をそのまま踏襲する。

リーグ戦の集計ロジックは新規 `src/composables/leagueSimulation.ts` に置く。`data/` 層への依存を
避けるため、`getMatchup`（`data/matchups.ts`）は呼び出し側（`LeaguePage.vue`）から関数として注入する
（`Formation[]` も同様に呼び出し側から渡す）。`simulateMatch` は同じ `composables/` 層なので通常の
import で構わない（デフォルト引数として注入可能にし、テストでは決定的なスタブに差し替える）。

```
FormationListPage.vue ──router-link──▶ LeaguePage.vue
                                          │
                                          ├─ formations (data/formations.ts)
                                          ├─ getMatchup (data/matchups.ts)
                                          │
                                          ▼
                          composables/leagueSimulation.ts
                          runLeagueSimulation(formations, getMatchupFn, simulateMatchFn = simulateMatch)
                                          │
                                          ├─ 28試合を simulateMatch で実行
                                          ├─ 順位表（LeagueStanding[]）を集計
                                          └─ 全試合結果（LeagueMatchResult[]）を保持
```

## コンポーネント設計

### 1. `composables/leagueSimulation.ts`（新規）

**責務**:
- 渡された `Formation[]`（8件）から総当たり1回戦の組み合わせ（全 `n(n-1)/2` = 28通り、i<jの組のみ）を生成する
- 各組み合わせについて `getMatchupFn` でマッチアップを取得し、`simulateMatchFn` で試合を実行する
- 試合結果から各フォーメーションの試合数・勝敗・得失点・勝ち点を集計し、順位を算出する

**実装の要点**:
- `data/` への依存を持たない。`getMatchupFn` は関数として引数で受け取る（`Shuffle` 型と同じ DI パターン）
- `simulateMatchFn` は既定値 `simulateMatch`（同一レイヤーなので直接 import）。テストでは固定スコアを返す
  スタブに差し替え、順位のタイブレークを狙って検証できるようにする
- マッチアップが見つからない組み合わせ（`getMatchupFn` が `undefined` を返す）は、
  データ不整合（本来存在しないはずの欠落）として `Error` を投げる。フォールバック表示で
  握りつぶすと「集計が静かに欠けたまま完走する」事故になるため、明示的に落とす
  （既存の `matchups.test.ts`「全組み合わせのMatchup存在検証」がこの前提を別途保証している）
- 勝敗判定は `MatchSimulationResult.score` の比較のみで行う（`overallEdge` は使わない。
  スコアが実際の勝敗であり、`overallEdge` はシミュレーション前の事前評価に過ぎないため）
- 順位算出はスポーツの標準的な「同着順位」方式（1, 2, 2, 4, ...）。
  比較キーは `[勝ち点, 得失点差, 総得点]` の降順、すべて一致する場合のみ同順位とする

**型定義**（`src/types/formation.ts` に追加）:
```ts
export interface LeagueStanding {
  formationId: string;
  formationName: string;
  rank: number;
  played: number;
  win: number;
  draw: number;
  lose: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDifference: number;
  points: number;
}

export interface LeagueMatchResult {
  formationAId: string;
  formationAName: string;
  formationBId: string;
  formationBName: string;
  scoreA: number;
  scoreB: number;
}

export interface LeagueSimulationResult {
  standings: LeagueStanding[];
  matches: LeagueMatchResult[];
}
```

**公開関数シグネチャ**:
```ts
export function runLeagueSimulation(
  formations: Formation[],
  getMatchupFn: (formationAId: string, formationBId: string) => Matchup | undefined,
  simulateMatchFn: (a: Formation, b: Formation, matchup: Matchup) => MatchSimulationResult = simulateMatch,
): LeagueSimulationResult
```

### 2. `pages/LeaguePage.vue`（新規）

**責務**:
- `/league` ルートの画面。`formations` と `getMatchup` を渡して `runLeagueSimulation` を実行し、
  「順位表」と「全対戦結果一覧」の2セクションを表示する
- 一覧画面への「戻る」導線を持つ（`MatrixPage.vue` の `goBack` パターンを踏襲）

**実装の要点**:
- 順位表: 順位・フォーメーション名・試合数・勝/分/敗・得点/失点/得失点差・勝ち点の列を持つ `<table>`
- 全対戦結果一覧: 28試合を `LeagueMatchResult` からそのままリスト表示し、各行の
  「対戦カードを見る」的なリンクで `/compare/:formationAId/:formationBId` へ遷移できるようにする。
  → **未決事項の解決**: 順位表の1行は「1チームの7試合の集計」であり、単独の比較画面
  （2チーム間）に自然には対応しない。そのため比較画面への遷移導線は「全対戦結果一覧」側の
  各試合行に持たせる（`MatrixPage.vue` のセルと同じ `router-link :to="/compare/${a}/${b}"` パターン）。
  順位表側は遷移導線を持たない
- `runLeagueSimulation` は `computed` で1回だけ実行する（`formations` は静的データで変化しないため、
  再計算は不要。`MatrixPage.vue` の `progress` 同様、マウント時に確定させてよい）
- スタイルは `MatrixPage.vue` の配色・トークン（`var(--color-team-a)` 等）をそのまま踏襲する

## データフロー

### リーグ戦画面を開く
```
1. FormationListPage.vue のヘッダーから「🏆 リーグ戦」導線をクリック
2. router が /league へ遷移、LeaguePage.vue がマウントされる
3. computed が formations + getMatchup を渡して runLeagueSimulation を実行
4. 28試合分の simulateMatch が決定的に実行され、standings・matches が確定する
5. 順位表と全対戦結果一覧が描画される
6. 全対戦結果一覧の行から /compare/:a/:b へ遷移できる
```

## エラーハンドリング戦略

- `runLeagueSimulation` はマッチアップ欠落時に `Error` を投げる（上記「実装の要点」参照）。
  本プロダクトの他画面同様、開発時に用意する静的データが完全である前提のため、
  ユーザー向けの try/catch は追加しない（既存の「異なるフォーメーション同士でのマッチアップ未検出は
  通常運用では発生しない」という `functional-overview.md` の確定事項と整合させる）

## テスト戦略

### ユニットテスト（`src/composables/leagueSimulation.test.ts`）
- 実データ（`data/formations.ts` の8件 + `data/matchups.ts` の `getMatchup`）を使い:
  - 各フォーメーションの `played` が7であること
  - 同一フォーメーション同士の対戦が `matches` に含まれないこと（`matches.length === 28`）
  - 各行の `win + draw + lose === played`
  - `goalDifference === goalsFor - goalsAgainst`
  - `points === win * 3 + draw`
  - 2回実行して結果が完全一致すること（決定性）
- 固定スコアを返すスタブ `simulateMatchFn` を注入したフェイク `Formation[]`（3〜4件）を使い:
  - 勝ち点・得失点差・総得点が完全に同じ2チームが同順位（同じ `rank` 値）になること
  - 標準的な同着順位方式（1, 2, 2, 4 ...）で採番されること
  - マッチアップ欠落（`getMatchupFn` が `undefined` を返すケース）で `Error` が投げられること

### 統合テスト
- 本プロダクトはE2Eフレームワークを導入していないため対象外（既存方針を踏襲）。
  `LeaguePage.vue` の表示確認は `npm run dev` での目視確認で代替する

## 依存ライブラリ

新規ライブラリの追加なし。

## ディレクトリ構造

```
src/
  composables/
    leagueSimulation.ts        (新規)
    leagueSimulation.test.ts   (新規)
  pages/
    LeaguePage.vue             (新規)
  types/
    formation.ts               (変更: LeagueStanding / LeagueMatchResult / LeagueSimulationResult 追加)
  router/
    index.ts                   (変更: /league ルート追加)
  pages/
    FormationListPage.vue      (変更: ヘッダーに「🏆 リーグ戦」導線追加)
```

## 実装の順序

1. `types/formation.ts` に型を追加
2. `composables/leagueSimulation.ts` を実装
3. `composables/leagueSimulation.test.ts` を実装し、パスすることを確認
4. `pages/LeaguePage.vue` を実装
5. `router/index.ts` にルートを追加
6. `FormationListPage.vue` に導線を追加
7. 型検査・リント・テスト・ビルドを実行

## セキュリティ考慮事項

- 外部入力・ユーザー入力を扱わない（静的データのみ）ため、追加のセキュリティ対策は不要

## パフォーマンス考慮事項

- 28試合 × 90分ループの計算量は小規模で、既存の `MatrixPage.vue`（N×N表示、N=8）と同等以下。
  性能上の懸念はない

## 将来の拡張性

- フォーメーションが `data/formations.ts` に追加されれば、`runLeagueSimulation` は
  `n(n-1)/2` 試合へ自動的に拡張される（NFR-03と整合、`.vue` の変更は不要）

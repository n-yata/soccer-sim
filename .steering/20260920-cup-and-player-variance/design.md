# 設計書

## アーキテクチャ概要

既存の3層構成（UIレイヤー ⇄ `composables/`（ロジック層）⇄ `data/`（静的データ）、
`architecture-overview.md`）をそのまま踏襲する。`composables/` は `data/` に依存しないという
既存方針（`leagueSimulation.ts` と同じDIパターン）を、新設する `cupSimulation.ts` にも適用する。
`squadCondition.ts` は `Formation`/`FormationStats` の型のみに依存する純粋関数群とし、
`data/` にも他の `composables/` にも依存しない（`matchSimulation.ts` からの決定的乱数関連の
ユーティリティのみ再利用する）。

```
FormationListPage.vue ──router-link──▶ CupPage.vue
                                          │
                                          ├─ formations (data/formations.ts, 8件)
                                          ├─ getMatchup (data/matchups.ts)
                                          │
                                          ▼
                          composables/cupSimulation.ts
                          runCupSimulation(formations, getMatchupFn, simulateMatchFn = simulateMatch)
                                          │
                                          ├─ 準々決勝4試合 → 勝者4チーム
                                          ├─ 準決勝2試合 → 勝者2チーム
                                          ├─ 決勝1試合 → 優勝チーム
                                          └─ 同点なら composables/matchSimulation.ts の
                                             mulberry32/fnv1aHash を再利用してPK戦を決定的に実行

ComparisonPage.vue ──状態(squadConditionSeed)──▶ composables/squadCondition.ts
                                                    │
                                                    └─ applySquadVariance(stats, seed)
                                                       → simulateMatch にのみ渡す実効stats
                                                       （レーダー・優位ポイントには不使用）
```

## コンポーネント設計

### 1. `composables/matchSimulation.ts`（変更: 既存の内部ユーティリティをexport）

**責務の変更点**:
- 既存の非公開関数 `mulberry32` / `fnv1aHash` / `clamp` を `export` する。
  PK戦（`cupSimulation.ts`）と選手個体差（`squadCondition.ts`）の両方が同じ
  「シードから決定的な乱数列を作る」「安全にクランプする」処理を必要とするため、
  同一の `composables/` 層内での再利用として素直にimportする
  （`matchSimulation.ts`冒頭コメントの「data/への依存を避けるための重複」とは別の話で、
  こちらは同一レイヤー内の共通ユーティリティなので重複させない）。
- ロジックの変更は無し（露出範囲の変更のみ）。

### 2. `composables/cupSimulation.ts`（新規）

**責務**:
- 8フォーメーション固定のノックアウト方式トーナメント（準々決勝4試合→準決勝2試合→決勝1試合）を、
  既存の `simulateMatch` を使って決定的に実行する。
- 90分で同点の場合、`matchup.id` から導出した別シードでPK戦を決定的に実行し、必ず勝者を1人決める。

**実装の要点**:
- 対戦カードの組み方は「渡された `formations` 配列の並び順」を固定シードとする。
  `[0]vs[1], [2]vs[3], [4]vs[5], [6]vs[7]` を準々決勝とし、勝者を配列順のまま
  `QF0勝者 vs QF1勝者`, `QF2勝者 vs QF3勝者` で準決勝を組む。
- `formations.length !== 8` の場合は `Error` を投げる（要求書の未決事項どおり、今回は
  8種類固定。9種類以上への拡張時の不戦勝対応は将来課題としてコード化しない）。
- PK戦のシードは `fnv1aHash(`${matchup.id}_pk`)`（`matchSimulation.ts` からexportした
  `fnv1aHash`/`mulberry32` を再利用）。90分の試合本体のシード（`matchup.id` そのもの）とは
  別の文字列にすることで、PK戦の乱数列が試合本体の乱数列（`runCanonicalSimulation`）と
  独立し、互いに影響しない。
- PK戦は5人ずつのキッカーがGK成功率一定（`PK_SUCCESS_PROBABILITY = 0.75`。実際のPK成功率の
  目安値）で決定的に順にシュートし、5人終了時点で同点ならサドンデス（1人ずつ交互に、
  どちらか一方だけが決めた時点で打ち切り）で必ず決着させる。フォーメーションの`stats`は
  PK戦の確率には反映しない（現実のPKも技術・メンタルの要素が大きく、陣形の戦術的特性とは
  独立事象として扱う方が単純で実装コストに見合う）。
- マッチアップが見つからない組み合わせは `leagueSimulation.ts` と同じ方針で `Error` を投げる
  （データ不整合を握りつぶさない）。

**型定義**（`src/types/formation.ts` に追加）:
```ts
export interface CupMatch {
  round: 1 | 2 | 3; // 1=準々決勝 2=準決勝 3=決勝
  formationAId: string;
  formationAName: string;
  formationBId: string;
  formationBName: string;
  scoreA: number;
  scoreB: number;
  // 90分で同点だった場合のみtrue。falseの場合penaltyScoreA/Bはundefined
  wentToPenalties: boolean;
  penaltyScoreA?: number;
  penaltyScoreB?: number;
  winnerId: string;
  winnerName: string;
}

export interface CupSimulationResult {
  quarterfinals: CupMatch[]; // 4件、入力formationsの並び順([0]vs[1], [2]vs[3], ...)
  semifinals: CupMatch[]; // 2件
  final: CupMatch; // 1件
  championId: string;
  championName: string;
}
```

**公開関数シグネチャ**:
```ts
export function runCupSimulation(
  formations: Formation[], // 必ず8件
  getMatchupFn: (formationAId: string, formationBId: string) => Matchup | undefined,
  simulateMatchFn: (a: Formation, b: Formation, matchup: Matchup) => MatchSimulationResult = simulateMatch,
): CupSimulationResult
```

### 3. `composables/squadCondition.ts`（新規）

**責務**:
- 「選手個体差（スカッドコンディション）」として、フォーメーションの5軸`stats`に
  シードベースの小さな乱数変動（±10%）を加えた実効statsを算出する純粋関数を提供する。
- 影響範囲は呼び出し側（`ComparisonPage.vue`）が `simulateMatch` に渡すFormationのstatsに
  限定する。この関数自体は他のロジック（マッチアップ判定・タグ導出）を一切呼ばない。

**実装の要点**:
- `matchSimulation.ts` からexportした `mulberry32` / `clamp` を再利用する（`data/` には
  依存しない）。
- 変動幅は5軸それぞれ独立して `factor = 1 + (random() * 2 - 1) * 0.1`（0.9〜1.1倍）とし、
  結果を四捨五入したうえで0〜100にクランプする。
- シード値は呼び出し側（UI）が管理する。同じシードを渡せば常に同じ実効statsになる
  （決定性）。シード自体の生成方法（乱数生成のタイミング）はUI層の責務とし、この関数は
  「シード→実効stats」の純粋関数であることに専念する。

**公開関数シグネチャ**:
```ts
export function applySquadVariance(stats: FormationStats, seed: number): FormationStats
```

### 4. `components/SquadConditionControls.vue`（新規）

**責務**:
- 比較画面に「選手個体差」の有効化トグルと再生成ボタンを表示する。
- `FreeLayoutControls.vue` と同じ見た目・実装パターン（ボタン2つ、`aria-pressed`で状態表示）を踏襲する。

**Props/Emits**:
```ts
defineProps<{ isActive: boolean }>();
defineEmits<{ toggle: []; reroll: [] }>();
```
- `toggle`: 有効/無効を切り替える（無効化時は呼び出し側でシードをnullに戻す）
- `reroll`: 有効な状態で新しいシードを引き直す（トグルON直後にも1回自動発火させる想定は
  呼び出し側=`ComparisonPage.vue`の責務とする）

### 5. `pages/CupPage.vue`（新規）

**責務**:
- `/cup` ルートの画面。`formations`（8件）と `getMatchup` を渡して `runCupSimulation` を実行し、
  準々決勝・準決勝・決勝の3ラウンドをブラケット形式で表示する。
- 各対戦カードから `/compare/:formationAId/:formationBId` へ遷移できる。
- 優勝フォーメーションを見出しで明示する。

**実装の要点**:
- `runCupSimulation` は `computed` で1回だけ実行する（`LeaguePage.vue`の`progress`と同じ、
  静的データに対する決定的計算のため再計算不要）。
- 各ラウンドを縦に並べたシンプルな表形式（ブラケット風のCSS Gridは今回不要。可読性優先で
  「準々決勝」「準決勝」「決勝」の見出し付きリストとする。将来デザイン強化の余地は残す）。
- PK戦になった試合は「PK 4-3」のように付記する（`wentToPenalties`が true の行のみ）。
- 一覧画面への「戻る」導線は `MatrixPage.vue`/`LeaguePage.vue` の `goBack` パターンを踏襲する。

### 6. `pages/ComparisonPage.vue`（変更）

**変更点**:
- `squadConditionSeed = ref<number | null>(null)` を追加。`null` は無効を表す。
- `SquadConditionControls` を `FreeLayoutControls` の下に配置する。
- `toggle` ハンドラ: 無効→有効化時は新しいシードを生成して即座にセットする（有効化した瞬間から
  効果が分かるように）。有効→無効化時は `null` に戻し、`simulationResult` を破棄する
  （既存の自由配置トグルOFF時の破棄方針と同じ）。
- `reroll` ハンドラ: 有効時のみ新しいシードを生成し直し、`simulationResult` を破棄する。
- `runSimulation` 内で、`squadConditionSeed.value` が非nullなら
  `applySquadVariance(formationA.value.stats, squadConditionSeed.value)` /
  `applySquadVariance(formationB.value.stats, squadConditionSeed.value + 1)`（A/Bで異なる
  乱数列にするため+1でオフセットする）で実効statsを算出した一時的な `Formation` オブジェクトを
  作り、`simulateMatch` にはそちらを渡す。`formationA.value`/`formationB.value` 自体は
  書き換えない（レーダーチャート・優位ポイントは常に元のstatsを参照し続ける）。
- 既存の「組み合わせ変更時にリセットする」`watch`（`simulationResult`・`isFreeLayoutMode`・
  `freePositionsA` をリセットしている箇所）に `squadConditionSeed.value = null` を追加する。
- シード生成自体（`Math.random()`ベースで整数を1つ引く）はコンポーネント内のローカル関数
  `generateSeed()` とし、`composables/squadCondition.ts` には持たせない
  （シードの「引き方」はUIの関心事、「シードから実効statsを作る」のは`composables/`の関心事、
  という責務分離を保つため）。

## データフロー

### カップ戦画面を開く
```
1. FormationListPage.vue のヘッダーから「🥇 カップ戦」導線をクリック
2. router が /cup へ遷移、CupPage.vue がマウントされる
3. computed が formations(8件) + getMatchup を渡して runCupSimulation を実行
4. 準々決勝4試合 → 準決勝2試合 → 決勝1試合が決定的に実行され、同点の試合はPK戦まで実行される
5. 3ラウンドのブラケットと優勝フォーメーションが描画される
6. 各対戦カードの行から /compare/:a/:b へ遷移できる
```

### 比較画面で選手個体差を有効にして試合をシミュレートする
```
1. 比較画面で「選手個体差」トグルをON → squadConditionSeedにランダムな初期シードがセットされる
2. 「試合をシミュレートする」を押すと、runSimulationがsquadConditionSeedを検出し、
   formationA/Bのstatsにapplyされた実効statsを持つ一時Formationを作ってsimulateMatchへ渡す
3. 結果が表示される。レーダーチャート・優位ポイントは元のstatsのまま変化しない
4. 「スカッドを組み直す」を押すと新しいシードが選ばれ、simulationResultが破棄される
   （再度「試合をシミュレートする」を押すまで新しい結果は表示されない）
```

## エラーハンドリング戦略

- `runCupSimulation` は `formations.length !== 8` およびマッチアップ欠落時に `Error` を投げる
  （`runLeagueSimulation` と同じ方針。本プロダクトの静的データが完全である前提のため、
  ユーザー向けtry/catchは追加しない）。
- `applySquadVariance` はユーザー入力を扱わない純粋関数であり、例外を投げる経路を持たない
  （`stats`は常に静的データ由来の有限な数値のため）。

## テスト戦略

### ユニットテスト（`src/composables/cupSimulation.test.ts`）
- 実データ（`data/formations.ts` の8件 + `data/matchups.ts` の `getMatchup`）を使い:
  - `quarterfinals.length === 4`, `semifinals.length === 2`, `final` が1件存在すること
  - 準々決勝の対戦カードが `formations` の並び順どおり（[0]vs[1], [2]vs[3], ...）であること
  - 準決勝の対戦カードが対応する準々決勝の勝者同士になっていること
  - `championId` が決勝の `winnerId` と一致すること
  - 2回実行して結果が完全一致すること（決定性）
- 固定スコアを返すスタブ `simulateMatchFn` を注入したフェイク `Formation[]`（8件）を使い:
  - 同点スコアを返すスタブで `wentToPenalties === true` になり、`penaltyScoreA !== penaltyScoreB`
    （必ず勝者が決まる）こと
  - 同じシード（同じmatchup.id）なら同じPK結果になること（決定性）
  - `formations.length !== 8` で `Error` が投げられること
  - マッチアップ欠落（`getMatchupFn` が `undefined` を返すケース）で `Error` が投げられること

### ユニットテスト（`src/composables/squadCondition.test.ts`）
- 全軸が変動範囲（元の値の90%〜110%、かつ0〜100にクランプ）に収まること
- 同じ `stats`・同じ `seed` なら常に同じ結果になること（決定性）
- 異なる `seed` なら（十分な確率で）異なる結果になること（複数シードで結果セットに重複が
  無いことを確認する形で検証する）
- 元の `stats` オブジェクトを変更しないこと（イミュータブル）

### 統合テスト
- 本プロダクトはE2Eフレームワークを導入していないため対象外（既存方針を踏襲）。
  `CupPage.vue`・`ComparisonPage.vue`の選手個体差UIは `npm run dev` での目視確認で代替する。
  既存の `ComparisonPage.test.ts` は無効時（デフォルト）の挙動を変えないため、既存テストは
  そのまま通ることを確認する。

## 依存ライブラリ

新規ライブラリの追加なし。

## ディレクトリ構造

```
src/
  composables/
    matchSimulation.ts         (変更: mulberry32/fnv1aHash/clampをexport)
    cupSimulation.ts           (新規)
    cupSimulation.test.ts      (新規)
    squadCondition.ts          (新規)
    squadCondition.test.ts     (新規)
  components/
    SquadConditionControls.vue (新規)
  pages/
    CupPage.vue                (新規)
    ComparisonPage.vue         (変更: 選手個体差UI・ロジック追加)
  types/
    formation.ts                (変更: CupMatch / CupSimulationResult 追加)
  router/
    index.ts                    (変更: /cup ルート追加)
  pages/
    FormationListPage.vue       (変更: ヘッダーに「🥇 カップ戦」導線追加)
```

## 実装の順序

1. `types/formation.ts` に `CupMatch` / `CupSimulationResult` を追加
2. `composables/matchSimulation.ts` の `mulberry32` / `fnv1aHash` / `clamp` を `export`
3. `composables/cupSimulation.ts` を実装
4. `composables/cupSimulation.test.ts` を実装し、パスすることを確認
5. `composables/squadCondition.ts` を実装
6. `composables/squadCondition.test.ts` を実装し、パスすることを確認
7. `pages/CupPage.vue` を実装
8. `router/index.ts` に `/cup` ルートを追加
9. `FormationListPage.vue` に導線を追加
10. `components/SquadConditionControls.vue` を実装
11. `pages/ComparisonPage.vue` に選手個体差UI・ロジックを統合
12. 既存 `ComparisonPage.test.ts` がそのまま通ることを確認（デフォルト無効の非破壊性）
13. 型検査・リント・テスト・ビルドを実行
14. 永続ドキュメント（`requirements-definition.md`にFR-17/FR-18追加、`functional-overview.md`の
    画面一覧・画面遷移図・データモデルにCupMatch/CupSimulationResult追加）を更新

## セキュリティ考慮事項

- 外部入力・ユーザー入力を扱わない（静的データ＋UI操作のみ）ため、追加のセキュリティ対策は不要。

## パフォーマンス考慮事項

- カップ戦は最大7試合（90分ループ×7 + 発生時のみPK戦）で、既存の`LeaguePage.vue`（28試合）
  より計算量が少ない。性能上の懸念はない。
- 選手個体差の`applySquadVariance`は5軸の単純な演算であり、無視できるコスト。

## 将来の拡張性

- フォーメーションが9種類以上に増えた場合のカップ戦の対戦表の組み方（不戦勝、8種類固定の
  継続等）は今回スコープ外。`formations.length !== 8`でErrorになる現在の実装は、
  データ追加時に「静かに壊れる」のではなく「明示的に失敗する」ことを優先した設計判断であり、
  将来対応時はこのガード条件を起点に拡張する。
- 選手個体差を本格的なロスター管理（選手名・永続編集）へ発展させる場合は、
  `squadCondition.ts`の「シード→実効stats」というインターフェースを保ったまま、
  シードの生成元を「ランダム」から「保存された選手データ」に差し替えるだけで拡張できる設計にしている。

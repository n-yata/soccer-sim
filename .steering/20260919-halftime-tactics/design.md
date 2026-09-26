# 設計書

## 要件との差分（実装可能性の調査結果）

`requirements.md` は「90分のハイライト再生が45分の時点で自動的に一時停止する」という
アニメーション再生を前提にしていたが、既存実装（`MatchSimulationPanel.vue`）に
時間経過に沿ったハイライト再生機能は存在しない。`simulateMatch` は90分ぶんの結果を
一括計算し、`timeline`は静的なリスト表示のみである。

**対応**: 「一時停止」を「前半（1-45分）のみを計算・表示し、後半を計算する前に
采配の意思決定ポイントを挟む」という2段階の計算トリガーとして実装する。
利用者から見た体験（前半の結果を見て、後半にどう入るかを選ぶ）は要求の意図を
満たしたまま、既存アーキテクチャ（ボタン押下で計算する同期処理）に自然に収まる。
アニメーション基盤の新規追加は行わない。

## アーキテクチャ概要

既存の3層構成（UIレイヤー / ロジック層 `composables/` / データレイヤー）をそのまま踏襲する。
FR-15と同じ設計方針（`composables/`は`data/`に依存しないため、タグ・マッチアップの
再計算はUIレイヤー`ComparisonPage.vue`が`data/formationTags.ts`・`data/matchupGenerator.ts`
を直接呼び出す）を継承する。

```
ComparisonPage.vue
  │
  ├─ startMatch(a, b, matchup, 45)         composables/matchSimulation.ts
  │     → { progress, result: 前半までの部分結果 }
  │
  │  [ハーフタイム采配モーダル]
  │  HalftimeTacticsModal.vue
  │    └─ FreeLayoutPitchDiagram.vue（draggableTeams=["A","B"]に拡張）
  │
  ├─ (配置変更があれば) generateMatchup(newA, newB)   data/matchupGenerator.ts
  │
  └─ resumeMatch(progress, newA, newB, newMatchup) composables/matchSimulation.ts
        → 90分ぶんの最終結果（MatchSimulationResult、既存型のまま）
```

## コンポーネント設計

### 1. `composables/matchSimulation.ts`（変更・内部リファクタ）

**方針**: 既存の`simulateMatch`は**外部から見た挙動を一切変えない**（既存テスト・
`leagueSimulation.ts`からの利用に影響を与えない）。内部の90分ループを
「前半だけ」「後半だけ」を実行できる形に分割し、`simulateMatch`はその2つを
続けて呼ぶ形にリファクタする。

**内部関数の抽出**:
- `SimAccumulator`（内部型）: `possessionMinutes` / `shots` / `shotsOnTarget` /
  `score` / `timeline` を保持するミュータブルな集計オブジェクト
- `createAccumulator(): SimAccumulator`
- `simulateMinuteRange(acc, a, b, overallEdge, random, fromMinute, toMinute)`:
  既存`runCanonicalSimulation`のfor文の中身をそのまま抽出し、`acc`に書き込む。
  ループ範囲を引数化する以外のロジック変更はしない
- `finalizeResult(a, b, acc, totalMinutes): MatchSimulationResult`:
  `possession%`の算出を`totalMinutes`基準にする（90分通しなら90、前半のみの
  中間表示なら45）。`summary`は`totalMinutes >= 90`のときのみ既存の`buildSummary`
  （勝敗の総括）を使い、`totalMinutes < 90`（前半終了時点の中間表示）のときは
  新設の`buildHalftimeSummary(a, b, score)`（「前半終了: Xが1-0でリード」等、
  勝敗を決めつけない中立な言い回し）を使う
- `mirrorEdgeIfNeeded(edge, reversed)`: `simulateMatch`内にあった
  overallEdge反転の三項式をそのまま関数として切り出す（`startMatch`/`resumeMatch`
  でも同じ反転が必要なため重複を避ける）
- `isReversed(a, matchup)`: `matchup.id`の前半がa.idと一致するか（正準順か）を
  判定する関数として切り出す

**新規公開関数**:
```ts
export interface MatchProgress {
  // 呼び出し側（UIレイヤー）はフィールドを直接読み書きしない前提の不透明な状態。
  // reversed: 初回呼び出し時のa/bとmatchup.idの正準順の関係。試合を通じて固定
  // （配置が変わってもフォーメーションid・チームの立場は変わらないため）
  reversed: boolean;
  random: () => number; // mulberry32のクロージャ。同一インスタンスを後半でも使い続ける
  acc: SimAccumulator;
  throughMinute: number; // 前半として計算済みの最終分（45）
  consumed: boolean; // resumeMatchで一度消費されたか（多重実行防止）
}

/** 前半（1〜throughMinute分、既定45）のみを計算する。resumeMatchで後半に続けられる */
export function startMatch(
  a: Formation,
  b: Formation,
  matchup: Matchup,
  throughMinute = 45,
): { progress: MatchProgress; result: MatchSimulationResult }

/**
 * progress（startMatchの戻り値）に続けて、90分目まで計算する。
 * a/b/matchupは後半用（配置変更が無ければstartMatchと同じ値を渡すこと）。
 * 決定性: 同じprogress + 同じa/b/matchupなら常に同じ結果になる
 * （前半で使ったrandomインスタンスをそのまま継続するため、配置を変更しない場合は
 * simulateMatchを90分通しで1回呼んだ場合と完全に同じ結果になる）。
 * 同じprogressを2回渡すとErrorを投げる（46分目以降の二重加算を防ぐ）
 */
export function resumeMatch(
  progress: MatchProgress,
  a: Formation,
  b: Formation,
  matchup: Matchup,
): MatchSimulationResult
```

`simulateMatch`自体は「`startMatch(a, b, matchup, 90).result`を返す」形に
書き換える（`resumeMatch`を経由しない。前半後半に分ける意味が無いため）。

**テスト**（`matchSimulation.test.ts`に追加）:
- 配置（a/b/matchup）を変えずに`startMatch`→`resumeMatch`をつなげた結果が、
  同じ入力で`simulateMatch`を1回呼んだ結果と**完全に一致**すること（受け入れ条件の core）
- 同じ変更を2回`resumeMatch`しても同じ結果になること（決定性。ただし同一progressの
  2回目呼び出しはErrorになるため、それぞれ新規にstartMatchした別progressで検証する）
- a/bを変えて`resumeMatch`を呼ぶと、後半のスコア・タイムラインが変化しうること
  （resumeMatchのAPI契約検証。実際の本番はpositionsのみ変更しstatsは変えないため、
  position変更が実際に反映されるかはComparisonPage.test.tsのE2E経路で検証する）
- `startMatch`/`resumeMatch`ともに、`matchup`が逆順（b起点）で渡された場合も
  既存`simulateMatch`と同じ鏡写しルールで結果が反転すること
- `resumeMatch`を同じprogressに2回呼ぶとErrorを投げること

### 2. `components/FreeLayoutPitchDiagram.vue`（変更）

**方針**: 既存のFR-15利用（Aチームのみドラッグ）を壊さずに、Bチームもドラッグ対象に
できるよう拡張する。

- 新規props: `draggableTeams: ("A" | "B")[]`（既定値 `["A"]`。既存呼び出し元は
  プロパティを渡さなければ現状のまま動く）
- `itemsA`/`itemsB`のいずれの`<circle>`も、対応するチームが`draggableTeams`に
  含まれる場合のみ`free-layout-pitch__player--draggable`クラスを持つ（算出プロパティ
  `isDraggable(team)`で分岐する）
- **バグ修正を兼ねる**: `onPointerMove`内の`cxToDepth("A", coords.cx)`は
  常にAチームの奥行き変換式を使っており、Bチームをドラッグする場合は逆側の
  変換式（`cxToDepth("B", ...)`）が必要。`onPointerDown`時に`draggingTeam`
  （"A" | "B"）も保持し、`onPointerMove`で参照する
- emit shape変更: `"update-position": [team: "A" | "B", positionId: string, x: number, y: number]`
  （既存の呼び出し元`ComparisonPage.vue`の`onUpdatePosition`もteam引数を受け取る
  形に合わせて更新するが、既存のFR-15用途では`team`は常に`"A"`になるため
  実質的な既存動作は変わらない）

### 3. `components/HalftimeTacticsModal.vue`（新規）

**責務**: ハーフタイム時点のスコア表示、A/B両チームの配置ドラッグUI
（`FreeLayoutPitchDiagram`を内包）、リセット・確定操作を提供するモーダル。

**Props**:
```ts
{
  formationA: Formation; // 前半終了時点の（=試合開始時の）Aフォーメーション
  formationB: Formation;
  halftimeResult: MatchSimulationResult; // startMatchが返した前半の部分結果
}
```

**内部状態**:
- `draftPositionsA` / `draftPositionsB`: `formationA.positions` / `formationB.positions`
  のクローンから開始し、`FreeLayoutPitchDiagram`の`update-position`で更新する
- `draftFormationA` / `draftFormationB`: `{ ...formationA, positions: draftPositionsA }`
  のcomputed（`FreeLayoutPitchDiagram`へ渡す）

**Emits**:
```ts
{
  confirm: [positionsA: Position[], positionsB: Position[]]; // 常に発火。未変更ならpropsのpositionsと同一内容
  cancel: []; // Escapeキー・閉じるボタン(✕)・バックドロップクリックで閉じた場合
}
```

`confirm`を1種類に統一する理由: 「そのまま続ける」も「配置を変更してから続ける」も、
呼び出し側（`ComparisonPage.vue`）にとっては「配置変更後の（未変更なら元と同じ）
positionsを受け取って後半を再開する」という同じ処理になる。ボタンを分けるより
モーダル内に「リセット」操作を用意し、確定操作を1つに統一する方がシンプル。

**UI要素**:
- ヘッダー: 「ハーフタイム采配」+ 閉じるボタン（✕）
- 前半終了時点のスコア（`halftimeResult.score`）
- `FreeLayoutPitchDiagram`（`draggable-teams="['A', 'B']"`）
- 「配置をリセット」ボタン（draftPositions*をformationA/B.positionsのクローンに戻す）
- 「この配置で後半を開始する」ボタン（`confirm`を発火）
- モーダル外枠: `role="dialog"` `aria-modal="true"` `aria-label="ハーフタイム采配"`。
  `TermAnnotatedText.vue`と同じパターンで、マウント時に`document`へ`keydown`
  リスナーを登録し、`Escape`で`cancel`を発火（アンマウント時に確実に解除する）。
  バックドロップの`@click.self`でも`cancel`を発火する

### 4. `pages/ComparisonPage.vue`（変更）

**追加する状態**:
```ts
const matchProgress = shallowRef<MatchProgress | null>(null); // 不透明な内部状態のためshallowRef
const halftimeResult = ref<MatchSimulationResult | null>(null);
const isHalftimeModalOpen = ref(false);
```

**`runSimulation`の変更**: `effectiveFormationA.value`（自由配置モードの変更を含む）を
入力にする。`matchup.value`も同じ`effectiveFormationA`から算出されているため、
前半の入力とmatchup（総合判定）の基準を揃える。

```ts
function runSimulation(): void {
  if (!effectiveFormationA.value || !formationB.value || !matchup.value) return;
  const { progress, result } = startMatch(effectiveFormationA.value, formationB.value, matchup.value, 45);
  matchProgress.value = progress;
  halftimeResult.value = result;
}
```

**新規関数**:
```ts
function openHalftimeTactics(): void {
  isHalftimeModalOpen.value = true;
}

function closeHalftimeTactics(): void {
  isHalftimeModalOpen.value = false;
}

function samePositions(a: readonly Position[], b: readonly Position[]): boolean {
  if (a.length !== b.length) return false;
  return a.every((position, index) => position.x === b[index].x && position.y === b[index].y);
}

// 配置が実際に変わっていなければ既存の静的matchupをそのまま使う。
// 「変更しなければFR-14と完全に同じ結果になる」を、generateMatchupの再計算結果が
// getMatchupの事前計算結果と厳密に一致する保証に頼らず、入力を変えないことで担保する
function onHalftimeConfirm(positionsA: Position[], positionsB: Position[]): void {
  if (!effectiveFormationA.value || !formationB.value || !matchProgress.value || !matchup.value) return;
  const changedA = !samePositions(positionsA, effectiveFormationA.value.positions);
  const changedB = !samePositions(positionsB, formationB.value.positions);
  const nextA = changedA ? { ...effectiveFormationA.value, positions: positionsA } : effectiveFormationA.value;
  const nextB = changedB ? { ...formationB.value, positions: positionsB } : formationB.value;
  const nextMatchup = changedA || changedB ? generateMatchup(nextA, nextB) : matchup.value;

  simulationResult.value = resumeMatch(matchProgress.value, nextA, nextB, nextMatchup);
  matchProgress.value = null;
  halftimeResult.value = null;
  isHalftimeModalOpen.value = false;
}

function proceedWithoutChange(): void {
  if (!effectiveFormationA.value || !formationB.value || !matchProgress.value || !matchup.value) return;
  simulationResult.value = resumeMatch(matchProgress.value, effectiveFormationA.value, formationB.value, matchup.value);
  matchProgress.value = null;
  halftimeResult.value = null;
  isHalftimeModalOpen.value = false;
}
```

**既存のリセット系（組み合わせ切替・自由配置トグル・ドラッグ）**: すべて
`resetMatchState()`（`simulationResult`/`matchProgress`/`halftimeResult`/
`isHalftimeModalOpen`を一括でリセットするヘルパー）を呼ぶ。

**テンプレート**: 「⚽ 試合をシミュレートする」ボタンは`!simulationResult && !halftimeResult`
のときのみ表示。`halftimeResult && !simulationResult`のとき、`MatchSimulationPanel`で
前半の部分結果を表示しつつ、「🔧 配置を変更する」「▶ 後半を開始する」ボタンと
`HalftimeTacticsModal`（`isHalftimeModalOpen`時のみ）を表示する。`simulationResult`が
確定したら最終結果の`MatchSimulationPanel`を表示する（既存と同じ）。

## データフロー

```
1. 利用者が「⚽ 試合をシミュレートする」を押す
2. runSimulation() が startMatch(...) を呼び、前半(1-45分)の部分結果を確定する
3. ハーフタイムパネルが前半のスコア・シュート・タイムラインを表示する
4a. 「▶ 後半を開始する」→ proceedWithoutChange() が元のformationA/Bのまま
    resumeMatch() を呼び、最終結果を表示する
4b. 「🔧 配置を変更する」→ HalftimeTacticsModal が開く
    → A/B双方をドラッグして配置変更 → 「この配置で後半を開始する」で onHalftimeConfirm()
    → 変更後（または未変更）のFormationでresumeMatch()を呼び、最終結果を表示する
```

## エラーハンドリング戦略

- 既存方針を踏襲: 静的データが完全である前提のため、`generateMatchup`が想定外の
  組み合わせで例外を投げるケースは通常運用では発生しない
- `resumeMatch`は同一`progress`の2回目呼び出しでErrorを投げる（実装ミスの早期検知。
  正常フローでは`ComparisonPage.vue`が呼び出し直後に`matchProgress.value = null`
  するため発火しない）

## テスト戦略

### ユニットテスト
- `composables/matchSimulation.test.ts`: 上記「テスト」節のケースを追加
- `components/FreeLayoutPitchDiagram.test.ts`: `draggableTeams`にBが含まれる場合、
  Bチームの円に`update-position`が`"B"`付きで発火し、`cxToDepth("B", ...)`を
  使った座標になること
- `pages/ComparisonPage.test.ts`:
  - シミュレーション実行後、ハーフタイムパネルが表示され最終結果はまだ表示されないこと
  - 「後半を開始する」で最終結果が表示され、90分ぶんの`simulateMatch`を通しで
    呼んだ場合と同じ結果になること（配置未変更時の後方互換性）
  - モーダルで配置を変更してから確定すると、変更後の配置に基づくマッチアップで
    最終結果が計算されること
  - Escapeキーで閉じても後半は開始されないこと
  - 組み合わせ切替でハーフタイム状態がリセットされること

### 統合テスト
- 既存方針（E2Eフレームワーク未導入）を踏襲し対象外。`npm run dev`での目視確認で代替する

## 依存ライブラリ

新規ライブラリの追加なし。

## ディレクトリ構造

```
src/
  composables/
    matchSimulation.ts          (変更: startMatch/resumeMatch追加、内部リファクタ)
    matchSimulation.test.ts     (変更: テストケース追加)
  components/
    FreeLayoutPitchDiagram.vue  (変更: draggableTeams対応)
    FreeLayoutPitchDiagram.test.ts (変更: テストケース追加)
    HalftimeTacticsModal.vue    (新規)
  pages/
    ComparisonPage.vue          (変更: ハーフタイムフロー追加)
    ComparisonPage.test.ts      (変更: テストケース追加)
  components/
    MatchSimulationPanel.vue    (変更: 空タイムライン時の文言を時間帯非依存にする)
```

## 実装の順序

1. `composables/matchSimulation.ts` の内部リファクタ（`SimAccumulator`/`simulateMinuteRange`/
   `finalizeResult`/`mirrorEdgeIfNeeded`/`isReversed`抽出）→ 既存テストがそのまま通ることを確認
2. `startMatch`/`resumeMatch`を追加し、テストを書く
3. `FreeLayoutPitchDiagram.vue`の`draggableTeams`対応・座標変換バグ修正
4. `HalftimeTacticsModal.vue`を新規実装する
5. `ComparisonPage.vue`にハーフタイムフローを組み込む
6. `ComparisonPage.test.ts`にシナリオテストを追加
7. `docs/specs/1_requirements/`（requirements-definition.md 等）へFR番号を採番して反映
8. 型検査・リント・テスト・ビルドを実行

## セキュリティ考慮事項

- 外部入力・ユーザー入力を扱わない（既存のドラッグ操作と同じ、座標はクランプ済み）ため、
  追加のセキュリティ対策は不要

## パフォーマンス考慮事項

- 前半・後半に分けても計算量は既存の90分ループと変わらない

## 将来の拡張性

- `startMatch`の`throughMinute`引数は45で固定利用するが、将来「任意の分で采配」
  （スコープ外・§6.2参照）を実装する場合もこの関数シグネチャのまま拡張できる

# 画面詳細設計書: 比較画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 比較画面 |
| ルート(FE) | `/compare/:formationAId/:formationBId` |
| 対応コンポーネント | `ComparisonPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-03, FR-04, FR-05, FR-06, FR-09, FR-11, FR-13, FR-14, FR-15, FR-18, FR-19 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面2: 比較画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
ComparisonPage
├── ComparisonControls（formations, formationAId, formationBId を渡し、
│                       swap/select-a/select-b イベントを受け取る）
├── FreeLayoutControls（isActive を渡し、toggle/reset イベントを受け取る。FR-15）
├── SquadConditionControls（isActive を渡し、toggle/reroll イベントを受け取る。FR-18）
├── MatchupPitchDiagram（自由配置モードOFF時。formationA, formationB を渡し、
│                       1つのピッチ図上に両チームを重ねて描画）
├── FreeLayoutPitchDiagram（自由配置モードON時。effectiveFormationA, effectiveFormationB を渡し、
│                       update-position/update-position-end イベントを受け取る。FR-15）
├── RadarChart（radarSeries を渡し、フォーメーション特性を表示）
├── TermAnnotatedText（優位ポイント各行・総合判定理由ごとに配置し、textを渡す）
├── MatchSimulationPanel（halftimeResult または simulationResult を渡す。FR-14/FR-19）
└── HalftimeTacticsModal（ハーフタイムモーダルOPEN時。effectiveFormationA/B, halftimeResult を渡し、
                        confirm/cancel イベントを受け取る。FR-19）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `ComparisonPage` | — | ルートパラメータ由来の `computed`: `formationA`, `formationB`, `matchup`（いずれも `undefined` になりうる）。加えて`isFreeLayoutMode`/`freePositionsA`/`freePositionsB`（FR-15）、`squadConditionSeed`（FR-18）、`simulationResult`/`matchProgress`/`halftimeResult`/`isHalftimeModalOpen`（FR-14/FR-19）。詳細は`component-design.md`「ComparisonPage」参照 |
| `ComparisonControls` | `formations: Formation[]`, `formationAId: string`, `formationBId: string` | なし（表示専用。emits `swap`/`select-a`/`select-b`。`component-design.md`参照） |
| `MatchupPitchDiagram` | `formationA: Formation`, `formationB: Formation` | なし（表示専用。`component-design.md`参照） |
| `TermAnnotatedText` | `text: string` | 開いているポップオーバーのindex（`component-design.md`参照） |
| `FreeLayoutControls` | `isActive: boolean` | なし（表示専用。emits `toggle`/`reset`。`component-design.md`参照） |
| `FreeLayoutPitchDiagram` | `formationA: Formation`, `formationB: Formation` | なし（表示専用。emits `update-position`/`update-position-end`。`component-design.md`参照） |
| `SquadConditionControls` | `isActive: boolean` | なし（表示専用。emits `toggle`/`reroll`。`component-design.md`参照） |
| `RadarChart` | `axes`, `maxValue`, `series` | 内部debounceタイマー（aria-live通知用。`component-design.md`参照） |
| `MatchSimulationPanel` | `result: MatchSimulationResult`, `formationAName: string`, `formationBName: string` | なし（表示専用。`component-design.md`参照） |
| `HalftimeTacticsModal` | `formationA: Formation`, `formationB: Formation`, `halftimeResult: MatchSimulationResult` | `draftPositionsA`/`draftPositionsB`（一時的なドラフト配置）、フォーカス管理用の内部ref。emits `confirm`/`cancel`。`component-design.md`参照 |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`,
`data/matchups.ts`）の関数（`getFormationById`, `getMatchup`）を直接呼び出して参照する。
TanStack Query等のデータ取得ライブラリは使用しない。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時・ルートパラメータ変更時）

1. `useRoute()` から `formationAId`, `formationBId` を取得する。
2. `computed` として `formationA = getFormationById(formationAId)`,
   `formationB = getFormationById(formationBId)` を算出する。
3. `formationA` と `formationB` の両方が存在する場合のみ、
   `matchup = getMatchup(formationAId, formationBId)` を算出する
   （`getMatchup` は順序に依存しない。`component-design.md`参照）。
4. テンプレート側は以下の優先順位で表示を出し分ける。
   - `formationA`・`formationB`・`matchup` のいずれかが `undefined` → 「例外・エラー表示」の
     ケースを表示し、ピッチ図・優位ポイントは表示しない。
   - 3つとも存在する → タイトル・色の凡例・総合判定見出し（`matchup.overallEdge`/
     `overallReason`）・`MatchupPitchDiagram`（両チームを重ねたピッチ図）・
     `matchup.advantagesForA`/`advantagesForB` の箇条書きを表示する。優位ポイント各行と
     総合判定理由は`TermAnnotatedText`でラップし、含まれるサッカー用語をインライン表示する
     （FR-11）。
5. `formationA.id`/`formationB.id`/`matchup !== undefined` の組を`watch`（`immediate: true`）で
   監視し、3つが揃った時点で`markPairViewed(formationA.id, formationB.id)`を呼び学習進捗として
   記録する（FR-13）。監視対象を`matchup`オブジェクト自体ではなくIDの組にしているのは、
   `getMatchup`が呼び出し順序に応じて新しいオブジェクトを返す仕様のため、同じ組み合わせでも
   参照差で`watch`が誤発火するのを避けるため。

### 戻るボタン

1. ユーザーが「戻る」（アイコン: ArrowLeft）をクリックする。
2. `router.push('/')` を呼び、フォーメーション一覧画面へ遷移する。

### A/B入れ替え・切替（FR-09）

1. ユーザーが「入れ替え」（アイコン: ArrowLeftRight）ボタンをクリックする、またはA側・B側のセレクトで別の
   フォーメーションを選ぶ。
2. いずれの操作も `router.replace()` を呼ぶ（`push` ではない）。比較画面から比較画面への
   移動は「同じ画面の表示内容を変える」操作であり、`push` にすると履歴に比較画面が
   積み重なり、ブラウザバックで一覧画面へ戻るまでに何度も比較画面を経由することになるため。
   - 入れ替え: `router.replace('/compare/${formationB.id}/${formationA.id}')`
   - A側セレクト変更: `router.replace('/compare/${選択したID}/${formationB.id}')`
   - B側セレクト変更: `router.replace('/compare/${formationA.id}/${選択したID}')`
3. `route.params` の変化により `formationA`/`formationB`/`matchup` の `computed` が
   再評価され、表示内容が新しい組み合わせに更新される。
4. `MatchupPitchDiagram` には組み合わせをキーにした `:key` を与えており、キーの変化で
   コンポーネントが再マウントされる。これにより入れ替え・切替後も対戦演出
   （スライドイン）が再生される。
5. 各セレクトの `<option>` は、相手側に選択中のフォーメーションIDと一致する場合
   `disabled` になる。これにより、UI操作で同一フォーメーション同士の組み合わせ
   （`getMatchup` が `undefined` を返すケース）を発生させない。
6. 上記4.の`watch`は入れ替え・切替（`route.params`の変化）にも反応するため、A/B切替後の
   新しい組み合わせも学習進捗として記録される。

### 用語のインライン表示（FR-11）

1. ユーザーが優位ポイントまたは総合判定理由の中の用語（下線付きボタン）をクリックする。
2. `TermAnnotatedText`内部の`openIndex`が該当indexに更新され、`TermPopover`が開く。
3. 同じ用語の再クリック・別の用語のクリック・`Escape`キー・本文外のクリックのいずれかで
   `openIndex`が`null`に戻り、ポップオーバーが閉じる（同時に開くのは1つ）。
4. `text`（表示する文）自体が差し替わった場合（A/B入れ替え・切替）、`openIndex`は自動的に
   `null`にリセットされる（開いていたindexが差し替え後の別の用語を指してしまうのを防ぐ）。

### 自由配置モード（FR-15）

1. ユーザーが`FreeLayoutControls`のトグルをクリックする（OFF→ON）。
2. `toggleFreeLayoutMode()`が、`data/freeLayoutStorage.ts`の`applyOverrides`で
   フォーメーションID単位の保存済み配置（無ければcanonical定義）を`freePositionsA`/
   `freePositionsB`に設定し、`isFreeLayoutMode`を`true`にする。表示中の試合シミュレーション
   結果（`simulationResult`/`halftimeResult`等）はすべて破棄する。
3. テンプレート側は`isFreeLayoutMode`がtrueの間、`MatchupPitchDiagram`の代わりに
   `FreeLayoutPitchDiagram`を`effectiveFormationA`/`effectiveFormationB`（`freePositionsA`/`B`を
   反映したFormation）付きで表示する。
4. ユーザーが選手をドラッグ、またはTab+矢印キーで移動する。
   - `update-position`（ドラッグのpointermove・キーのkeydownのたびに発火）: 該当する
     `freePositionsA`/`B`を更新し、表示のみ再計算する（`onUpdatePosition`）。
   - `update-position-end`（ドラッグのpointerup・キーのkeyupのタイミングで1回のみ発火）:
     `savePositionOverride(formation.id, positionId, x, y)`で永続化する（`onUpdatePositionEnd`）。
5. `effectiveFormationA`/`B`の変化により、`matchup`（`freePositionsA`/`B`のいずれかが
   非nullなら`generateMatchup`を都度呼び直す）・`effectiveStatsA`/`B`（`estimateStats`で
   タグ差分から概算）が再計算され、優位ポイント・総合判定・レーダーチャート
   （変更したチーム側）が更新される。Aチームの配置変更はBチームの表示に影響しない
   （`effectiveStatsB`はfreePositionsBのみに依存）。
6. リセットボタン（`resetFreeLayout()`）を押すと、A・B両方について
   `clearFormationOverride(formation.id)`で保存データを削除したうえで、
   `freePositionsA`/`B`をcanonical定義で上書きする。
7. トグルをクリックする（ON→OFF）と、`freePositionsA`/`B`を`null`に戻し
   `isFreeLayoutMode`を`false`にする（保存データ自体は削除しない。次回ONにすると復元される）。
8. フォーメーションの組み合わせを切り替える（`route.params`の変化）と、
   `isFreeLayoutMode`/`freePositionsA`/`B`はすべてリセットされる（保存データは
   フォーメーションIDに紐づくため消えない）。

### 選手個体差（FR-18）

1. ユーザーが`SquadConditionControls`のトグルをクリックする（OFF→ON）。
2. `toggleSquadCondition()`が`Math.random()`ベースの新しいシードを`squadConditionSeed`に
   設定し、表示中の試合シミュレーション結果を破棄する。
3. 「スカッドを組み直す」（アイコン: RefreshCw）ボタン（`rerollSquadCondition()`）で、有効なシードを選び直す
   （表示中の結果は同様に破棄する）。
4. 試合シミュレーション実行時（`runSimulation()`/`onHalftimeConfirm()`/
   `proceedWithoutChange()`）、`squadConditionSeed`が非nullなら
   `composables/squadCondition.ts`の`applySquadVariance(stats, seed)`でA/B双方の実効statsを
   算出し（Bのシードは`seed + 1`でオフセットし、A/Bで異なる乱数列にする）、
   その実効statsを持つ一時的なFormationを`startMatch`/`resumeMatch`へ渡す。
5. `matchup`（タグ・優位ポイント・総合判定）・レーダーチャートには実効statsを一切使わない
   （常に`effectiveFormationA`/`B`の元のstatsで計算する）。
6. トグルをOFFにする、またはフォーメーションの組み合わせを切り替えると、
   `squadConditionSeed`は`null`に戻る（永続化しない）。

### 試合シミュレーション・ハーフタイム采配（FR-14, FR-19）

1. ユーザーが「試合をシミュレートする」（アイコン: Play）をクリックする（`runSimulation()`）。
2. `effectiveFormationA`/`B`（自由配置モードの変更を含む）に`squadConditionSeed`があれば
   実効statsを適用し、`composables/matchSimulation.ts`の`startMatch(a, b, matchup, 45)`を
   呼ぶ。戻り値の`progress`を`matchProgress`に、`result`（前半45分の部分結果）を
   `halftimeResult`に設定する。
3. テンプレート側は`halftimeResult`が非nullかつ`simulationResult`がnullの間、
   `MatchSimulationPanel`（前半の部分結果）と「配置を変更する」（アイコン: Wrench）「後半を開始する」（アイコン: Play）の
   2操作を表示する。
4. 「配置を変更する」（アイコン: Wrench）（`openHalftimeTactics()`）で`isHalftimeModalOpen`を`true`にし、
   `HalftimeTacticsModal`を`effectiveFormationA`/`B`・`halftimeResult`付きで開く。
5. モーダル内で選手をドラッグ/キー操作すると、モーダル内部の`draftPositionsA`/`B`
   （一時状態、`localStorage`へは永続化しない）のみが更新される。
6. モーダルの「この配置で後半を開始する」（アイコン: Play）（`onHalftimeConfirm(positionsA, positionsB)`）:
   - `draftPositionsA`/`B`が`effectiveFormationA`/`B`の元の配置と一致するか
     （`samePositions`）をA・Bそれぞれ判定する。
   - 変更が無ければ`matchup`（既存の値）をそのまま使い、変更があれば変更後の配置から
     `generateMatchup`で総合判定を再計算する。「配置を変更しなければFR-14と完全に同じ結果に
     なる」という後方互換性を、入力を変えないことで担保する。
   - `squadConditionSeed`があれば実効statsを適用したうえで、
     `resumeMatch(matchProgress, a, b, matchup)`を呼ぶ。結果を`simulationResult`に設定し、
     `matchProgress`/`halftimeResult`を`null`に、`isHalftimeModalOpen`を`false`に戻す。
7. モーダルを`Escape`・閉じるボタン（Xアイコン）・背景クリックのいずれかで閉じる
   （`closeHalftimeTactics()`）と、`isHalftimeModalOpen`のみ`false`に戻り、
   ハーフタイム結果パネルの表示に留まる（後半は開始されない）。
8. ハーフタイムパネル側の「後半を開始する」（アイコン: Play）（`proceedWithoutChange()`）は、
   配置変更なしで`resumeMatch(matchProgress, effectiveFormationA, effectiveFormationB, matchup)`
   を呼ぶ（6.と同じ後始末を行う）。
9. `simulationResult`が非nullの間、テンプレート側は最終結果の`MatchSimulationPanel`
   （90分ぶん）を表示する。
10. フォーメーションの組み合わせを切り替えると、`simulationResult`/`matchProgress`/
    `halftimeResult`/`isHalftimeModalOpen`はすべてリセットされる
    （表示中のフォーメーションと結果が食い違わないようにするため）。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「戻る」（アイコン: ArrowLeft）をクリック | `/`（`FormationListPage`） | — |
| エラー表示中のリンクをクリック | `/`（`FormationListPage`） | 戻るボタンと同じ遷移 |
| 「入れ替え」（アイコン: ArrowLeftRight）をクリック | `/compare/:formationBId/:formationAId`（`ComparisonPage`） | `router.replace`。履歴を積まない |
| 青チーム変更セレクトを変更 | `/compare/:選択したID/:formationBId`（`ComparisonPage`） | `router.replace`。履歴を積まない |
| 赤チーム変更セレクトを変更 | `/compare/:formationAId/:選択したID`（`ComparisonPage`） | `router.replace`。履歴を積まない |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| `formationA` または `formationB` が `undefined`（存在しないフォーメーションIDでの直接アクセス等） | 「指定された組み合わせを表示できません」等のメッセージを表示し、一覧画面へのリンクを併記する。ピッチ図・優位ポイントは表示しない |
| `formationA`・`formationB` は存在するが `matchup` が `undefined`（同一フォーメーション同士の
  ID指定によるURL直打ち、または将来のデータ追加漏れ） | 上記と同じエラー表示にする |

> **コミット前レビューで判明した経緯**: 当初は `formationA`/`formationB` の存在チェックのみで
> 表示を出し分けていたが、同一フォーメーション同士のURL直打ち（例:
> `/compare/4-4-2/4-4-2`）では両方とも存在するのに `getMatchup` が `undefined` を返し、
> タイトル・ピッチ図は表示されたまま解説文だけが無言で空欄になる欠陥があった。
> `formationA`/`formationB`/`matchup` の3つ全てが揃っていることをエラー表示の条件にすることで、
> このケースも一覧画面へのリンク付きエラー表示に含める。
>
> なお、`matchups.ts` はMVPで扱うフォーメーション全組み合わせ分の解説文をあらかじめ用意する
> 運用のため、**異なるフォーメーション同士**での `matchup` 未検出（データ追加漏れ）は
> 通常発生しない前提だが、発生した場合も同じエラー表示で扱われるため実装上の弊害は無い。

# 設計書

## アーキテクチャ概要

既存の3層構成（UIレイヤー ⇄ `composables/` ⇄ `data/`）を踏襲する。永続化ロジックは
`learningProgress.ts`と同じ配置・同じ防御パターン（読み込み時の型検証、書き込み失敗の
握りつぶし）で`data/freeLayoutStorage.ts`に新設する。座標変換（`freeLayoutCoordinates.ts`）
は既にチーム非依存（`depthToCx(team, y)`/`cxToDepth(team, cx)`）のため変更不要。

```
FreeLayoutPitchDiagram.vue
  ├─ Aチーム選手: pointerdown可能（既存）
  └─ Bチーム選手: pointerdown可能（今回追加）
       ↓ update-position(team, positionId, x, y)
ComparisonPage.vue
  ├─ freePositionsA / freePositionsB（一時状態。トグルOFF・切替で破棄）
  ├─ effectiveFormationA / effectiveFormationB
  ├─ effectiveStatsA / effectiveStatsB（レーダーチャート用）
  ├─ matchup: 両方未変更なら getMatchup、どちらか変更ありなら generateMatchup(A, B)
  └─ onUpdatePosition(team, positionId, x, y)
       ├─ 対応するfreePositionsX を更新（画面反映）
       └─ data/freeLayoutStorage.ts の savePositionOverride(formationId, positionId, x, y)
          で永続化（フォーメーションID単位、組み合わせに依存しない）

data/freeLayoutStorage.ts
  ├─ loadOverrides(): Record<formationId, Record<positionId, {x,y}>>
  ├─ applyOverrides(positions, formationId): Position[]
  │    （自由配置モードON時、canonical positionsへ保存済み上書きをマージして初期値にする）
  ├─ savePositionOverride(formationId, positionId, x, y): void
  └─ clearFormationOverride(formationId): void（リセット時に呼ぶ）
```

## コンポーネント設計

### 1. `data/freeLayoutStorage.ts`（新規）

**責務**:
- 自由配置モードでの配置変更を、フォーメームID単位で`localStorage`へ永続化する。
- `learningProgress.ts`と同じ防御方針: 読み込み時に型を検証し、期待から外れたら空として扱う。
  書き込み失敗（容量超過・プライベートモード等）は握りつぶし、画面を壊さない。

**実装の要点**:
- ストレージキー: `formation-lab.free-layout-overrides.v1`
- 保存形式: `Record<formationId, Record<positionId, { x: number; y: number }>>`
- `applyOverrides(positions, formationId)`は、保存済みの`positionId`と一致するものだけ
  `x`/`y`を上書きし、一致しないもの（将来フォーメーションのポジション構成が変わった場合）は
  canonicalな値のまま残す。座標は`clampToPitchRange`相当のクランプ（0-100）を通してから
  適用する（保存データが手動で書き換えられていても、描画・タグ判定へ範囲外の値が
  流れ込まないようにするため）。
- `savePositionOverride`は「読み込み→該当エントリだけ更新→書き込み」を1操作ごとに行う
  （`learningProgress.ts`の`markPairViewed`と同じ、都度読み書きするシンプルな方式。
  ドラッグ中は`pointermove`のたびに呼ばれるため書き込み頻度は上がるが、扱うデータは
  小さく〔1フォーメーションあたり最大11ポジション〕、本プロダクトの規模で問題になる
  水準ではない〔NFR-01の対象外項目「性能」と同様の判断〕）。
- `clearFormationOverride(formationId)`は該当フォーメーションIDのエントリのみ削除する
  （他フォーメーションの保存済み配置に影響しない）。

**型定義**（`src/types/formation.ts`に追加）:
```ts
// FR-15: 自由配置モードでドラッグした配置の永続化（data/freeLayoutStorage.ts）。
// フォーメーションID単位で保存し、組み合わせ（相手フォーメーション）には依存しない
export type FreeLayoutOverrides = Record<string, Record<string, { x: number; y: number }>>;
```

**公開関数シグネチャ**:
```ts
export function applyOverrides(positions: Position[], formationId: string): Position[];
export function savePositionOverride(formationId: string, positionId: string, x: number, y: number): void;
export function clearFormationOverride(formationId: string): void;
```
（`loadOverrides`は内部実装用として非公開でよい。呼び出し側が必要とするのは
「適用済みpositions」と「保存」「消去」の3操作のみで、生のRecordを外へ渡す必要がない）

### 2. `components/FreeLayoutPitchDiagram.vue`（変更）

**変更点**:
- Bチームの`<circle>`にも`free-layout-pitch__player--draggable`クラスと
  `@pointerdown`ハンドラを追加する（Aチームと同じマークアップパターン）。
- `emit`のシグネチャを`"update-position": [team: "A" | "B", positionId: string, x: number, y: number]`
  に変更する（既存は`positionId`のみでチーム情報を持たなかった）。
- ドラッグ状態の追跡に`draggingTeam`を追加し、`onPointerMove`内の
  `cxToDepth(team, coords.cx)`の`team`引数を、ドラッグ中の実際のチームに切り替える
  （既存は`"A"`固定だった）。

### 3. `pages/ComparisonPage.vue`（変更）

**変更点**:
- `freePositionsB = ref<Position[] | null>(null)`を追加（`freePositionsA`と対）。
- `toggleFreeLayoutMode`: ON時、A・B両方の初期値を`applyOverrides(formation.positions, formation.id)`
  で作る（保存済みの配置があればそれを初期値にする。無ければcanonicalなpositionsと同じ値が返る）。
- `resetFreeLayout`: A・B両方について`clearFormationOverride(formation.id)`を呼んでから、
  `clonePositions(formation.positions)`（canonical）で上書きする。
- `onUpdatePosition(team, positionId, x, y)`: `team`に応じて`freePositionsA`/`freePositionsB`の
  該当ポジションを更新し、`savePositionOverride(formation.id, positionId, x, y)`で永続化する。
- `effectiveFormationB`を`effectiveFormationA`と対称に追加する。
- `effectiveStatsB`を`effectiveStatsA`と対称に追加する（`estimateStats`をBチームにも適用）。
- `matchup`の分岐条件を`!freePositionsA.value`単独から`!freePositionsA.value && !freePositionsB.value`
  に変更し、`generateMatchup`の第2引数を`formationB.value`から`effectiveFormationB.value`に変更する。
- `radarSeries`の2件目（Bチーム側）の`values`を`formationB.value.stats`から`effectiveStatsB.value`に
  変更する。
- 既存の「組み合わせが変わったら自由配置モードをリセットする」`watch`には
  `freePositionsB.value = null`を追加する（`localStorage`の消去はしない。永続化の対象は
  フォーメームIDに紐づく保存データであり、組み合わせの切替では破棄しないという要求どおり）。

## データフロー

### Bチームの選手をドラッグする
```
1. 自由配置モードON状態で、Bチームの選手をポインタで押下する
2. pointermoveのたびに、FreeLayoutPitchDiagram.vueがteam="B"付きでupdate-positionをemit
3. ComparisonPage.vueのonUpdatePositionが、freePositionsBの該当ポジションを更新
   + savePositionOverride("フォーメームB のID", positionId, x, y) で永続化
4. effectiveFormationB → matchup(generateMatchup) → advantagesForB / overallEdge / effectiveStatsB
   が再計算され、優位ポイント・総合判定・レーダーチャート(Bチーム側)が再描画される
```

### 保存済み配置の復元
```
1. 自由配置モードをOFFからONへ切り替える（または、別の組み合わせ画面で同じフォーメームを
   選び自由配置モードをONにする。ページ再読み込み後も含む）
2. toggleFreeLayoutModeが applyOverrides(formation.positions, formation.id) を呼ぶ
3. 保存済みのpositionIdごとの上書きがあれば適用され、無ければcanonicalな配置のまま
4. 復元されたfreePositionsA/Bを初期値として、以降は通常のドラッグ操作と同じ経路で動く
```

### リセット
```
1. 「配置をリセット」を押す
2. resetFreeLayoutが clearFormationOverride(formationA.id) / clearFormationOverride(formationB.id)
   を呼び、保存済みの上書きを削除する
3. freePositionsA/Bをcanonicalなpositionsで上書きする（画面にも即座に反映）
4. 以降、そのフォーメームで自由配置モードをONにしても、保存データが無いためcanonicalな配置から始まる
```

## エラーハンドリング戦略

- `data/freeLayoutStorage.ts`の読み込みは、`learningProgress.ts`の`parseProgress`と同じ方針で
  防御する: JSON.parse失敗・期待する型（`Record<string, Record<string, {x:number,y:number}>>`）
  から外れる値は、該当エントリ（またはストア全体）を「保存無し」として扱う。書き込みも
  try/catchで囲み、失敗しても呼び出し元（`ComparisonPage.vue`）には例外を伝播させない
  （画面の操作自体は成立させ、永続化だけが効かない状態に留める）。

## テスト戦略

### ユニットテスト（`src/data/freeLayoutStorage.test.ts`）
- `applyOverrides`: 保存済みの上書きがpositionIdごとに正しく適用されること。保存が無い
  positionIdはcanonicalな値のまま残ること。保存データの座標が0-100の範囲外でもクランプ
  されること。
- `savePositionOverride`→`applyOverrides`の往復で値が一致すること（決定性）。
- 別のフォーメームIDへの保存が、他のフォーメームIDのデータへ影響しないこと。
- `clearFormationOverride`後は、該当フォーメームIDの上書きが`applyOverrides`に反映されなく
  なること。他フォーメームIDのデータは残ること。
- 不正なJSON・期待と異なる型（配列、null、x/yが数値でない等）が保存されていても、
  `applyOverrides`がcanonicalな値をそのまま返すこと（画面を壊さない）。
- `window.localStorage`へのアクセスが例外を投げる環境（スタブで再現）でも、
  `applyOverrides`/`savePositionOverride`/`clearFormationOverride`が例外を投げないこと。

### ユニットテスト（`src/components/FreeLayoutPitchDiagram.test.ts`、既存の拡張）
- Bチームの選手にも`free-layout-pitch__player--draggable`クラスが付与されること
  （既存の「Bチームには付与されない」検証を、今回の変更に合わせて更新する）。
- Bチームの選手をドラッグすると、`update-position`が`team: "B"`付きでemitされること。
- Aチームのドラッグでも、`update-position`が`team: "A"`付きでemitされること（既存テストの
  シグネチャ変更に追従）。

### ユニットテスト（`src/pages/ComparisonPage.test.ts`、既存の拡張）
- Bチームの配置変更（`update-position`のemitを模擬）で、Bチーム側の優位ポイント・
  レーダーチャートが再計算されること（既存のAチーム向けテストと対称の検証を追加）。
- 自由配置モードをOFF→ONへ切り替えると、直前に保存された配置（`localStorage`を直接
  事前セットして再現）が復元されること。
- リセット操作後は、`localStorage`から該当フォーメームIDのエントリが削除され、
  再度ONにしてもcanonicalな配置から始まること。

### 統合テスト
- 本プロダクトはE2Eフレームワークを導入していないため対象外（既存方針を踏襲）。
  `npm run dev`でのドラッグ操作・リロード後の復元は目視確認で代替する。

## 依存ライブラリ

新規ライブラリの追加なし。

## ディレクトリ構造

```
src/
  data/
    freeLayoutStorage.ts       (新規)
    freeLayoutStorage.test.ts  (新規)
  components/
    FreeLayoutPitchDiagram.vue      (変更: Bチームのドラッグ対応、emitシグネチャ変更)
    FreeLayoutPitchDiagram.test.ts  (変更: 上記に追従)
  pages/
    ComparisonPage.vue         (変更: freePositionsB追加、永続化との連携)
    ComparisonPage.test.ts     (変更: Bチーム自由配置・永続化のテスト追加)
  types/
    formation.ts               (変更: FreeLayoutOverrides型を追加)
```

## 実装の順序

1. `types/formation.ts`に`FreeLayoutOverrides`型を追加
2. `data/freeLayoutStorage.ts`を実装
3. `data/freeLayoutStorage.test.ts`を実装し、パスすることを確認
4. `components/FreeLayoutPitchDiagram.vue`を変更（Bチームのドラッグ対応・emitシグネチャ変更）
5. `components/FreeLayoutPitchDiagram.test.ts`を変更後の仕様に追従させ、パスすることを確認
6. `pages/ComparisonPage.vue`にBチーム自由配置・永続化を統合
7. `pages/ComparisonPage.test.ts`にテストを追加し、既存分も含めてパスすることを確認
8. 型検査・リント・テスト・ビルドを実行
9. 永続ドキュメント（`requirements-definition.md`のFR-15更新・§6.2の積み残し解消、
   `functional-overview.md`の表示仕様、`architecture-overview.md`のデータ永続化戦略の
   既存の誤った記述の修正）を更新

## セキュリティ考慮事項

- 外部入力・ユーザー入力を扱わない（ドラッグ操作由来の数値のみ）ため、追加のセキュリティ
  対策は不要。`localStorage`に保存する値は座標の数値のみで、個人情報・秘匿値を含まない。

## パフォーマンス考慮事項

- `savePositionOverride`はドラッグ中の`pointermove`ごとに呼ばれるが、対象データは
  1フォーメーション最大11ポジション分の小さなJSONであり、性能上の懸念はない
  （`requirements-definition.md` §5「性能」が対象外としている規模）。

## 将来の拡張性

- `data/freeLayoutStorage.ts`の保存形式（フォーメームID単位）は、将来「複数の保存済み配置を
  名前付きで管理する」（スコープ外として明記）機能を追加する際も、キーを
  `formationId`から`presetId`へ差し替えるだけで移行しやすい設計にしている。

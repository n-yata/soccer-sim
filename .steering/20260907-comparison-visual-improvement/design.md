# 設計書

## アーキテクチャ概要

既存の2層構成（UIレイヤー / データレイヤー）は変更しない。`Matchup`型の構造変更と、
`PitchDiagram`・`ComparisonPage`の表示ロジック変更が中心。

## コンポーネント設計

### 1. `Matchup`型（`src/types/formation.ts`）

```typescript
export interface Matchup {
  id: string;
  formationAId: string;
  formationBId: string;
  advantagesForA: string[]; // formationAId 側の優位ポイント（箇条書き）
  advantagesForB: string[]; // formationBId 側の優位ポイント（箇条書き）
}
```

`commentary: string` を廃止し、2つの配列に置き換える。「Aの弱点＝Bの優位点」という対称関係を
前提に、弱点を独立した配列としては持たない（データ作成コストとのバランスを取る）。

### 2. `getMatchup`（`src/data/matchups.ts`）

**実装の要点**: 順序非依存の検索は維持しつつ、呼び出し時の `formationAId`/`formationBId` の
順序に合わせて `advantagesForA`/`advantagesForB` を正規化して返す。レコード上の格納順序と
呼び出し順序が逆の場合は、2つの配列を入れ替えて返す。

```typescript
export function getMatchup(formationAId: string, formationBId: string): Matchup | undefined {
  const found = matchups.find(
    (m) =>
      (m.formationAId === formationAId && m.formationBId === formationBId) ||
      (m.formationAId === formationBId && m.formationBId === formationAId),
  );
  if (!found) return undefined;
  if (found.formationAId === formationAId) return found;
  // 呼び出し順序がレコードと逆なので、A/B を入れ替えて返す
  return {
    ...found,
    formationAId,
    formationBId,
    advantagesForA: found.advantagesForB,
    advantagesForB: found.advantagesForA,
  };
}
```

> **呼び出し側は常に「戻り値の `formationAId` = 呼び出し時の `formationAId`」を前提にできる。**
> `ComparisonPage` 側で入れ替えを意識する必要はない。

### 3. `PitchDiagram`（`src/components/PitchDiagram.vue`）

**責務追加**: ピッチ背景（`<rect>`）の描画有無を `showField` props で切り替える。

```typescript
interface PitchDiagramProps {
  formation: Formation;
  color: "blue" | "red";
  showField?: boolean; // 既定値 true。重ね合わせ表示の2枚目で false にする
}
```

**実装の要点**: `<rect>` を `v-if="showField"` で囲む。`withDefaults` で `showField: true` を
既定値にし、既存の呼び出し（一覧画面が無いので今回はComparisonPageのみ）で `showField` を
省略した場合は従来どおり背景ありで描画される（後方互換）。

### 4. `ComparisonPage`（`src/pages/ComparisonPage.vue`）

**実装の要点**:
- ピッチ図2枚を同一の `position: relative` コンテナ内に重ねる。1枚目（フォーメーションA・青、
  `showField` 省略=true）を通常配置、2枚目（フォーメーションB・赤、`showField=false`）を
  `position: absolute` で1枚目に重ねる。
- 解説文セクションは `matchup.advantagesForA` / `advantagesForB` を、フォーメーション名を見出しに
  した2カラムの箇条書き（`<ul><li>`）で表示する。

## データフロー

### 比較画面表示（変更点のみ）

```
1. computed で formationA, formationB, matchup を算出（変更なし）
2. テンプレートで:
   a. PitchDiagram（formationA, blue, showField省略=true）を配置
   b. PitchDiagram（formationB, red, showField=false）を絶対配置で重ねる
   c. matchup.advantagesForA を見出し「{formationA.name}の優位ポイント」+箇条書きで表示
   d. matchup.advantagesForB を見出し「{formationB.name}の優位ポイント」+箇条書きで表示
```

## テスト戦略

### 変更・追加するユニットテスト

- `matchups.test.ts`:
  - 既存の「正しい組み合わせを返す」「順序非依存」テストを、新データ構造
    （`advantagesForA`/`advantagesForB`）に合わせて更新する。
  - 順序が逆の呼び出しで `advantagesForA`/`advantagesForB` が入れ替わって返ることを検証する
    テストを追加する（`getMatchup` の正規化ロジックの担保）。
  - 既存の「全組み合わせのMatchup存在検証」はデータ構造に依存しないため変更不要。
- `PitchDiagram.test.ts`:
  - `showField=false` のとき `<rect>` が描画されないことを検証するテストを追加する。
  - `showField` 省略時は従来どおり `<rect>` が描画される（後方互換）ことを検証するテストを
    追加する。
  - 既存のviewBox内ラベル走査テストは影響を受けないため変更不要。
- `ComparisonPage.test.ts`:
  - 解説文の検証を、`commentary` のテキスト長チェックから、優位ポイント見出し・箇条書きの
    表示検証に更新する。
  - ピッチ図が重ね合わせコンテナ内に2つ存在することを検証する（既存の「2つ描画される」
    テストを流用しつつ、`showField` propsの値も確認する）。

## 依存ライブラリ

追加・変更なし。

## 実装の順序

1. `Matchup`型を変更する（`types/formation.ts`）
2. `getMatchup`の正規化ロジックを実装する（`data/matchups.ts`）+ 全6組み合わせのコンテンツを
   刷新する
3. `matchups.test.ts`を新データ構造に合わせて更新する
4. `PitchDiagram.vue`に`showField` propsを追加する + テスト追加
5. `ComparisonPage.vue`のレイアウトを重ね合わせ表示・箇条書き解説文に変更する + テスト更新
6. 関連ドキュメント（functional-overview.md, component-design.md, screen-design.md,
   screen-02-comparison.md, glossary.md, test-screen-02-comparison.md）を更新する
7. 品質チェック（test, lint, typecheck, build）

## セキュリティ考慮事項

優位ポイントの箇条書きも `v-html` を使わずテキスト補間（`{{ }}`）で表示する（既存方針を継続）。

## パフォーマンス考慮事項

該当なし（データ件数・計算量に変化なし）。

## 将来の拡張性

`advantagesForA`/`advantagesForB` は配列なので、今後ポイント数を増減させても
データ追加のみで対応できる。ピッチ図の重ね合わせは `showField` propsにより、将来3枚以上の
重ね合わせが必要になっても同じ仕組みを流用できる。

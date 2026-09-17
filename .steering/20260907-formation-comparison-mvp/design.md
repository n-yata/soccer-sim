# 設計書

> 詳細設計は既存のドキュメント一式（`docs/specs/2_basic-design/`, `docs/specs/3_detail-design/`）
> が正本。本ファイルはそれを実装順に要約したもの。

## アーキテクチャ概要

バックエンドを持たない、フロントエンド完結の2層構成（`architecture-overview.md`）。

```
UIレイヤー（pages/, components/） → データレイヤー（data/, types/）
```

## コンポーネント設計

### 1. FormationListPage（`src/pages/FormationListPage.vue`）

**責務**:

- フォーメーション一覧表示、比較対象2件の選択状態管理、比較画面への自動遷移

**実装の要点**:

- `selectedIds: string[]` を内部stateとして持つ。
- 3件目選択時は最も古い選択を解除する（`screen-01-formation-list.md`参照。防御的仕様）。
- `watch`で`selectedIds.length === 2`を検知して`router.push`。

### 2. FormationCard（`src/components/FormationCard.vue`）

**責務**: 1件のフォーメーション表示・選択状態の表示・クリックイベントのemit

**実装の要点**: props (`formation`, `selected`)、emits (`select`)のみを持つ単純表示コンポーネント。

### 3. ComparisonPage（`src/pages/ComparisonPage.vue`）

**責務**: ルートパラメータからのデータ取得、ピッチ図2つと解説文の表示、エラー表示

**実装の要点**:

- `computed`で`formationA`, `formationB`, `matchup`を算出。
- `formationA`/`formationB`いずれかが`undefined`ならエラー表示に切り替える。

### 4. PitchDiagram（`src/components/PitchDiagram.vue`）

**責務**: 1つのフォーメーションの選手配置をSVGで描画する表示専用コンポーネント

**実装の要点**: props (`formation`, `color`)のみ。データモジュールを直接importしない。

### 5. データレイヤー（`src/data/formations.ts`, `src/data/matchups.ts`, `src/types/formation.ts`）

**責務**: フォーメーション・マッチアップの静的データと検索関数を提供する

**実装の要点**:

- `getFormationById(id)`, `getMatchup(formationAId, formationBId)`は外部依存なしの純粋関数。
- `getMatchup`は引数の順序に依存しない（内部で両方の順序を試すか、正規化して検索する）。

## データフロー

### フォーメーション比較のユースケース

```
1. ユーザーが `/` でフォーメーションAをクリック → selectedIds=[A]
2. ユーザーがフォーメーションBをクリック → selectedIds=[A, B]
3. watchが検知し、router.push(`/compare/A/B`)
4. ComparisonPageがマウントされ、getFormationById(A), getFormationById(B), getMatchup(A, B)を実行
5. 両方のフォーメーションが見つかれば、PitchDiagram×2と解説文を表示
```

## エラーハンドリング戦略

カスタムエラークラスは使わない（例外を投げず、`undefined`で未検出を表現する設計。
`component-design.md`参照）。`ComparisonPage`側で`formationA`/`formationB`の`undefined`判定に
より表示を出し分ける。

## テスト戦略

`docs/specs/4_unit-test/test-screen-01-formation-list.md`（9ケース）・
`test-screen-02-comparison.md`（16ケース。コミット前レビュー対応で同一フォーメーション同士の
ケースを追加）の全ケースをVitest + @vue/test-utilsで実装する。
テストの書き方（Given-When-Then）は`reference/rules/testing.md`に従う。

### ユニットテスト

- `FormationCard`, `FormationListPage`, `PitchDiagram`, `ComparisonPage`（コンポーネントテスト）
- `getFormationById`, `getMatchup`（純粋関数のテスト）

### 統合テスト

該当なし（実DBを持たないため`5_integration-test`は対象外）。

## 依存ライブラリ

```json
{
  "dependencies": {
    "vue": "^3.5.0",
    "vue-router": "^4.4.0"
  },
  "devDependencies": {
    "vite": "^6.4.3",
    "@vitejs/plugin-vue": "^5.1.0",
    "typescript": "^5.6.0",
    "vue-tsc": "^2.1.0",
    "vitest": "^4.1.11",
    "@vue/test-utils": "^2.4.0",
    "jsdom": "^25.0.0",
    "eslint": "^9.11.0",
    "typescript-eslint": "^8.69.0",
    "eslint-plugin-vue": "^9.28.0",
    "vue-eslint-parser": "^10.4.1",
    "eslint-config-prettier": "^10.1.8",
    "prettier": "^3.3.0"
  }
}
```

> `vite`は当初`^5.4.0`を想定していたが、`npm audit`でesbuildの開発サーバー脆弱性
> （moderate〜critical、devサーバー限定）が検出されたため、`npm audit fix --force`で
> `^6.4.3`（`vitest`も連動して`^4.1.11`）へ更新した。
> ESLintは`typescript-eslint`（TS向けルール）・`eslint-config-prettier`
> （Prettierとの競合回避）を追加した（`coding-typescript-vue.md`「フォーマット・Lint」対応）。

## ディレクトリ構造

`repository-structure.md`のとおり:

```
soccer-sim/
├── src/
│   ├── main.ts
│   ├── App.vue
│   ├── router/index.ts
│   ├── pages/{FormationListPage,ComparisonPage}.vue
│   ├── components/{FormationCard,PitchDiagram}.vue
│   ├── data/{formations,matchups}.ts
│   └── types/formation.ts
├── public/
├── index.html
├── vite.config.ts
├── tsconfig.json
└── package.json
```

## 実装の順序

1. プロジェクト初期化（`package.json`, `vite.config.ts`, `tsconfig.json`, `index.html`）
2. 型定義（`types/formation.ts`）
3. データレイヤー（`data/formations.ts`, `data/matchups.ts`）とその単体テスト
4. 表示コンポーネント（`FormationCard.vue`, `PitchDiagram.vue`）とその単体テスト
5. ページコンポーネント（`FormationListPage.vue`, `ComparisonPage.vue`）とその単体テスト
6. ルーター設定・`App.vue`・`main.ts`
7. 品質チェック（lint, typecheck, test, build）

## セキュリティ考慮事項

- 戦術解説文の表示は`v-html`を使わずテキスト補間で行う（`component-design.md`参照）。
- 外部入力・認証・シークレットを扱わないため、他のセキュリティ考慮事項は無し。

## パフォーマンス考慮事項

該当なし（想定データ量が小さく、静的データのみのため。`architecture-overview.md`参照）。

## 将来の拡張性

簡易シミュレーション機能等を追加する場合は`src/composables/`を新設し、`pages/`から呼び出す
ロジック層として分離する（`architecture-overview.md`「機能拡張性」参照）。

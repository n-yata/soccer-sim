# 設計書

## アーキテクチャ概要

既存の`pages/` → `components/`（今回は新規コンポーネント無し） → `data/` という
一方向依存を踏襲する。新規ページ`MatrixPage.vue`は`data/formations.ts`の
`formations`配列と`data/matchups.ts`の`getMatchup`をそのまま利用し、
新しいデータモデル・composableは追加しない（`repository-structure.md`
「機能追加時の配置方針」の「小規模機能」に該当）。

```
FormationListPage.vue --(ヘッダーボタン click)--> router.push("/matrix")
                                                        │
                                                        v
                                                  MatrixPage.vue
                                          (formations × formations の<table>)
                                                        │
                                          各セル(対角線以外) = <router-link>
                                                        │
                                          click --> /compare/:formationAId/:formationBId
                                                        │
                                                        v
                                                 ComparisonPage.vue（既存・変更なし）
```

## コンポーネント設計

### 1. MatrixPage.vue（新規、`src/pages/`）

**責務**:
- `formations`配列からN×Nの`<table>`を描画する（行=formationA、列=formationB）
- 各セル（対角線以外）について`getMatchup(row.id, col.id)`を呼び、
  `overallEdge`に応じた色クラスを付与した`<router-link>`を描画する
- 対角線セルはリンクにせず、クリック不可のプレースホルダを表示する

**実装の要点**:
- `getMatchup`は呼び出し順（row, col）に対する相対的な`overallEdge`（"A"=row有利）
  を返すため、マトリクスの对称性を気にせず`getMatchup(row.id, col.id)`をそのまま
  呼べばよい（既存の入れ替えロジックに乗る）
- 色分けは既存デザイントークン`--color-team-a`（row有利）/`--color-team-b`
  （col有利）/グレー（互角・対角線）を流用し、新規トークンは追加しない
- ルーティングは`<router-link :to="\`/compare/${row.id}/${col.id}\`">`を使う
  （`ComparisonPage.vue`のエラー時リンクと同じパターン）
- 一覧画面への「← 戻る」ボタンも設ける（`ComparisonPage.vue`と同じ導線パターン。
  そのため`useRouter`を使用する。実装時に追加した要素で、当初この設計書には
  記載していなかった）
- 表全体を`<table>`要素で構成し、`<th scope="col">`/`<th scope="row">`で
  見出しを明示する（スクリーンリーダー対応。`review-pre-commit`のa11y観点を踏襲）

### 2. FormationListPage.vue（変更）

**責務追加**:
- ヘッダーに「相性表を見る」ボタンを追加し、クリックで`router.push("/matrix")`する

**実装の要点**:
- 既存の`useRouter()`をそのまま使う（`ComparisonPage.vue`の「戻る」ボタンと
  同じ`router.push`パターン。`RouterLink`は使わずボタン+pushで統一する）

### 3. router/index.ts（変更）

- `{ path: "/matrix", name: "matrix", component: MatrixPage }` を追加

## データフロー

### マトリクスからの比較画面遷移
```
1. MatrixPageがformations配列をv-forで行・列に展開
2. 各セルでgetMatchup(row.id, col.id)を呼びoverallEdgeを取得
3. row.id === col.id なら非リンクのプレースホルダを描画
4. それ以外は<router-link :to="/compare/{row.id}/{col.id}">を、
   overallEdgeに応じた色クラス付きで描画
5. クリックでComparisonPageへ遷移（既存の比較画面ロジックは変更なし）
```

## エラーハンドリング戦略

- `getMatchup`が万一`undefined`を返すケース（現状のデータでは発生しない。
  4フォーメーション全6組み合わせが`matchups.ts`に定義済みのため）は、
  安全側としてそのセルを「互角」と同じグレー表示にフォールバックする
  （例外を投げない。バックエンド無しの静的データのため復旧手段が無く、
  画面を壊さないことを優先する）

## テスト戦略

### ユニットテスト
- `MatrixPage.test.ts`（新規）:
  - フォーメーション件数×件数のセルが描画される
  - 対角線セルが`<router-link>`ではない（クリック不可）
  - 既知の組み合わせ（例: "4-4-2"×"4-2-3-1" → overallEdge "B"）で、
    行=4-4-2/列=4-2-3-1のセルが「col有利」色クラスを持つことを検証
  - 各セルの`to`属性が`/compare/{row.id}/{col.id}`になっている
- `FormationListPage.test.ts`（既存に追記）:
  - ヘッダーの新ボタンをクリックすると`router.push("/matrix")`が呼ばれる

### 統合テスト
- 対象外（`repository-structure.md`のとおり本プロダクトは実DBを持たず結合テスト非対象）

## 依存ライブラリ

新規追加なし（既存のVue Router・Vueのみ使用）。

## ディレクトリ構造

```
src/
├── pages/
│   ├── FormationListPage.vue   # 変更: ヘッダーにボタン追加
│   ├── FormationListPage.test.ts  # 変更: ボタンのテスト追加
│   ├── MatrixPage.vue          # 新規
│   └── MatrixPage.test.ts      # 新規
└── router/
    └── index.ts                # 変更: /matrix ルート追加
```

## 実装の順序

1. `router/index.ts`に`/matrix`ルートを追加
2. `MatrixPage.vue`を実装（表描画・色分け・遷移リンク）
3. `MatrixPage.test.ts`を実装
4. `FormationListPage.vue`にヘッダーボタンを追加
5. `FormationListPage.test.ts`にボタンのテストを追加
6. 品質チェック（テスト・lint・型検査・ビルド）
7. 影響のある永続ドキュメント（`requirements-definition.md`のFR一覧・スコープ、
   `functional-overview.md`の画面一覧、`repository-structure.md`のpages一覧）を更新

## セキュリティ考慮事項

- 新規の外部入力・ユーザー入力は無い（静的データの組み合わせ表示のみ）。
  XSS/インジェクションの攻撃面なし

## パフォーマンス考慮事項

- N×N（現状4×4=16セル）の`computed`のみ。フォーメーションが将来6件に増えても
  36セルでありパフォーマンス上の懸念なし

## 将来の拡張性

- `formations`配列から動的に行・列を生成するため、フォーメーション追加時の
  コード変更は不要（NFR-03と整合）
- 将来セルにミニ文言を追加したくなった場合も、色クラスとは独立した
  `<span>`を追加するだけで対応できる構造にしておく

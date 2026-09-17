# 画面: フォーメーション一覧画面 単体テスト仕様書

> 対象画面の詳細設計は
> [`screen-01-formation-list.md`](../3_detail-design/screen/screen-01-formation-list.md)。
> テスト方針全体は `<kit>/reference/rules/testing.md`「テストの種類と目安比率」を正本とする。
> 本書はコンポーネント単位のユニットテスト（実API呼び出し不要。本画面はそもそもAPIを持たない）の
> ケースを列挙する。

## テスト対象

| コンポーネント | テスト種別 |
|---|---|
| `FormationMiniPitch` | ユニットテスト（Vitest + Testing Library） |
| `FormationCard` | ユニットテスト（Vitest + Testing Library） |
| `FormationListPage` | ユニットテスト（Vitest + Testing Library。`vue-router` はモック化） |

## 前提データ（全テストケース共通）

```typescript
// data/formations.ts の実データ（4種類）
const formations: Formation[] = [
  { id: "4-4-2", name: "4-4-2", positions: [/* GK1, DF4, MF4, FW2 = 11件 */] },
  { id: "4-3-3", name: "4-3-3", positions: [/* GK1, DF4, MF3, FW3 = 11件 */] },
  { id: "4-2-3-1", name: "4-2-3-1", positions: [/* GK1, DF4, MF5, FW1 = 11件 */] },
  { id: "3-5-2", name: "3-5-2", positions: [/* GK1, DF3, MF5, FW2 = 11件 */] },
];
```

## テストケース一覧

### FormationMiniPitch

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 31 | 正常系 | 11ポジション分の `formation` を渡してマウントする | ポジション数と同数（11件）の円が描画される | [x] |
| 32 | 正常系 | 同上 | `y` が最も大きいポジション（FW）の `cy` が、`y` が最も小さいポジション（GK）の `cy` より小さい（攻撃方向が画面上になる） | [x] |
| 33 | 正常系 | 同上 | ルート要素に `aria-hidden="true"` が付与される（装飾専用コンポーネントであり、アクセシブルネームは呼び出し元の`FormationCard`が名称・説明文のテキストで担う） | [x] |

### FormationCard

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 1 | 正常系 | `formation={id:"4-4-2", name:"4-4-2", description:"...", ...}`, `selected=false` でマウントする | `"4-4-2"` と説明文が表示される。強調表示用のクラス（例: `selected`）は付与されない | [x] |
| 2 | 正常系 | `formation={id:"4-4-2", ...}`, `selected=true` でマウントする | 強調表示用のクラスが付与され、「選択中」バッジが表示される | [x] |
| 3 | 正常系 | カード要素をクリックする | `select` イベントが `"4-4-2"`（`formation.id`）を引数として1回 emit される | [x] |
| 34 | 正常系 | `selected=false` でマウントする | `formation.positions` と同数分の円を持つ `FormationMiniPitch` が描画される | [x] |
| 35 | 正常系 | `selected=false` でマウントする | 「選択中」バッジは表示されない | [x] |

### FormationListPage

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 4 | 正常系 | マウントする | `formations`（実データ4件）と同数の `FormationCard` が描画される。すべて `selected=false` | [x] |
| 5 | 正常系 | `"4-4-2"` の `FormationCard` から `select` イベントを1回発火する | 選択状態が更新され、`"4-4-2"` の `FormationCard` の `selected` プロパティが `true` になる。他のカードは `false` のまま | [x] |
| 6 | 正常系 | 5に続けて、`"4-3-3"` の `FormationCard` から `select` イベントを発火する（2件目の選択） | `router.push` が `"/compare/4-4-2/4-3-3"` で1回呼ばれる（選択順どおり `formationAId=4-4-2`, `formationBId=4-3-3`） | [x] |
| 7 | 境界値 | 6の状態（`"4-4-2"`→`"4-3-3"` の順で選択済み）からさらに `"4-2-3-1"` を選択する（3件目） | 最も古い選択（`"4-4-2"`）が解除され、選択状態は `["4-3-3", "4-2-3-1"]` になる。この時点で2件揃うため `router.push` が `"/compare/4-3-3/4-2-3-1"` で呼ばれる | [x] |

> ケース7は `router.push` をモック化しているため実際の画面遷移は起きず、コンポーネントの
> 状態のみを検証する。実ブラウザでは2件目選択と同時に画面遷移するためこの状態に到達しないが、
> `screen-01-formation-list.md`「3件目選択について」の防御的仕様を担保する必須ケースとして残す。
| 8 | 正常系 | `"4-4-2"` を選択した状態から、同じ `"4-4-2"` の `FormationCard` から再度 `select` イベントを発火する（選択解除） | `"4-4-2"` の `selected` が `false` に戻る。選択件数は0件になり `router.push` は呼ばれない | [x] |
| 9 | 異常系 | `formations` が空配列の状態でマウントする | `FormationCard` は1件も描画されない。エラーは発生しない（本プロダクトの実データでは発生しない状態だが、堅牢性として確認する） | [x] |
| 36 | 正常系 | マウントする | 用語集画面へのリンクが描画され、リンク先が `"/glossary"` である | [x] |

## 備考

- `vue-router` の `useRouter` はモック化し、`push` の呼び出し引数を検証する。
- テストケース7の「最も古い選択を解除する」ロジックは
  `screen-01-formation-list.md`「カード選択（トグル）」で確定した仕様であり、本テストが
  唯一の担保になる（実装の要となるため必須）。
- `data/formations.ts` の `getFormationById` / `getMatchup` のテストケースは、比較画面から
  主に参照されるため
  [`test-screen-02-comparison.md`](./test-screen-02-comparison.md) にまとめる（重複を避ける）。

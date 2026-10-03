# 画面: 比較画面 単体テスト仕様書

> 対象画面の詳細設計は
> [`screen-02-comparison.md`](../3_detail-design/screen/screen-02-comparison.md)。
> テスト方針全体は `<kit>/reference/rules/testing.md`「テストの種類と目安比率」を正本とする。
> 本書はコンポーネント単位のユニットテスト、および両画面から参照されるデータレイヤー関数
> （`getFormationById`, `getMatchup`）のテストケースを列挙する。

## テスト対象

| コンポーネント / 関数 | テスト種別 |
|---|---|
| `getFormationById`（`data/formations.ts`） | ユニットテスト（Vitest）。外部依存なしの純粋関数 |
| `getMatchup`（`data/matchups.ts`） | ユニットテスト（Vitest）。外部依存なしの純粋関数 |
| `MatchupPitchDiagram` | ユニットテスト（Vitest + Testing Library） |
| `ComparisonControls` | ユニットテスト（Vitest + Testing Library） |
| `annotateText`（`data/termAnnotation.ts`） | ユニットテスト（Vitest）。外部依存なしの純粋関数 |
| `TermAnnotatedText` | ユニットテスト（Vitest + Testing Library） |
| `markPairViewed`/`loadProgress`/`isPairViewed`（`data/learningProgress.ts`） | ユニットテスト（Vitest）。`localStorage`をモック/操作 |
| `ComparisonPage` | ユニットテスト（Vitest + Testing Library。`vue-router` はモック化） |

## 前提データ（全テストケース共通）

```typescript
// data/formations.ts のテスト用フィクスチャ
const formations: Formation[] = [
  { id: "4-4-2", name: "4-4-2", positions: [/* GK1, DF4, MF4, FW2 = 11件 */] },
  { id: "4-2-3-1", name: "4-2-3-1", positions: [/* GK1, DF4, MF5, FW1 = 11件 */] },
];

// data/matchups.ts のテスト用フィクスチャ
const matchups: Matchup[] = [
  {
    id: "4-4-2_vs_4-2-3-1",
    formationAId: "4-4-2",
    formationBId: "4-2-3-1",
    advantagesForA: ["（4-4-2の優位ポイント）"],
    advantagesForB: ["（4-2-3-1の優位ポイント）"],
    overallEdge: "B",
    overallReason: "（4-2-3-1がやや優位である理由）",
  },
];
```

## テストケース一覧

### getFormationById（`data/formations.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 1 | 正常系 | `getFormationById("4-4-2")` を呼ぶ | `id: "4-4-2"` の `Formation` オブジェクトを返す | [x] |
| 2 | 異常系 | `getFormationById("存在しないID")` を呼ぶ | `undefined` を返す | [x] |
| 3 | 境界値 | `getFormationById("")`（空文字）を呼ぶ | `undefined` を返す | [x] |

### getMatchup（`data/matchups.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 4 | 正常系 | `getMatchup("4-4-2", "4-2-3-1")`（レコードの格納順序どおり）を呼ぶ | `id: "4-4-2_vs_4-2-3-1"`、`formationAId: "4-4-2"`、`advantagesForA`/`advantagesForB`ともに1件以上を持つ `Matchup` オブジェクトを返す | [x] |
| 5 | 正常系（順序非依存の正規化） | `getMatchup("4-2-3-1", "4-4-2")`（4の引数を逆順にする）を呼ぶ | 4と同一の`id`を返すが、`formationAId: "4-2-3-1"`に正規化され、`advantagesForA`/`advantagesForB`が4と入れ替わって返る（`functional-overview.md`「ドメイン上の制約」の順序非依存の仕様を担保する必須ケース） | [x] |
| 6 | 異常系 | `getMatchup("4-4-2", "4-4-2")`（同一フォーメーション同士）を呼ぶ | `undefined` を返す | [x] |
| 7 | 異常系 | `getMatchup("4-4-2", "存在しないID")` を呼ぶ | `undefined` を返す | [x] |
| 22 | 不変条件（全走査） | `formations`の全2件組み合わせについて`getMatchup`を呼ぶ | 全組み合わせでMatchupが存在し、`advantagesForA`/`advantagesForB`ともに1件以上を持つ（優位ポイントの追加漏れをデータ全体で検知する） | [x] |
| 23 | 不変条件（全走査） | `formations`の全2件組み合わせについて`advantagesForA`/`advantagesForB`の配列内容を検査する | 同一配列内に重複する文言が無い（コンテンツ品質の担保） | [x] |
| 24 | 不変条件（全走査） | `formations`の全2件組み合わせについて`getMatchup`を呼ぶ | `overallReason`が空文字でない（総合判定理由の追加漏れをデータ全体で検知する。`overallEdge`は型のunionで網羅性が保証されているため恒真になる検査は行わない） | [x] |
| 30 | コンテンツ品質 | 全マッチアップの`overallReason`を検査する | 「Aは」「Bの」等のA/B相対表現が含まれていない（`getMatchup`の入れ替え時に`overallReason`は反転されないため、相対表現が混入すると入れ替え後に誤った側を指す文言に見えてしまう不変条件の担保） | [x] |
| 25 | 正常系（順序非依存の正規化） | `matchups`から`overallEdge`が`"B"`のレコードを動的に1件選び、引数の順序を逆にして`getMatchup`を呼ぶ | `overallEdge`が`"A"`に反転して返る。`overallReason`は変化しない（特定のマッチアップIDをハードコードせず、データ変更に追随できる形で検証する） | [x] |
| 26 | 正常系（順序非依存の正規化） | `matchups`から`overallEdge`が`"even"`のレコードを動的に1件選び、引数の順序を逆にして`getMatchup`を呼ぶ | `overallEdge`は`"even"`のまま変化しない | [x] |

### MatchupPitchDiagram

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 8 | 正常系 | `formationA`/`formationB` に4-3-3/3-5-2を渡してマウントする | 両フォーメーションの全選手数分のcircleとラベルが、それぞれ青（A）・赤（B）の色で描画される | [x] |
| 9 | 正常系 | 同上 | GKは青が画面左端（cx=0）、赤が画面右端（cx=260）に固定される | [x] |
| 17 | 正常系 | 4-4-2 vs 4-4-2でマウントする | 青の攻撃陣（FW）が赤の守備陣（DF）に、赤の攻撃陣（FW）が青の守備陣（DF）に近づく非対称な列配置になっている（青DF-赤FW間・青FW-赤DF間の距離が、青DF-赤DF間・青FW-赤FW間の距離より小さい） | [x] |
| 18 | 正常系 | 4-3-3/3-5-2でマウントする | 同じチーム内でDFラインは、幅方向（元のx座標）の昇順でcyが単調増加する（陣形のラインが滑らかに保たれる） | [x] |
| 19 | 正常系 | 4-4-2/3-5-2でマウントする | GKのcyは、自チームDFラインの中で最も中央（x=50）に近い選手のcyと一致する（3-5-2のCB(50,15)がDFラインの中央そのものであるケースで厳密一致を検証） | [x] |
| 29 | 不変条件（全走査） | 全フォーメーション2件組み合わせで`MatchupPitchDiagram`をマウントし、両チームのcircle座標間の距離を総当たりで計算する | 距離2未満（面積の大半が隠れる状態）のペアが存在しない（列配置が実際に重なりを緩和できているかを検証する必須ケース） | [x] |

### ComparisonControls

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 42 | 正常系 | `formationAId="4-4-2"`, `formationBId="4-3-3"` でマウントし、入れ替えボタンをクリックする | `swap` イベントが1回emitされる | [x] |
| 43 | 正常系 | 同上の状態で青チームセレクトを `"4-3-3"` に変更する | `select-a` イベントが `"4-3-3"` を引数に1回emitされる | [x] |
| 44 | 正常系 | 同上の状態で赤チームセレクトを `"4-4-2"` に変更する | `select-b` イベントが `"4-4-2"` を引数に1回emitされる | [x] |
| 45 | 境界値 | 同上の状態でセレクトの `<option>` 一覧を確認する | 青チームセレクトでは `value="4-3-3"`（`formationBId`）の `<option>` が `disabled`。赤チームセレクトでは `value="4-4-2"`（`formationAId`）の `<option>` が `disabled` | [x] |
| 105 | 境界値（`ComparisonPage`統合。45とは別に、実際にマウントされた画面上での検証） | `ComparisonPage`を11の状態でマウントし、セレクトの`<option>`一覧を確認する | 各セレクトで、相手側に選択済みのフォーメーションが`disabled`になっている | [x] |

### ComparisonPage

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 11 | 正常系 | ルートパラメータ `formationAId="4-2-3-1"`, `formationBId="4-4-2"` でマウントする | タイトルに `"4-2-3-1 vs 4-4-2"` が表示される。`MatchupPitchDiagram` が1つ、`formationA.id="4-2-3-1"`・`formationB.id="4-4-2"` のpropsで描画される。青カラムに4-2-3-1側、赤カラムに4-4-2側の`advantagesForA`/`advantagesForB`がそれぞれ1件以上の`<li>`として、取り違えずに表示される（`getMatchup`の正規化を通るケースであり、恒真テストを避けるため文言の中身まで検証する必須ケース）。総合判定に`overallEdge`の入れ替え反転（"B"→"A"）を反映した「4-2-3-1がやや優位」が表示される | [x] |
| 28 | 正常系 | ルートパラメータ `formationAId="4-4-2"`, `formationBId="4-3-3"`（`overallEdge: "even"`の組み合わせ）でマウントする | 総合判定に「互角」が表示される | [x] |
| 12 | 異常系 | ルートパラメータ `formationAId="存在しないID"`, `formationBId="4-4-2"` でマウントする | 「指定された組み合わせを表示できません」等のメッセージと一覧画面へのリンクが表示される。`MatchupPitchDiagram` は描画されない | [x] |
| 13 | 異常系 | ルートパラメータ `formationAId="4-2-3-1"`, `formationBId="存在しないID"` でマウントする | 12と同様にエラーメッセージが表示され、`MatchupPitchDiagram` は描画されない | [x] |
| 14 | 正常系 | 11の状態で「戻る」（アイコン: ArrowLeft）をクリックする | `router.push` が `"/"` で1回呼ばれる | [x] |
| 15 | 正常系 | 12の状態で表示される一覧画面へのリンクが `"/"` を指す | `<router-link to="/">` が描画され、リンク先が `"/"` である（`RouterLink` をスタブ化して `href` を検証する） | [x] |
| 16 | 異常系 | ルートパラメータ `formationAId="4-4-2"`, `formationBId="4-4-2"`（同一フォーメーション同士）でマウントする | `getFormationById` は両方成功するが `getMatchup` が `undefined` を返すため、12と同様にエラー表示になる。`MatchupPitchDiagram` は描画されない | [x] |
| 37 | 正常系 | 11の状態で「入れ替え」（アイコン: ArrowLeftRight）をクリックする | `router.replace` が `"/compare/4-4-2/4-2-3-1"`（A/B逆順）で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 38 | 正常系 | 11の状態で青チーム変更セレクトを `"3-5-2"` に変更する | `router.replace` が `"/compare/3-5-2/4-4-2"` で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 39 | 正常系 | 11の状態で赤チーム変更セレクトを `"3-5-2"` に変更する | `router.replace` が `"/compare/4-2-3-1/3-5-2"` で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 40 | 境界値 | 11の状態でセレクトの `<option>` 一覧を確認する | 青チームセレクトでは `value="4-4-2"`（現在の赤チーム）の `<option>` が `disabled`。赤チームセレクトでは `value="4-2-3-1"`（現在の青チーム）の `<option>` が `disabled` | [x] |
| 41 | 正常系 | 11の状態でマウントする | `.comparison-page__body`が`max-width: 1400px`・`margin: 0 auto`を持ち、広い画面幅で中央寄せされる（2026-09-27追加。用語集への導線は`AppHeader`と重複するため削除し、対応するテストケースも削除した） | [x] |
| 71 | 正常系（FR-13） | 11の状態でマウントする | `markPairViewed`により、表示している組み合わせ（"4-2-3-1"/"4-4-2"）が学習進捗として記録される | [x] |
| 72 | 正常系（FR-13） | 11の状態から青チーム変更セレクトを変更する（同一コンポーネント内のパラメータ変更） | 変更後の新しい組み合わせも学習進捗として記録される | [x] |
| 73 | 不変条件（FR-13） | 順序を入れ替えて2回マウントする（"4-2-3-1"/"4-4-2" → "4-4-2"/"4-2-3-1"） | 学習進捗としては同一の組み合わせとして扱われ、二重に記録されない | [x] |
| 74 | 異常系（FR-13） | 16の状態（同一フォーメーション同士、`matchup`が`undefined`）でマウントする | 学習進捗として記録されない（成立していない組み合わせを記録しない） | [x] |
| 75 | 正常系（FR-11） | 11の状態でマウントする | 優位ポイント（例:「マンツーマン」）・総合判定理由（例:「中盤」）の中のサッカー用語が、説明を開けるボタンとして表示される | [x] |
| 76 | 不変条件（FR-11） | 11の状態でマウントする | 用語をボタン化しても、優位ポイントの本文が欠落しない（区間の切り出しで文字が落ちない） | [x] |

### annotateText（`data/termAnnotation.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 46 | 正常系 | 用語を含む文（例: 「相手のスペースを突く」）を渡す | 平文/用語の区間に正しく切り出される（用語区間は`term`オブジェクトを持つ） | [x] |
| 47 | 境界値 | 用語を含まない文を渡す | 平文1区間のみを返す | [x] |
| 48 | 境界値 | 空文字を渡す | 空配列を返す | [x] |
| 49 | 正常系 | 用語のみで構成された文を渡す | term区間のみを返す（平文の空区間を挟まない） | [x] |
| 50 | 最長一致（必須） | 「最終ライン」と「ライン間」が部分的に重なる文（例: 「最終ラインを押し上げる」）を渡す | 短い用語（「ライン間」）ではなく長い用語（「最終ライン」）を優先して切り出す（短い方を先に採ると本文が別の意味の用語へ静かに化けるため必須） | [x] |
| 51 | 最長一致 | 「ライン間」のみが一致する文（例: 「ライン間で受ける」）を渡す | 「ライン間」を切り出す | [x] |
| 52 | 境界値 | `term`が空文字の用語をリストに含めて渡す | 無限ループにならず、空文字の用語は無視される | [x] |
| 53 | 不変条件 | 実データ（`soccerTerms`）で任意の解説文を注釈する | 切り出した全区間の`text`を連結すると元の文字列と一致する（文字の欠落・重複が無い） | [x] |

### TermAnnotatedText

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 54 | 正常系 | 用語を含む文でマウントする | 用語がボタンとして描画され、`aria-expanded="false"`である | [x] |
| 55 | 正常系 | 用語ボタンをクリックする | 説明（`role="tooltip"`）が表示され、`aria-expanded="true"`・`aria-describedby`が説明のidと一致する | [x] |
| 56 | 正常系 | 開いた状態で同じボタンを再度クリックする | 説明が閉じる | [x] |
| 57 | 正常系 | 1つ目の用語を開いた状態で2つ目の用語をクリックする | 1つ目が閉じ、2つ目のみが開く（同時に開くのは1つ） | [x] |
| 58 | 正常系 | 開いた状態で`Escape`キーを押す | 説明が閉じる | [x] |
| 59 | 境界値 | 開いた状態で`Escape`以外のキーを押す | 説明は閉じたままにならない（開いたまま） | [x] |
| 60 | 正常系 | 開いた状態で本文の外側をクリックする | 説明が閉じる | [x] |
| 61 | 境界値 | 開いた状態で説明（吹き出し）自身をクリックする | 説明は閉じない | [x] |
| 62 | 正常系（FR-09との整合） | 開いた状態で`text` propsを差し替える | 説明が自動的に閉じる（A/B入れ替え・切替で開いたindexが別の用語を指す事故を防ぐ） | [x] |
| 63 | 境界値 | 同一画面に複数インスタンスを配置し、それぞれ開く | 各説明の`id`が衝突しない | [x] |

### markPairViewed / loadProgress / isPairViewed / clearProgress（`data/learningProgress.ts`）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 64 | 正常系 | `buildPairKey("4-4-2", "4-3-3")`と`buildPairKey("4-3-3", "4-4-2")`を比較する | 同じキーになる（順序非依存） | [x] |
| 65 | 正常系 | `markPairViewed("4-4-2", "4-3-3")`を呼んだ後`loadProgress()`する | 記録した組み合わせが`viewedPairs`に含まれる | [x] |
| 66 | 不変条件 | 順序を入れ替えて2回`markPairViewed`を呼ぶ | `viewedPairs`は1件のまま増えない（二重計上しない） | [x] |
| 67 | 異常系 | `localStorage.getItem`が例外を投げる状態で`loadProgress()`を呼ぶ | 例外を投げず、空の進捗（`{ viewedPairs: [] }`）を返す | [x] |
| 68 | 異常系 | `localStorage.setItem`が例外を投げる状態で`markPairViewed`を呼ぶ | 例外を投げない。戻り値には更新後の進捗が反映される | [x] |
| 69 | 異常系（保存データの改竄） | `localStorage`に壊れたJSON・`viewedPairs`が配列でない値・要素に文字列以外を含む値を保存した状態で`loadProgress()`を呼ぶ | いずれも空の進捗として扱う（保存値を信用せず形式検証する） | [x] |
| 70 | 正常系 | `markPairViewed`で記録後`clearProgress()`を呼ぶ | `viewedPairs`が空になり、`localStorage`からも削除される | [x] |

## 備考

- `vue-router` の `useRoute` / `useRouter` はモック化する。`useRoute` はテストケースごとに
  異なる `params` を返すよう設定する。
- テストケース5（`getMatchup` の順序非依存）は、`component-design.md`「データレイヤー」で
  明記された仕様の唯一の担保であり必須とする。
- `getFormationById` / `getMatchup` は外部依存を持たない純粋関数のため、モック不要で
  直接呼び出してテストできる（`architecture-overview.md`「アーキテクチャパターン」参照）。
- テストケース9・17-19・29（`MatchupPitchDiagram`の列配置）は、`component-design.md`で明記された
  非対称な列配置（青の攻撃陣と赤の守備陣が近づく対戦配置、GKのDFライン中心合わせ）の担保である。
- テストケース24-26・28（総合判定 `overallEdge`/`overallReason`）は、優位ポイントの箇条書き
  だけでは総合的にどちらが有利か読み取りにくいというフィードバックを受けて追加した機能の担保である。
- テストケース50（`annotateText`の最長一致）は、用語同士の部分的な重なりで本文が誤った意味の
  用語へ静かに化けるのを防ぐ唯一の担保であり必須とする。
- テストケース62（`TermAnnotatedText`の表示切替時のクローズ）は、FR-09（A/B入れ替え・切替）
  との組み合わせで実際に起きうる不具合（開いたindexが差し替え後の別内容を指す）の担保である。
- テストケース66（`markPairViewed`の順序非依存）・69（保存データの改竄への耐性）は、FR-13の
  「1周したかの判定」が壊れないための不変条件であり必須とする。
- テストケース71-74（`ComparisonPage`の学習進捗記録）は、`markPairViewed`が正しいタイミング
  （組み合わせが解決できた時点、A/B切替時も含む）で、かつ正しい対象（成立した組み合わせのみ）
  に対して呼ばれることの担保である。

- 撤去回帰: 有効な旧保存配置を置いてもGKが固定座標のままで、保存値を削除せず、設定・自由配置・試合操作を表示しないことをComparisonPage.test.tsで確認する。

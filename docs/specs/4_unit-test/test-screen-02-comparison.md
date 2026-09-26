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
| `FreeLayoutPitchDiagram`（FR-15） | ユニットテスト（Vitest + Testing Library）。`getScreenCTM`/`createSVGPoint`をスタブ化 |
| `FreeLayoutControls`（FR-15） | ユニットテスト（Vitest + Testing Library） |
| `SquadConditionControls`（FR-18） | ユニットテスト（Vitest + Testing Library） |
| `simulateMatch`/`startMatch`/`resumeMatch`（`composables/matchSimulation.ts`。FR-14/FR-19） | ユニットテスト（Vitest）。外部依存なしの純粋関数（リーグ戦・カップ戦画面から参照される中核アルゴリズムのため、テストケースは本ファイルに一本化する） |
| `applySquadVariance`（`composables/squadCondition.ts`。FR-18） | ユニットテスト（Vitest）。外部依存なしの純粋関数 |
| `applyOverrides`/`savePositionOverride`/`clearFormationOverride`（`data/freeLayoutStorage.ts`。FR-15） | ユニットテスト（Vitest）。`localStorage`をモック/操作 |
| `MatchSimulationPanel`（FR-14/FR-19） | ユニットテスト（Vitest + Testing Library） |
| `HalftimeTacticsModal`（FR-19） | ユニットテスト（Vitest + Testing Library）。`document.activeElement`によるフォーカス検証を含む |

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
| 14 | 正常系 | 11の状態で「← 戻る」をクリックする | `router.push` が `"/"` で1回呼ばれる | [x] |
| 15 | 正常系 | 12の状態で表示される一覧画面へのリンクが `"/"` を指す | `<router-link to="/">` が描画され、リンク先が `"/"` である（`RouterLink` をスタブ化して `href` を検証する） | [x] |
| 16 | 異常系 | ルートパラメータ `formationAId="4-4-2"`, `formationBId="4-4-2"`（同一フォーメーション同士）でマウントする | `getFormationById` は両方成功するが `getMatchup` が `undefined` を返すため、12と同様にエラー表示になる。`MatchupPitchDiagram` は描画されない | [x] |
| 37 | 正常系 | 11の状態で「⇄ 入れ替え」をクリックする | `router.replace` が `"/compare/4-4-2/4-2-3-1"`（A/B逆順）で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 38 | 正常系 | 11の状態で青チーム変更セレクトを `"3-5-2"` に変更する | `router.replace` が `"/compare/3-5-2/4-4-2"` で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 39 | 正常系 | 11の状態で赤チーム変更セレクトを `"3-5-2"` に変更する | `router.replace` が `"/compare/4-2-3-1/3-5-2"` で1回呼ばれる。`router.push` は呼ばれない | [x] |
| 40 | 境界値 | 11の状態でセレクトの `<option>` 一覧を確認する | 青チームセレクトでは `value="4-4-2"`（現在の赤チーム）の `<option>` が `disabled`。赤チームセレクトでは `value="4-2-3-1"`（現在の青チーム）の `<option>` が `disabled` | [x] |
| 41 | 正常系 | 11の状態でマウントする | 用語集画面へのリンクが描画され、リンク先が `"/glossary"` である | [x] |
| 71 | 正常系（FR-13） | 11の状態でマウントする | `markPairViewed`により、表示している組み合わせ（"4-2-3-1"/"4-4-2"）が学習進捗として記録される | [x] |
| 72 | 正常系（FR-13） | 11の状態から青チーム変更セレクトを変更する（同一コンポーネント内のパラメータ変更） | 変更後の新しい組み合わせも学習進捗として記録される | [x] |
| 73 | 不変条件（FR-13） | 順序を入れ替えて2回マウントする（"4-2-3-1"/"4-4-2" → "4-4-2"/"4-2-3-1"） | 学習進捗としては同一の組み合わせとして扱われ、二重に記録されない | [x] |
| 74 | 異常系（FR-13） | 16の状態（同一フォーメーション同士、`matchup`が`undefined`）でマウントする | 学習進捗として記録されない（成立していない組み合わせを記録しない） | [x] |
| 75 | 正常系（FR-11） | 11の状態でマウントする | 優位ポイント（例:「マンツーマン」）・総合判定理由（例:「中盤」）の中のサッカー用語が、説明を開けるボタンとして表示される | [x] |
| 76 | 不変条件（FR-11） | 11の状態でマウントする | 用語をボタン化しても、優位ポイントの本文が欠落しない（区間の切り出しで文字が落ちない） | [x] |
| 77 | 正常系（FR-14） | 11の状態でマウントする | 初期表示ではシミュレーション結果パネル（`MatchSimulationPanel`）を表示しない | [x] |
| 78 | 正常系（FR-14） | 77の状態で「⚽ 試合をシミュレートする」をクリックする | ハーフタイム結果パネル（前半45分の部分結果）が表示され、フォーメーション名が渡される | [x] |
| 79 | 境界値（FR-19） | 78の状態を確認する | シミュレーション実行直後は前半の部分結果のみが表示され、まだ最終結果（90分ぶん）ではない | [x] |
| 80 | 正常系（FR-19、後方互換性） | 78の状態で「▶ 後半を開始する」をクリックする | `resumeMatch`による最終結果が、同じ組み合わせで`simulateMatch`を90分通しで1回実行した結果と完全に一致する（配置変更が無い場合の後方互換性） | [x] |
| 81 | 正常系（FR-19） | 78の状態で「🔧 配置を変更する」をクリックし、モーダル内でA/B双方の配置を変更してから「この配置で後半を開始する」を確定する | 変更後の配置が後半の結果に反映される（`generateMatchup`で再計算した総合判定を用いる）。モーダルが閉じ、最終結果パネルに切り替わる | [x] |
| 82 | 境界値（FR-19） | 78の状態で「🔧 配置を変更する」を開き、`Escape`キーでモーダルを閉じる | 後半は開始されず、ハーフタイム結果パネルの表示に留まる | [x] |
| 83 | 不変条件（FR-14/FR-19） | 78またはハーフタイム状態でフォーメーションの組み合わせを切り替える | ハーフタイムパネル・モーダルの状態を含め、表示中のシミュレーション結果がすべてリセットされる | [x] |
| 84 | 正常系（FR-14） | シミュレーション結果表示後（78または最終結果表示後） | 結果表示後は「⚽ 試合をシミュレートする」ボタンが消える（再実行しても同じ結果にしかならないため、再クリックの導線を持たない） | [x] |
| 85 | 正常系（FR-15） | 11の状態でマウントする | 初期表示では自由配置モードはOFFで、通常の`MatchupPitchDiagram`が表示される | [x] |
| 86 | 正常系（FR-15） | 85の状態で自由配置トグルをONにする | `FreeLayoutPitchDiagram`に切り替わり、Aチームの現在の配置（`formationA.positions`）が渡される | [x] |
| 87 | 正常系（FR-15） | 86の状態でAチームの配置を変更する（`update-position`をemit） | 優位ポイント・総合判定・レーダーチャートのAチーム側が、変更後の配置に基づいて再計算される | [x] |
| 88 | 正常系（FR-15） | 86の状態でBチームの配置を変更する（`update-position`をemit） | レーダーチャートのBチーム側が再計算され、Bチームの配置（`FreeLayoutPitchDiagram`のformationB props）に反映される | [x] |
| 89 | 不変条件（FR-15） | 86の状態でAチームの配置のみを変更する | Bチームの表示・状態には影響しない（逆にBチームのみ変更してもAチームに影響しないことも確認する） | [x] |
| 90 | 正常系（FR-15） | 86の状態でトグルをOFFにする | 元の配置・`MatchupPitchDiagram`表示に戻る | [x] |
| 91 | 不変条件（FR-15） | 86の状態でフォーメーションの組み合わせを切り替える | 自由配置モードがOFFに戻る | [x] |
| 92 | 正常系（FR-15） | 86の状態でA・B双方の配置を変更してからリセットボタンを押す | A・B両チームの配置が元のフォーメーション定義に戻る | [x] |
| 93 | 不変条件（FR-15） | シミュレーション結果表示中に自由配置トグルをONにする、または配置を変更する | 表示中の試合シミュレーション結果が破棄される | [x] |
| 94 | 正常系（FR-15、永続化） | 86の状態で配置を変更し（`update-position-end`をemit）、トグルをOFF→ONにする | 直前にドラッグした配置が復元される | [x] |
| 95 | 正常系（FR-15、永続化） | 94の状態でコンポーネントを再マウントする（ページ再読み込み相当） | `localStorage`が維持されたまま、保存済みの配置が復元される | [x] |
| 96 | 正常系（FR-15、永続化） | 94の状態で同じフォーメーションを別の組み合わせで表示する | 保存済みの配置が組み合わせに依らず復元される（フォーメーションID単位の永続化） | [x] |
| 97 | 不変条件（FR-15、永続化） | 94の状態でリセット操作を行う | 保存データも削除され、再度自由配置モードをONにしても元の配置から始まる | [x] |
| 98 | 正常系（FR-18） | 11の状態でマウントする | 初期表示では選手個体差はOFFで、リロールボタンは表示されない | [x] |
| 99 | 正常系（FR-18） | 98の状態でトグルをONにする | リロールボタンが表示される | [x] |
| 100 | 不変条件（FR-18） | 選手個体差OFFのままシミュレーションする | レーダーチャートのAチーム側stats（`formationA.stats`）は変化しない | [x] |
| 101 | 不変条件（FR-18） | 選手個体差をONにする（シミュレーション実行前） | レーダーチャートのAチーム側statsは変化しない（影響範囲が試合シミュレーションのみのため） | [x] |
| 102 | 不変条件（FR-18） | シミュレーション結果表示中に選手個体差トグルをONにする、またはリロールする | 表示中の試合シミュレーション結果が破棄される | [x] |
| 103 | 不変条件（FR-18） | 選手個体差ON状態でフォーメーションの組み合わせを切り替える | 選手個体差がOFFに戻る | [x] |
| 104 | 正常系（FR-18） | 99の状態でトグルをOFFに戻す | リロールボタンが消える | [x] |

### FreeLayoutPitchDiagram（FR-15）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 106 | 正常系 | `formationA`/`formationB`に4-3-3/3-5-2を渡してマウントする | 両フォーメーションの全選手数分のcircleが、それぞれ青（A）・赤（B）の色で描画される | [x] |
| 107 | アクセシビリティ（必須。WCAG 2.1.1） | 同上でマウントする | ラッパー要素は`role="group"`で全体の説明（フォーメーション名2つ）を持つ。選手のcircleは`tabindex="0"`でアクセシブルネーム（チーム名+ポジションラベル）を持つが、`role="button"`は付与しない（Enter/Space未対応のままロールを名乗るARIA契約違反を避けるため） | [x] |
| 185 | 正常系 | 同上でマウントする | A・B両チームの選手に、ドラッグ可能であることを示すクラス（`free-layout-pitch__player--draggable`）が付与される | [x] |
| 108 | アクセシビリティ | 同上でマウントする | ピッチの装飾要素（背景・ライン・ペナルティエリア）と選手ラベルの`<text>`は`aria-hidden="true"`で読み上げから除外される（`role="group"`の子要素として露出するため、装飾まで露出すると雑音になる） | [x] |
| 109 | 正常系 | Aチームの選手をポインタでドラッグする（pointerdown→pointermove） | `update-position`が`team:"A"`付きでemitされ、実座標(0-100)に変換された値になる | [x] |
| 110 | 正常系 | Bチームの選手をポインタでドラッグする | `update-position`が`team:"B"`付きでemitされ、Bチームの深さ変換（自陣方向が反転）が使われる | [x] |
| 111 | 不変条件 | Aチームをドラッグ後、Bチームをドラッグする | teamごとに独立して扱われる（Aのドラッグ中はBに影響せず、逆も同様） | [x] |
| 112 | 境界値 | ピッチ範囲外の座標へドラッグする | emitされる値が0-100にクランプされる | [x] |
| 113 | 異常系（防御） | ポインタキャプチャを喪失した状態（`buttons=0`）でpointermoveが発生する | emitされずドラッグ状態が終了する（取りこぼしたpointerupを回復する） | [x] |
| 114 | 異常系（防御） | `getScreenCTM`が非可逆な行列を返す状態でドラッグする | emitされない（NaN座標を配置状態へ持ち込まない） | [x] |
| 115 | 境界値 | pointerup後にpointermoveが発生する | `update-position`はemitされない（ドラッグ終了） | [x] |
| 116 | 正常系 | ドラッグ中に複数回pointermoveしてからpointerupする | `update-position`は複数回emitされるが、`update-position-end`はpointerup時に直近の座標で1回だけemitされる | [x] |
| 117 | 境界値 | pointermoveが一度も無いままpointerupする | `update-position-end`はemitされない（確定すべき変更が無いため） | [x] |
| 118 | 異常系（防御） | ポインタキャプチャ喪失からの回復（`buttons=0`での回復ロジック発動） | 回復時点で`update-position-end`が直近の座標で1回emitされる（pointerup相当として扱う） | [x] |
| 119 | 正常系（WCAG 2.1.1） | 選手のcircleにフォーカスし矢印キー（Arrow系）を押す | `update-position`がemitされ、押下方向に応じて実座標が更新される。矢印キー以外のキーではemitされない | [x] |
| 120 | 境界値 | ピッチ範囲外（境界付近）で矢印キーを押す | emitされる値が0-100にクランプされる | [x] |
| 121 | 正常系（永続化との整合。FR-15） | 矢印キーを押下（keydown）した直後 | `update-position`のみemitされ、`update-position-end`はまだemitされない（キーを離す=keyupまで確定しない） | [x] |
| 122 | 異常系（防御。オートリピート対策） | keydownを連続発火（ブラウザのキーリピートを模擬）させてからkeyupする | `update-position-end`はkeyup時の1回だけemitされる（永続化がキー押下のたびに走らない） | [x] |
| 123 | 境界値 | 矢印キー以外のキーでkeyupする | `update-position-end`はemitされない | [x] |
| 124 | 正常系 | 4-4-2 vs 4-4-2でマウントする | Aチームの選手の座標は、実座標(0-100)を`freeLayoutCoordinates.ts`で変換した位置に描画される | [x] |

### FreeLayoutControls（FR-15）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 125 | 正常系 | `isActive=false`でマウントする | トグルボタンのみ表示され、リセットボタンは表示されない | [x] |
| 126 | 正常系 | `isActive=true`でマウントする | トグルボタンとリセットボタンの両方が表示される | [x] |
| 127 | 正常系 | トグルボタンをクリックする | `toggle`イベントが1回emitされる | [x] |
| 128 | 正常系 | `isActive=true`の状態でリセットボタンをクリックする | `reset`イベントが1回emitされる | [x] |

### SquadConditionControls（FR-18）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 129 | 正常系 | `isActive=false`でマウントする | トグルボタンのみ表示され、リロールボタンは表示されない | [x] |
| 130 | 正常系 | `isActive=true`でマウントする | トグルボタンとリロールボタンの両方が表示される | [x] |
| 131 | 正常系 | トグルボタンをクリックする | `toggle`イベントが1回emitされる | [x] |
| 132 | 正常系 | `isActive=true`の状態でリロールボタンをクリックする | `reroll`イベントが1回emitされる | [x] |

### simulateMatch / startMatch / resumeMatch（`composables/matchSimulation.ts`。FR-14/FR-19）

> `simulateMatch`はリーグ戦画面（`test-screen-06-league.md`）・カップ戦画面
> （`test-screen-07-cup.md`）からも参照される中核アルゴリズムのため、テストケースは
> 本ファイルに一本化する（両画面の仕様書からは本節を参照する）。

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 133 | 正常系 | 同一の`a`/`b`/`matchup`で`simulateMatch`を複数回呼ぶ | 決定性: 完全に同じ結果（`MatchSimulationResult`）になる | [x] |
| 134 | 不変条件 | `matchup`をディープクローンしてから`simulateMatch`を呼ぶ | シードは`matchup.id`の値に基づく（オブジェクト参照ではない）ため、クローンでも同じ結果になる | [x] |
| 135 | 不変条件（必須） | `a`/`b`を入れ替えて`simulateMatch`を呼ぶ | 順序非依存の同じ90分間の鏡写しになる（勝敗が呼び出し順で変わらない） | [x] |
| 136 | 正常系 | `id`が異なる`matchup`で`simulateMatch`を呼ぶ | 異なる90分間になる（ハッシュが入力に応じて変化することの検証） | [x] |
| 137 | 回帰検知 | 固定フォーメーションペアで`simulateMatch`を呼ぶ | 既知の結果（スコア等の固定値）と一致する | [x] |
| 138 | 不変条件（全走査） | `formations`の全2件組み合わせで`simulateMatch`を呼ぶ | 検証対象の組み合わせが1件以上ある（テスト自体が空振りしないことの確認） | [x] |
| 139 | 境界値 | 全stats軸が同一の2フォーメーションで`simulateMatch`を呼ぶ | 例外を投げず有効な結果を返す | [x] |
| 140 | 境界値 | 全stats軸が0のフォーメーションで`simulateMatch`を呼ぶ | 0除算にならない | [x] |
| 141 | 異常系（防御。review-pre-commit M-3対応） | statsにNaNが混入した状態で`simulateMatch`を呼ぶ | 確率計算がNaNを素通ししない（`clamp`のNaNガード） | [x] |
| 142 | 正常系（後方互換性。FR-19） | 配置を変更せず`startMatch`→`resumeMatch`を呼ぶ | `simulateMatch`を90分通しで1回実行した結果と完全に一致する | [x] |
| 143 | 正常系（決定性。FR-19） | 同じ配置変更を行った別々の`startMatch`から`resumeMatch`を呼ぶ | 後半の結果が完全に同じになる | [x] |
| 144 | 異常系（防御） | 同じ`MatchProgress`を2回`resumeMatch`に渡す | `Error`を投げる（46分目以降の二重加算を防ぐガード） | [x] |
| 145 | 正常系（FR-19） | statsを変えたFormationを`resumeMatch`に渡す | 後半のフォーメーション変更が入力に反映される | [x] |
| 146 | 不変条件 | `matchup`が逆順（b起点）で渡された場合に`startMatch`/`resumeMatch`を呼ぶ | `simulateMatch`と同じ鏡写しルールで一致する | [x] |
| 147 | 境界値 | `throughMinute=90`を渡して`startMatch`を呼ぶ | `simulateMatch`の90分通し結果と一致する（前半後半に分けない場合の整合性） | [x] |

### applySquadVariance（`composables/squadCondition.ts`。FR-18）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 148 | 正常系 | 任意のstatsとseedで`applySquadVariance`を呼ぶ | 全軸が元の値の90%〜110%の範囲（0-100にクランプ）に収まる | [x] |
| 149 | 境界値 | 0または100に近いstatsで`applySquadVariance`を呼ぶ | 0-100の範囲にクランプされる（極端な入力値でも超過しない） | [x] |
| 150 | 正常系 | 同じstats・同じseedで`applySquadVariance`を複数回呼ぶ | 決定性: 常に同じ結果になる | [x] |
| 151 | 正常系 | 異なるseedで`applySquadVariance`を呼ぶ | 異なる結果になりうる（複数シードの結果が全て同一にはならない） | [x] |
| 152 | 不変条件 | `applySquadVariance`を呼ぶ | 元のstatsオブジェクトを変更しない（イミュータブル） | [x] |

### applyOverrides / savePositionOverride / clearFormationOverride（`data/freeLayoutStorage.ts`。FR-15）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 153 | 正常系 | 何も保存されていない状態で`applyOverrides`を呼ぶ | canonicalなpositionsをそのまま返す | [x] |
| 154 | 正常系 | 一部のpositionIdのみ`savePositionOverride`で保存してから`applyOverrides`を呼ぶ | 保存済みのpositionIdはx/yが上書きされ、保存の無いpositionIdはcanonicalな値のまま残る | [x] |
| 155 | 正常系 | `savePositionOverride`→`applyOverrides`を往復する | 決定性: 値が一致する | [x] |
| 156 | 境界値 | 範囲外の座標で`savePositionOverride`を呼ぶ | 座標は0-100にクランプされて保存される | [x] |
| 157 | 不変条件 | 別のフォーメーションIDへ`savePositionOverride`する | 他フォーメーションのデータに影響しない | [x] |
| 158 | 正常系 | 同一フォーメーション内の複数positionIdへ`savePositionOverride`する | 両方反映される | [x] |
| 159 | 正常系 | `savePositionOverride`後に`clearFormationOverride`を呼ぶ | 該当フォーメーションの上書きが消え、canonicalな値が返る | [x] |
| 160 | 不変条件 | `clearFormationOverride`を呼ぶ | 他フォーメーションのデータを消さない | [x] |
| 161 | 境界値 | 保存が無いフォーメーションIDに`clearFormationOverride`を呼ぶ | 何もしない（例外を投げない） | [x] |
| 162 | 異常系（改竄データ） | `localStorage`にJSONとして解釈できない値を保存した状態で`applyOverrides`を呼ぶ | 保存無しとして扱う | [x] |
| 163 | 異常系（改竄データ） | オブジェクトでない値（配列・数値・null）を保存した状態で`applyOverrides`を呼ぶ | 保存無しとして扱う | [x] |
| 164 | 異常系（改竄データ） | x/yが数値でない・NaN・Infinityの値を保存した状態で`applyOverrides`を呼ぶ | そのpositionだけcanonicalな値のまま残る | [x] |
| 165 | 異常系（改竄データ） | 一部のフォーメーションエントリが壊れた状態で`applyOverrides`を呼ぶ | 他の正しいエントリは活かされる | [x] |
| 166 | セキュリティ（必須。プロトタイプ汚染対策） | `__proto__`/`constructor`/`prototype`キーが混入した状態で`applyOverrides`を呼ぶ | 他の無関係なフォーメーション・ポジションの座標を汚染しない | [x] |
| 167 | 異常系（防御） | `localStorage.getItem`が例外を投げる状態で`applyOverrides`を呼ぶ | canonicalなpositionsを返して落ちない | [x] |
| 168 | 異常系（防御） | `localStorage.setItem`が例外を投げる状態で`savePositionOverride`を呼ぶ | 例外を投げない | [x] |
| 186 | 異常系（防御） | `localStorage.setItem`が例外を投げる状態で`clearFormationOverride`を呼ぶ | 例外を投げない | [x] |

### MatchSimulationPanel（FR-14/FR-19）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 169 | 正常系 | `result`/`formationAName`/`formationBName`を渡してマウントする | スコアボードにチーム名とスコアを表示する | [x] |
| 170 | 正常系 | 同上 | ポゼッションバーの幅がpropsの値に応じて設定される | [x] |
| 171 | 正常系 | 同上 | シュート・枠内シュートの数値を表示する | [x] |
| 172 | 正常系 | `timeline`に複数件のイベントを含む`result`を渡す | タイムラインの全イベントを分昇順のまま表示する | [x] |
| 173 | 境界値（FR-19） | `timeline`が空配列の`result`を渡す | 代替メッセージを表示する（ハーフタイム前半で決定機の無い時間帯を「90分」と決め打ちしない文言） | [x] |
| 174 | 正常系 | `result.summary`を含む`result`を渡す | サマリー文を表示する | [x] |

### HalftimeTacticsModal（FR-19）

| No | 観点 | 前提・操作 | 期待結果 | 完了 |
|---|---|---|---|:--:|
| 175 | アクセシビリティ（必須。WCAG 2.4.3） | マウントする | フォーカスが閉じるボタンへ移る | [x] |
| 176 | アクセシビリティ（必須。WCAG 2.4.3） | アンマウントする | 開く前にフォーカスされていた要素へフォーカスが戻る | [x] |
| 177 | 異常系（防御） | 開く前にフォーカスされていた要素がDOMから取り除かれた状態でアンマウントする | `document.body`へフォールバックする（フォーカスの迷子を防ぐ） | [x] |
| 178 | 不変条件 | 177の状態から別の要素へフォーカスが移る | フォールバック用の一時的なtabindexが除去される（DOMに余分な属性を残さない） | [x] |
| 179 | アクセシビリティ（必須。フォーカストラップ） | 最後のフォーカス可能要素でTabを押す | 最初の要素へ折り返す | [x] |
| 180 | アクセシビリティ（必須。フォーカストラップ） | 最初のフォーカス可能要素でShift+Tabを押す | 最後の要素へ折り返す | [x] |
| 181 | 正常系 | マウントする | `role="dialog"`・`aria-modal="true"`が設定されている | [x] |
| 182 | 正常系 | 閉じるボタンをクリックする | `cancel`イベントがemitされる | [x] |
| 183 | 正常系 | `Escape`キーを押す | `cancel`イベントがemitされる | [x] |
| 184 | 正常系 | 「この配置で後半を開始する」をクリックする | A/Bの現在のドラフト配置が`confirm`イベントとしてemitされる | [x] |

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
- テストケース107（`FreeLayoutPitchDiagram`のARIA構造）は必須とする。キーボード操作自体
  （テストケース119）が成立していても、親要素の`role`が子要素をアクセシビリティツリーから
  剪定していれば、スクリーンリーダーには何も伝わらない（2026-09-26のコミット前レビューで
  実際に見つかった欠陥。属性の有無だけを見るテストではこの剪定を検知できないため、
  ラッパーのroleと選手circleのroleの両方を明示的に検証する）。
- テストケース121-122（`FreeLayoutPitchDiagram`のキーボード操作における永続化タイミング）は
  必須とする。矢印キーはオートリピートするため、`update-position-end`（`localStorage`書き込み）
  をkeydownのたびに発火させると、ドラッグのpointermoveと同じ高頻度I/O問題が復活する
  （2026-09-26のコミット前レビューで実際に見つかった欠陥）。
- テストケース135（`simulateMatch`の順序非依存）は、FR-14の受け入れ条件（A/Bの入れ替えで
  勝敗が変わらない）の唯一の担保であり必須とする。カップ戦（PK戦の勝者判定）も同じ
  正準順の考え方に依存するため、この不変条件が崩れると波及範囲が広い。
- テストケース144（`resumeMatch`の二重呼び出しガード）は、`MatchProgress`が可変な累積状態
  （`acc`）を内部に持つことに起因する実装上の制約（同じ状態を2回進行させると二重加算になる）
  の担保であり必須とする。
- テストケース166（`freeLayoutStorage`のプロトタイプ汚染対策）はセキュリティ観点で必須とする。
  `JSON.parse`は`__proto__`等のキーを通常のenumerableなown propertyとして生成するため、
  型検証だけでは防げない（2026-09-26のコミット前レビューで実際に見つかった欠陥）。
- テストケース175-180（`HalftimeTacticsModal`のフォーカス管理・フォーカストラップ）は
  WCAG 2.4.3の担保であり必須とする。特に177-178（フォーカス復帰先がDOMから消えていた場合の
  フォールバック）は、開いたモーダルの起点要素が別の理由で消えるケース（例:
  組み合わせ変更によるボタンの再描画）を想定した防御である。

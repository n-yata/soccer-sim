# コミット前レビューレポート

## 第1回（2026-09-11）

対象: `src/types/formation.ts`, `src/data/formations.ts`, `src/data/radarAxes.ts`,
`src/components/RadarChart.vue`(+test), `src/components/MatchupPitchDiagram.vue`(+test),
`src/pages/ComparisonPage.vue`(+test), `src/components/FormationCard.test.ts`,
`docs/specs/1_requirements/requirements-definition.md`, `functional-overview.md`,
`docs/specs/2_basic-design/screen-design.md`, `component-design.md`
（`wireframes.drawio`はXML図表のため対象外、整形式であることは別途Pythonで検証済み）

結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件

## コミット前レビュー結果

対象: `git diff` 出力（約1000行、`wireframes.drawio` 除く）

重点確認事項（依頼元指定）: RadarChartの座標計算境界値、MatchupPitchDiagramのチーム分割が
既存ロジックに影響していないか、formations.tsのstats不変条件、CSSアニメーションによる
既存テストへの悪影響、ドキュメントと実装の矛盾。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[バグ/表示] レーダーチャート最左軸ラベルが viewBox 外にはみ出して切れる**: `viewBox="0 0 200 200"`、
  `labelRadius=88`のため、5軸目「プレッシング強度」（角度198°）のラベル左端が約-11.7となりSVG既定の
  overflow:hiddenで切れる。→ viewBoxに左右パディングを持たせる
- **[バグ] `maxValue`が0のとき頂点座標がNaNになり無効なSVG属性として静かに描画が壊れる**: 現在の
  唯一の呼び出し元は`:max-value="100"`固定で実害なしだが、「軸数・系列数に依存しない汎用実装」と
  設計書に明記した以上防御が必要
- **[運用/正しさ] `formations.ts`のstats算出方針コメントとデータの値が整合していない**: ヘッダコメントは
  「positionsから機械的に算出」と宣言しているが、実データは規則と逆・無相関な箇所がある
  （pressIntensity、spaceControl、balanceで規則と矛盾する値）

### Low / 改善提案
- role="img"のa11y対応が無い / `:key="s.label"`の重複リスク / component-design.mdの
  RadarChartPropsがreadonly不一致 / CSSアニメーションはマウント時1回のみ発火（将来パラメータのみの
  遷移で再生されない） / RadarChart.test.tsが軸数非依存を検証していない

### 問題なし
- セキュリティ①〜④: シークレット・URL・アカウント情報の混入なし
- MatchupPitchDiagramの回帰: buildTeamItems/colXByTeam/GKのcy算出は無変更、itemsA/itemsBへの
  分割は算出結果・描画順ともに完全に等価
- RadarChartの座標計算: value=0/maxValue/超過/負値いずれも境界値で正しく動作、恒真テストでない
- formations.tsのstats不変条件: 4フォーメーション×5軸すべて0-100範囲内、ベクトル4件すべて相異なる
- 既存テストへのアニメーション影響: DOM構造・属性値に影響なし、jsdomはCSSアニメーションを評価しない
- 性能: O(軸数×系列数)のcomputedのみ、無視できる規模
- 運用/ドキュメント整合: 型定義・軸配列順・stats独立性がすべてのドキュメントと一致

### 未検証
- wireframes.drawioのv3ページ実在確認（対象外のため）
- ブラウザでの実描画未実施
- npm run test/lint/build は本レビューでは未実行（依頼元報告に依拠）

### 総合評価
Critical/High無し。重点確認4点はいずれも問題なし。Medium3件は現行呼び出し経路では顕在化しないが、
ラベル切れは実画面で見える可能性があるためブラウザ確認を推奨。

### 対応
- Medium（ラベル切れ）: `viewBox`を`"-35 0 270 200"`に変更。ブラウザで実際に「プレッシング強度」が
  切れていたことを確認し、修正後に完全表示されることを確認
- Medium（maxValue=0のNaN）: `safeMaxValue`変数を導入して0除算を防止（ただし第2回レビューで
  意味論の誤りが発覚、後述）
- Medium（formations.tsコメント不整合）: ヘッダコメントを「機械的算出」から「開発者が定性的に判断」
  という実態に即した表現に修正
- Low（:key重複）: `${seriesIndex}-${s.label}`に変更
- Low（component-design.md型不一致）: `readonly RadarAxisMeta[]`に修正
- Low（a11y、再マウント、テスト網羅）: 申し送りとして残置

---

## 第2回（2026-09-11）— 修正後の再レビュー

対象: `RadarChart.vue`, `RadarChart.test.ts`, `formations.ts`, `component-design.md`の追加差分

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[バグ/新規混入] `maxValue<=0`のフォールバックが、コメントの説明とも安全側の挙動とも逆になっている**:
  `const safeMaxValue = props.maxValue > 0 ? props.maxValue : 1;` は実際には`1`を代入しており、
  「全頂点が中心に潰れる」というコメントと矛盾。`maxValue:0`かつ`attack:50`なら`50/1=50`→
  `Math.min(1,50)=1`となり、頂点は中心ではなく最大半径（満点表示）に描かれる。NaN（明らかに壊れる）
  から「もっともらしいが完全に誤ったチャート」（静かに誤る）への変化。新規テストは`Number.isFinite`
  のみで、中心収束でも満点表示でも同じく通ってしまい意味を固定できていない
  → `ratio`の三項演算子で`maxValue>0`のときのみ計算し、それ以外は`0`にする

### Low / 改善提案
- viewBox拡張によるチャート本体の相対サイズ縮小（左右対称のため中心ズレはなし、問題なし）
- spaceControlの値に軽微な逆転が残っている（厳密な計算式ではないと明示済みのためブロッカーでない）
- 値側（s.values[axis.id]）のNaNは依然未ガード（型とテストで到達不能）

### 問題なし
- ラベルはみ出し: viewBox拡張で解消確認（座標計算・ブラウザ確認の両方）
- formations.tsコメント不整合: 解消確認、4-2-3-1の個別コメントとヘッダの整合性も確認
- :key重複: 解消確認
- component-design.md型不一致: 解消確認
- (b)新規混入なし: 座標計算ロジック・既存テスト・:key変更・stats実数値いずれも無変更、
  セキュリティ・性能への影響なし

### 未検証
- ブラウザでの実描画は本レビューでは未実施（依頼元確認結果との整合のみ確認）
- wireframes.drawioのv3ページ実在確認（継続申し送り）
- npm run test/lint/typecheck/build 未実行（依頼元報告に依拠）

### 総合評価
Critical/High無し。round1の4件は解消確認。新たなMedium1件（safeMaxValueの意味論誤り）を検出。
現行呼び出し元は`:max-value="100"`固定のため実害無しだが、小さな修正で済むためこのコミットに
含めることを推奨。

### 対応
- Medium（safeMaxValueの意味論誤り）: 中間変数を削除し、`ratio`計算を
  `props.maxValue > 0 ? clamp(value/maxValue) : 0`の三項演算子に変更。テストも
  「maxValue=0のとき全頂点が中心(100,100)に一致する」という意味を固定する形に強化

---

## 第3回（2026-09-11）— 修正後の再レビュー

対象: `RadarChart.vue`, `RadarChart.test.ts`の追加差分（2ファイルのみ）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- コメント「除算がNaNになり」は0/0のときのみ正確（50/0はInfinity）。実害なしだが次の機会に文言修正
- 三項演算子が軸ループの内側で評価される（系列×軸=10回、計測不能な差、可読性優先の判断は妥当）
- 値側NaNガード・a11y・アニメーション再マウント・テスト網羅は引き続き申し送り

### 問題なし
- maxValue<=0時の満点表示: 解消確認。ratio=0→全頂点が中心(100,100)に収束することを計算で確認
- フォールバックの網羅性: 0/負数/NaN/Infinityいずれのケースも有限座標を返すことを確認
- テストの強化: 「全頂点が中心に一致する」テストはround2実装（safeMaxValue=1）では確実に落ちる、
  恒真でも実装コピーでもない有効な回帰テストであることを確認
- (b)新規混入なし: 変更範囲は`ratio`算出ブロック3行のみ、既存テスト・呼び出し元契約への影響なし、
  セキュリティ・性能への影響なし

### 未検証
- ブラウザでの実描画（round2で確認済みのラベル収まりに影響する変更は今回無し）
- npm run test/lint/typecheck/build 未実行（依頼元報告に依拠、ただしテストの性質から整合性を確認）
- wireframes.drawioのv3ページ実在確認（継続申し送り）

### 総合評価
Critical・High・Medium いずれも指摘なし。round1〜2で挙げた指摘はすべて解消を確認。
**コミットしてよい。**

### 対応
- wireframes.drawioのv3ページ実在確認: メイン側でPythonによるUTF-8対応の文字列比較を実施し、
  `screen-design.md`が参照する`wireframe-comparison-v3(対戦演出+レーダーチャート)`が
  実際にファイル内に存在することを確認（完全一致）

---

## レビュー完了（2026-09-11）
- 最終ラウンド: 第3回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - コメント文言の精度（0/0以外のケースの言及漏れ、実害なし）
  - `RadarChart`の値側（stats）のNaNガードが未実装（型・テストで到達不能）
  - `RadarChart`の`<svg>`に`role="img"`等のアクセシブル名が無い
  - CSSアニメーションはマウント時1回のみ発火し、将来パラメータのみの画面遷移では再生されない
    （現行UIでは一覧画面経由のため到達しない）
  - `RadarChart.test.ts`が軸数非依存であることを検証していない（常に5軸固定）
  - いずれも実害が無い、または悪用可能な欠陥ではないため、次回作業への申し送りとする

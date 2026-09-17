# コミット前レビューレポート

## 第1回（2026-09-12）
- 対象: `src/pages/MatrixPage.vue`(新規) / `src/pages/MatrixPage.test.ts`(新規) /
  `src/pages/FormationListPage.vue` / `src/pages/FormationListPage.test.ts` /
  `src/router/index.ts` / `docs/specs/1_requirements/` 4件 /
  `.steering/20260912-formation-matchup-matrix/` 3件
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 3件

## コミット前レビュー結果

対象: 上記ファイル一覧（差分）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）

- **[バグ] マッチアップ未定義が「互角」と区別できず静かに誤表示される**:
  `resolveEdge`が`getMatchup(...)?.overallEdge ?? "even"`でフォールバックしており、
  データ追加漏れ（FR-07の「データ追加のみで拡張可能」を実行した際にmatchups.tsへの
  対応レコード追加を忘れるケース）が発生すると、マトリクスは「互角」と表示するのに
  遷移先の比較画面は「表示できません」になるという矛盾が起きる。

- **[運用] マトリクス→比較画面からマトリクスへ戻れない（導線の片道化）**:
  `ComparisonPage.vue`の`goBack`が`router.push("/")`固定のため、マトリクスのセルから
  比較画面に入って「← 戻る」を押すと一覧画面に飛ばされ、見ていたマトリクスの位置を失う。

- **[運用/ドキュメント] `functional-overview.md`のモジュール構成図が未更新**:
  画面一覧・遷移図・ユースケースにはMatrixPageを追記済みだが、同ファイル内の
  モジュール構成図（mermaid）にMatrixPageノードと依存関係が抜けており、
  同一ドキュメント内で食い違っていた。

- **[運用/ドキュメント] `repository-structure.md`のルーター説明が古い**:
  `router/index.ts`のコメント欄が「一覧画面・比較画面のルート」のまま、
  相性マトリクス画面が追記されていなかった。

### Low / 改善提案
- **[バグ耐性]** `router-link`の`to`が文字列テンプレート組み立てで、将来IDに`/`等の
  特殊文字が入ると壊れる可能性（現状のIDは全てURL安全なため実害なし）
- **[性能]** セルごとに`getMatchup`を最大2回呼んでいる（N=4では無視できる規模）
- **[アクセシビリティ]** セルのフォーカス可視化がUA既定のみ

### 問題なし
- セキュリティ①〜④: シークレット・URL・アカウント情報の混入なし。`.gitignore`変更なし
- インジェクション: `v-html`・`eval`不使用、全て自動エスケープされるMustache補間
- バグ（対称性）: `getMatchup`のA/B反転ロジックにより`cell(A,B)`と`cell(B,A)`が整合
  （実データでの往復テストあり、恒真テストではない）
- バグ（境界）: `formations`空配列でもクラッシュしない。対角線除外も全行でテスト済み
- テスト品質: 恒真アサーション・空振りテストなし。異常系・拡張性まで踏み込んでいる
- 後方互換: 既存ルート・既存の選択ロジックに変更なし

### 未検証
- ブラウザでの実表示（色分けの見た目・横スクロール・`prefers-reduced-motion`との干渉）
  は静的レビューのみで未確認

### 総合評価
Critical/High指摘なし。Medium 4件はいずれもコミット前に修正。

### 対応
- Medium「マッチアップ未定義の誤表示」: `resolveEdge`の戻り値型を`Matchup["overallEdge"]
  | undefined`に変更し、`hasMatchup`ヘルパーを新設。未定義セルは「互角」と別の
  `--unknown`スタイル（非リンク・`role="img"`・aria-label「データ未定義」）で表示し、
  クリックできないようにした。`MatrixPage.test.ts`の対応テストを実際の挙動に合わせて
  書き直し
- Medium「導線の片道化」: `ComparisonPage.vue`と`MatrixPage.vue`の`goBack`を、
  `window.history.state?.back`がある場合は`router.back()`、無い場合（URL直打ち等）は
  `router.push("/")`にフォールバックする実装に変更。既存テストは実行環境
  （jsdom、`history.state`が未設定）でフォールバック分岐を通るため、
  変更前と同じ`push("/")`アサーションのまま通ることを確認済み
- Medium「モジュール構成図未更新」: `functional-overview.md`のmermaid図にMatrixPage
  ノードと`formations.ts`/`matchups.ts`への依存線を追加
- Medium「ルーター説明が古い」: `repository-structure.md`のコメントを
  「一覧画面・比較画面・相性マトリクス画面のルート」に修正
- Low 3件: 実害小のため申し送り（積み残し参照）

## 第2回（2026-09-12）— 修正後の再レビュー

修正差分（`MatrixPage.vue`のunknown-cell分岐、`ComparisonPage.vue`/`MatrixPage.vue`の
`goBack`、`MatrixPage.test.ts`のテスト書き直し、`functional-overview.md`/
`repository-structure.md`のドキュメント追記）について、メイン側で以下を確認済み:

- `npx vitest run` → 8ファイル / 71件全て成功、スキップ0件
- `npx vue-tsc --noEmit` → エラーなし
- `npx eslint src --max-warnings=0` → 警告0件
- `npm run build` → 成功

前回指摘の解消状況:
- マッチアップ未定義の誤表示: 解消（`--unknown`状態を新設しテストで固定）
- 導線の片道化: 解消（history-awareな`goBack`に変更）
- モジュール構成図未更新: 解消
- ルーター説明が古い: 解消

修正が触った箇所（`goBack`のhistory依存分岐、`hasMatchup`追加によるテンプレート分岐増加）
について、新たな欠陥の兆候は見当たらない。`goBack`のフォールバック分岐はテスト環境の
`window.history.state`が未設定であることに依存するため、実ブラウザでの`router.back()`側
分岐（履歴があるケース）は未検証のまま残る。

## レビュー完了（2026-09-12）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - `router-link`の`to`を文字列組み立てにしている点（Low、実害なし。将来ID命名規則を
    変える場合は route オブジェクト形式への切り替えを検討）
  - セルごとの`getMatchup`呼び出し回数（Low、N=4では無視できる規模）
  - `goBack`の`router.back()`分岐（履歴ありのケース）はユニットテスト環境では
    通らないため、実ブラウザでの動作確認は未実施

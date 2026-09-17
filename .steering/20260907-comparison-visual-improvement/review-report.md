# コミット前レビューレポート

## 第1回（2026-09-08）

- 対象: main（e39db89）からの未コミット差分。実コード差分は `src/types/formation.ts`、
  `src/data/matchups.ts`、`src/components/PitchDiagram.vue`、`src/pages/ComparisonPage.vue`
  と対応するテスト、およびドキュメント8ファイル + `.steering/20260907-comparison-visual-improvement/`
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 6件

## コミット前レビュー結果

対象: `feature/comparison-visual-improvement` の main（e39db89）からの未コミット差分。実コード差分のあるファイルは `src/types/formation.ts`、`src/data/matchups.ts`、`src/components/PitchDiagram.vue`、`src/pages/ComparisonPage.vue` と対応する 3 つのテスト、およびドキュメント 8 ファイル + `.steering/20260907-comparison-visual-improvement/` 3 ファイル。
（`src/App.vue`、`src/main.ts`、`src/router/index.ts`、`src/data/formations.ts`、`src/components/FormationCard.vue`、`src/pages/FormationListPage.vue` および `FormationCard.test.ts` / `PitchDiagram` 以外のテストは `git status` 上 modified だが `git diff main` の内容差分はゼロ＝CRLF 差分のみ。レビュー対象外とした。）

### Critical（即時対応必須）

なし。

### High（優先対応）

なし。

### Medium（対応推奨）

- **[運用 / ドキュメント] 「フォーメーム」誤記の再発（修正済み欠陥のリグレッション）**: 過去のレビューで
  全置換済みの誤記が、今回の追加行で再び10箇所混入していた。用語集にも入っていた。
  → 対応: `フォーメーム` → `フォーメーション` で全箇所を機械的に一括置換。

- **[バグ] `getMatchup` の戻り値が呼び出し順序によって「モジュール内配列への参照そのもの」と
  「新規オブジェクト」に分岐する**（`src/data/matchups.ts:88-102`）。順方向では `matchups` 配列の
  要素をそのまま返すため、呼び出し側が返り値を変更すると静的データが破壊される。
  → 対応: `Matchup.advantagesForA` / `advantagesForB` の型を `string[]` から `readonly string[]`
  に変更し、実行時コストゼロで書き換え不能にした（`src/types/formation.ts`）。

### Low / 改善提案

- `labelY` の viewBox 上下限クランプなし → 現行データでは実害なし。判断により見送り（全走査テストが将来のデータ追加時に検知する）。
- `getMatchup` 入れ替え時に `id` と `formationAId/formationBId` の不変条件が崩れる → コード内コメント・設計書・テストで既に明示済み。見送り。
- `ComparisonPage.test.ts` の弱いアサーション（`not.toBe`）→ 対応: `toBe(true)` / `toBe(false)` の直接比較に変更。
- `advantagesForA`/`advantagesForB` 間の重複検知なし → 現状の網羅度で妥当と判断し見送り。
- `requirements-definition.md` のスコープ節「戦術解説文」表記が旧仕様のまま → 対応: 「優位ポイントの表示」に修正。
- `.pitch-layer--overlay` に `pointer-events: none` なし → 現状インタラクション無く無害。見送り。

### 問題なし

**セキュリティ**: シークレット・URL・アカウント情報のハードコードなし。`v-html` 不使用でXSSリスクなし。ルートパラメータは静的データへのホワイトリスト照合を経由。OWASP該当カテゴリなし（外部通信・DB・認証機構を持たない静的SPAのため）。

**バグ・正しさ**: 境界値・0件・undefined分岐をテンプレート `v-if` で確実に処理。恒真テストなし（`ComparisonPage.test.ts` は実文言のリテラルで取り違えを検知する設計）。テストの空振りなし。

**性能**: ループ内I/Oなし。`getMatchup` は6件の線形探索のみ。

**運用**: ログ・設定の新規追加なし。破壊的変更（`commentary`→`advantagesForA/B`）は同一差分内で参照元をすべて更新済み。単一コミットのrevertで戻せる。

### 未検証

- 実ブラウザでの重ね合わせ表示の視認性（座標計算上は衝突回避されている設計だが、目視確認はシャビに依頼）
- レスポンシブ挙動（狭幅画面でのカラム潰れ）

## レビュー完了（2026-09-08）

- 最終ラウンド: 第1回
- 新たな Critical / High: なし（1周目から指摘なし）
- Medium 2件はコミット前に対応済み（誤記一括置換、`readonly string[]` 化）
- Low 6件のうち2件（弱いアサーション、スコープ節の表記）を対応済み、残り4件は実害が小さいため申し送り不要と判断し見送り
- 修正後、`npm run test`（47件）・`lint`・`typecheck`・`build` を再実行し全て成功

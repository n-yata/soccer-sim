# コミット前レビューレポート

## 第1回（2026-09-27）

- 対象: `C:\develop\workspace-claude\soccer-sim-worktrees\remove-league-cup` の `git diff`（34ファイル、+273/-2135）。①リーグ戦・カップ戦機能の削除 ②ヘッダー/フッターの一貫性修正（`PageHeader.vue`統一）
- 結果: Critical 0件 / High 1件 / Medium 5件 / Low 5件

## コミット前レビュー結果

（サブエージェントの返答をそのまま記録。全文は長いため要点を記す。詳細な指摘一覧は下記「対応」を参照）

### Critical
なし

### High
- **[運用] 用語集画面の戻り動作変更がドキュメント3点に未追随**: `GlossaryPage.vue`が`router-link to="/"`から`PageHeader`経由の`BackButton`へ変わったが、`screen-design.md`・`screen-03-glossary.md`・`test-screen-03-glossary.md`が旧仕様（固定文言「← 一覧画面へ戻る」・静的遷移）のまま。

### Medium
1. `test-screen-02-comparison.md`にリーグ戦・カップ戦への言及が残存（削除済み画面を根拠にした説明文）
2. `repository-structure.md`の`components/`依存関係ルールが、`PageHeader`→`BackButton`のような同一層コンポーネント合成を明記していない
3. `QuizPage`の用語集リンクのスタイルが白背景のまま（`ComparisonPage`/`FormationListPage`は透明背景+白枠に統一済み）で見た目が不揃い
4. `ComparisonPage.vue`の新規ラッパーdiv内部の字下げが1段分ズレている
5. `GlossaryPage.test.ts`の新規テストが`history.state`を明示的に初期化していない

### Low
- `requirements-definition.md`の見出し直前の空行欠落
- `.comparison-page`/`.matrix-page`/`.quiz-page`ルートクラスがスタイル定義ゼロになった（実害なし）
- import表記の不統一（`@/components/...` vs `./...`）
- 白枠ピルのCSS重複（3箇所）
- `.steering/`が未追跡

### 問題なし（確認済み）
- セキュリティ①〜④: 該当変更なし、削除によりマジックナンバー・ログ出力が減る方向
- 削除漏れ（コード・型）: 横断検索でゼロ確認
- 削除漏れ（ドキュメント構成）: screen-06/07・test-screen-06/07削除後の被リンクなし
- CSS構造変更: padding/@media漏れなし、prefers-reduced-motion対応も追加済み
- a11y/コントラスト: BackButtonの視認性、タップ領域44px確保
- 性能: 純減（リーグ戦28試合・カップ戦7試合+PK戦の計算が消える）
- 後方互換性: 意図した削除範囲を超えた公開API削除なし
- テストの追随: AppHeader/FormationListPage/MatrixPage/QuizPageのテスト修正は妥当

### 未検証
- テスト・型チェック・ビルドの再実行（メイン側で実行済みと報告、レビューでは読み取り専用のため未実施）
- ブラウザでの目視確認（メイン側で実施済みと報告）
- `.steering/`の中身（レビュー対象差分外）

### 総合評価
Critical: なし。High: 1件。Medium 5件とあわせて対応してからコミットを推奨。

### 対応

- High（用語集戻り動作のドキュメント未追随）: `screen-design.md`・`screen-03-glossary.md`・
  `test-screen-03-glossary.md`の3ファイルを、`PageHeader`経由の`BackButton`（履歴があれば
  `router.back()`、無ければ`/`。文言「← 戻る」）に合わせて更新した。
- Medium1（test-screen-02-comparison.mdの残存記述）: リーグ戦・カップ戦への言及を削除し、
  「比較画面（およびハーフタイム采配）の中核アルゴリズム」という表現に修正した。
- Medium2（repository-structure.mdの依存関係ルール）: `components/`の依存関係に
  「同階層の`components/`（コンポーネント合成。例: `PageHeader.vue`→`BackButton.vue`、
  `FormationCard.vue`→`FormationMiniPitch.vue`）」を追記した。
- Medium3（QuizPageの用語集リンクスタイル不統一）: `ComparisonPage`/`FormationListPage`と
  同じ透明背景+白枠+白文字のスタイルに統一した。
- Medium4（ComparisonPage.vueの字下げ）: 新規ラッパーdiv内部を1段字下げし直した。
- Medium5（GlossaryPage.test.tsのhistory.state初期化漏れ）: `QuizPage.test.ts`と同じパターンで
  `window.history.replaceState`による明示的な初期化と、履歴ありケースのテストを追加した。
- Low: 実害が小さいため今回は見送り、次回作業時の申し送りとして記録する
  （空行・BEMブロック名の空セレクタ・import表記・CSS重複・`.steering/`の扱いはコミット時に判断）。

## 第2回（2026-09-27）— 修正後の再レビュー

- 対象: 第1回で指摘されたHigh 1件・Medium 5件の修正箇所
- 結果: 前回指摘すべて解消。新たなCritical 0件 / 新たなHigh 0件 / 新規Medium 1件 / 新規Low 3件

### 前回指摘の解消状況

High（用語集画面の戻り動作ドキュメント未追随）・Medium 1〜5すべて解消を確認。特に
`ComparisonPage.vue`の字下げ修正は`git diff -w`（空白無視）で純粋な空白差分のみであることを
機械的に確認し、v-if/v-else分岐・タグ対応の破壊がないことを検証済み。

### 新たなCritical / High
なし。

### 新規Medium（1件・対応済み）
- `test-screen-03-glossary.md`のGlossaryPageケースが3本のみで、GlossaryPage.test.tsに
  追加した「履歴がある場合はrouter.back()」のテストに対応する行がなかった
  → ケース6として追記した。

### 新規Low（3件）
- `PageHeader.vue`のprops宣言行が100文字超過 → 複数行に整形して対応済み。
- `GlossaryPage.test.ts`の`routerLinkStub`が死にコード化していた（GlossaryPage/PageHeader/
  BackButtonのいずれも`router-link`を使わなくなったため）→ 削除して対応済み。
- `requirements-definition.md`のFR-18削除行の直後に空行が無い → 実害は軽微（CommonMarkの
  見出し解釈上は問題ない）なため、今回は見送り、次回ドキュメント整形時の申し送りとする。

### 総合評価
コミットして問題ない。新たなCritical/Highなし。

## レビュー完了（2026-09-27）

- 最終ラウンド: 第2回（新規Medium対応後、再テストのみ実施しレビューは省略。理由: 修正内容が
  単体テスト仕様書への1行追記のみで、コード・挙動への影響がないため）
- 新たな Critical / High: なし
- 積み残し（Low）: `requirements-definition.md`の空行、白枠ピルCSSの重複（3箇所）、
  BEMブロック名が空になった`.comparison-page`/`.matrix-page`/`.quiz-page`セレクタ、
  `.steering/20260920-cup-and-player-variance`という既存ディレクトリ名（履歴参照のため
  変更不要）、既存の`screen-design.md`比較画面節・`matchSimulation.test.ts`のFR-17コメント
  （いずれも本作業のスコープ外）。実害は小さく、次回UI/UX・ドキュメント整備作業時に
  併せて検討する。

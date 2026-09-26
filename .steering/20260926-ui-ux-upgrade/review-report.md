# コミット前レビューレポート

## 第1回（2026-09-26）
- 対象: ブランチ`feature/ui-ux-upgrade`の未コミット変更全件
  - 変更: `src/App.vue`, `src/styles/tokens.css`, `src/pages/{FormationListPage,ComparisonPage,MatrixPage,QuizPage,LeaguePage,CupPage,GlossaryPage}.vue`
  - 新規: `src/components/{AppHeader.vue,AppHeader.test.ts,BackButton.vue,BackButton.test.ts,PageHeader.vue}`, `.steering/20260926-ui-ux-upgrade/{requirements,design,tasklist}.md`
- 結果: Critical 0件 / High 1件 / Medium 4件 / Low 7件

## コミット前レビュー結果

対象: ブランチ `feature/ui-ux-upgrade` の未コミット変更全件
- 変更: `src/App.vue`, `src/styles/tokens.css`, `src/pages/{FormationListPage,ComparisonPage,MatrixPage,QuizPage,LeaguePage,CupPage,GlossaryPage}.vue`
- 新規: `src/components/{AppHeader.vue,AppHeader.test.ts,BackButton.vue,BackButton.test.ts,PageHeader.vue}`, `.steering/20260926-ui-ux-upgrade/{requirements,design,tasklist}.md`
- 検証実行: `npx vitest run`(33ファイル/483件 全パス)、`npx vue-tsc --noEmit`(エラーなし)、`npx eslint .`(エラーなし)、`npx prettier --check`

### Critical（即時対応必須）

なし。

### High（優先対応）

- **[運用/アーキテクチャ] `components/` の依存禁止ルール違反**:
  `src/components/AppHeader.vue:79` が `import { formations } from "@/data/formations";` で静的データモジュールを直接参照している。
  `docs/specs/1_requirements/repository-structure.md` の `components/` 依存関係は
  「依存可能: `types/`」「依存禁止: `pages/`、`composables/`、`data/`配下の**静的データ定義**」
  と明記しており、例外は `termAnnotation.ts`（副作用なしの純粋関数）のみと限定列挙されている。
  → (a) `showCupLink` を props にして `App.vue` 側で `formations.length` を判定して渡す、
  (b) 逸脱を許容する判断なら `repository-structure.md` の例外規定に AppHeader を明記して根拠を残す。

### Medium（対応推奨）

- **[運用] 新規コンポーネント3件がドキュメント未反映**:
  `repository-structure.md`（`components/`の配置ファイル一覧）と`component-design.md`
  （コンポーネントごとの役割・依存可能の記載）に`AppHeader.vue`/`PageHeader.vue`/`BackButton.vue`
  の項目が無い。また`screen-design.md`は各画面のヘッダーを画面固有要素として記述しており、
  全ページ共通のグローバルナビが追加された事実が反映されていない。
  → 同一コミットで3ドキュメントに追記する。

- **[バグ/保守] カップ戦導線の閾値が2箇所に二重定義**:
  `src/components/AppHeader.vue:84`と`src/pages/FormationListPage.vue:46`にそれぞれ
  `const CUP_REQUIRED_FORMATION_COUNT = 8;`が存在する。挙動一致は確認済み。
  → 定数を単一の場所（`data/formations.ts`の導出値）に寄せる。

- **[バグ] `AppHeader.test.ts`のアサーションが空振り**:
  `wrapper.find("a[href='/']").attributes("aria-current")).toBeUndefined();`は、
  `find`が先頭のブランドリンク（`:aria-current`バインド無し）を返すため、実装がどう壊れても
  必ず通る。併せて`routeState.name`を書き換えたまま復元していない（`beforeEach`での初期化が無い）。
  → `.app-header__link`セレクタで一覧リンクを明示的に選ぶ。`beforeEach`でリセットする。

- **[運用/UX] 一覧画面でナビゲーションが二重表示**:
  `App.vue`に AppHeader を追加した一方で、`FormationListPage.vue`は PageHeader スロット内に
  リーグ戦・カップ戦・理解度チェック・用語集リンクを維持しているため、トップページでは同じ
  遷移先のリンクが2組並ぶ。
  → 意図的に残すなら、その方針を design.md に残す。

### Low / 改善提案

- Prettier 非準拠（CupPage.vueの余分な空行、FormationListPage.vueの長い行）
- `MatrixPage.test.ts`のvue-routerモックに`back`が無い（現状は通っているが、履歴ありのケースを追加すると落ちる）
- 性能懸念なし
- トークン化に伴う微小な視覚ドリフト（意図通りと判断）
- `tokens.css`のコメントアウトされたブレークポイント変数が実際には使われていない
- AppHeaderから比較画面への導線がない（仕様上の制約として妥当）
- モバイルメニューの開閉（ブラウザバックで開いたままになりうる。実害小）

### 問題なし

セキュリティ（シークレット・URL・XSS・オープンリダイレクト・認証認可・情報漏洩）全項目該当なし。
バグ・正しさ: 「戻る」ロジックの挙動同一性（5ページすべてで元実装と完全一致）、カップ戦導線の条件一致、
境界値・状態リセット・既存ロジックへの影響、いずれも確認済み。
性能: 追加された計算量・I/Oなし。
後方互換: 既存テスト483件パス、削除クラス名を参照する既存テストなし。

### 未検証

- 375px/768px幅での実機目視確認（実行環境の`resize_window`制約で未実施）
- `npm run build`（本レビュー時点では未実行、後続で成功確認済み）

### 総合評価

**Critical: なし。High: 1件あり。** 現状のままコミットすることは推奨しない。

### 対応

- **High（依存禁止ルール違反）**: 解消。`AppHeader.vue`から`@/data/formations`のimportを削除し、
  `showCupLink: boolean`をpropsで受け取る形に変更。判定は`App.vue`（`computed`）へ移動。
- **Medium（ドキュメント未反映）**: 解消。`repository-structure.md`・`component-design.md`・
  `screen-design.md`の3ファイルに`AppHeader`/`PageHeader`/`BackButton`と共通グローバルナビの
  記述を追加。
- **Medium（定数の二重定義）**: 解消。`data/formations.ts`に`CUP_REQUIRED_FORMATION_COUNT`を
  export する形に統一し、`FormationListPage.vue`・`App.vue`の双方がそこから import する形に変更。
  （component-design.mdのインターフェース節にも追記）
- **Medium（AppHeader.test.tsの空振り）**: 解消。`.app-header__link`セレクタで一覧リンクを明示的に
  選ぶよう修正し、`beforeEach`で`routeState.name`を毎回リセットするよう追加。併せてモック方式を
  props直接指定（`showCupLink`）ベースに書き換え。
- **Medium（一覧画面のナビ二重表示）**: 対応せず維持。理由と次に解消する際の手順を
  `.steering/20260926-ui-ux-upgrade/design.md`「実装後の判断メモ」に明記。
- **Low**: Prettierの指摘は`npx prettier --write`で解消。それ以外のLowは申し送り（実害が小さく、
  今回のスコープでの対応は見送り）。

## 第2回（2026-09-26）— 修正後の再レビュー

対象: 第1回の High 1件・Medium 4件への対応差分（`src/App.vue`, `src/components/AppHeader.vue`,
`src/components/AppHeader.test.ts`, `src/components/PageHeader.vue`, `src/data/formations.ts`,
`src/pages/FormationListPage.vue`, `src/pages/FormationListPage.test.ts`, `src/styles/tokens.css`,
`docs/specs/`配下3ファイル, `.steering/20260926-ui-ux-upgrade/design.md`）

## 再レビュー結果

### 前回指摘の解消状況
- High: `components/`の依存禁止ルール違反 → **解消**。`AppHeader.vue`から`@/data/formations`
  のimportが消え、`showCupLink: boolean`をpropsで受け取る形に変更済み。判定は`App.vue`の
  `computed`に移行し、`:show-cup-link`で渡している。`components/`配下を全走査し、静的データ定義
  への直接依存が他に無いことも確認した。
- Medium: 新規コンポーネント3件のドキュメント未反映 → **解消**。`repository-structure.md`・
  `component-design.md`・`screen-design.md`に記載済みで、記載された利用元とコード上のimportが一致。
- Medium: 閾値(8)の二重定義 → **解消**。`data/formations.ts`に`CUP_REQUIRED_FORMATION_COUNT`を
  1箇所だけexportし、`App.vue`と`FormationListPage.vue`の両方がそこからimportしている。
- Medium: `AppHeader.test.ts`のアサーション空振り → **解消**。`.app-header__link`セレクタで一覧
  リンクを明示的に選ぶようになり、`aria-current`を実装から外せばテストが落ちることを確認。
  `beforeEach`での`routeState.name`リセットも追加済み。
- Medium: 一覧画面のナビ二重表示 → **対応せず維持（判断として妥当）**。design.mdの記載内容が
  指摘への回答として妥当と確認。

### 新たに見つかった問題
Critical / High はなし。Low 4件（`App.vue`の導線判定条件を直接検証するテストが無い、
`FormationListPage.test.ts`のモックが閾値をハードコードしている、`component-design.md`の
AppHeader依存可能欄に実装に無い`types/formation.ts`が残っていた、design.md本文の記述が
最終実装と食い違っていた箇所）。

### 検証コマンドの結果
- vitest: 成功（33 files / 483 tests すべてpass）
- lint: 成功（エラーなし）
- typecheck: 成功（エラーなし）
- build: 成功

### 総合評価
新たなCritical/Highはなし。**コミットして問題ない。**

### 対応（第2回分）
- `component-design.md`のAppHeader依存可能欄から実装に無い`types/formation.ts`を削除
- `.steering/20260926-ui-ux-upgrade/design.md`の記述（定数の移動先）を最終実装（`data/formations.ts`
  にexportしApp.vueがpropsで渡す）に合わせて修正
- 残り2件（`App.vue`の導線判定テスト追加、`FormationListPage.test.ts`モックの閾値ハードコード）は
  実害が小さいLowのため、今回は申し送りとする

## レビュー完了（2026-09-26）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - `App.vue`の`formations.length === CUP_REQUIRED_FORMATION_COUNT`条件を直接検証するテストが無い
    （`App.test.ts`の新規追加で対応可能。検出手段: 条件を反転させても現状は全テストが緑のまま通る）
  - `FormationListPage.test.ts`のモックが`CUP_REQUIRED_FORMATION_COUNT: 8`をハードコードしている
    （実害なし。`vi.importActual`で実値を差し込む形に寄せると二重定義が消える）
  - 一覧画面のナビゲーション二重表示（design.mdに理由記載済み。悪用可能な欠陥ではない）
  - `MatrixPage.test.ts`のvue-routerモックに`back`が無い（既存テストの潜在的な脆弱性）
  - `tokens.css`のコメントアウトされたブレークポイント変数、AppHeaderの比較画面への導線なし、
    モバイルメニューの開閉タイミング — いずれも実害の小さいLow

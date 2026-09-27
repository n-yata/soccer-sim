# コミット前レビューレポート

## 第1回（2026-09-27）
- 対象: アイコン全面刷新の全差分（24変更ファイル + 新規3件: `src/components/AppIcon.vue`,
  `src/components/AppIcon.test.ts`, `.steering/20260927-icon-migration/`）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 5件

## コミット前レビュー結果

対象: `soccer-sim` の未コミット作業ツリー差分（24 変更ファイル）+ 新規 3 件。絵文字 →
`@lucide/vue` アイコン全面置換。ファイルへの書き込みは一切行っていない（検証として
`npm run typecheck` / `lint` / `vitest run` / `npm audit` / `npm run build` を実行）。

### Critical（即時対応必須）
なし

### High（優先対応）
なし

### Medium（対応推奨）
- **[運用] 設計・テスト仕様書の絵文字更新が中途半端**: `screen-02-comparison.md`
  `screen-design.md` `test-screen-02-comparison.md`他に絵文字表記の残存箇所が多数あり、
  未着手だった`screen-03-glossary.md`/`screen-04-matrix.md`/`screen-05-quiz.md`/
  対応する単体テスト仕様書にも「← 戻る」等が残っていた。
- **[運用] 新規追加テストが単体テスト仕様書に未登録**: `AppIcon.test.ts`と
  `HalftimeTacticsModal.test.ts`の追加1件が仕様書に採番されていない。

### Low / 改善提案
- `.steering/.../design.md`内に旧パッケージ名`lucide-vue-next`の記載が経緯説明以外にも残存
- `requirements.md`「全26箇所」と`design.md`対応表31行の数値不一致
- `ComparisonPage.vue`の`verdictIcon`が`matchup`未確定時にTrophyへフォールバックする設計
- `AppIcon.test.ts`はCSS変数の実測ではなくクラス名検証（jsdom制約、妥当な妥協）
- `PageHeader.vue`の`h1`をinline-flex化した際のタイトル折り返し時の整列（実害は薄い）

### 問題なし
- セキュリティ①〜④: シークレット・URL・クラウド情報のハードコーディングなし。
  新規追加URLなし（Jリーグリンクは既存行の再掲のみ）。`v-html`/`eval`の新規使用なし。
  `:is="icon"`はTS型`LucideIcon`で縛られ、ユーザー入力が流れる経路なし。
- **依存関係（A06）**: `@lucide/vue@1.48.0`はnpm registry上で実在確認済み。lucide本家
  メンテナによる公式パッケージ（タイポスクワッティングではない）。`npm audit` 0件。
  `lucide-vue-next`の非推奨化も裏取り済み。
- バグ・正しさ: design.mdの対応表31行とコードの突き合わせでアイコン名・配置の不一致ゼロ。
  CSS `::before`削除によるレイアウト崩れなし（`gap`が`margin-right`と等価に代替）。
  アクセシビリティの後退なし（`HalftimeTacticsModal`閉じるボタンの`aria-label`維持を
  新規テストで固定）。新規テストは全て具体的なDOM検証で恒真テストではない。
  テスト全通過（34ファイル/533件/0スキップ）。
- 性能: 全ファイルで名前付きimport（deep importなし）。ビルド成果物のgrepで
  tree-shakingが実際に効いていることを確認（未使用アイコンのSVGノードが含まれない）。
- 運用: `architecture-overview.md`/`repository-structure.md`/`component-design.md`の
  記述が実装と整合。

### 未検証
- 変更前後のバンドルサイズ差分の実測値（作業ツリーを変更しない方針のため）
- 実機ブラウザでのモバイル幅表示（ツール制約。CSSの`@media`ブロック自体は無変更のため
  リスクは低いと判断）

### 総合評価
Critical / High の指摘なし。Medium 2件を要修正としてコミット前対応。

### 対応
- **Medium1（絵文字表記の残存）**: `docs/specs/`配下を機械的に再grepし、指摘箇所全て
  （`screen-02-comparison.md`, `screen-design.md`, `screen-03-glossary.md`,
  `screen-04-matrix.md`, `screen-05-quiz.md`, 対応する`test-screen-*.md`4ファイル）の
  「← 戻る」「⇄ 入れ替え」「▶ 後半を開始する」等をアイコン名表記へ一括置換。
  再grepで`docs/specs/`配下の絵文字残存ゼロを確認済み（`wireframes.drawio`は
  requirements.mdで明示的にスコープ外）。
- **Medium2（新規テスト未登録）**: `HalftimeTacticsModal.test.ts`の`aria-label="閉じる"`
  維持テストを`test-screen-02-comparison.md`のHalftimeTacticsModalセクションへNo.187として
  追加登録。`AppIcon.test.ts`は共通コンポーネントテストであり、同種の既存コンポーネント
  （`BackButton.test.ts`等）も本プロジェクトの単体テスト仕様書（画面単位の構成）には
  カタログされていない既存慣習と整合するため、意図的に対象外とした。
- **Low対応**:
  - `verdictIcon`のロジックを`overallEdge === "even" ? Scale : Trophy`から
    `edge === "A" || edge === "B" ? Trophy : Scale`へ修正（未確定時にTrophyを誤表示
    しないようフォールバックを安全側に変更）。`ComparisonPage.test.ts`53件パス確認済み
  - `design.md`内の旧パッケージ名`lucide-vue-next`の記載（経緯説明以外）を`@lucide/vue`へ修正
  - `requirements.md`の「全26箇所」を実態に合わせ「全31箇所」に修正
  - 残り2件（AppIconのCSS変数実測・PageHeaderのinline-flex整列）は実害が小さいため
    申し送りとし、対応しない

修正後、`npm run test`（533件）/ `npm run lint` / `npm run typecheck`を再実行し、
全てパスすることを確認済み。

## レビュー完了（2026-09-27）
- 最終ラウンド: 第1回（Medium対応後の再レビューは不要と判断。対応内容はドキュメント修正・
  条件分岐の安全化・テスト追加のみで、既存ロジックの構造変更を伴わないため）
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: Low 2件（AppIconのサイズCSS変数はjsdom制約で
  実測できないためクラス名検証で代替している旨、PageHeaderのタイトル折り返し時の整列は
  現状2画面のみ短いタイトルのため実害なしと判断）

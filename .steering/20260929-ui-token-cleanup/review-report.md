# コミット前レビューレポート

## 第1回（2026-10-01）
- 対象: `feature/ui-token-cleanup` の `master` 差分 27ファイル（`tokens.css`・`base.css`、`App.vue`、components 15件、pages 5件 + テスト3件、`docs/specs/2_basic-design/screen-design.md`）
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件

## コミット前レビュー結果

対象: `feature/ui-token-cleanup` の master 差分 27ファイル（`src/styles/tokens.css`・`base.css`、`src/App.vue`、components 15件、pages 5件 + テスト3件、`docs/specs/2_basic-design/screen-design.md`）。検証として `npx vitest run`（34ファイル/535テスト 全passed）と `npm run build`（成功）を実行。ファイルの書き込み・編集は一切行っていない。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし（セキュリティ必須4項目①〜④、OWASP 該当の指摘もなし。詳細は「問題なし」参照）

### Medium（対応推奨）
- **[バグ/テスト] コンテナ幅テストの検証力低下**: `src/pages/FormationListPage.test.ts:129` / `src/pages/ComparisonPage.test.ts:250` は `getComputedStyle(...).maxWidth` を `"var(--width-wide)"` と文字列比較している。セレクタ不一致や宣言漏れなら `""` になるため完全な空振りではないが、元のテスト意図（実際の幅が十分広いこと）は検証できていない。`--width-wide` が将来変えられても両テストは緑のまま通る。→ トークンの実値を1か所で検証するテストを追加し、各画面のテストは「正しいトークンを参照している」役割に限定する、と役割分担を明示するのが安全。
- **[運用/ドキュメント] screen-design.md 内の記述が自己矛盾**: 共通節は用語集の段組みを `min-width: 901px` としたが、画面4の既存記述は「769px以上で2カラム」のままで、フリガナ表示の削除も未反映だった。
- **[運用] `--color-surface` を文字色・線色として使っている**: 各所で `color/stroke/fill: var(--color-surface)` としており、意味が逆方向のトークン。Phase 3（ダークモード）で面色を暗くすると同時にこれらの文字が暗転して読めなくなる。→ `--color-text-inverse` 等を新設して置き換える必要あり。

### Low / 改善提案
- **[運用] 死んだCSS**: `GlossaryPage.vue` の `.glossary-page__reading` はテンプレートから参照元が無くなっていた。
- **[バグ] `scrollbar-gutter: stable` の効果範囲**: 非対応ブラウザ（Safari 18.2 未満等）では解消しない。
- **[バグ/UI] FormationCard のバッジ重なり**: グリッド最小列幅付近でバッジがピッチ枠に重なる可能性。実機幅での目視確認を推奨。
- **[UI] `PageHeader` に `overflow: hidden` を追加**: グラデーション演出撤回後は不要。
- **[バグ] `App.vue` の `min-height: 100vh`**: モバイルのツールバー伸縮で超過しうる。`100dvh` 併記が無難。

### 問題なし
- セキュリティ①ハードコーディング: シークレット・APIキー・トークン・URL・クラウドアカウント情報の追加なし。追加直値は色・寸法のみで、むしろハードコード色をトークンへ寄せる方向。
- セキュリティ②認証・認可: 該当変更なし（認証機構を持たない静的フロントエンド）。
- セキュリティ③インジェクション/XSS: `v-html`/`innerHTML`/`eval`/動的`<script>`の追加なし。
- セキュリティ④情報漏洩: ログ・エラー表示の変更なし。
- バグ: 新規参照トークンの定義漏れなし。`--color-pitch-dark`値変更は描画に影響なし。`.selected`のアクセントリングは維持。
- 性能: 計算量・I/Oの変化なし。FormationCardのホバーはリフト→border/background変化で描画負荷はむしろ低下。
- 運用（後方互換・切り戻し）: `router/index.ts`に変更なし。CSSカスタムプロパティは追加・値変更のみで削除された変数はない。ブレークポイントは640px/901pxの2値に収束。revert可能。

### 未検証
- 実ブラウザでの目視確認（jsdomでは検証不可）: メインエージェント側で開発サーバーを起動し、5画面すべてを1920px幅で確認済み（header/body左端352.5pxで一致、matrix tableの中央寄せも確認）。狭いビューポート（640px/901px境界）での目視は本レビューでは未実施。
- コントラスト比: WCAG比は未計測（旧値とほぼ同等のため大きな後退はない見込み）。
- 型チェック: レビュー実行時は`vite build`のみで`vue-tsc`含まず。メインエージェント側で別途`npx vue-tsc --noEmit`を実行しエラー無しを確認済み。

### 総合評価
Critical / High の指摘はなし。セキュリティ必須4項目およびOWASP観点でも指摘事項なし。コミット可能と判断。

### 対応
- Medium「screen-design.md内の記述が自己矛盾」: 対応済み。画面4の記述を901px・フリガナ非表示に更新し、`functional-overview.md`の該当箇所も修正。
- Low「死んだCSS」: 対応済み。`.glossary-page__reading`を削除。
- Low「PageHeaderのoverflow:hidden」: 対応済み。グラデーション演出撤回に合わせて削除。
- Medium「コンテナ幅テストの検証力低下」: 申し送り。Phase 8（ダークモード）着手前に、トークン実値を検証する専用テストの追加を検討する。
- Medium「--color-surfaceの文字色流用」: 申し送り。Phase 8（ダークモード）着手時に`--color-text-inverse`等の新設とあわせて解消する（design.mdに記録済み）。
- Low「scrollbar-gutter非対応ブラウザ」「FormationCardバッジ重なり」「100vh」: 申し送り（実害未確認のため今回は見送り）。

## レビュー完了（2026-10-01）
- 最終ラウンド: 第1回
- 新たなCritical / High: なし
- 積み残し（Medium / Low）:
  - コンテナ幅テストの検証力低下（テスト強化。悪用性なし）
  - `--color-surface`の文字色流用（Phase 8で解消予定。design.md記載済み）
  - `scrollbar-gutter`非対応ブラウザでの残存ずれ（影響範囲: 旧Safari。design.mdに既知の限界として記載済み）
  - FormationCardバッジの重なり可能性（極端に狭いグリッド列幅でのみ発生、実機確認が必要）
  - `100vh`のモバイルツールバー挙動（実害小）

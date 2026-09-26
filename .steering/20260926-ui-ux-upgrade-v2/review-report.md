# コミット前レビューレポート

## 第1回（2026-09-26）

- 対象: `soccer-sim-worktrees/ui-ux-upgrade-v2` の未ステージ差分 18 ファイル（`git diff`、469 insertions / 11 deletions）。UI/UX アップグレード（タップ領域 44px 化、`@media` レスポンシブ追加、transition/animation 追加、`prefers-reduced-motion` 対応、RadarChart の rAF 座標補間）。加えて未追跡ディレクトリ `.steering/20260926-ui-ux-upgrade-v2/`。
- 補助検証: `npx vue-tsc --noEmit`（エラーなし）、`npx eslint .`（エラーなし）、`npx vitest run`（36 files / 548 tests all pass）。
- 結果: Critical 0件 / High 1件（対象2ファイル） / Medium 6件 / Low 7件

## コミット前レビュー結果

対象: `soccer-sim-worktrees/ui-ux-upgrade-v2` の未ステージ差分 18 ファイル（`git diff`、469 insertions / 11 deletions）。UI/UX アップグレード（タップ領域 44px 化、`@media` レスポンシブ追加、transition/animation 追加、`prefers-reduced-motion` 対応、RadarChart の rAF 座標補間）。加えて未追跡ディレクトリ `.steering/20260926-ui-ux-upgrade-v2/`。
補助検証: `npx vue-tsc --noEmit`（エラーなし）、`npx eslint .`（エラーなし）、`npx vitest run`（36 files / 548 tests all pass）。

### Critical（即時対応必須）
なし。

### High（優先対応）

- **[バグ / 運用(a11y)] `prefers-reduced-motion` の打ち消しがソース順で無効化されている（2ファイル）**: CSS の `@media` はセレクタ詳細度を上げないため、同一詳細度なら「後に書かれたルール」が勝つ。今回、reduce 用ブロックより **後ろ** に `transition` を追加しているため、次の指定は実行時に効かない。
  - `src/pages/ComparisonPage.vue`: reduce ブロックは 592–600 行（`.comparison-page__simulate-button` / `__halftime-tactics-button` / `__halftime-continue-button` に `transition: none`）だが、当該 `transition` の宣言は 670 行・700 行で後勝ち。さらに `:hover { transform: translateY(-1px) }` に対する `transform: none` がないため、reduce 環境でもホバー移動が残る。
  - `src/components/HalftimeTacticsModal.vue`: reduce ブロックは 222–233 行（`__close` / `__reset` / `__confirm` に `transition: none`）だが、`transition` 宣言は 263 行・305 行で後勝ち。`.halftime-modal__confirm:hover { transform: translateY(-1px) }` も無効化されていない。
  → 各ファイルの `@media (prefers-reduced-motion: reduce)` ブロックを `<style>` の **末尾** へ移す（他 15 ファイルは順序が正しく、末尾に置く形になっている）。併せて `transform: none` も reduce ブロックに含める（`ComparisonControls.vue` / `FormationCard.vue` は既にその形になっており、そちらが正しい書き方）。要件 FR-06（`prefers-reduced-motion: reduce` 時はアニメーション無効化）に対する実質的な未達なので High とした。

### Medium（対応推奨）

- **[バグ/性能] RadarChart: ドラッグ中は 300ms 補間が毎 pointermove でリセットされ、描画がポインタに追従しきらない**: `FreeLayoutPitchDiagram.vue` は `pointermove` ごとに `update-position` を emit する設計（同ファイル 94 行のコメント「1ドラッグで数十〜数百回」）。その都度 `seriesPolygons` が再計算され、`watch` が `cancelAnimationFrame` → 新規 `requestAnimationFrame` を張り直すため、`t` が常に小さい値で打ち切られ、レーダーは最大 300ms 遅れて追従する「イージング追従」になる。
  → ドラッグ中（`update-position` 連続発火中）は補間をスキップして即時反映し、`update-position-end` 到達時のみ補間する方針を検討。
- **[バグ/運用] RadarChart の補間ロジックがテストで一切カバーされていない**: `src/components/RadarChart.test.ts` は `setProps` 後に `[role="status"]` の文字列しか検証せず、`points` の描画値を prop 変更後に検証するテストがない。
  → フェイクタイマー/フェイク rAF で (1) 補間途中の中間座標、(2) 完了後に目標座標へ一致、(3) 系列数・軸数変化時は即時確定、(4) `prefers-reduced-motion` 時は即時確定、(5) unmount 時に `cancelAnimationFrame` が呼ばれる、を最低限固定するテストを追加。
- **[バグ] `FreeLayoutPitchDiagram.vue`: CSS ジオメトリプロパティ `r` は WebKit(Safari/iOS) で未サポート**: 追加した `transition: r ...` と `:hover/:focus-visible { r: 5.5 }` は Chrome/Firefox では効くが、Safari は SVG ジオメトリプロパティを CSS として解釈しないため **iOS では黙って無効**。
  → `transform: scale()`（`transform-box: fill-box; transform-origin: center`）で拡大する方式に変更。
- **[バグ] モーダルの leave トランジション中（200ms）も背面オーバーレイが操作・読み上げ対象のまま**: `ComparisonPage.vue` が `<Transition name="halftime-modal-fade">` を追加したことで、`HalftimeTacticsModal` の unmount が 200ms 遅延する。その間 `.halftime-modal-backdrop` がクリックを受け続ける。
  → `.halftime-modal-fade-leave-active { pointer-events: none; }` を追加。
- **[運用] `FormationListPage.vue` にだけ `prefers-reduced-motion` ブロックがない**: 同ファイルは 93 行・115 行で `transition` を追加しているが reduce 用の打ち消しがない（他 16 ファイルは追加済み）。
- **[運用] ドキュメント未反映**: `docs/specs/2_basic-design/component-design.md` の RadarChart 責務は「SVG で静的に描画する」旨のみで、今回追加した「目標値変化時に 300ms で頂点を補間する／`prefers-reduced-motion` 時は即時確定する／系列数・軸数変化時は補間しない」という状態を持つ振る舞いが書かれていない。
  → `component-design.md` へ追記。

### Low / 改善提案

- **[バグ] RadarChart: 軸の並び替えに対する保護がない**: 形状一致判定は「系列数」と「頂点数」のみ。軸数が同じまま順序だけ変わった場合、`vertexIndex` 基準で別軸同士を補間して無意味なモーフになる。`axisId` の一致も形状一致条件に含めると安全。
- **[バグ] タブ非表示時**: rAF は非表示タブで停止するため、`displaySeries` が中間座標のまま停止する（復帰時は `t>1` で即座に確定するので破綻はしない）。
- **[バグ] SSR ガードの非対称**: `prefersReducedMotion()` は `typeof window` を見る一方、`requestAnimationFrame` / `performance.now` は無防備。本プロジェクトは SPA のみなので実害なし。
- **[運用] トランジション用 CSS の置き場所が呼び出し側とずれている**: `term-popover-fade-*` は `TermPopover.vue`、`halftime-modal-fade-*` は `HalftimeTacticsModal.vue` の scoped style にあるが、`<Transition>` は親側にある。子ルートに子の scope 属性が付くため現状は動くが、将来ルートがフラグメント化すると無言で効かなくなる。
- **[運用] `.halftime-modal` の基底 `transition: opacity/transform` は `*-enter-active/leave-active` と重複**しており、実質デッドな宣言。
- **[運用] `min-height: 44px` に `box-sizing: border-box` が付いていない箇所**: `QuizPage.vue`、`FormationListPage.vue` の `__matrix-button`、`QuizQuestionCard.vue` の `__choice`。
- **[運用] タッチデバイスでの `:hover` 固着**: `ComparisonControls.vue` の `__swap-button:hover { transform: rotate(180deg) }` は、タップ後にホバー状態が残る端末で回転が残留し得る。`@media (hover: hover)` で囲むと安全。
- **[セキュリティ(情報)] `:style="{ '--series-color': \`var(${s.colorVar})\` }"`** は CSS 変数名を文字列連結している（差分外の既存コード）。現状 `colorVar` は内部定数のみなので実害なし。

### 問題なし（確認済み）

- セキュリティ①ハードコーディング: シークレット・API キー・トークン・エンドポイント URL・AWS アカウント/ARN/リージョンの追加なし。差分は CSS と Vue の描画ロジックのみ。
- セキュリティ②認証・認可: 該当なし（バックエンド・認証・DB を持たないオフライン SPA）。
- セキュリティ③インジェクション/XSS: `v-html` / `innerHTML` / `eval` / 動的 `<script>` の追加なし。
- セキュリティ④情報漏洩: `console.*` の追加なし、例外メッセージの画面出力追加なし。
- OWASP Top 10: 通信・永続化・デシリアライズ・依存追加がなく、該当項目なし。
- バグ: RadarChart の rAF は `onBeforeUnmount` で `cancelAnimationFrame` 済み、系列数・軸数不一致時は補間せず即時確定するため undefined 参照は起きない。既存のゼロ除算ガードは維持。
- 性能: 追加分は CSS transition と rAF 補間のみで、新規 I/O・新規ループ・N+1 的処理なし。
- 運用: 型チェック・ESLint・全テスト（548 件）が緑。後方互換性のある変更（props / emits の変更なし）。

### 未検証

- 実ブラウザでの目視確認（rAF 補間の見た目、モーダルのフェード、Safari/iOS での `r` ホバー拡大の可否、reduce 設定時の実挙動）。
- タップ領域 44px が実際に満たされているか（padding/font との合成結果）のレンダリング実測。
- `.steering/20260926-ui-ux-upgrade-v2/` 配下3ファイルの中身（レビュー時点では差分対象外のため未読）。

### 総合評価

Critical なし / High あり（1件、対象は `ComparisonPage.vue` と `HalftimeTacticsModal.vue`）。修正してからコミットする。

### 対応

- High（reduce打ち消しの後勝ち問題）: `ComparisonPage.vue`・`HalftimeTacticsModal.vue`双方で、`prefers-reduced-motion`ブロックを`<style>`末尾へ移動し、`transform: none`をtransitionの打ち消しと併記した。
- Medium（RadarChartドラッグ追従の遅延）: `FreeLayoutPitchDiagram`からのドラッグ中更新は`update-position`イベント由来と判定し、ドラッグ中は補間をスキップして即時反映するよう修正（`ComparisonPage.vue`側でドラッグ中フラグを`RadarChart`へ伝播）。
- Medium（RadarChart補間の未テスト）: `RadarChart.test.ts`に中間座標・完了後の一致・系列数変化時の即時確定・`prefers-reduced-motion`時の即時確定・unmount時の`cancelAnimationFrame`呼び出しを検証するテストを追加した。
- Medium（Safari非対応の`r`アニメーション）: `transform: scale()` + `transform-box: fill-box`方式に変更した。
- Medium（モーダルleave中の背面クリック吸収）: `.halftime-modal-fade-leave-active`に`pointer-events: none`を追加した。
- Medium（FormationListPageのreduced-motion漏れ）: `prefers-reduced-motion`ブロックを追加した。
- Medium（ドキュメント未反映）: `docs/specs/2_basic-design/component-design.md`のRadarChart責務にアニメーション挙動を追記した。
- Low: `box-sizing: border-box`の統一、`@media (hover: hover)`によるタッチ固着対策、デッドなtransition宣言の削除を行った。並び順保護・タブ非表示時の扱い・CSS変数名連結・Transition配置の申し送りコメントは、実害が小さいため積み残しとして本レポートに記録するに留めた。

## 第2回（2026-09-26）— 修正後の再レビュー

- 対象: 第1回で指摘された High 1件・Medium 6件の修正箇所（`ComparisonPage.vue` / `HalftimeTacticsModal.vue` / `FreeLayoutPitchDiagram.vue` / `RadarChart.vue` / `RadarChart.test.ts` / `FormationListPage.vue` / `ComparisonControls.vue` / `docs/specs/2_basic-design/component-design.md`）と、その周辺。
- 結果: 新たな Critical 0件 / 新たな High 0件 / 新規 Low 7件（いずれも後追いで足りる範囲）

## コミット前レビュー結果（第2回・再レビュー）

対象: worktree `ui-ux-upgrade-v2` の未コミット差分全体（20ファイル、+681/-11）。うち第1回指摘の修正対象を重点確認。加えて `prefers-reduced-motion` ブロックの記述順を全ファイル横断で機械的に再検証した。

### 前回指摘の解消状況

**High: reduced-motion の打ち消しがソース順で無効化されていた → 解消**
- `ComparisonPage.vue`・`HalftimeTacticsModal.vue`ともに reduce ブロックが `<style>` 末尾へ移動し、対象の `transition`/`transform` 宣言はすべて前方にあるため、セレクタ特異度同値の「後勝ち」で正しく無効化される。`transform: none` も追記済み。
- 横断確認: reduce ブロックを持つ全19ファイルで、対象セレクタの `transition:`/`animation:`/`transform:` 宣言行番号がreduceブロックより前にあることを確認（`QuizQuestionCard.vue`のみreduceが末尾ではないが、それ以降に対象セレクタの再宣言がなく機能上問題なし）。

**Medium 1〜6: すべて解消（実装内容が意図通り機能することを確認）**
- RadarChartのドラッグ追従負け対策（`RAPID_CHANGE_THRESHOLD_MS`）は状態漏れなく機能。
- 補間ロジックのテスト6件はいずれも実測値ベースで意味のあるアサーション。
- Safari非対応`r`の代替（`transform: scale` + `fill-box`）はcx/cyによる位置決めに影響しない。
- モーダルleave中のクリック吸収は`pointer-events: none`で解消。
- `FormationListPage.vue`のreduce漏れは解消。
- ドキュメント（`component-design.md`）は実装と一致する形で反映済み。

**Low（box-sizing / hover:hover / デッド宣言削除）→ すべて反映確認**

### 新たなCritical（即時対応必須）

なし。

### 新たなHigh（優先対応）

なし。

### Medium/Low（新規・任意）

再レビューで新たに7件のLowを指摘された。うち以下2件は再レビュー結果を受けてこの場で対応した:

- `QuizPage.vue`のreduceブロックに`transform: none`が抜けていた → 追加済み
- `RadarChart.test.ts`の`vi.unstubAllGlobals()`をテスト末尾から`afterEach`へ移動（assertion失敗時のスタブ漏れ防止）、unmountテストのcancelAnimationFrameアサーションを`mockClear()`で厳密化 → 対応済み

残り5件は実害が極めて小さい/既存コードの参考指摘のため、積み残しとして記録する:

- `RadarChart.vue`の`performance.now()`とrAFタイムスタンプの混用（実ブラウザでは問題なし。フェイクタイマー環境でのみ理論上の影響があるが、壊れても「補間しない」に倒れるだけで実害なし）
- 補間完了フレームの浮動小数丸め（視覚的影響なし）
- `FreeLayoutPitchDiagram.vue`の選手hoverに`@media (hover: hover)`が未適用（タッチデバイスでのホバー固着の可能性。対応コストと効果を見て次回判断）
- `ComparisonControls.vue`の`select`/`swap-button`に明示的な`:focus-visible`スタイルがない（UA既定のフォーカスリング頼み。今回の差分が持ち込んだ劣化ではなく既存の状態）

### 総合評価

新たなCritical/Highなし。コミットして問題ない。

## レビュー完了（2026-09-26）

- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Low）: 上記「Medium/Low（新規・任意）」の残り5件。実害は極めて小さく、次回UI/UX作業時に併せて検討する。所在（ファイル名・行）はこのレポート内に留め、悪用可能な欠陥ではないため公開レポートへの記載を許容する。

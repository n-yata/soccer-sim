# コミット前レビューレポート

## 第1回（2026-10-05）
- 対象: worktree `feature/screen-6-8-tests` の未コミット差分（`src/pages/LearningListPage.test.ts`・`src/pages/FormationLearningPage.test.ts`・`src/components/TacticalReplay.test.ts`・`src/pages/FreeLayoutBoardPage.test.ts`、`docs/specs/4_unit-test/test-screen-06/07/08-*.md`、新規 `.steering/20261005-screen-6-8-tests/`）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: worktree `C:/develop/workspace-claude/soccer-sim-worktrees/feature-screen-6-8-tests`（ブランチ `feature/screen-6-8-tests`）の未コミット差分 — `src/pages/LearningListPage.test.ts` / `src/pages/FormationLearningPage.test.ts` / `src/components/TacticalReplay.test.ts` / `src/pages/FreeLayoutBoardPage.test.ts`、`docs/specs/4_unit-test/test-screen-06/07/08-*.md`、untracked の `.steering/20261005-screen-6-8-tests/`（requirements.md・design.md・tasklist.md）。差分が依存する本番側の要素（`LearningListPage.vue` の flatMap、`FormationLearningPage.vue` の lessonTerms・roles・alert、`FreeLayoutBoardPage.vue` の aria-describedby、`TacticalReplayPlayer.vue` の document.hidden・matchMedia、`BackButton.vue` のクラス名、`vite.config.ts` の test 設定）を突き合わせた。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] No.41 の赤チーム非干渉チェックが自己比較になりうる（`FreeLayoutBoardPage.test.ts`）: `redBefore = pitch().props("formationB")` は値のコピーではなく、そのオブジェクトへの参照を保持している。陣形変更処理が赤の配置オブジェクトを**その場で書き換える**不具合だと、`toEqual(redBefore)` は同一オブジェクト同士の比較になり緑のまま通る。新しいオブジェクトに差し替える不具合なら検出できるため実害は小さい。修正例: `structuredClone(toRaw(...))`、または比較に使う値（`positions` の id・x・y）だけを先に取り出しておく。
- [バグ] 「戻るボタンが無い」の確認がクラス名頼み（LearningList No.14・Board No.40）: `find(".back-button").exists()).toBe(false)` は `BackButton.vue` のクラス名に依存しており、クラス名を変えるとボタンが出ていても黙って通る（現時点のクラス名は一致を確認済み）。修正例: `findComponent(BackButton).exists()).toBe(false)`、または `show-back-button` を付けた画面で同じセレクタが見つかる陽性対照を置く。
- [運用] steering の tasklist で review-pre-commit・retrospective が `[ ]`: 今回のレビュー結果を反映した時点で更新すること。

### 問題なし
- セキュリティ①: 差分（テスト・仕様書・steering）に URL・キー・トークン・アカウント情報なし（http/api_key/token/secret/password を grep し該当0件）。外部通信なし。②認証・認可、③インジェクション: 本番コード変更なし・該当面なし。④情報漏洩: ログ出力・エラーレスポンスの追加なし。
- バグ（空振り・恒真になっていないか）:
  - LearningList No.10・11: 全8陣形をループし、期待値を実装からコピーしないようリテラル「4-3-3を学ぶ：サイドの2対1」も確認している。
  - LearningList No.13: `learningFormations` は script setup 内でマウントごとに計算されるため、マウント前に `missingId` を設定すれば効く。7枚・4-4-2 無し・4-3-3 あり（陽性対照）・alert 無しを確認。
  - FormationLearning No.19: 置換文言が登録用語21件のいずれも含まないことを確認。`lessonTerms` が走査する項目（objective・caution・scene.title・各 step の4項目）はすべて置換済みで漏れなし。将来、用語の追加で誤一致した場合はテストが目に見えて失敗する。
  - FormationLearning No.17・18: `aria-current` が1件のみ、役割一覧は完全一致で、恒真になっていない。
  - TacticalReplay No.27〜33: いずれも状態変更の前の値を確認してから変化を見ている（No.30 の「再生完了」が最初は無いこと、No.31 の到着時点ラベル、No.32 の「1 / 5」とタイマー0件など）。No.33 のスパイは本番の `if (isLastStep.value || document.hidden) return;` に対応。
  - Board No.41: 陣形変更でボールが中央へ戻る不具合と区別するため、先にボールを動かしてから変更している。選ぶ陣形が初期と異なることも事前に確認。
- バグ（後始末漏れ・順序依存）: 部分モックの `vi.mock` はファイル単位で、`vite.config.ts` に `isolate: false` が無い（既定でファイルごとに分離）ため他ファイルへ漏れない。同一ファイル内では `afterEach` で `missingId` / `override` を `undefined` に戻し、未設定時は実関数に委譲するので既存テストへの影響なし。`document.hidden` スパイは `try/finally` で `mockRestore`。フェイクタイマーと matchMedia スタブは既存の `beforeEach`/`afterEach`（`useRealTimers`・`unstubAllGlobals`・`motionChange = undefined`）で片付く。Board は `beforeEach(localStorage.clear)` が describe 全体に掛かり、No.41 のボール保存は次のテストへ持ち越されない。追加テストは `unmount` も実行。
- 仕様書の完了欄: 画面6 No.10〜14、画面7 No.17〜19・27・28・30〜33、画面8 No.40・41 が `[x]` になり、対応するテスト実体が差分にあることを1対1で確認。備考の対応ファイル記述もテストと一致。
- 性能: テストにループ内 I/O・外部呼び出しなし。
- 運用: 本番コード無変更で revert により戻せる。不可逆な操作なし。

### 未検証
- テスト実行結果（543件成功、変異注入18通り）は依頼元の報告に依拠し、再実行していない（書き込みをしない方針のため、本番コードを壊す変異の再現も行っていない）。
- `requirements.md` は機密情報の grep のみで、全文の精読はしていない。
- 改行コードの警告（LF→CRLF）はリポジトリの git 設定によるもので、内容への影響は確認していない。

### 総合評価
Critical / High の指摘はなし。コミット可。Low の2件（No.41 の参照比較、`.back-button` セレクタへの依存）は、テストの検出力を強める改善としてこのタイミングで直すことを推奨する。

### 対応
- Low 1（No.41 の参照比較）: 赤の配置を、変更前に `positions` の id・x・y の配列として値で取り出してから比較する形に直した。「赤の配置をその場で書き換える」変異（`board.B.positions` の置き換え）を入れて、修正後のテストが落ちることを確認した（修正前のテストでは緑のまま通ることも確認）。
- Low 2（`.back-button` 依存）: LearningList No.14・Board No.40 を `findComponent(BackButton)` での確認に直した。`show-back-button` を付ける変異で、修正後も落ちることを確認した。
- Low 3（tasklist 未更新）: 本レポート作成後に更新した。
- いずれもテストの検出力の強化で、Critical / High ではないため再レビューは行わない。

## レビュー完了（2026-10-05）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: なし

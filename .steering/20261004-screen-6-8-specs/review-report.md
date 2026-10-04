# コミット前レビューレポート

## 第1回（2026-10-04）
- 対象: worktree `feature/screen-6-8-specs` の未コミット差分（新規 `docs/specs/3_detail-design/screen/screen-06/07/08-*.md`、新規 `docs/specs/4_unit-test/test-screen-06/07/08-*.md`、変更 `docs/specs/2_basic-design/screen-design.md`、新規 `.steering/20261004-screen-6-8-specs/` の requirements.md・tasklist.md）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 5件

## コミット前レビュー結果

対象: worktree `C:/develop/workspace-claude/soccer-sim-worktrees/feature-screen-6-8-specs`（ブランチ `feature/screen-6-8-specs`）の未コミット差分。新規 `docs/specs/3_detail-design/screen/screen-06/07/08-*.md`、`docs/specs/4_unit-test/test-screen-06/07/08-*.md`、`.steering/20261004-screen-6-8-specs/{requirements,tasklist}.md`、変更 `docs/specs/2_basic-design/screen-design.md`。突き合わせ先として `src/pages/{LearningList,FormationLearning,FreeLayoutBoard}Page.vue`（+test）、`src/components/{TacticalReplay,TacticalReplayPlayer,TacticalReplayPitch,FreeLayoutPitchDiagram,BoardBall}.vue`・`freeLayoutCoordinates.ts`・`tacticalReplayFrame.test.ts`、`src/data/{formationLessons,freeLayoutStorage,boardBallStorage,tacticalScenes,formations}.ts`（+test）を読んだ。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ（文書の正確さ）] screen-06「props / state 設計」: `learningFormations` を「モジュール読み込み時に1回だけ組み立てる定数」としているが、実装は `<script setup>` 直下の const であり、組み立てはコンポーネントの setup ごと（マウントのたび）に走る。動作上の害はないが、test-06 No.13（`getFormationLesson` をモックするケース）を実装する人が「モジュール読み込み時」を前提にモックの差し込み方を誤る恐れがある。→「マウント時（setup）に1回組み立てる非リアクティブな定数」に修正。
- [バグ（文書の正確さ）] screen-07 手順8（動きを減らす設定への切替）: 文書は「再生中に設定が有効になった場合は…」だが、実装の `motionChanged` は再生中かどうかを見ず、`progress > 0` なら一時停止中でも次の解説へ進め、そうでなければ `pause()` するだけ。→「設定が有効になったとき、移動途中（再生中・一時停止中を問わない）なら次の解説へ到着させて止め、そうでなければ停止する」に修正し、test-07 に「一時停止中（移動途中）に設定が有効になると次の解説へ進む」を `[ ]` で追加することを推奨。
- [バグ（テスト仕様の完了欄）] test-07 No.29（`matchMedia` が無い環境）は既存テストで実質的に検証済み: vitest 設定に `setupFiles` が無く jsdom は `window.matchMedia` を実装しないため、`src/pages/FormationLearningPage.test.ts`「再生中の陣形切替でタイマーを破棄し、不明IDからも復帰できる」は matchMedia をスタブせずに再生し `vi.getTimerCount()` が 1 になることを確かめている。これは No.29 の期待結果そのもの。→ `[x]` にして備考へ「jsdom に matchMedia が無いことに依存した間接検証」と書くか、明示的に `vi.stubGlobal("matchMedia", undefined)` するテストを追加してから `[x]` にする。
- [バグ（テスト仕様の網羅）] screen-07 手順9の「非表示の間は再生を開始しない」に対応するケースが test-07 に無い（実装は `togglePlay` の `if (... || document.hidden) return;`。No.24 は「非表示で一時停止」「破棄で解除」のみ）。→「`document.hidden` = true の状態で再生ボタンを押す → タイマー0件・`1 / 5` のまま」を `[ ]` で追加。
- [運用（文書の正確さ）] screen-08 の確定イベント記述で `pointercancel` が抜けている: 選手は `FreeLayoutPitchDiagram.vue` で `pointercancel` も `onPointerUp` に繋がっているが、文書は「`pointerup` で…1回だけ発火」のみ。ボールも `BoardBall.vue` で `pointercancel` が `endDrag` に繋がっているが、文書は「`pointerup` / ポインタキャプチャの喪失」のみ。test-08 No.27 は `pointercancel` での確定を検証済みで、テスト仕様と詳細設計で記述範囲が食い違う。→ どちらも「`pointerup` / `pointercancel`（ボールは加えて `lostpointercapture`）」と書く。

### 問題なし
- セキュリティ①: 新規6ファイルと .steering 2ファイルを `https?://`・api key・token・secret・password・`arn:` で走査し該当なし。文書中の `localStorage` キー名（`formation-lab.board-layout-overrides.v1`）は秘匿値ではなくアプリ内部の保存キー。screen-design.md の差分はファイル名の対応記述のみ。
- セキュリティ②〜④・OWASP: 差分はドキュメントのみで `src/` 無変更のため該当なし。
- バグ（文書と実装の突き合わせ。実装・テストを読んで一致を確認）:
  - screen-06: `flatMap` による教材なし陣形の除外、カードの `aria-label` 書式、`h2`/`h3` 構成、カード内に button 無し、`PageHeader` の既定 `showBackButton=false`。
  - screen-07: `formationId`/`formation`/`lesson`/`lessonTerms` の導出（連結フィールドも一致）、`TacticalReplay` の `key`・`description`・`isOpen`・`useId`、再生規則（32ms 間隔、`progress` の足し込み、`go` での停止）、前の解説（`progress > 0` で現在の解説の始点へ）、disabled 条件、「再生完了」文言、ピッチ図の `aria-label` と強調描画の条件（`!isMoving && isAtCheckpoint`）、エラー文言、役割一覧の書式。4-3-3 の教材データ（青7 ウイング → `4-3-3-rw`（RW）、青2 サイドバック → `4-3-3-rb`（RB））は test-07 No.18 の期待値と一致。
  - screen-08: 初期値（`formations[0]` / `formations[1] ?? formations[0]`）、保存キー `{team}:{id}`、ボード専用の保存先キー、ピッチの `key`、`resetTeam`/`resetBall` の revision 加算の意図、座標換算（ボール `5 + x×2.5` / `5 + y×1.5`、矢印キーは選手6単位・ボール左右2.4・上下4）、`hitRadius = max(9, 22×260/幅)`、危険キーの除外、有限値への制限。
  - screen-design.md の差分（画面3 相性マトリクス → `screen-04-matrix.md`、画面4 用語集 → `screen-03-glossary.md`）は、screen-design.md の見出しと既存ファイルの見出しで一致を確認。
- バグ（テスト仕様の完了欄）: `[x]` の全ケース（test-06 No.1〜9、test-07 No.1〜16・20〜26、test-08 No.1〜39）を、対応する既存テストのアサーションと照合し、未実装を実装済みに見せているケースは無かった。数値まで一致を確認した期待値: (264, 126)、(160, 118)、translate(136 80)/(130 80)、{52.4, 50}、{50, 46}、r = 22/44、深さ 0 → 5、x = 10・y = 20。`[ ]` のケース（test-06 No.10〜14、test-07 No.17〜19・27・28・30・31、test-08 No.40・41）も `aria-current`・`aria-expanded`・「再生完了」・`board-instructions`・`BackButton`・場面タイトルで src 配下の test を検索し、該当する検証は無かった（`AppHeader.test.ts` の `aria-current` は主ナビの検証で陣形切替ナビではない）。例外は No.29（Low に記載）。
- 性能: ドキュメントのみで該当なし。
- 運用: 正本の二重管理なし。3文書とも、画面一覧・ルートの正本は functional-overview.md、外部設計は screen-design.md として参照に留めている。リンク先見出し（「画面設計」「自由配置ボード（FR-21）の確定事項」「画面共通の状態表現」）は実在。test-08 備考の撤去回帰の参照先 `test-screen-02-comparison.md` にも該当記述あり。

### 未検証
- `npm test` / lint / typecheck / build は再実行していない（依頼元の結果「36ファイル528件成功」に依拠）。
- テスト本体のうち行範囲を開いて読んだのは `BoardBall.test.ts` 23〜160行と `boardBallStorage.test.ts` 24〜32行まで。`FreeLayoutPitchDiagram.test.ts`・`freeLayoutStorage.test.ts` は it のタイトルのみ確認し、本文のアサーションは開いていない（test-08 No.5〜13・18〜24 との対応はタイトルと実装から判断）。
- `data/lessons/` 配下の各教材データの中身は、4-3-3（`tacticalScenes.ts`）以外を開いていない。

### 総合評価
Critical / High の指摘はなく、コミットしてよい。機密情報の混入なし。Low 5件は文書の正確さと完了欄の扱いで、コミット前修正でも申し送りでもよい。直すなら screen-07 手順8の記述と test-07 No.29 の完了欄を優先すると、「静かに誤る」記述と完了欄の過小申告を防げる。

### 対応
- Low 1（screen-06 の組み立てタイミング）: 「マウント時（setup）に1回組み立てる非リアクティブな定数」に修正した。
- Low 2（screen-07 手順8）: 「移動途中（再生中・一時停止中を問わない）なら次の解説へ到着させて止め、そうでなければ停止する」に修正し、test-07 に No.32「一時停止中（移動途中）に設定が有効になる」を `[ ]` で追加した。
- Low 3（test-07 No.29）: 根拠（vitest に `setupFiles` が無く、`FormationLearningPage.test.ts` が matchMedia をスタブせずに再生しタイマー1件を確認している）を確認したうえで `[x]` にし、備考に間接検証であることを明記した。
- Low 4（非表示中は再生を開始しない）: test-07 に No.33 を `[ ]` で追加した。
- Low 5（`pointercancel`）: screen-08 の選手・ボールの確定イベント記述に `pointercancel`（ボールは加えて `lostpointercapture`）を追記した。
- いずれもドキュメントの記述修正のみで、Critical / High ではないため再レビューは行わない。

## レビュー完了（2026-10-04）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: なし（Low 5件はすべて対応済み）。仕様書で `[ ]` としたケース（未実装テスト）は retrospective.md で後続作業として申し送る。

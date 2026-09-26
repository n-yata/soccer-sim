# タスクリスト

## フェーズ1: 監査

- [x] サブエージェントによるアクセシビリティ監査を実施（FreeLayoutPitchDiagram・HalftimeTacticsModal・FreeLayoutControls・SquadConditionControls・MatchSimulationPanel・LeaguePage・CupPage・QuizQuestionCard・ComparisonPage・RadarChart・色トークン）
- [x] 監査結果を重要度順に整理（Critical 1件・High 1件・Medium 2件・Low数件）

## フェーズ2: Critical対応（自由配置モードのキーボード操作）

- [x] `FreeLayoutPitchDiagram.vue`にtabindex/role/aria-labelを追加
- [x] 矢印キーによる移動ハンドラ`onKeyDown`を追加
- [x] focus-visibleスタイルを追加
- [x] `FreeLayoutPitchDiagram.test.ts`にキーボード操作のテストを追加（4件）

## フェーズ3: High対応（ハーフタイム采配モーダルのフォーカス管理）

- [x] 初期フォーカス（マウント時に閉じるボタンへ）を実装
- [x] フォーカス復帰（アンマウント時に起点要素へ）を実装
- [x] フォーカストラップ（Tab/Shift+Tabでの折り返し）を実装
- [x] `HalftimeTacticsModal.test.ts`を新規作成（8件。既存のテスト未整備の解消も兼ねる）

## フェーズ4: Medium対応

- [x] `CupPage.vue`の勝者強調に太字・アイコンを追加
- [x] `CupPage.test.ts`を新規作成（5件。既存のテスト未整備の解消も兼ねる）
- [x] `RadarChart.vue`に`aria-live="polite"`を追加
- [x] `RadarChart.test.ts`にテストを追加（1件）

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npx vitest run`（534 tests passed / 34 test files）
- [x] リントエラーがないことを確認
  - [x] `npx eslint .`（エラー無し）
- [x] 型エラーがないことを確認
  - [x] `npx vue-tsc --noEmit`（エラー無し）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功）
- [x] `npm run dev`で自由配置モードの矢印キー操作を実ブラウザで確認（フォーカスインジケータ表示・LM選手の移動を確認）

## フェーズ6: ドキュメント更新

- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

## フェーズ7: コミット前レビュー対応（第1回レビューのHigh 2件・Medium 6件）

- [x] `FreeLayoutPitchDiagram.vue`: role="group"ラッパーdiv構造へ変更、SVGからrole="img"を削除、装飾要素・選手ラベルにaria-hidden追加（H-1）
- [x] `FreeLayoutPitchDiagram.vue`: 選手circleからrole="button"を削除（H-2）
- [x] `HalftimeTacticsModal.vue`: フォーカス復帰先のisConnected確認・document.bodyへのフォールバックを追加（M-1）
- [x] `RadarChart.vue`: aria-liveをrole="status"の別要素へ分離し、500msデバウンス（M-2）
- [x] `FreeLayoutPitchDiagram.vue`: keydown/keyupを分離し、update-position-endはkeyup時の1回のみに（M-3）
- [x] `CupPage.test.ts`: 勝者/敗者を明示的に判別する非恒真テストへ書き換え（M-4）
- [x] `requirements-definition.md`・`repository-structure.md`・`functional-overview.md`を更新（M-5、test-screen-02-comparison.mdへの行追加のみ申し送り）
- [x] `CupPage.vue`: ::beforeを廃止しaria-hidden付き絵文字＋sr-onlyテキストへ変更（M-6）
- [x] 対応するテストを追加・更新（FreeLayoutPitchDiagram.test.ts +5件、RadarChart.test.ts +4件、HalftimeTacticsModal.test.ts +2件）
- [x] 全チェック再実行（542 tests passed / lint・typecheck・build 成功）
- [x] 第2回レビュー（再レビュー）を実施し、新たなCritical/High無しを確認

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。

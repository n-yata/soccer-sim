# タスクリスト

- [x] 1. `composables/matchSimulation.ts` を内部リファクタ（`SimAccumulator`/`simulateMinuteRange`/`finalizeResult`/`mirrorEdgeIfNeeded`/`isReversed`を抽出。`simulateMatch`の外部挙動は変えない）し、既存テストが通ることを確認する
- [x] 2. `composables/matchSimulation.ts` に `startMatch`/`resumeMatch`（多重実行ガード含む）を実装する
- [x] 3. `composables/matchSimulation.test.ts` に `startMatch`/`resumeMatch` のテストケースを追加する（決定性・後方互換性・配置変更の反映・鏡写しルール・多重実行ガード）
- [x] 4. `components/FreeLayoutPitchDiagram.vue` に `draggableTeams` propを追加し、Bチームのドラッグ・座標変換（`cxToDepth("B", ...)`）に対応する
- [x] 5. `components/HalftimeTacticsModal.vue` を新規実装する（スコア表示・ドラッグUI・リセット・確定・Escape/閉じるボタン/バックドロップクリックでのclose）
- [x] 6. `pages/ComparisonPage.vue` にハーフタイムフロー（`runSimulation`変更、`matchProgress`/`halftimeResult`/`isHalftimeModalOpen`状態、`effectiveFormationA`統一、確定・リセット系watchへの追加）を組み込む
- [x] 7. `pages/ComparisonPage.test.ts` にシナリオテスト（ハーフタイムパネル表示・後方互換性・配置変更の反映・Escapeで後半が始まらないこと・組み合わせ切替時のリセット）を追加する
- [x] 8. `docs/specs/1_requirements/requirements-definition.md` にFR番号（FR-17）を採番し、機能一覧・機能詳細・画面一覧・スコープに反映する
- [x] 9. `docs/specs/1_requirements/functional-overview.md` の画面設計・モジュール構成図に本機能を反映する
- [x] 10. `docs/specs/1_requirements/repository-structure.md` に新規ファイル（`HalftimeTacticsModal.vue`等）を反映する
- [x] 11. 型検査・リント・テスト・ビルドを実行し、すべて成功することを確認する（型検査・lint・459テスト・build全て成功。`npm run dev`での目視確認も実施）

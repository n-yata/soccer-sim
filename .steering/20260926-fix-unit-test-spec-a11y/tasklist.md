# タスクリスト

## フェーズ1: 現状調査

- [x] `test-screen-02-comparison.md`のテスト対象が実際のコンポーネント構成と乖離していることを確認
- [x] `screen-02-comparison.md`（3_detail-design）がFR-14以降未反映であることを確認
- [x] `screen-design.md`・`component-design.md`（2_basic-design）もFR-14以降未反映であることを確認
- [x] ユーザーに現状を報告し、FR-14〜19全体（リーグ戦・カップ戦画面含む）への対応範囲を確認

## フェーズ2: 2_basic-design復旧

- [x] `screen-design.md`: 画面2（比較画面）にFR-14/15/18/19を追記
- [x] `screen-design.md`: 画面6（リーグ戦画面）・画面7（カップ戦画面）を新設
- [x] `component-design.md`: ComparisonPageの責務・インターフェース・依存関係を更新
- [x] `component-design.md`: FreeLayoutControls/FreeLayoutPitchDiagram/SquadConditionControls/MatchSimulationPanel/HalftimeTacticsModalを追記
- [x] `component-design.md`: LeaguePage/CupPageを追記
- [x] `component-design.md`: matchSimulation/leagueSimulation/cupSimulation/squadCondition/freeLayoutStorage/freeLayoutCoordinatesを追記

## フェーズ3: 3_detail-design復旧

- [x] `screen-02-comparison.md`: コンポーネント構成・props/state設計を更新
- [x] `screen-02-comparison.md`: 自由配置モード・選手個体差・試合シミュレーション/ハーフタイム采配の詳細フローを追記
- [x] `screen-06-league.md`を新規作成
- [x] `screen-07-cup.md`を新規作成

## フェーズ4: 4_unit-test復旧

- [x] `test-screen-02-comparison.md`: テスト対象表を更新
- [x] `test-screen-02-comparison.md`: ComparisonPageの新規テストケース（FR-14/15/18/19）を追記
- [x] `test-screen-02-comparison.md`: FreeLayoutPitchDiagram/FreeLayoutControls/SquadConditionControls/matchSimulation/squadCondition/freeLayoutStorage/MatchSimulationPanel/HalftimeTacticsModalのテストケースを追記
- [x] `test-screen-02-comparison.md`: 備考に必須テストケースの根拠を追記
- [x] `test-screen-06-league.md`を新規作成（LeaguePage.vueにテストファイルが無いことを明記）
- [x] `test-screen-07-cup.md`を新規作成

## フェーズ5: 品質チェックと修正

- [x] `MatchSimulationPanel.vue`のFR番号誤記（FR-17→FR-19）を修正
- [x] `npx vitest run MatchSimulationPanel`で既存テストへの影響が無いことを確認
- [x] 全体整合性チェック（functional-overview.mdとの整合、リンク切れ確認）

## フェーズ6: ドキュメント更新

- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

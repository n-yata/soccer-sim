# 要求内容

## 概要

前回のアクセシビリティ監査（`.steering/20260926-a11y-audit/`）の振り返りで申し送りにしていた
「`test-screen-02-comparison.md`へのアクセシビリティ行追加」に着手したところ、
2_basic-design → 3_detail-design → 4_unit-test の3階層すべてがFR-14〜19（試合シミュレーション・
自由配置モード・リーグ戦・カップ戦・選手個体差・ハーフタイム采配）に未対応のまま止まっていた
ことが判明した。ユーザーの判断により、FR-14〜19全体（リーグ戦・カップ戦画面を含む）を対象に
2_basic-design・3_detail-design・4_unit-testの3階層を復旧する。

## 背景

`docs/specs/2_basic-design/screen-design.md`・`component-design.md`は、FR-01〜FR-13
（クイズ機能まで）の内容で止まっており、その後2026-09-13〜09-26にかけて追加された
FR-14（試合シミュレーション）・FR-15（自由配置モード）・FR-16（リーグ戦）・FR-17（カップ戦）・
FR-18（選手個体差）・FR-19（ハーフタイム采配）が反映されていなかった。`docs/specs/1_requirements/
functional-overview.md`・`requirements-definition.md`（要件定義工程の正本）は都度更新されて
いたが、実装詳細に踏み込む2_basic-design以降の工程が追随できていなかった。

## 実装対象の機能

### 1. 2_basic-design（外部設計）の復旧

- `screen-design.md`の画面2（比較画面）へFR-14/15/18/19の追加要素（自由配置トグル・選手個体差
  トグル・試合シミュレーション・ハーフタイム采配モーダル）を追記する
- `screen-design.md`へ画面6（リーグ戦画面）・画面7（カップ戦画面）を新設する
- `component-design.md`へ、新規コンポーネント（`FreeLayoutControls`/`FreeLayoutPitchDiagram`/
  `SquadConditionControls`/`MatchSimulationPanel`/`HalftimeTacticsModal`/`LeaguePage`/`CupPage`）
  と関連する`composables/`/`data/`モジュール（`matchSimulation.ts`/`leagueSimulation.ts`/
  `cupSimulation.ts`/`squadCondition.ts`/`freeLayoutStorage.ts`/`freeLayoutCoordinates.ts`）の
  責務・インターフェース・依存関係を追記する

### 2. 3_detail-design（画面詳細設計）の復旧

- `screen-02-comparison.md`へprops/state・詳細フロー・例外表示を追記する
- `screen-06-league.md`・`screen-07-cup.md`を新規作成する

### 3. 4_unit-test（単体テスト仕様書）の復旧

- `test-screen-02-comparison.md`のテスト対象表・テストケース一覧を、実際に存在する
  `.test.ts`ファイルの内容に基づき全面的に追記する（アクセシビリティ関連のテストケースを含む）
- `test-screen-06-league.md`・`test-screen-07-cup.md`を新規作成する

## 受け入れ条件

- [ ] `screen-design.md`に画面6・画面7のセクションが追加され、画面2にFR-14/15/18/19の
      画面項目・画面イベントが追記されていること
- [ ] `component-design.md`に、対象コンポーネント・composables/data モジュールすべての
      責務・インターフェース・依存関係が記載されていること
- [ ] `screen-02-comparison.md`にFR-14/15/18/19の詳細フローが記載されていること
- [ ] `screen-06-league.md`・`screen-07-cup.md`が新規作成され、既存のテンプレート・
      既存ファイルの記述粒度と一貫していること
- [ ] `test-screen-02-comparison.md`のテストケース一覧が、実際の`.test.ts`ファイルの
      テストケースと過不足なく対応していること
- [ ] `test-screen-06-league.md`・`test-screen-07-cup.md`が新規作成されていること
- [ ] `LeaguePage.vue`にテストファイルが存在しないことが判明した場合、その旨を
      仕様書内に明記し、ユーザーへ報告すること

## 成功指標

- 定性: 2_basic-design→3_detail-design→4_unit-testの3階層とfunctional-overview.mdの間で、
  FR-14〜19に関する記述の齟齬・欠落が解消されること。

## スコープ外

- `LeaguePage.vue`の実際のテストコード（`LeaguePage.test.ts`）の新規作成（ドキュメントへの
  記載に留め、実装は別タスクとする）
- `docs/specs/5_integration-test/`（結合テスト仕様書）への反映
- FR-01〜13相当の既存記述の見直し（監査対象外。今回変更しない）

## 参照ドキュメント

- `.steering/20260926-a11y-audit/retrospective.md` - 本作業の発端となった申し送り事項
- `docs/specs/1_requirements/requirements-definition.md` - FR-14〜19の正本
- `docs/specs/1_requirements/functional-overview.md` - 画面一覧・画面遷移の正本（既に最新）

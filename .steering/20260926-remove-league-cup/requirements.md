# 要求内容

## 概要

リーグ戦（FR-16）・カップ戦（FR-17）機能を完全削除する。ユーザー（シャビ）の判断で
「あっても何の目安にもならない」ため、画面・ルーティング・ナビ導線・ロジック・テスト・
関連ドキュメント記述をすべて除去する。

## 背景

ユーザーからのフィードバック: 「リーグ戦とカップ戦の機能はいらないね。正直あっても何の目安にも
ならない。」実装済みではあるが、プロダクトの価値に寄与していないと判断されたため削除する。

## 実装対象の機能（削除対象）

### 1. リーグ戦（FR-16）の削除
- `src/pages/LeaguePage.vue`、`src/composables/leagueSimulation.ts`とそれぞれのテストを削除
- ルーティング（`/league`）、`AppHeader.vue`・`FormationListPage.vue`のナビ導線を削除
- `types/formation.ts`の`LeagueStanding`/`LeagueMatchResult`/`LeagueSimulationResult`型を削除

### 2. カップ戦（FR-17）の削除
- `src/pages/CupPage.vue`、`src/composables/cupSimulation.ts`とそれぞれのテストを削除
- ルーティング（`/cup`）、`AppHeader.vue`・`FormationListPage.vue`・`App.vue`のナビ導線
  （`showCupLink`/`CUP_REQUIRED_FORMATION_COUNT`）を削除
- `types/formation.ts`の`CupMatch`/`CupSimulationResult`型を削除

### 3. ドキュメントの整合
- `docs/specs/1_requirements/requirements-definition.md`: FR-16/FR-17の項目・機能一覧・
  画面一覧からの記述を削除
- `docs/specs/1_requirements/functional-overview.md`・`repository-structure.md`:
  リーグ戦・カップ戦関連の記述を削除
- `docs/specs/2_basic-design/component-design.md`・`screen-design.md`: 該当セクション削除
- `docs/specs/3_detail-design/screen/screen-06-league.md`・`screen-07-cup.md`: ファイル削除
- `docs/specs/4_unit-test/test-screen-06-league.md`・`test-screen-07-cup.md`: ファイル削除
- `docs/specs/4_unit-test/test-screen-02-comparison.md`: リーグ戦・カップ戦からの遷移に
  関する記述があれば削除

## 受け入れ条件

- [ ] `/league`・`/cup`ルートが存在せず、直接アクセスしても該当画面が表示されない
- [ ] `AppHeader`・`FormationListPage`にリーグ戦・カップ戦への導線が無い
- [ ] `formations.ts`の`CUP_REQUIRED_FORMATION_COUNT`とその利用箇所が削除されている
- [ ] `LeaguePage.vue`/`CupPage.vue`/`leagueSimulation.ts`/`cupSimulation.ts`と
      対応するテストファイルが削除されている
- [ ] `types/formation.ts`からリーグ戦・カップ戦専用の型が削除されている
      （`matchSimulation.ts`が提供する共通のシミュレーション機能・型はそのまま残す）
- [ ] 既存テストがすべて通ること（削除対象のテストを除く）
- [ ] `npm run lint` / `npm run typecheck` / `npm run build` が成功すること
- [ ] 関連ドキュメントからFR-16・FR-17の記述が除去され、矛盾がないこと

## 成功指標

- 定量: 上記受け入れ条件をすべて満たす。テストスイートが全パス。
- 定性: リーグ戦・カップ戦に触れる形でコードベース・ドキュメントが残っていない。

## スコープ外

- 試合シミュレーションの共通ロジック（`composables/matchSimulation.ts`、ハーフタイム采配）は
  リーグ戦・カップ戦専用ではなく比較画面（ComparisonPage）が直接利用するため、削除しない
- 選手個体差（スカッドコンディション、FR-18）は削除しない（カップ戦と同じ振り返りディレクトリで
  導入されたが独立した機能のため）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md`
- `docs/specs/1_requirements/repository-structure.md`

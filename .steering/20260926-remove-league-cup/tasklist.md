# タスクリスト

## 🚨 タスク完全完了の原則

全タスクが`[x]`になるまで作業を継続する。スキップは技術的理由がある場合のみ。

---

## フェーズ1: ヘッダー/フッターの一貫性修正

- [x] `PageHeader.vue`に`showBackButton`/`backFallbackTo`propsを追加
- [x] `ComparisonPage.vue`を`PageHeader`経由に統一
- [x] `MatrixPage.vue`を`PageHeader`経由に統一
- [x] `QuizPage.vue`を`PageHeader`経由に統一
- [x] `GlossaryPage.vue`の戻りリンクを`PageHeader`の`showBackButton`に統一
- [x] 関連テスト（`MatrixPage.test.ts`/`QuizPage.test.ts`/`GlossaryPage.test.ts`）の
      セレクタ・アサーションを新構造に合わせて修正
- [x] `npm test`で全件パスすることを確認

## フェーズ2: リーグ戦・カップ戦の削除

- [x] `src/router/index.ts`から`/league`・`/cup`ルートとimportを削除
- [x] `src/App.vue`から`showCupLink`算出・`AppHeader`への受け渡しを削除
- [x] `src/components/AppHeader.vue`から`showCupLink` prop・リーグ戦/カップ戦nav-linkを削除
- [x] `src/pages/FormationListPage.vue`からリーグ戦/カップ戦へのnav-linkを削除
- [x] `src/data/formations.ts`から`CUP_REQUIRED_FORMATION_COUNT`を削除
- [x] `src/types/formation.ts`からリーグ戦・カップ戦専用の型を削除
- [x] `src/pages/LeaguePage.vue`・`src/pages/CupPage.vue`を削除
- [x] `src/composables/leagueSimulation.ts`・`src/composables/cupSimulation.ts`を削除
- [x] 上記に対応するテストファイル（`LeaguePage.test.ts`/`CupPage.test.ts`/
      `leagueSimulation.test.ts`/`cupSimulation.test.ts`）を削除
- [x] `AppHeader.test.ts`からリーグ戦・カップ戦関連テストを削除・修正
- [x] `FormationListPage.test.ts`からリーグ戦・カップ戦関連テストを削除・修正
      （元々リーグ戦・カップ戦への言及が無かったため変更不要）

## フェーズ3: ドキュメントの整合

- [x] `docs/specs/1_requirements/requirements-definition.md`からFR-16・FR-17を削除
- [x] `docs/specs/1_requirements/functional-overview.md`・`repository-structure.md`から
      リーグ戦・カップ戦関連の記述を削除
- [x] `docs/specs/2_basic-design/component-design.md`・`screen-design.md`から該当セクション削除
      （ヘッダー統一に伴う`PageHeader`/`BackButton`セクションの更新も含む）
- [x] `docs/specs/3_detail-design/screen/screen-06-league.md`・`screen-07-cup.md`を削除
- [x] `docs/specs/4_unit-test/test-screen-06-league.md`・`test-screen-07-cup.md`を削除
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`の関連記述を確認・削除
- [x] ソースコード側の残存コメント（`matchSimulation.ts`のcupSimulation.ts言及等）を確認・修正

## フェーズ4: 品質チェックと修正

- [x] `npm test`（33 test files / 525 tests、すべてpassed）
- [x] `npm run lint`（エラー0件）
- [x] `npm run typecheck`（エラー0件）
- [x] `npm run build`（成功）
- [x] テストが実際に実行されたことを確認（33 files, 525 tests, 0 skipped）
- [x] ブラウザで実画面を目視確認（一覧・比較・相性マトリクス・クイズ・用語集の
      ヘッダーが統一され、リーグ戦・カップ戦への導線が消えていることを確認）

## フェーズ5: コミット前レビュー・振り返り

- [x] `review-pre-commit`を実施（第1回: Critical0/High1/Medium5/Low5、修正→
      第2回: 新たなCritical/High0、新規Medium1件を追加修正。526件全パス・
      lint/typecheck/build成功を確認）
- [x] `retrospective.md`を作成

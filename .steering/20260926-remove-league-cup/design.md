# 設計書

## アーキテクチャ概要

本作業は2つの独立した変更を同一ブランチで行う。

1. **ヘッダー/フッターの一貫性修正**（ユーザーからの追加フィードバックで発覚したスコープ）:
   `PageHeader`コンポーネントに`showBackButton`/`backFallbackTo`propsを追加し、
   `ComparisonPage`/`MatrixPage`/`QuizPage`/`GlossaryPage`の独自ヘッダー実装を
   すべて`PageHeader`経由に統一する。**実施済み**。
2. **リーグ戦（FR-16）・カップ戦（FR-17）の完全削除**: 画面・ルーティング・ナビ導線・
   composables・型・テスト・関連ドキュメントを削除する。

## コンポーネント設計（ヘッダー統一・実施済み）

### PageHeader.vue の拡張
- `showBackButton?: boolean`（既定false）・`backFallbackTo?: string`（既定"/"）を追加
- `showBackButton`が真のとき、タイトルの左に`BackButton`を描画する
- `components/`層内での`BackButton`への依存は、既存の`FormationCard.vue`→`FormationMiniPitch.vue`と
  同様の同一層内コンポーネント合成であり、依存禁止ルール（`data/`静的データへの依存禁止）には抵触しない

### 各ページの変更
- `ComparisonPage.vue`: 独自の`__header`divを`PageHeader`（動的タイトル`${A} vs ${B}`、
  用語集リンクをslotへ）に置き換え。本体を`__body`、エラー表示を`__error`にラップし直す
- `MatrixPage.vue`: 独自の`__header`+`__subtitle`を`PageHeader`（title+subtitle）に統一
- `QuizPage.vue`: 独自の`__header`を`PageHeader`（用語集リンクをslotへ）に統一
- `GlossaryPage.vue`: 素の`router-link`だった戻りリンクを`PageHeader`の`showBackButton`に統一
  （挙動が`router.back()`優先に変わるが、他画面と同じ挙動になるため改善）

## コンポーネント設計（リーグ戦・カップ戦削除）

### 削除するファイル
- `src/pages/LeaguePage.vue` / `src/pages/LeaguePage.test.ts`（無ければ確認）
- `src/pages/CupPage.vue` / `src/pages/CupPage.test.ts`
- `src/composables/leagueSimulation.ts` / `src/composables/leagueSimulation.test.ts`
- `src/composables/cupSimulation.ts` / `src/composables/cupSimulation.test.ts`
- `docs/specs/3_detail-design/screen/screen-06-league.md` / `screen-07-cup.md`
- `docs/specs/4_unit-test/test-screen-06-league.md` / `test-screen-07-cup.md`

### 変更するファイル
- `src/router/index.ts`: `/league`・`/cup`ルート定義とimportを削除
- `src/App.vue`: `showCupLink`の算出・`AppHeader`への受け渡しを削除
- `src/components/AppHeader.vue`: `showCupLink` prop・カップ戦/リーグ戦のnav-linkを削除
- `src/components/AppHeader.test.ts`: 上記に対応するテストを削除・修正
- `src/pages/FormationListPage.vue`: リーグ戦/カップ戦へのnav-linkを削除
- `src/pages/FormationListPage.test.ts`: 対応するテストを削除・修正
- `src/data/formations.ts`: `CUP_REQUIRED_FORMATION_COUNT`定数を削除
- `src/types/formation.ts`: `LeagueStanding`/`LeagueMatchResult`/`LeagueSimulationResult`/
  `CupMatch`/`CupSimulationResult`型を削除
- `docs/specs/1_requirements/requirements-definition.md`: FR-16・FR-17の項目を削除
- `docs/specs/1_requirements/functional-overview.md`・`repository-structure.md`: 該当記述を削除
- `docs/specs/2_basic-design/component-design.md`・`screen-design.md`: 該当セクション削除
- `docs/specs/4_unit-test/test-screen-02-comparison.md`: リーグ戦/カップ戦からの遷移に
  関する記述があれば削除

### 依存関係の確認
- `composables/matchSimulation.ts`（`simulateMatch`/`startMatch`/`resumeMatch`）は
  `ComparisonPage`が直接利用する共通ロジックであり、`leagueSimulation.ts`/`cupSimulation.ts`は
  これを呼び出す側（依存の向きは一方向）。削除しても`matchSimulation.ts`自体には影響しない
- `data/formations.ts`の`CUP_REQUIRED_FORMATION_COUNT`はカップ戦専用の定数であり、
  他の用途（フォーメーション数の一般的なバリデーション等）には使われていない

## テスト戦略

- 削除対象のテストファイルはそのまま削除する（対象機能が無くなるため）
- 変更対象のテストファイル（`AppHeader.test.ts`/`FormationListPage.test.ts`）は、
  リーグ戦・カップ戦への言及を削除し、残りのナビ項目のテストが引き続き通ることを確認する
- ヘッダー統一に伴うテスト修正（`.back-button`セレクタへの統一等）は実施済み

## 実装の順序

1. ヘッダー/フッターの一貫性修正（実施済み）
2. リーグ戦・カップ戦のソースコード削除（画面・composables・型・ルーティング・ナビ導線）
3. 削除に伴うテストの修正・削除
4. ドキュメントの整合
5. 品質チェック（lint/typecheck/test/build）
6. コミット前レビュー→振り返り→コミット→マージ

## セキュリティ考慮事項

該当なし（機能削除のみ）。

## パフォーマンス考慮事項

該当なし。

## 将来の拡張性

リーグ戦・カップ戦を将来的に再導入する場合は、`git log`から本コミットの前状態を参照できる
（削除であり、履歴は残る）。

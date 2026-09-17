# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール

- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: プロジェクト初期化

- [x] `package.json` を作成する（vue, vue-router, vite, @vitejs/plugin-vue, typescript, vue-tsc, vitest, @vue/test-utils, jsdom, eslint, prettier）
- [x] `npm install` を実行する（`npm audit`でesbuild関連の脆弱性を検出したため`npm audit fix --force`でvite^6.4.3/vitest^4.1.11へ更新。0件を確認）
- [x] `vite.config.ts` を作成する（Vueプラグイン + Vitest設定）
- [x] `tsconfig.json` を作成する
- [x] `index.html` を作成する

## フェーズ2: 型定義・データレイヤー

- [x] `src/types/formation.ts` を実装する（`PositionType`, `Position`, `Formation`, `Matchup`）
- [x] `src/data/formations.ts` を実装する（4-4-2, 4-3-3, 4-2-3-1, 3-5-2の4種類、`getFormationById`）
- [x] `src/data/matchups.ts` を実装する（4種類の全組み合わせ6件分の解説文、`getMatchup`。順序非依存）
- [x] `test-screen-02-comparison.md` ケース1-7（`getFormationById`, `getMatchup`）を実装する（7件全てパス確認済み）
  - [x] ケース1: 正常系 `getFormationById("4-4-2")`
  - [x] ケース2: 異常系 存在しないID
  - [x] ケース3: 境界値 空文字
  - [x] ケース4: 正常系 `getMatchup("4-2-3-1", "4-4-2")`
  - [x] ケース5: 正常系（順序非依存）引数を逆順にしても同一結果
  - [x] ケース6: 異常系 同一フォーメーション同士
  - [x] ケース7: 異常系 存在しないID

## フェーズ3: 表示コンポーネント

- [x] `src/components/FormationCard.vue` を実装する（props: formation, selected / emits: select）
- [x] `test-screen-01-formation-list.md` ケース1-3（`FormationCard`）を実装する（3件パス確認済み）
  - [x] ケース1: 正常系 selected=false時の表示
  - [x] ケース2: 正常系 selected=true時の強調表示
  - [x] ケース3: 正常系 クリックでselectイベントemit
- [x] `src/components/PitchDiagram.vue` を実装する（props: formation, color）
- [x] `test-screen-02-comparison.md` ケース8-10（`PitchDiagram`）を実装する（3件パス確認済み）
  - [x] ケース8: 正常系 ポジション数分の要素描画
  - [x] ケース9: 正常系 color="red"の配色
  - [x] ケース10: 境界値 positions空配列

## フェーズ4: ページコンポーネント

- [x] `src/pages/FormationListPage.vue` を実装する（選択状態管理・トグル・3件目挙動・自動遷移）
- [x] `test-screen-01-formation-list.md` ケース4-9（`FormationListPage`）を実装する（6件パス確認済み）
  - [x] ケース4: 正常系 初期表示
  - [x] ケース5: 正常系 1件目選択
  - [x] ケース6: 正常系 2件目選択でrouter.push
  - [x] ケース7: 境界値 3件目選択で最古の選択を解除
  - [x] ケース8: 正常系 選択解除
  - [x] ケース9: 異常系 formations空配列
- [x] `src/pages/ComparisonPage.vue` を実装する（データ取得・表示出し分け・戻るボタン）
- [x] `test-screen-02-comparison.md` ケース11-15（`ComparisonPage`）を実装する（5件パス確認済み）
  - [x] ケース11: 正常系 正常表示
  - [x] ケース12: 異常系 formationAId未検出
  - [x] ケース13: 異常系 formationBId未検出
  - [x] ケース14: 正常系 戻るボタン
  - [x] ケース15: 正常系 エラー時の一覧リンク

## フェーズ5: ルーティング・エントリーポイント

- [x] `src/router/index.ts` を実装する（`/`, `/compare/:formationAId/:formationBId`）
- [x] `src/App.vue` を実装する（`<router-view>`のみのルートコンポーネント）
- [x] `src/main.ts` を実装する（Vueアプリ生成・router登録・マウント）

## フェーズ6: 品質チェックと修正

> 対応するコマンドは `package.json` の scripts に定義する。

- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（Vitest） → 6 Test Files, 24 Tests すべてpassed
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（ESLint） → 当初14件のフォーマット系warningを`--fix`で解消。0 problems
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（vue-tsc） → tsconfig.jsonのpathエイリアス未設定・jsdom型定義誤指定を
        修正し、0エラー
- [x] ビルドが成功することを確認
  - [x] `npm run build`（Vite） → ビルド成功（40 modules transformed, dist生成確認）
- [x] **テストが実際に実行されたことを確認**（実行件数24件＋純粋関数・コンポーネントテストの
      スキップ数0件であること） → `Test Files 6 passed (6)` `Tests 24 passed (24)`、スキップ0件
- [x] `review-implementation`による実装検証を実施し、指摘（[必須]2件・[推奨]6件）に対応する
  - [x] [必須] GKラベルがviewBox外に出て不可視になる不具合を修正（`PitchDiagram.vue`）+ 回帰テスト追加
  - [x] [必須] マッチアップ全組み合わせの存在を検証するテストを追加（`matchups.test.ts`）
  - [x] [推奨] ドメイン制約（ポジション数11人・名称の数字合計一致）のテストを追加（`formations.test.ts`）
  - [x] [推奨] `typescript-eslint`・`eslint-config-prettier`を導入しESLint設定を規約準拠に修正
  - [x] [推奨] Prettier設定ファイル・`format`スクリプトを追加（`src/`に対象を限定。誤って
        `docs/`等を広範囲整形した事故があり、`.prettierignore`で二重に防御した）
  - [x] [推奨] フォーメーションカードのグリッドを固定3列→可変グリッドに変更
  - [x] [推奨] `FormationCard`にキーボード操作対応（role/tabindex/Enter・Spaceキー）を追加
  - [x] [推奨] `repository-structure.md`に`FormationCard.vue`を追記
  - [x] [提案] タイポ「フォーメーム」の残存箇所を修正
  - [x] 対応後、`npm run test`（37件）・`lint`・`typecheck`・`build`を再実行し全て成功を確認
- [x] `review-pre-commit`によるコミット前レビューを実施し、指摘（Medium4件・Low4件）に対応する
  - [x] [Medium] 解説文が無言で空欄になる経路を修正（`ComparisonPage.vue`のv-if条件に`matchup`
        を追加。エラーメッセージを「指定された組み合わせを表示できません」に統一）+ テスト追加
  - [x] [Medium] `.prettierignore`に`.claude/`全体・`.mcp.json`・`package-lock.json`を追記
  - [x] [Medium] テスト仕様書と実装の食い違い（ID表記順序・ケース15の検証内容・件数表記）を修正
  - [x] [Medium] `createWebHistory`のデプロイ前提は積み残しとする（デプロイ先未定のため）
  - [x] 併せて`functional-overview.md`・`glossary.md`・`screen-design.md`・`component-design.md`・
        `screen-02-comparison.md`のエラーハンドリング記述を実装（matchup未検出もエラー表示）に
        合わせて更新し、正本間の矛盾を解消した
  - [x] 対応後、`npm run test`（38件）・`lint`・`typecheck`・`build`を再実行し全て成功を確認。
        `git status`で意図しないファイル変更が無いことも確認済み

## フェーズ7: ドキュメント更新

- [x] `docs/specs/4_unit-test/test-screen-01-formation-list.md` の完了チェック欄（9件）を
      `[x]` に更新する
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md` の完了チェック欄（16件。レビュー
      対応で1件追加）を `[x]` に更新する
- [x] `docs/specs/1_requirements/repository-structure.md` に `FormationCard.vue` を追記する
      （review-implementation指摘対応）
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

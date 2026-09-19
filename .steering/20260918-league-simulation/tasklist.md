# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
実装方針の変更・アーキテクチャ変更・依存関係の変更など、明確な技術的理由がある場合のみ。
スキップ時は必ず理由を明記する。

---

## フェーズ1: 型定義とドメインロジック

- [x] `src/types/formation.ts` に型を追加
  - [x] `LeagueStanding` インターフェースを追加
  - [x] `LeagueMatchResult` インターフェースを追加
  - [x] `LeagueSimulationResult` インターフェースを追加
- [x] `src/composables/leagueSimulation.ts` を実装
  - [x] 総当たり組み合わせ生成（i<jの28通り）
  - [x] `runLeagueSimulation(formations, getMatchupFn, simulateMatchFn = simulateMatch)` を実装
  - [x] 勝敗判定（`score.a` vs `score.b`）と集計（played/win/draw/lose/goalsFor/goalsAgainst/points）
  - [x] 順位算出（勝ち点→得失点差→総得点、同着順位方式）
  - [x] マッチアップ欠落時に `Error` を投げる

## フェーズ2: テスト

- [x] `src/composables/leagueSimulation.test.ts` を実装
  - [x] 実データで `played === 7`（全フォーメーション）を検証
  - [x] 実データで `matches.length === 28`、同一フォーメーション同士が含まれないことを検証
  - [x] 実データで `win + draw + lose === played` を検証
  - [x] 実データで `goalDifference === goalsFor - goalsAgainst` を検証
  - [x] 実データで `points === win * 3 + draw` を検証
  - [x] 実データで2回実行し結果が完全一致すること（決定性）を検証
  - [x] フェイクデータ + スタブ `simulateMatchFn` で同着順位（1, 2, 2, 4...）を検証
  - [x] マッチアップ欠落時に `Error` が投げられることを検証
- [x] `npm test` で新規テストがパスすることを確認（10 passed）

## フェーズ3: 画面実装

- [x] `src/pages/LeaguePage.vue` を実装
  - [x] `computed` で `runLeagueSimulation(formations, getMatchup)` を実行
  - [x] 順位表（順位・フォーメーション名・試合数・勝/分/敗・得点/失点/得失点差・勝ち点）を表示
  - [x] 全対戦結果一覧（28試合）を表示し、各行から `/compare/:formationAId/:formationBId` へ遷移できるようにする
  - [x] 「戻る」導線（`MatrixPage.vue` の `goBack` パターンを踏襲）
  - [x] `MatrixPage.vue` の配色トークンを踏襲したスタイルを実装
- [x] `src/router/index.ts` に `/league` ルート（`LeaguePage`）を追加
- [x] `src/pages/FormationListPage.vue` のヘッダーに「🏆 リーグ戦」導線（`router-link to="/league"`）を追加

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（402 passed / 24 files）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）（402 passed, 0 skipped）
- [x] `npm run dev` を起動し、ブラウザで `/league` の表示・遷移を目視確認する（順位表・全対戦結果表示、対戦結果クリックで `/compare/4-4-2/4-3-3` へ遷移、一覧画面ヘッダーの「🏆 リーグ戦」導線を確認）
- [x] コミット前レビュー（Medium 3件）対応後、テスト・lint・型検査・ビルド・目視確認を再実行し全て成功を確認

## フェーズ5: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` の機能一覧・スコープに今回の機能を反映（FR-15として採番、4.1.5/4.2/4.3/6.1を更新）
- [x] `docs/specs/1_requirements/functional-overview.md` の画面一覧・画面遷移図・モジュール構成図・ユースケース一覧に今回の画面を反映
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

## フェーズ6: mainインシデント復旧後の再移植（追加作業）

> mainの作業ツリーが`.git`ごと消失するインシデント（別セッション起因）が発生し、別セッションが
> 本worktreeを元にmainを再構築した。再構築後のmainには並行開発中だった別機能
> 「自由配置モード」が`FR-15`として先に取り込まれており、本機能のFR番号（当初FR-15）と
> 衝突したため、以下を実施した。

- [x] 新しいworktree（`feature-league-simulation-v2`、ブランチ`feature/league-simulation`）を
      再構築後のmainから作成
- [x] レビュー済みの実装ファイル（`leagueSimulation.ts`/`leagueSimulation.test.ts`/
      `LeaguePage.vue`）をそのまま移植し、`types/formation.ts`・`router/index.ts`・
      `FormationListPage.vue`へ同一差分を再適用
- [x] `requirements-definition.md`/`functional-overview.md`/`repository-structure.md`を、
      FR番号をFR-16へ繰り下げたうえで再構築後のmain（自由配置モード関連の追記を含む）に
      整合する形で再反映
- [x] テスト・lint・型検査・ビルド・目視確認を再実行し、全て成功することを確認
      （コード本体はレビュー済みのため再レビューは実施せず）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

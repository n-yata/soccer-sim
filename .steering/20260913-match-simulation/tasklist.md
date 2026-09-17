# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: 型定義

- [x] `src/types/formation.ts` に `MatchEventKind`（"chance"|"shot"|"goal"）を追加
- [x] `src/types/formation.ts` に `MatchEvent`（minute, team, kind, text）を追加
- [x] `src/types/formation.ts` に `MatchSimulationResult`（possession, shots, shotsOnTarget, score, timeline, summary）を追加

## フェーズ2: シミュレーションロジック（composables/matchSimulation.ts）

- [x] `src/composables/matchSimulation.ts` を新規作成
  - [x] FNV-1aハッシュ関数（`matchupGenerator.ts`の`hash()`と同方式で自前実装。重複コードだが、composablesはdata/に依存しない設計方針のためimportしない）
  - [x] mulberry32 PRNGジェネレータ関数
  - [x] ポゼッション判定関数（stats + overallEdge → possessor）
  - [x] チャンス/枠内/ゴールの3段階確率判定関数
  - [x] イベントテキスト生成関数（team名を含む自然文、goal/shot/chanceの3種）
  - [x] 90分ループ本体
  - [x] 集計（possession/shots/shotsOnTarget/score）
  - [x] サマリー文生成関数
  - [x] `simulateMatch(a, b, matchup)` のエクスポート
- [x] `src/composables/matchSimulation.test.ts` を新規作成
  - [x] 固定フォーメーションペアでの出力検証（初回実行結果を固定値としてスナップショット的に記述）
  - [x] 決定性テスト（同一引数を複数回呼び出し、深い等価性を確認）
  - [x] 不変条件テスト: 全フォーメーション組み合わせをテーブル駆動で検証（possession合計100、shots>=score、shotsOnTarget<=shots、score<=shotsOnTarget、timelineのminute範囲・昇順）
  - [x] 極端ケース（全stats軸が同一の仮想フォーメーション2つ）のテスト
  - [x] ~~A/B入れ替え時の完全対称性テスト~~（実装方針変更: possessionの確率境界は非対称な乱数消費のため厳密なミラー対称は保証されず、要求（requirements.md）にも明記されていない不変条件だった。代わりにmatchup.idの値（オブジェクト参照ではなく）にシードが基づくことを検証するテストに置き換えた）
- [x] `npm test` で matchSimulation.test.ts がすべてパスすることを確認（12件パス）

## フェーズ3: 用語集の追加（→ 実装方針変更。下記参照）

- [x] ~~`src/data/soccerTerms.ts` に「ポゼッション」「枠内シュート」を追加~~（実装方針変更:
  `matchupRules.test.ts`が「用語集の全用語はmatchupRules.tsの文言に実際に登場すること」を
  検証しており、soccerTerms.tsはmatchupRules起点のコンテンツパイプライン専用の設計
  だったため衝突した。用語集への追加はやめ、NFR-02の「文中で説明を添える」を選択。
  「ポゼッション」は「ボール保持率」という平易な日本語に置き換え、「枠内シュート」は
  既存UIの GK/DF/MF/FW 等と同様に自明な語の組み合わせと判断しそのまま使用する。
  design.md「NFR-02対応の設計判断」参照）
- [x] `src/data/soccerTerms.test.ts` に加えた変更を revert（matchSimulation由来の文言を
  sourceTextに含める対応は不要になったため）
- [x] `npm test` で soccerTerms.test.ts / matchupRules.test.ts が全件パスすることを確認

## フェーズ4: UIコンポーネント（MatchSimulationPanel.vue）

- [x] `src/components/MatchSimulationPanel.vue` を新規作成
  - [x] スコアボード表示（大きくスコア表示）
  - [x] ポゼッションバー表示
  - [x] シュート数・枠内シュート数の対比表示
  - [x] タイムライン表示（ゴール強調、スクロール可能）
  - [x] サマリー文の表示（TermAnnotatedTextで用語インライン表示）
  - [x] `prefers-reduced-motion`対応
- [x] `src/components/MatchSimulationPanel.test.ts` を新規作成
  - [x] 固定のMatchSimulationResultを渡し、スコア・ポゼッション・タイムラインが描画されることを検証（6件パス）

## フェーズ5: ComparisonPage.vue への組み込み

- [x] 「試合をシミュレートする」ボタンを追加
- [x] ボタン押下時に`simulateMatch`を呼び出し、結果をrefに保持
- [x] `MatchSimulationPanel`をpropsで結果を渡して表示
- [x] フォーメーション切替（swap/select-a/select-b）時にシミュレーション結果をリセットする
- [x] `src/pages/ComparisonPage.test.ts` に上記の統合的な振る舞いのテストケースを追加（4件追加、全25件パス）

## フェーズ6: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md`: §6.2から本文へ移動し、FR-14として新規セクション（機能詳細と受け入れ基準）を追加。§6.1のMVPスコープ・§4.3画面一覧・§7.1未決事項にも追記
- [x] `docs/specs/1_requirements/architecture-overview.md`: レイヤー構成図を2層→3層へ更新し`composables/`を追記、「機能拡張性」の実績欄を更新
- [x] `docs/specs/1_requirements/repository-structure.md`: `src/composables/`のディレクトリツリー・依存関係表（依存可能: types/。依存禁止: pages/, components/, data/）を追記。pages/の依存可能一覧にcomposables/を追加、機能追加時の配置方針を実装済みへ更新

## フェーズ7: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（276件中276件パス、0スキップ）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（no-non-null-asserted-optional-chainエラーを修正して0件に）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）（Test Files 23 passed, Tests 276 passed、スキップ0件）

## フェーズ8: 検証・レビュー・振り返り

- [x] `review-implementation` スキルで実装を検証（総合スコア4.4/5。[必須]1件・[推奨]4件・[提案]6件）
- [x] [必須] A/Bを入れ替えて呼ぶと勝敗が反転する不具合を修正
  （`matchSimulation.ts`に`runCanonicalSimulation`/`mirrorResult`を追加し、
  内部計算を`matchup.id`の正準順へ揃えてから鏡写しで返す方式に変更。
  対称性を保証するテストを追加。design.mdの該当記述も更新）
- [x] [推奨] `goalText`に「0点側が2点以上のビハインドから1点を返す」分岐を追加
  （既存の分岐だと誤って「追加点」と表示されていた）
- [x] [推奨] `buildSummary`の指標選択ロジックを修正
  （ポゼッション・シュートの両差分が0以下＝勝者が内容面で劣勢のケース向けの
  専用の言い回しを追加。単位の異なる差分を直接比較する問題を回避）
- [x] [推奨] 要件定義書の節番号の逆順（4.1.5が4.1.4より前にあった）を修正
- [x] [推奨] `matchSimulation.test.ts`の恒真アサーション（`timeline.length >= 0`）を
  意味のある検証（`Number.isFinite`・`timeline.length > 0`）へ置換
- [x] [提案] 不変条件テストに「タイムラインのゴール件数=スコア合計」
  「枠内シュート相当のイベント件数=枠内シュート合計」を追加
- [x] [提案] `it.each(cases)`が0件でも気づけるよう`cases.length > 0`のガードテストを追加
- [x] [提案] 回帰用の固定値テストを、`generateMatchup`直呼びではなく`data/matchups.ts`の
  `getMatchup`経由（本番の`ComparisonPage`と同じ経路）へ変更
- [x] [提案] `MatchSimulationPanel.test.ts`のfixtureに残っていた旧文言「ポゼッション」を
  「ボール保持率」へ修正
- [x] [提案] `types/formation.ts`の`MatchEvent.minute`コメントを実装（1-90）に合わせて修正
- [x] [提案] 「もう一度シミュレーションを見る」ボタン（実質no-op）を、結果表示後は
  ボタン自体を非表示にする方式へ変更し、誤解を招く文言を無くした
  （`ComparisonPage.test.ts`の該当テストも実態に合わせて更新）
- [x] 修正後、`npm test` / `npm run lint` / `npm run typecheck` / `npm run build` を再実行し全てパスすることを確認
- [x] `review-pre-commit` スキルでコミット前レビューを実施（Critical/High 0件、Medium 3件、Low 5件）
- [x] Medium 3件(M-1/M-2/M-3)を修正。M-1対応でmainをマージ（feature/add-formations、8フォーメーション・28組を取り込み）
- [x] Low 2件(L-1/L-2)も追加で修正。L-3/L-4/L-5は積み残しとしてreview-report.mdに記録
- [x] 修正後、`npm test`（384件）/ `npm run lint` / `npm run typecheck` / `npm run build` を再実行し全てパスすることを確認
- [x] `retrospective.md` を作成（レビュー結果の要約・review-report.mdへのリンクを含む）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

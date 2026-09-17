# コミット前レビューレポート

## 第1回（2026-09-14）

- 対象: `feature/match-simulation`（マージベース `eccfb72`）の差分。
  `src/composables/matchSimulation.ts`/`.test.ts`、`src/components/MatchSimulationPanel.vue`/`.test.ts`、
  `src/pages/ComparisonPage.vue`/`.test.ts`、`src/types/formation.ts`、
  `docs/specs/1_requirements/{requirements-definition,architecture-overview,repository-structure}.md`、
  `.steering/20260913-match-simulation/*`
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件

## コミット前レビュー結果

対象: `feature/match-simulation`（worktree: `C:\develop\workspace-claude\soccer-sim-worktrees\feature-match-simulation`）のマージベース `eccfb72` からの差分

検証: `npm test`（23ファイル / 278テスト 全通過）、`npm run typecheck`、`npm run lint` いずれもクリーン。

### Critical（即時対応必須）
なし。

### High（優先対応）
なし。

### Medium（対応推奨）

**M-1 [運用] ブランチが main より2コミット遅れており、固定値回帰テストが main マージ後に壊れる可能性が高い**
main は `feature/add-formations`（フォーメーション4→8種、28組）まで進んでおり、`matchupRules.ts`/`formationTags.ts` の変更で既存ペアの `overallEdge` が変化しうる。`overallEdge` はシミュレーションの確率に直接効くため、固定値テストが main マージ後に無言でズレる可能性がある。
→ コミット前に main を取り込み、テスト再実行してから固定値を確定させること。

**M-2 [バグ] `goalText` の分岐に穴がある（2点以上ビハインドかつ自チーム1点以上のケース）**
`scoreBeforeSelf === 0` のときだけ「1点を返す」に落ちるため、例えば1-3の状況で得点すると「〜が追加点を挙げる」になる。実際には2点ビハインドのまま1点返しただけで、文言として誤り。

**M-3 [バグ] `clamp` は NaN を素通しし、NaN 時は「例外」ではなく「毎分ゴール」という静かな誤りになる**
`x >= NaN` は常に false なので確率判定が全段階を通過し、90分すべてゴールという結果が無言で出る。現状 `stats` は静的データのみに由来し有限だが、`simulateMatch` は公開純粋関数であり将来のカスタムフォーメーション入力にも備えて防御すべき。

### Low / 改善提案

**L-1 [バグ/堅牢性]** `matchup.id.split("_vs_")` は id 形式へのハードな依存。フォーメーションidに`_vs_`が含まれると正準判定が反転しうる。
**L-2 [バグ/表示品質]** `buildSummary` の差分比較が単位混在（%と本数を直接比較）。僅差でも「支配し」と言い切ってしまう。
**L-3 [バグ/仕様]** 組み合わせ変更の watch が配列リテラルを返すため理論上は不要な再評価がありうる（実害は低い）。
**L-4 [運用/a11y]** 結果表示後にボタンが消えるとキーボードフォーカスが失われる。
**L-5 [性能]** ループ内で不変値を再計算している（実害なし、計測不能なレベル）。

### 問題なし

- セキュリティ①〜④: ハードコーディング・シークレット・APIキー・URLなし。認証・認可は該当なし（バックエンドを持たない静的SPA）。`v-html`/`innerHTML`/`eval`なし、全て mustache 補間で自動エスケープ。ログへの機密情報出力なし。
- 決定性（FR-14受け入れ条件）: シードは `matchup.id` の文字列値由来。A/B入れ替え時の鏡写しも実データ経路で検証済み。
- 不変条件: ポゼッション合計100、score<=shotsOnTarget<=shots、タイムラインのゴール件数とスコア合計の一致、全組み合わせで検証済み。恒真アサーションなし。
- ゼロ除算: `total === 0` ガードあり、テストで到達確認済み。
- 性能: 90回ループ・1回あたり最大4回のPRNG呼び出しのみ。ループ内I/Oなし。
- 後方互換: 既存型は変更せず末尾追加のみ。`composables/`は新設で既存モジュールへの逆依存なし。
- ドキュメント整合性: architecture-overview/repository-structure/requirements-definitionが相互に矛盾なく更新されている。

### 総合評価

Critical/Highの指摘は無し。コミットしてよい状態だが、Medium 3件（M-1〜M-3）は対応してから確定する。

### 対応

- **M-1**: `git merge main` を実行し、`feature/add-formations`（8フォーメーション・28組）を取り込んだ。
  `docs/specs/1_requirements/requirements-definition.md` の§6.1に1件コンフリクトが発生し、
  両方の実装済み項目を残す形で解決した。マージ後、全384テスト・lint・typecheck・buildを
  再実行しすべてパスすることを確認した（固定値回帰テストの対象ペア4-2-3-1 vs 4-4-2は
  overallEdgeが変わらず、既存の期待値のままパスした）。
- **M-2**: `goalText`の分岐条件を`scoreBeforeSelf === 0`から`scoreBeforeSelf < scoreBeforeOpponent`へ一般化し、
  任意のビハインド幅で正しく「1点を返す」と表示されるよう修正した。回帰テストとして、
  全28組み合わせのタイムラインを走査し「ビハインド中の得点イベントに『追加点』の文言が
  含まれないこと」を検証するテストを追加した。
- **M-3**: `clamp`関数に`Number.isFinite`のガードを追加し、NaNが渡された場合は`min`（保守的な下限値）へ
  フォールバックするようにした。NaNを含むフォーメーションでシミュレーションしても
  スコアが90-0のような不自然な値にならないことを検証する専用テストを追加した。
- **L-1**: `matchup.id.split("_vs_")`による判定を`matchup.id.startsWith(\`${a.id}_vs_\`)`へ変更し、
  フォーメーションidに`_vs_`が含まれるケースでも誤判定しない形にした。
- **L-2**: `buildSummary`にポゼッション差の閾値（10ポイント）を設け、僅差の場合は
  「支配し」ではなく「わずかに上回り」という控えめな表現にした。
- **L-3・L-4・L-5**: 今回は対応せず、積み残しとする（下記参照）。L-3は既存コード
  （FR-13の学習進捗トラッキング用watch）と同じパターンであり実害の報告例が無いこと、
  L-4はa11y改善として別途取り組む方が影響範囲を見積もりやすいこと、L-5は計測不能な
  レベルの最適化であることが理由。

修正後、`npm test`（384件）・`npm run lint`・`npm run typecheck`・`npm run build`を再実行し、
すべてパスすることを確認した。

## レビュー完了（2026-09-14）

- 最終ラウンド: 第1回（Critical/Highが0件だったため再レビューは不要）
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - L-3（`ComparisonPage.vue`のwatchが配列リテラルを返す件）: 既存パターンと同型のため
    今回は見送り。検出テストは無し（実害の再現手順が無いため）
  - L-4（結果表示後にボタンが消えるa11y上のフォーカス喪失）: 検出テストは無し。
    次回のアクセシビリティ改善タスクで対応する
  - L-5（ループ内の不変値再計算）: 計測不能なレベルのため対応不要と判断

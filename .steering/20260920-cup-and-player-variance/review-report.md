# コミット前レビューレポート

## 第1回（2026-09-20）
- 対象: カップ戦シミュレーション（`composables/cupSimulation.ts`等）・選手個体差（`composables/squadCondition.ts`等）の新規実装差分（tracked 7ファイル + 新規6ファイル。`.steering/`配下の計画書は対象外）
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 5件

## コミット前レビュー結果

対象: `C:\develop\workspace-claude\soccer-sim-worktrees\feature-tournament-player-variance` の作業ツリー差分（tracked 7ファイル + 新規 6ファイル。`.steering/` 配下の計画書は対象外）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）

- **[バグ/設計] PK戦の勝者が呼び出し順に依存する（既存の決定性インバリアント違反）**
  `cupSimulation.ts:70-72`
  `getMatchup` が返す `matchup.id` は正準順（呼び出し順で反転しない）なので、`fnv1aHash(\`${matchup.id}_pk\`)` は `playMatch(x, y)` と `playMatch(y, x)` で同一シードになる。一方 `pk.scoreA/scoreB` は「呼び出し時の a/b」にそのまま割り当てられるため、同じカードでも引数順を入れ替えると PK の勝者が入れ替わる。90分の本体は `simulateMatch` が `mirrorResult` で順序非依存を保証しているのに、PK だけがその保証から外れている。
  → PK も正準順で解決してから、呼び出し順が逆なら結果を入れ替える。

- **[運用] `CupPage.vue` が例外を無言で握りつぶす**
  `CupPage.vue:66-72`
  `catch { return null; }` はログも出さず、`formations.length !== 8`（要件変更・データ追加）と「マッチアップ欠落」（データ不整合）という性質の違う2つの失敗を同じ「カップ戦を集計できませんでした」に潰す。
  → `catch (error) { console.error(...); return null; }` で捕捉した例外を必ず残す。

- **[運用] 8件でないときカップ戦リンクが死んだページへ誘導する**
  `FormationListPage.vue:16`
  `/cup` リンクは無条件に表示される。`formations` が8件でない状態では必ずエラー表示になる導線が一覧画面に残る。
  → リンクを `v-if="formations.length === 8"` で出し分ける。

- **[バグ/テスト] 新規UIにテストが無い**
  `SquadConditionControls.vue` と `CupPage.vue` にテストファイルが無い。`src/components/` の他10コンポーネントは全て `.test.ts` を持っており、この規約から外れているのはこの1件だけ。また `ComparisonPage.test.ts` は更新されておらず、今回追加した挙動の検証価値の高いものが一切カバーされていない。
  → 最低限 `SquadConditionControls.test.ts` と、ComparisonPage のリセット挙動のテストを追加。

### Low / 改善提案

- **[バグ] PK サドンデスの無限ループ懸念は実務上・理論上とも問題なし**
  シード0〜2,999,999の全数で`simulatePenaltyShootout`を実測: サドンデス最大35ラウンド・非終了ゼロ。実際に使われるシードは7個のみで、1000ラウンド超の確率は無視できる水準。番人（`if (round > 1000) throw`）は将来`PK_SUCCESS_PROBABILITY`が0/1に変更された場合の保険として申し送り。

- **[バグ] `squadConditionSeed + 1` のオーバーフローは問題なし**
  `Math.random() * 0xffffffff`の上限は`0xfffffffe`、+1で最大`0xffffffff`。`mulberry32`は32bitへ畳むため飽和・精度落ちなし。連続シードの相関も実測（20万ペア×5軸）で独立時の期待値と一致。境界値・相関ともに実害なし。申し送りでよい。

- **[運用] 型定義の整合性は問題なし**
  `CupMatch`/`CupSimulationResult`は`LeagueMatchResult`/`LeagueSimulationResult`の命名規約を踏襲。判別共用体化は現状の規模では過剰、申し送り。

- **[品質] 誤字**: 「フォーメーム」→「フォーメーション」（`requirements-definition.md` FR-18、`cupSimulation.test.ts`）

- **[品質] コメント配置**: `matchSimulation.ts`の新規コメントが既存JSDocブロックと関数宣言の間に挿入されている。申し送り（軽微）。

- **[UX] PKの打ち切り**: 5本勝負で一方が数学的に勝利確定しても5本すべて蹴る実装。ゲーム性として許容範囲、申し送り。

### 問題なし

- セキュリティ①〜④（ハードコーディング・認証認可・インジェクション・情報漏洩）: 該当なし
- バグ（境界値・堅牢性）: `applySquadVariance`のクランプ・NaN防御、状態リセット漏れなし
- 性能: ループ内I/Oなし、カップ戦は固定7試合、`computed`でキャッシュ
- 運用（後方互換）: `matchSimulation.ts`の変更はexport追加のみ、既存シグネチャ不変

### 未検証

- ユニットテスト・lint・typecheck・buildは依頼文の「実行済み・成功」を前提とし、レビュー内では再実行していない
- 実ブラウザでの`/cup`表示・遷移は未確認（読み取り専用レビューのため。→メインエージェント側でブラウザ確認済み）

### 総合評価

**Critical / High の指摘は無し。コミットしてよい。** Medium 4件のうち2件（PK順序依存・例外握りつぶし）はマージ前に潰すことを推奨。

### 対応

- PK戦の勝者が呼び出し順に依存するバグ: 修正済み。`playMatch`内で`matchup.id`の正準順を判定し、正準順でPK戦を解決してから呼び出し順へマッピングするよう変更（`cupSimulation.ts`）。順序非依存性を検証するテストを`cupSimulation.test.ts`に追加。
- `CupPage.vue`の例外握りつぶし: 修正済み。`catch`節に`console.error`を追加。
- カップ戦リンクの出し分け: 修正済み。`FormationListPage.vue`に`v-if="formations.length === CUP_REQUIRED_FORMATION_COUNT"`を追加。
- 新規UIのテスト不足: 修正済み。`SquadConditionControls.test.ts`を新規作成、`ComparisonPage.test.ts`に選手個体差の状態管理テスト（トグルON/OFF・リロール・組み合わせ変更時のリセット・レーダーチャートへの非影響）を8件追加。
- 誤字「フォーメーム」: 今回の差分内（`requirements-definition.md`・`cupSimulation.test.ts`・本ディレクトリの`requirements.md`）で修正。既存コード（`matchSimulation.test.ts`等の過去差分）は対象外（診療対象は今回のコミット差分のみのため）。
- PK無限ループ番人・型の判別共用体化・コメント配置・PK打ち切り: 実害なしの申し送り事項として対応しない（積み残し）。

## レビュー完了（2026-09-20）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）: PKサドンデスに上限の番人を置いていない（`PK_SUCCESS_PROBABILITY`が将来0/1に変更されない限り実害なし）、`penaltyScoreA/B`と`wentToPenalties`の関係が判別共用体化されていない（型では未保証）、`matchSimulation.ts`のコメント配置、PK5本勝負が数学的決着後も打ち切らない（ゲーム性として許容）。いずれもテストや実害の裏付けを確認済みで、再発時の検出手段（既存テスト・実測）を本レポートに記録済み。

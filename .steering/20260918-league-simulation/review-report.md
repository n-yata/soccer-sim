# コミット前レビューレポート

## 第1回（2026-09-18）
- 対象: リーグ戦シミュレーション機能の全差分（`git diff HEAD`）
  - 新規: `src/composables/leagueSimulation.ts`, `src/composables/leagueSimulation.test.ts`, `src/pages/LeaguePage.vue`
  - 変更: `src/router/index.ts`, `src/types/formation.ts`, `src/pages/FormationListPage.vue`,
    `docs/specs/1_requirements/functional-overview.md`, `docs/specs/1_requirements/requirements-definition.md`
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 5件

## コミット前レビュー結果

対象: `C:\develop\workspace-claude\soccer-sim-worktrees\feature-league-simulation` の未コミット差分全件
- 新規: `src/composables/leagueSimulation.ts`、`src/composables/leagueSimulation.test.ts`、`src/pages/LeaguePage.vue`
- 変更: `src/router/index.ts`、`src/types/formation.ts`、`src/pages/FormationListPage.vue`、`docs/specs/1_requirements/functional-overview.md`、`docs/specs/1_requirements/requirements-definition.md`
- `.steering/20260918-league-simulation/` は依頼どおり対象外（存在のみ確認）

### Critical（即時対応必須）
なし

### High（優先対応）
なし

### Medium（対応推奨）

- **[運用] マッチアップ欠落時に画面全体が白画面化する**
  `src/pages/LeaguePage.vue:71` は `computed(() => runLeagueSimulation(formations, getMatchup))` をテンプレート（`league.matches.length` ほか）から直接参照しており、`leagueSimulation.ts:113` の `throw new Error(...)` はレンダー中に伝播する。`src/App.vue` は `<router-view />` のみ、`src/main.ts` に `app.config.errorHandler` も `onErrorCaptured` も無いため、投げた瞬間にリーグ戦画面だけでなくアプリ全体がアンマウントされ、ユーザーには無言の白画面しか残らない。既存の同種ケースは明確に「劣化表示」で受けている（`ComparisonPage.vue:3` の `v-if="formationA && formationB && matchup"`、`MatrixPage.vue:154-159` のコメント「静かな不整合が起きるため、edgeが無い（=matchup未定義）ことを独立した状態として扱う」）ので、新画面だけが規約から外れている。
  なお `buildAllMatchups`（`src/data/matchupGenerator.ts:238-246`）が全ペアを必ず生成するため、本番データでこの分岐に入る経路は現状無い（＝Critical/High には上げない）。
  → 修正方針: ドメイン側の `throw` はデータ不整合検知として残してよいが、`LeaguePage.vue` 側で `try/catch` するか、`league` を「成功結果 or エラー」を返す形にして `v-if` でエラーメッセージ表示に落とす。最低でもアプリ全体が落ちない形にすること。

- **[運用] `repository-structure.md` にファイル追加が反映されていない**
  `docs/specs/1_requirements/repository-structure.md` は `pages/`・`composables/` 配下を1ファイルずつ列挙して説明する構造だが、今回の差分にこのファイルが含まれておらず、`LeaguePage.vue` と `leagueSimulation.ts` がツリーにも役割説明にも載っていない。列挙型のドキュメントなので、抜けるとそのまま乖離が固定化する。
  → 修正方法: ツリーへの2行追加と、`pages` / `composables` 役割説明セクションへの追記。

- **[バグ/テスト] 順位の並び順を検証しているテストが実質恒真**
  `leagueSimulation.test.ts:50-54` の「順位は勝ち点の降順に並んでいる」は `standings[i].rank >= standings[i-1].rank` を検証しているが、`rank` は `assignRanks`（`leagueSimulation.ts:69-81`）がソート済み配列の添字から採番する値なので、ソート結果が何であろうとこのアサーションは通る。テスト名（勝ち点の降順）と検証内容（rank の単調性）も一致していない。結果として、実データでのタイブレーク順序（勝ち点→得失点差→総得点）を検証しているテストが1本も無い。
  → 修正方法: `standings[i].points <= standings[i-1].points` を検証し、勝ち点同値時は `goalDifference`、さらに同値なら `goalsFor` が非増加であることまで辞書式に検証する。

### Low / 改善提案

- **[バグ] フォーメーション ID の重複に対する防御が無い**: `leagueSimulation.ts` は `new Map(formations.map(f => [f.id, ...]))` で集計器を作るため、`formations` に同一 ID が2件あると集計器が1つに畳まれる。現状の静的データは8件すべて一意のため実害は無い。
- **[バグ] `:key` の組み立てが ID 内のハイフンと衝突しうる**: `LeaguePage.vue` の `` `${match.formationAId}-${match.formationBId}` `` は ID 自体がハイフン区切りのため区切りが曖昧。現データでは衝突しない。
- **[セキュリティ] `router-link :to` の動的パスは文字列連結より名前付きルート推奨**: 値が静的データ由来かつ `:to` 経由でエスケープされるため XSS/インジェクションの余地は無いが、ID に `/` や `?` が入ると経路が壊れうる。
- **[運用] コメントと実装のズレ**: `LeaguePage.vue` の「マウント時に確定させてよい」は `computed`（遅延評価＋キャッシュ）の説明としてやや不正確。また `functional-overview.md` の画面一覧表記とデータフロー図の表記が揺れている。
- **[テスト] エラー検証が `toThrow()` のみ**: 別の想定外例外でも緑になるため、メッセージ断片でのマッチが望ましい。

### 問題なし

- セキュリティ①〜④（ハードコーディング・認証認可・インジェクション・情報漏洩）: 該当なし。API キー・URL・シークレットのハードコーディングなし。DB/シェル/`eval`/`v-html` 不使用。ログ出力の追加なし。
- バグ（境界値・計算・決定性）: 空配列でもクラッシュしない。ゼロ除算なし。勝敗判定三分岐が網羅的。勝ち点・得失点差の計算式が正しい。自己対戦・重複対戦なし（28試合）。決定的ソート。
- 同着順位方式（1,2,2,4...）が正しく実装されている。
- 性能: I/O・N+1なし。28試合規模で懸念なし。
- 運用（後方互換）: 新規ルート追加のみで既存機能への破壊的変更なし。
- 検証コマンド: `npm test`（10 passed / leagueSimulation）、`npm run typecheck`、`npm run lint` いずれも成功。

### 未検証

- `LeaguePage.vue` の実ブラウザでの見た目の細部（メイン側で別途 `npm run dev` による目視確認を実施済み）。
- 28試合の具体的なスコアの戦術的妥当性（決定性・集計整合性は検証済み、値の妥当性はドメイン判断のため対象外）。
- `docs/specs/2_basic-design/` 以降の工程ドキュメントへの反映有無（先行機能FR-14も`1_requirements`のみの更新で済ませている前例があり、運用判断として対象外とした）。

### 総合評価

Critical・High の指摘はなし。Medium 3件はいずれも小さな修正で解消可能なため、コミット前に対応する。

### 対応

- **[Medium-1] エラー未処理による白画面化**: `LeaguePage.vue` の `league` computed を try/catch し、
  マッチアップ欠落時は `ComparisonPage.vue`/`MatrixPage.vue` と同様にエラーメッセージ表示へ
  劣化させるよう修正した。
- **[Medium-2] repository-structure.md の反映漏れ**: `LeaguePage.vue` と `leagueSimulation.ts` を
  ディレクトリツリー・役割説明へ追記した。
- **[Medium-3] 恒真テストの修正**: 「勝ち点の降順」テストを、`points → goalDifference → goalsFor`
  の辞書式非増加を検証する内容に修正した。
- Low 5件のうち、`:key` の衝突可能性・名前付きルートへの変更・エラーメッセージのマッチ強化は
  併せて修正した。フォーメーションID重複防御・コメント表記ズレは実害が無いため、修正せず
  本レポートへの記録のみで積み残す。

## 第2回（2026-09-18）— mainインシデント復旧後のrebase整合性再レビュー
- 背景: mainの作業ツリーが`.git`ごと消失するインシデント（別セッション起因）が発生し、
  別セッションが本worktreeを元にmainを再構築した。再構築後のmainには並行開発中だった
  別機能「自由配置モード」が`FR-15`として先に取り込まれており、本機能のFR番号（当初FR-15）
  と衝突したため、新しいworktree（`feature-league-simulation-v2`）へレビュー済みのコードを
  そのまま移植し、ドキュメントの採番のみFR-16へ繰り下げた。この移植（rebase）が正しく
  行われたかを、読み取り専用エージェント（Explore、Bashは使うがEdit/Writeを持たない）で
  再確認した（前回インシデントの申し送りに基づき、書き込み権限のないエージェント種別を
  意図的に選定）
- 対象: `git diff HEAD` の全差分（rebase後の状態）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 6件

### Critical（即時対応必須）
なし

### High（優先対応）
なし

### Medium（対応推奨）

- **[運用/ドキュメント整合] エラーハンドリング表にリーグ戦の縮退表示が未記載**:
  `functional-overview.md`「エラーハンドリング」表に、`LeaguePage.vue`のマッチアップ欠落時
  縮退表示（「リーグ戦を集計できませんでした」＋一覧画面リンク）の行が無かった。
- **[運用/ドキュメント整合] 表示仕様の「表示項目」にリーグ戦の項目が無い**:
  画面一覧表・遷移図・モジュール図は更新済みだったが、「表示項目」表だけ
  リーグ戦の「順位表」「全対戦結果一覧」が欠落していた。

### Low / 改善提案（積み残し）

- `architecture-overview.md`の`composables/`層の説明がFR-16（composables同士の依存を
  初めて導入した変更）に触れていない。
- `repository-structure.md`の`types/formation.ts`行が`League*`型に個別言及していない
  （「等」で読めるため実害なし）。
- FR-16本文のルート表記（`/compare/:a/:b`）が実パラメータ名と異なっていた。
- FR-16の「8種類・28試合」という値は、NFR-03により変動しうる現状値である旨を
  明示するとより正確。
- `formations`のid一意性を検証する専用テストが無い（`leagueSimulation.ts`は
  重複時に静かに集計が壊れる設計だが、現状データは8件とも一意）。
- モジュール構成図の`leagueSimulation.ts → matchSimulation.ts`の依存がノードとして
  図に表現されていない（`matchSimulation.ts`自体が元から図に無い既存の簡略化方針と
  整合しており、矛盾ではない）。

### 問題なし

- FR-15（自由配置モード）とFR-16（リーグ戦）の記述混同・番号衝突なし。
- mermaidノードID（S1〜S6, D1〜D4, L1〜L4, P1）の重複なし。
- 型（`League*`）・ルート名（`league`）・CSSクラス（`league-page__*`,
  `formation-list-page__league-link`）いずれも自由配置モード関連コードと衝突なし。
- セキュリティ・性能・バグ観点も差分範囲で問題なし。
- 検証: `npm run typecheck` / `npm run lint` / `npm test`（28ファイル・448テスト）全てグリーン。

### 対応

- Medium 2件（エラーハンドリング表・表示項目表への追記）は本コミットに含めて対応した。
- Low 6件のうち、FR-16のルート表記修正（実パラメータ名への統一）のみ併せて対応した。
  残り5件は実害が無いため積み残す（`architecture-overview.md`の反映漏れ、
  `types/formation.ts`行の型言及省略、8種類/28試合の現状値明示、id一意性テストの不足、
  モジュール構成図のノード省略）。

## レビュー完了（2026-09-18）
- 最終ラウンド: 第2回（Critical/Highが無かったため3巡ルールの対象外）
- 新たな Critical / High: なし
- 積み残し（Low）:
  - フォーメーションID重複に対する防御が無い（`leagueSimulation.ts`）。現状の静的データ8件が
    すべて一意であることは `data/formations.test.ts` 等の既存検証に委ねる。これを検出する
    専用テストは追加していない。
  - `LeaguePage.vue` の `computed` に関するコメントの表記が実装（遅延評価＋キャッシュ）と
    ややズレている。実害はなし。
  - `architecture-overview.md`・`repository-structure.md`（`types/formation.ts`行）への
    軽微な反映漏れ、FR-16の現状値（8種類/28試合）明示、モジュール構成図のノード省略。
    いずれも実害なし。

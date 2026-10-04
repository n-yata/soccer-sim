# コミット前レビューレポート

## 第1回（2026-10-05）
- 対象: worktree `feature/learning-to-board` の未コミット差分（本番 `src/router/index.ts`・`src/pages/FreeLayoutBoardPage.vue`・`src/pages/FormationLearningPage.vue`、テスト2件、docs 8件（drawio 含む）、新規 `.steering/20261005-learning-to-board/`）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 2件

## コミット前レビュー結果

対象: worktree `C:/develop/workspace-claude/soccer-sim-worktrees/feature-learning-to-board`（ブランチ `feature/learning-to-board`）の未コミット差分。本番3件（`src/router/index.ts`・`src/pages/FreeLayoutBoardPage.vue`・`src/pages/FormationLearningPage.vue`）、テスト2件、docs 8件（drawio 含む）、untracked の `.steering/20261005-learning-to-board/` 3件。直近の呼び出し元として `src/components/AppHeader.vue` の `/board` リンクを確認した。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ／運用] 「同じ画面のままクエリだけ変わる遷移は無い」という設計前提が成り立っていない:
  - **何が起きるか**: `/board?blue=4-1-4-1` を開いたあと主ナビ「自由配置ボード」（`AppHeader.vue:50`、`to="/board"`）を押すと `/board` へ遷移するが、ルートレコードが同じなので `FreeLayoutBoardPage` は再マウントされず使い回される。props の `initialBlueFormationId` は `undefined` に変わるが、`initialBlue` はマウント時に1回だけ評価される定数のため、青は 4-1-4-1 のまま残る。URL はクエリなしの `/board` なのに青が既定（`formations[0]`）ではない、という食い違いが静かに起きる。ブラウザの戻る・進むで `/board?blue=X` と `/board` を行き来しても同じ。
  - **文書との関係**: design.md 113行目「同じ画面のままクエリだけが変わる遷移は無い（学習画面からの遷移は画面をまたぐため、毎回マウントされる）」は事実と異なる。functional-overview.md の「主ナビの『自由配置ボード』はクエリなしの `/board` を開く」と screen-08 の「props の変化には追従しない」を合わせても、この遷移で青がどうなるかが文書から読み取れない。
  - **影響**: データは壊れない（保存キーは常に実在する陣形 ID からのみ作られる）。ただし利用者には「主ナビから開いたのに既定の陣形にならない」と見え、この挙動を押さえるテストも無い。
  - **修正方法**（いずれかを選び、文書とテストをそろえる）:
    1. 今の挙動（使い回し・操作中の配置を上書きしない）を仕様として確定する: design.md の記述を直し、screen-08（と FR-21 確定事項）に「ボード表示中に主ナビで `/board` へ遷移しても青の陣形は変わらない」と明記し、`/board?blue=3-5-2` から `router.push("/board")` した後も `#board-formation-a` が 3-5-2 のままであることを実ルート定義のテストで固定する。
    2. URL と表示を常に一致させる: props の変化を `watch` して青を作り直し（`board.A = restoreFormation("A", f); pitchRevision.value++`）、遷移後に青が既定へ戻ることをテストで固定する（`App.vue` の `<RouterView :key="$route.fullPath" />` は全画面に効くため避ける）。

### Low / 改善提案
- [バグ] `/board?blue=X` を開いてセレクトで陣形を変えたあと再読み込みすると青は X に戻る。FR-21 確定事項の「再訪時は初期値へ戻る」どおりで、文書にも「URL に反映しない」と明記されているため、指摘ではなく確認事項として残す。
- [運用] `FreeLayoutBoardPage.test.ts` の No.42 は `route.matched[0]!.props.default` という vue-router の内部表現に依存している。ライブラリ更新で壊れうるが、No.36 で実ルート経由の結合も押さえているため実害は小さい。

### 前回指摘の解消状況
- 初回レビューのため該当なし

### 問題なし
- セキュリティ①: 差分に URL・キー・トークン・アカウント情報なし。drawio の追加文字列は「この陣形をボードで試す →」のみ。steering 3ファイルにも URL・シークレット相当なし（grep で確認）。
- セキュリティ②: 認証のないオフラインアプリで、保護リソースの追加なし。
- セキュリティ③（インジェクション・XSS）: クエリ `blue` の値は `formations.find((f) => f.id === …)` の厳密比較にしか使われず、描画・`v-html`・属性へ流れない。選択後に描画・保存へ流れるのは静的データの `Formation` のみ。ルートの props 関数は配列・null を `undefined` に絞る。学習画面側の `boardLink` は `query` オブジェクトで渡しエンコードは vue-router が行う。`formationId` は `route.params` を文字列に絞った値。
- 保存データ汚染・プロトタイプ汚染: `localStorage` の保存キー `A:{id}` は実在する陣形 ID からしか作られず、クエリ値をオブジェクトのキーに使う箇所もないため、`__proto__` 等を渡されても影響しない。
- セキュリティ④: ログ出力・エラー応答の追加なし。
- バグ・境界値: 未指定・空文字・未知 ID・複数指定はいずれも `formations[0]` へ倒れ、No.42・No.45 で固定。赤とボールの不変は No.43、保存配置の復元は No.44 で固定。不明な陣形 ID では導線が `v-if="formation && lesson"` の内側にあるため非表示（No.35）。
- テストの実効性: 期待値は実装のコピーではなく `formations` の実データと比較。No.36 は実ルート定義でクリックから遷移までたどる結合テスト。
- 性能: 8件の線形探索1回のみ。
- 運用・文書整合: FR-21 確定事項（正本）の受け取り規則が component-design.md・screen-design.md・screen-07/08・test-screen-07/08 の書き写しと矛盾なく一致（上記 Medium の主ナビ遷移時の挙動が書かれていない点を除く）。revert で戻せ、不可逆な要素なし。

### 未検証
- テスト・lint・typecheck・build は再実行していない（依頼元の実行結果を前提）。
- drawio は差分の文字列のみ確認し、図としての見た目は確認していない（依頼元が目視確認済み）。
- Medium の挙動（主ナビ遷移で青が残る）はコードを読んで導いた結論で、実際の画面操作・テストでの再現はしていない。

### 総合評価
Critical / High は指摘なし。コミット可。ただし Medium（設計前提「同じ画面でクエリだけ変わる遷移は無い」が誤りで、主ナビ `/board` への遷移で URL と青の陣形が食い違う）は、文書の修正とテストでの固定、または props 変化への追従のいずれかで近いうちに直すことを推奨する。

### 対応
- Medium（主ナビ遷移で青が残る）: 修正方法1（今の挙動を仕様として確定）を採用した。理由: 要求書で「開いた後の陣形変更は URL に反映しない」と決めており URL と表示の不一致は元々許容している。また、主ナビを押しただけで操作中のボードの陣形が勝手に変わるのを避ける。
  - functional-overview.md（FR-21 確定事項）・screen-design.md（画面8）・screen-08 詳細設計に「ボード表示中に主ナビで `/board` へ移っても青の陣形は変わらない（ボードはその時点の状態のまま）」を明記し、design.md の誤った前提を訂正した。
  - 実ルート定義を使うテストを追加（`/board?blue=3-5-2` → `router.push("/board")` 後も青のセレクトが 3-5-2、同じコンポーネントインスタンスのまま）。props の変化へ追従する `watch` を入れる変異でこのテストが落ちることを確認した。test-screen-08 に No.46 として追加。
- Low 1（再読み込みで青が X に戻る）: 仕様どおりのため変更なし。
- Low 2（No.42 の内部表現依存）: No.36 の結合テストで押さえているため変更なし。
- review-implementation の [推奨] 1（design.md のテスト配置記述）: design.md を実態（ルート props のテストは `FreeLayoutBoardPage.test.ts` 内）に合わせて修正した。

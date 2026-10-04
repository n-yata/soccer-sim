# コミット前レビューレポート

## 第1回（2026-10-04）
- 対象: worktree `feature/screen-docs-alignment` の未コミット差分（AGENTS.md、functional-overview.md、repository-structure.md、screen-design.md、component-design.md、wireframes.drawio、`.steering/20261004-screen-docs-alignment/` の requirements.md / design.md / tasklist.md）
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 2件

## コミット前レビュー結果

対象: worktree `C:/develop/workspace-claude/soccer-sim-worktrees/feature-screen-docs-alignment`（ブランチ `feature/screen-docs-alignment`）の未コミット差分。変更6ファイル（AGENTS.md / functional-overview.md / repository-structure.md / screen-design.md / component-design.md / wireframes.drawio）＋新規 `.steering/20261004-screen-docs-alignment/`（requirements.md / design.md / tasklist.md）。記述の正しさは `src/router/index.ts`・`AppHeader.vue`・`pages/*.vue`・`BoardBall.vue`・`FreeLayoutPitchDiagram.vue`・`data/*Storage.ts`・`formationLessons.ts`・`freeLayoutCoordinates.ts` と照合した。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [運用] 正式ドキュメントから未作成ファイルへのリンク: `repository-structure.md` の新ルール「理由」が kit 改善提案の記録先として `.steering/20261004-screen-docs-alignment/retrospective.md` を参照しているが、同ファイルは未作成（`tasklist.md` 86行目 `- [ ] retrospective.md を作成` も未完了）。このままコミットすると正本ドキュメントが存在しない根拠を指す状態になる。→ 同一コミットで retrospective.md を含める（または後続コミットまで当該文を「作成予定」に変える）。
- [運用] 新ルールの確認手段が人手依存で fail open: 「コミット前レビューでは、上記対象の差分があるのに `wireframes.drawio` が差分に含まれていなければ指摘する」は、レビュー担当が repository-structure.md を読むことに依存しており、kit の review-pre-commit はこのプロジェクト固有ルールを知らない。見落としても何も起きず、今回と同じ乖離が静かに再発しうる。「確認方法」の「drawio のページ数がルート数と一致」「全ページの主ナビが AppHeader.vue と同じ項目・順序」はどちらも機械検査可能。→ 推奨: drawio をパースし、`router` の routes 数・`wireframe-*` ページ数・主ナビラベル列を照合する Vitest テストを追加する。ドキュメントのみの PR として後回しにするなら、最低限 retrospective に申し送りを残す。

### Low / 改善提案
- [バグ（記述の正しさ）] component-design.md「データレイヤー: freeLayoutStorage / boardBallStorage」の「保存先キーは比較画面用と分ける」: 現在の src では `freeLayoutStorage` の利用は `FreeLayoutBoardPage.vue` のみで、ComparisonPage は使っていない（同節の「呼び出し元は FreeLayoutBoardPage に限る」とは整合）。「比較画面用」の保存先が現存するように読めるため、「既定キー（STORAGE_KEY）とは別の専用キーを渡す」程度の表現にすると誤読がない。
- [運用] drawio の主ナビのアイコンは絵文字（✏️ / 📖 / ⚽）で代替表現している。項目名・順序は実装と一致しているが、将来機械照合する場合は絵文字を除去して比較する前提にしておくこと。

### 問題なし
- セキュリティ①（ハードコード・シークレット）: 差分全体と .steering 新規3ファイルに実URL・APIキー・トークン・アカウント情報なし（`https?://`・key/token/secret/password で走査。component-design.md 中の "key" は Vue の `key` 属性の説明で無関係）。drawio にも URL なし。「Jリーグリンク」は文言のみで URL は書かれていない。
- セキュリティ（drawio XML）: 8ページとも XML としてパース可能。`<script`・`javascript:`・`onload`・`onerror`・`xlink:href`・`image=`・`data:`・`link=`・`plugins`・`placeholders` は0件。mxCell id のページ内重複なし、存在しない parent 参照なし。`mxfile host="65bd71144e"` は HEAD と同値。
- セキュリティ②〜④（認証・インジェクション・情報漏洩）: 差分はドキュメントのみでコード変更なし。該当なし。
- AGENTS.md: 変更は `<!-- sdd:end -->` より後ろの「プロジェクト固有の設定」欄の「（未記入）」→3行置換のみで、kit 管理のマーカー区間は無変更。
- 実装との整合（静かに誤る記述の検査）: ルート8件と drawio 8ページが一対一。主ナビ6項目と順序が AppHeader.vue・screen-design.md・component-design.md・drawio 全8ページで一致。`aria-current="location"` の挙動（比較→フォーメーションを選ぶ、陣形学習→戦術を学ぶ）が `isActive` と一致。PageHeader は全8画面で使用、`show-back-button` は比較・相性・用語集・クイズの4画面、`variant="hero"` は一覧のみ、学習一覧・ボードは戻るなし — いずれも実装どおり。各画面の説明文（一覧・比較・クイズ・学習一覧・陣形学習・ボード）が pages の `subtitle` と一字一句一致。ボールの保存タイミング（ドラッグ終了・矢印キーを離した時・フォーカス離脱）が BoardBall.vue の `pointerup`/`lostpointercapture`/`keyup`/`blur` と一致。FreeLayoutPitchDiagram の `update-position-end` がドラッグ終了と keyup のみで発火（一致）。component-design.md に書いた公開シグネチャ（freeLayoutStorage / boardBallStorage / formationLessons / freeLayoutCoordinates / tacticalReplayFrame の export、lessons/buildLesson.ts の存在）が実装と一致。formationLessons の呼び出し元は LearningListPage と FormationLearningPage のみ、boardBallStorage を参照する components は BoardBall.vue のみ（型参照）。functional-overview.md の遷移図に追加した FreeLayoutBoardPage、モジュール構成図の S6〜S8・D5・P2・P3 の依存は実際の依存と矛盾なし。
- 性能: ドキュメントのみで実行時の計算量・I/O の変化なし。drawio は約1,800行増だが、リポジトリ・エディタ運用上問題にならない規模。
- 運用（切り戻し）: すべてテキストファイルの変更で、revert で戻せる。外部送信・不可逆操作なし。

### 未検証
- drawio の描画結果（レイアウトの見た目・はみ出し）は未確認。依頼元が draw.io デスクトップで目視確認済みとの申告に依拠し、こちらは XML 構造・header 行の主ナビラベル列・URL や埋め込みスクリプトが無いことのみを検査した。
- .steering の requirements.md / design.md / tasklist.md は機密走査と retrospective への言及箇所の確認のみで、内容の妥当性は見ていない（コミット前レビューの範囲外）。
- screen-design.md の画面項目定義の細かな条件付き挙動（エラー時の `role="alert"`、用語抽出条件、`aria-label` の書式など）は、該当 pages の実装と行単位では照合していない。
- `npm test`・lint・typecheck・build は依頼元の実行結果を前提とし、再実行していない。

### 総合評価
Critical / High の指摘はなし。コミット可。ただし Medium 1件目（retrospective.md の未作成リンク）は、同一コミットで retrospective.md を作成するか文言を直してからコミットすることを推奨する。2件目（新ルールの機械検査）は、後回しにするなら retrospective で申し送ること。

### 対応
- Medium 1（retrospective.md 未作成）: 同一コミットに `retrospective.md` を含めて解消する（本レポートの後に作成）。
- Medium 2（新ルールの機械検査が無い）: 今回はドキュメントのみの作業として範囲外とし、`retrospective.md` の「次回への改善提案」に後続作業として申し送る（drawio のページ数・主ナビラベル列を router / AppHeader.vue と照合する Vitest テスト。絵文字は除去して比較）。Critical / High ではないため再レビューは不要。
- Low 1（「比較画面用」の表現）: component-design.md の該当文を「ボードはページ側から既定キーとは別の専用キーを渡す」に修正した（記述のみの変更）。
- Low 2（絵文字表記）: Medium 2 の申し送りに「ラベル照合時は絵文字を除去する」を含めた。

## レビュー完了（2026-10-04）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: Medium 2（wireframe と router / AppHeader の整合を機械検査するテストが無い）。現時点で検出するテストは無く、retrospective.md で後続作業として申し送る。

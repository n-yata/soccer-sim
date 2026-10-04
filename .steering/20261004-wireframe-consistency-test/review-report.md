# コミット前レビューレポート

## 第1回（2026-10-04）
- 対象: worktree `feature/wireframe-consistency-test` の未コミット差分（新規 `src/router/wireframeConsistency.test.ts`、変更 `docs/specs/1_requirements/repository-structure.md`、新規 `.steering/20261004-wireframe-consistency-test/` の requirements.md・design.md・tasklist.md）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果

対象: worktree `feature/wireframe-consistency-test` の未コミット差分（新規 `src/router/wireframeConsistency.test.ts`、変更 `docs/specs/1_requirements/repository-structure.md`（確認方法の追記）、新規 `.steering/20261004-wireframe-consistency-test/` の requirements.md・design.md・tasklist.md）。照合のため、直近の参照先 `src/components/AppHeader.vue`・`src/router/index.ts`・`docs/specs/2_basic-design/wireframes.drawio`（id とページ名のみ）・`src/vite-env.d.ts` を読んだ。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [バグ] 主ナビセルの抽出が id 規約依存（fail open の残り経路）: `includes("app-header-nav-")` で抽出するため、drawio 上で規約外の id（コピー&ペーストで drawio が自動採番する id）を持つ主ナビ項目が増えた場合、その項目は検査から黙って外れる。実装側で項目を増やした場合は件数不一致で失敗するので fail closed だが、「drawio にだけ余分な項目がある」ケースは漏れる。repository-structure.md で id 規約を明文化済みなので申し送りで足りる。塞ぐなら、ヘッダー領域（y 座標範囲）にあるテキスト付きセルで規約外 id のものを検出したら失敗させる。
- [バグ] 強調色判定が部分一致: `fontcolor=#15803d` の部分一致なので、`#15803dff` のような色も一致する。現実的な実害はなく記録程度。
- [運用] ヘッダーコメントの id 例: 既知の限界（id は正しいまま x 座標だけ入れ替えた図は検出しない）が明記されていて良い。ただし例示の `ll-app-header-nav-3` / `app-header-nav-3-2` が実データ（`qz-app-header-nav-N` 形式等）と一致しないため、実際の命名例へ揃えると読み手が迷わない。

### 問題なし
- セキュリティ①（ハードコーディング・シークレット）: テスト・repository-structure.md・.steering 3ファイルに URL・キー・トークン・アカウントID・ローカル絶対パス・メールアドレスなし（.steering と drawio 周辺を grep）。`#15803D` は配色の規約値で秘匿値ではない。
- セキュリティ②〜④・OWASP: 本番コード無変更、テストとドキュメントのみで、認証・インジェクション・情報漏洩の攻撃面なし。DOMParser で読むのはリポジトリ内の drawio のみで外部入力ではない。
- `?raw` と本番バンドル: drawio の `?raw` import はテストファイルのみで、エントリから到達しないためバンドルに入らない（依頼元が build 成果物で確認済み）。型は `vite/client` 参照（`src/vite-env.d.ts`）で解決。
- 部分モックの影響範囲: `vi.mock` はファイル単位でスコープされ、他のテストへ波及しない。`importOriginal` 展開により `createRouter` / `createWebHistory` は本物のままで、`router.getRoutes()` は実ルート定義を返す。`src/router/index.ts` は `useRoute` を使わないため差し替えの副作用なし。
- fail open 対策: ルート/ページ0件、XML 解析エラー、名前の無いルート、命名規則違反のページ名（一対一照合で落ちる）、番号の無い nav id（`navOrder` が throw）、圧縮形式の diagram（mxCell 0件で空配列比較により落ちる）、AppHeader が現在地を出さない（`toBeDefined`）、実装側の主ナビ0件（`toBeGreaterThan(0)`）はいずれも失敗する。現在地の `"location"` の扱いも `isActive` の描画結果を正としており、実装の複製になっていない。RouterLink スタブはルート要素が `<a>` なので `aria-current` がフォールスルーで付く。ブランドリンクは `nav` の外なので `nav a` の対象外。drawio 実データは diagram 8・`wireframe-*` 8種がルート名と一致し、`app-header-nav-` の id は48個（8×6）で重複なし。`routeState` は各 it が同期的に設定してから mount し、`it.concurrent` もないため競合なし。
- 性能: 187KB の drawio をファイルあたり1回解析、mount はルート数×2回（現状16回）で軽量。ルートが数十規模でも問題にならない。
- 運用: repository-structure.md にテストの前提規約（ページ名・セル id・強調色）と、機械検査の対象外（タイトル・画面項目）は従来どおりレビューで見ることが明記されている。失敗メッセージが過不足のページ名・ルート名を名指しで出す。revert のみで戻せ、不可逆な要素なし。

### 未検証
- `npm test` / lint / typecheck / build と変異注入は再実行していない（依頼元の実施結果に依拠）。
- .steering 3ファイルは本文を通読しておらず、機密文字列（URL・パス・メールアドレス・12桁数字）の grep のみで確認した。
- drawio は id・ページ名の抽出のみで、ラベル本文の目視照合はしていない。

### 総合評価
Critical / High の指摘はなし。コミットして問題ない。Low 3件は申し送りでよい。

### 対応
- Low 1（規約外 id の主ナビセルが検査から外れる）: 申し送り。drawio にだけ余分な項目がある場合に限られ、id 規約は repository-structure.md に明記済み。retrospective.md の「次回への改善提案」に記録した（現時点でこのケースを検出するテストは無い）。
- Low 2（強調色の部分一致）: 実害なしとして変更しない。
- Low 3（コメントの id 例）: 確認の結果、例示の `ll-app-header-nav-N`（戦術学習一覧ページ）と `app-header-nav-N-2`（比較ページ）は drawio に実在する形式だったため、変更しない（実データは `app-header-nav-N` / `app-header-nav-N-2` / `bd-` `fle-` `gl-` `ll-` `mx-` `qz-` 接頭辞の8種）。

## レビュー完了（2026-10-04）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: Low 1（drawio にだけ規約外 id の主ナビ項目がある場合の検出漏れ）。検出するテストは無く、retrospective.md で申し送る。

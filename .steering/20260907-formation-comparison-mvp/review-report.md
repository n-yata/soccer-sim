# コミット前レビューレポート

## 第1回（2026-09-07）
- 対象: worktree `feature-formation-comparison-mvp` の全変更（`src/` 16ファイル、設定一式、`.steering/20260907-*`、docs 3ファイルの差分）
- 結果: Critical 0件 / High 0件 / Medium 4件 / Low 4件

## コミット前レビュー結果

対象: worktree `feature-formation-comparison-mvp` の全変更（`src/` 16ファイル、設定一式、`.steering/20260907-*`、docs 3ファイルの差分）。読み取り専用で検査、ファイル変更なし。

### Critical（即時対応必須）
なし。

### High（優先対応）
なし。

### Medium（対応推奨）

- [バグ] 解説文が無言で空欄になる経路が残っている: `ComparisonPage.vue`の`{{ matchup?.commentary }}`にv-elseの代替表示がない。同一フォーメーション同士のURL直打ち等で`getMatchup`が`undefined`を返すと、タイトルとピッチ図2枚は表示されたまま解説枠だけが空白になる。→ `formationA.id === formationB.id`のケースをエラー表示分岐に含める。
- [運用] `.prettierignore`に`.claude/settings.json`と`.mcp.json`が入っていない: `prettier --check .`実行時にkit関連設定ファイルが「未整形」検出される（実測）。現状は`format`スクリプトが`src/`限定なので事故は起きないが、誰かが`prettier --write .`を打つと書き換わる穴。→ `.claude/`ごと除外し`.mcp.json`・`package-lock.json`も追記。
- [運用] テスト仕様書と実装の食い違いが残ったまま`[x]`になっている: ケース4/5の期待値ID表記の順序、ケース15の検証内容（実装はhref検証、仕様書はrouter.push検証）、ケース4のformations件数（仕様書3件、実データ4件）の食い違い。→ 仕様書側を実装に合わせて更新。
- [運用] `createWebHistory`のデプロイ前提が未記載: 静的ホスティングでSPAフォールバック設定が必要（次回に回してよいと評価）。

### Low / 改善提案
- [運用] `repository-structure.md`のツリーが実体とずれている（eslint.config.js等の未記載、public/の記載だが実体なし）
- [運用] npm scriptsが「セットアップ手順」に載っていない
- [運用] formatの対象がsrc/**限定でprettier --check系スクリプトがない
- [バグ] `router.push`のPromiseが未処理（実害は想定しにくい）

### 問題なし
- セキュリティ①〜④: ハードコーディングなし、認証該当なし、v-html/innerHTML/evalなし、情報漏洩なし。package-lock.jsonのintegrity全件付与、npm audit 0件。
- バグ: ラベル座標は全44ポジションでviewBox内に収まる（機械検証済み）。getMatchupの順序非依存も担保済み。テストの空振りなし（37件全パス、スキップ0、lint 0、typecheck 0エラー、prettier --check準拠を実測）。
- 性能: 該当なし（静的データのみ、線形探索）。
- 運用（ログ）: console.*残置ゼロ。
- レイヤー依存: components/がdata/をimportしない規約を遵守。

### 未検証
- npm run build（本レビューの「ファイルを変更しない」制約により実行を見送り。既に別途実行し成功記録あり）
- ブラウザ実機での描画・キーボード操作
- 静的ホスティング環境でのHistoryモード直リンク挙動

### 総合評価
Critical / Highの指摘はなし。品質ゲートも実測で全通過。Medium 4件のうち2件（解説文の無言空欄、テスト仕様書の食い違い）はコミット前に直すのが望ましいとの評価。

### 対応
- Medium「解説文が無言で空欄になる経路」: `ComparisonPage.vue`のv-if条件に`matchup`を加え、
  同一フォーメーション同士等でマッチアップ未検出の場合もエラー表示に切り替わるよう修正。
  エラーメッセージを「指定された組み合わせを表示できません」に統一。テストケースを1件追加。
- Medium「.prettierignoreの穴」: `.claude/`全体・`.mcp.json`・`package-lock.json`を追記した。
- Medium「テスト仕様書と実装の食い違い」: `test-screen-02-comparison.md`のID表記順序・ケース15
  の検証内容・件数表記（15→16、同一フォーメーション同士のケースを追加）、
  `test-screen-01-formation-list.md`のフィクスチャ件数（3→4）を実装に合わせて修正した。
- Medium「createWebHistoryのデプロイ前提」: 積み残しとする（デプロイ先未定のため）。

## レビュー完了（2026-09-07）
- 最終ラウンド: 第1回（Medium指摘への対応をレポート追記と同ラウンドで実施）
- 新たな Critical / High: なし
- 対応後、`npm run test`（38件）・`lint`・`typecheck`・`build`を再実行し全て成功を確認。
  意図しないファイル変更（`git status`）も無いことを確認済み。
- 積み残し（Medium / Low を申し送る場合）:
  - `createWebHistory`のデプロイ前提（静的ホスティングでのSPAフォールバック設定）が
    `repository-structure.md`に未記載（デプロイ先が決まったタイミングで追記する）
  - `repository-structure.md`のツリーが実体と一部ずれている（`eslint.config.js`等の未記載）
  - npm scriptsがセットアップ手順に未記載
  - `router.push`のPromise未処理（実害は想定しにくい）
- Low指摘は申し送りとし、今回は修正しない。

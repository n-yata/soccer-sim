# コミット前レビューレポート

## 第1回（2026-11-26）
- 対象: feature/home-game-link の未コミット差分（`src/pages/FormationListPage.vue`・`FormationListPage.test.ts`・
  `docs/specs` 配下6ファイル・`.steering/20261126-home-game-link/`）。`*.import` の改行コードのみの差は対象外
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果

対象: worktree `feature/home-game-link` の未コミット差分。src/pages/FormationListPage.vue、FormationListPage.test.ts、docs/specs 配下5ファイル（functional-overview.md、repository-structure.md、screen-design.md、component-design.md、wireframes.drawio）、test-screen-01-formation-list.md、未追跡の .steering/20261126-home-game-link/（requirements.md、design.md、tasklist.md）。`*.import` は対象外。

**Critical と High の指摘はない。**

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- [運用] 開発サーバーではリンク先が無い: `gameUrl` は `${BASE_URL}game/index.html` だが、`dist/game/` は CI（`soccer-game/tools/export-web.sh`）でしか作られない。そのため `npm run dev` やローカルの preview ではリンクが 404 になる。本番の CI は毎回書き出すので実害はない。気になるなら repository-structure.md の該当箇所に「ローカルではゲームを書き出さない限りリンク先は存在しない」と1行足せば足りる。
- [運用] CI のゲーム書き出しが将来スキップ・失敗すると、リンクだけが残って 404 になる。ただしこれは既存 CI の構成（書き出しはデプロイ前の必須ステップ）の範囲で、今回の差分が持ち込んだ問題ではない。申し送りのみ。

### 問題なし
- **セキュリティ①（ハードコーディング/シークレット）**: 遷移先は `import.meta.env.BASE_URL` から作る同一サイト内の相対パスで、外部 URL・キー・アカウント情報の埋め込みはない。ドキュメントに出てくるのは公開パス `/soccer-sim/game/index.html` だけで、機密ではない。steering の3ファイルも http・key・token・ARN・12桁の数字で grep して該当なし。
- **セキュリティ②（認証・認可）**: 該当なし。静的 SPA に静的リンクを足しただけ。
- **セキュリティ③（インジェクション/XSS）**: `href` はビルド時に決まる定数で、ユーザー入力を含まない。`v-html` も使っていない。同じタブ・同一オリジンへの遷移なので `rel="noopener"` も不要。
- **セキュリティ④（情報漏洩）**: ログ・エラー出力の追加はない。
- **OWASP**: 依存の追加はない（`Gamepad2` は既存の `@lucide/vue` に含まれるアイコン）。設定・SSRF・完全性に当たる変更もない。
- **バグ**: `BASE_URL` は Vite が末尾 `/` 付きで保証するので、文字列連結は正しい（公開時 `/soccer-sim/game/index.html`、テスト時 `/game/index.html`）。
- **バグ（テスト）**: `vi.stubEnv` は既存の `afterEach` にある `vi.unstubAllEnvs()` で戻るので、テスト間で設定が漏れない。新しい2テストは `href`、`target` が無いこと、ヘッダー内への配置、Jリーグリンク未設定時にもゲームリンクが出ることを実際の DOM で確かめている。期待値は実装のコピーではない（`BASE_URL` を `/soccer-sim/` にして公開時の値で照合している）ので、恒真テストでも空振りでもない。
- **バグ（CSS）**: `--color-green-800` と `--color-primary` は tokens.css に定義されている。キーボード操作時の枠は base.css のグローバル `:focus-visible` が効く。`prefers-reduced-motion` の対象にも新しいクラスが追加されている。白文字と green-700 のコントラストは約 5:1 で AA を満たす。
- **性能**: リンク1本の追加だけで、計算量・I/O の変化はない。
- **運用（ドキュメント）**: 画面設計（項目表・イベント表）、コンポーネント設計、機能概要の画面一覧、リポジトリ構造（「導線はまだ無い」の記述を更新）、ワイヤーフレーム、単体テスト仕様 No.38・39 が実装と整合している。requirements.md の受け入れ条件もすべて差分で満たされている。
- **運用（切り戻し）**: revert だけで戻せる。不可逆な変更はない。

### 未検証
- テストは実行していない。読み取りのみのレビューで、テストが緑かどうかは確認していない。
- 本番の GitHub Pages で `/soccer-sim/game/index.html` が実際に開けるか、Service Worker でオフライン起動できるかは確認していない。
- ワイヤーフレームの drawio は XML の差分だけを確認した。描画結果（2つのリンクの重なりや位置）は目視していない。

### 総合評価
コミットしてよい。Critical と High の指摘はない。残るのは Low の運用上の申し送り2件だけ。

### 対応
- Low（開発サーバーではリンク先が無い）: 直さない。手元でゲームを遊ぶ手順（`npm run game:export` で `public/game/` へ書き出すと、
  `npm run dev`・`vite preview` で `/soccer-sim/game/index.html` が開ける）は `repository-structure.md`「セットアップ手順」に既にある。
  この手順で書き出したうえで `vite preview` からリンクを押し、ゲームが起動することを依頼元で確認済み
- Low（CI の書き出しが失敗するとリンクだけ残る）: 申し送り。書き出しはデプロイ前の必須ステップで、失敗すればデプロイ自体が止まる
- 未検証のうち、テスト（36ファイル・562件成功）と公開 URL での起動（PR #20 のデプロイ後に確認）は依頼元で確認済み

## レビュー完了（2026-11-26）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 2件（上の「対応」のとおり、どちらも直さない判断）

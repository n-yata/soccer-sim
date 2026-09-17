# コミット前レビューレポート

## 第1回（2026-09-12）
- 対象: `index.html`, `vite.config.ts`, `src/components/MatchupPitchDiagram.vue`,
  `src/components/RadarChart.vue`, `src/pages/FormationListPage.vue`,
  `src/pages/ComparisonPage.test.ts`, `docs/specs/1_requirements/requirements-definition.md`、
  新規 `docs/content-review-checklist.md`, `public/favicon.svg`
  （`.mcp.json`は今回の作業と無関係な既存のローカル変更のため対象外）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 4件

## コミット前レビュー結果

対象: 上記ファイル一覧（差分）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[バグ・正しさ / A11y] コントラスト改善が目的を達成していない**: `FormationListPage.vue`の
  サブタイトルを白文字+text-shadowにしたが、text-shadowはWCAGのコントラスト比計算に算入されない。
  実測で白文字 on `--color-primary`/`--color-primary-end` は3.30:1/3.75:1で、13px通常テキストに
  必要なAA 4.5:1未達だった。

### Low / 改善提案
- **[テスト] flex-basisアサーションが弱い**: `not.toBe("0%")`では`flex-basis`宣言自体の消失を
  検知できない
- **[運用] `test.css: true`は全テストファイルに効く**: 現状は問題ないが、テスト数増加時は
  `css: { include: [...] }`で対象を絞る余地
- **[運用 / SEO] OGPが不完全**: `og:image`/`og:url`が無い
- **[A11y] RadarChartのaria-labelに文脈が無い**: 数値列だけで「何のグラフか」が伝わらない

### 問題なし
- セキュリティ①〜④: シークレット・APIキー・トークン・URL等の混入なし。新規追加ファイルは
  `.gitignore`で誤って除外されていないことを確認
- 認証・認可/インジェクション: バックエンドを持たない静的SPAで該当なし。`aria-label`はVueの
  属性バインディングでエスケープされ、値は静的データ由来。favicon.svgはスクリプト・外部参照を
  含まない純粋な図形のみ
- バグ・正しさ: `chartLabel`の型整合性、空配列時の非例外動作を確認。追加テストは実CSSを
  jsdomに適用した上での検証であり恒真テストではない
- 性能: `chartLabel`はcomputedでO(系列数×軸数)のみ。ループ内I/O・N+1なし
- 運用: 後方互換の破壊なし。要件定義書§7.1の更新が実際の成果物と対応

### 未検証
- 実ブラウザ・スクリーンリーダー実機での確認（jsdomとコード読解のみ）
- `.mcp.json`の変更（対象外）

### 総合評価
Critical/High指摘なし。Medium 1件（コントラスト未達）はコミット前に修正必須と判断。

### 対応
- Medium「コントラスト未達」: `tokens.css`の`--color-primary`/`--color-primary-end`自体を
  `#15803d`/`#115e59`へ暗く調整し、白文字で計算上4.5:1以上（実測5.01:1/7.57:1）を確保。
  コメントの記述も「text-shadowはコントラスト計算に算入されない」旨に修正
- Low「flex-basisアサーションが弱い」: `toBe("520px")`/`toBe("320px")`の正値アサーションに変更
- Low「RadarChartのaria-labelに文脈が無い」: 先頭に「フォーメーション特性レーダーチャート
  （100点満点）」を追加
- Low「OGPが不完全」「test.cssの適用範囲」: 実害小のため申し送り（次回、公開方針が固まった
  タイミングでog:image等を追加）

---

## レビュー完了（2026-09-12）
- 最終ラウンド: 第1回（Medium/Lowの一部はその場で修正し再テスト・再ビルドで確認済みのため
  再レビューは実施せず、修正内容を本レポートに追記する形で完結。修正後に
  `npx vitest run` / `npx vue-tsc --noEmit` / `npx eslint src` / `npm run build` が
  いずれも成功することを確認済み）
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - OGPの`og:image`/`og:url`未設定（実害なし、公開方針確定後に追加検討）
  - `test.css: true`の適用範囲がプロジェクト全体（現状はテスト数が少なく実害なし）

---

## 第2回（2026-09-12）— 比較画面のVSバッジ削除
- 対象: `src/pages/ComparisonPage.vue`（テンプレート/CSS）、
  `docs/specs/1_requirements/requirements-definition.md`、
  `docs/specs/1_requirements/functional-overview.md`、
  `docs/specs/2_basic-design/component-design.md`、
  `docs/specs/2_basic-design/screen-design.md`、
  `docs/specs/2_basic-design/wireframes.drawio`
  （比較画面中央の装飾用VSバッジをコードとドキュメント・ワイヤーフレームから削除する作業。
  純粋な削除のみで新規ロジックの追加なし）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件（いずれも実害なし）

## コミット前レビュー結果

対象: 上記6ファイル（VSバッジ削除差分）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- `prefers-reduced-motion`メディアクエリのセレクタが単一になった点は意味論上の欠落なし
- `requirements-definition.md`の diff に本タスクと無関係な「7.1 残存する未決事項」の更新が
  混在（別件の追記、実害なし）

### 問題なし
- コード・4ドキュメント・ワイヤーフレーム間でVSバッジ関連記述の削除に整合性あり。他要素からの
  参照（クラス名文字列参照、mxCellのparent参照等）なし
- セキュリティ4項目（ハードコーディング・認証認可・インジェクション・情報漏洩）に該当なし
- 性能・運用への影響なし（削除のみ）
- `ComparisonPage.test.ts`にVSバッジ関連のテスト・アサーションが残っていないことを確認済み

### 未検証
- なし（指摘された確認事項は本ラウンドで解消済み）

### 総合評価
Critical/High指摘なし。コミットして問題ない。

## レビュー完了（2026-09-12・第2回）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し: なし

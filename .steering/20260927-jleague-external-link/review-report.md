# コミット前レビューレポート

## 第1回（2026-09-27）
- 対象: `src/pages/FormationListPage.vue`（Jリーグ公式サイトへの外部リンク追加、+20行）
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 3件

## コミット前レビュー結果

対象: `C:\develop\workspace-claude\soccer-sim\src\pages\FormationListPage.vue`（未ステージの working tree 差分、+20行。テンプレートに外部リンク `<a href="https://www.jleague.jp/j1/special/" target="_blank" rel="noopener noreferrer">` を1つ追加、`.formation-list-page__jleague-link` の CSS を追加）。ステージ済み差分は空。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- **[運用/ドキュメント] 仕様書に未反映の画面要素**: `docs/specs/2_basic-design/screen-design.md`「画面1: フォーメーション一覧画面」の画面項目定義・画面イベント表、および `docs/specs/1_requirements/functional-overview.md` の画面一覧「主な要素」列に外部リンクの記載がなかった。
- **[運用/a11y] タップターゲットが44px未満**: 新リンクは `display: block` のみでクリック領域が ~15px しかなく、他のヘッダーリンク（`min-height: 44px`）と不整合。WCAG 2.5.8観点で不十分。
- **[運用/テスト] 回帰テスト欠如**: `href` / `target` / `rel` を固定するテストがなく、`rel="noopener noreferrer"` のリグレッション（タブナビング再発）を検知できない状態だった。

### Low / 改善提案
- 外部URLの直書きは、秘匿値・環境依存エンドポイントではない公開コンテンツリンクのため許容（環境変数化は不要と判断）。
- 学習アプリへの外部（招待キャンペーン）導線はプロダクト判断事項。トラッキングパラメータなし・`rel="noreferrer"` によりプライバシー上の懸念はなし。
- 新規タブで開くことの読み上げ補助（`aria-label`）は既存リンク群と同水準のため必須ではない。

### 問題なし
- セキュリティ①〜④（ハードコーディング、認証・認可、インジェクション、情報漏洩）: 該当なし・問題なし。
- タブナビング対策: `target="_blank"` に対し `rel="noopener noreferrer"` が正しく付与されており適切。
- バグ・正しさ / 性能: 既存ロジック・レイアウトへの影響なし。静的リンク1つの追加のみ。
- コントラスト: `--color-text-muted` は十分なコントラスト比を確保、下線もあり色のみに依存しない。

### 未検証
- 外部サイト `https://www.jleague.jp/j1/special/` の到達性・内容（読み取り専用方針のため未アクセス）。シーズン特集ページのため中身は時期により変わるが、URL自体は固定と想定。
- `npm run lint` の実行（レビュー方針上、書き込みを伴わない範囲に限定したため未実施。別途 `vitest run` は対応後に実施し10件成功を確認済み）。

### 総合評価
Critical / High の指摘なし。コミット可能。

### 対応
- Medium 3件すべて対応済み:
  1. `screen-design.md` の画面項目定義・画面イベント表、`functional-overview.md` の画面一覧「主な要素」列に外部リンクを追記
  2. `.formation-list-page__jleague-link` に `display: inline-flex; align-items: center; min-height: 44px; box-sizing: border-box;` を追加し、他のヘッダーリンクと同じ44pxタップターゲットに統一
  3. `FormationListPage.test.ts` に `href` / `target="_blank"` / `rel="noopener noreferrer"` を検証するテストケースを追加（`vitest run` で10件成功を確認）
- Low 3件は申し送り事項として記録のみ（実害なしと判断、対応不要）

## レビュー完了（2026-09-27）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし（Medium対応後の再レビューは不要と判断。Medium対応はドキュメント追記・スタイル統一・テスト追加のみでロジック変更を伴わないため）
- 積み残し（Medium / Low を申し送る場合）: なし

## 第2回（2026-09-27）— 配置変更（ヘッダーへ移動）
- 経緯: シャビからのフィードバックにより、フッター下部に置いていたJリーグ外部リンクをヘッダー内の他ナビゲーションリンク群と同じ並びへ移動。リンク先URL・`rel`属性・クリック挙動は変更なし。CSSは既存の白ピル型ボタングループへ統合し、`border-style: dashed`で外部遷移を視覚的に区別。
- 対象: `src/pages/FormationListPage.vue`、`docs/specs/2_basic-design/screen-design.md`、`docs/specs/1_requirements/functional-overview.md`
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 1件

### Critical（即時対応必須）
なし

### High（優先対応）
なし

### Medium（対応推奨）
なし

### Low / 改善提案
- [a11y] タブ順序の変化: リンクがDOM末尾からヘッダー内アクション群の末尾（相性表→理解度チェック→用語集→Jリーグ）に移動し、キーボード操作でのフォーカス到達順が早まる。移動は意図的な仕様変更であり技術的問題はない。実機での目視確認を推奨（未実施）。

### 問題なし
- セキュリティ: `target="_blank"` + `rel="noopener noreferrer"` は移動後も維持。tabnabbing対策に欠落なし。
- バグ・正しさ: CSSセレクタ統合による他リンク（用語集・理解度チェック）への意図しないスタイル影響なし。`border-style: dashed`の単一クラス上書きも問題なし。テンプレートの要素移動に構造上の問題なし。
- 運用: `screen-design.md` / `functional-overview.md` の記述が実装（ヘッダー内配置・文言「⚽ Jリーグ情報（外部サイト）」）と整合。
- タップターゲット: 3リンクとも `min-height: 44px` を維持、縮小なし。

### 未検証
- 実ブラウザ・スクリーンリーダーでの実機確認（フォーカスリング表示、レスポンシブ折り返し時の見た目）。

### 総合評価
Critical / High の指摘なし。コミット可能。

## レビュー完了（2026-09-27・第2回）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: なし（Lowの実機確認は任意）

# コミット前レビューレポート

## 第1回（2026-09-12）
- 対象: `src/pages/ComparisonPage.vue`, `docs/specs/2_basic-design/screen-design.md`,
  `docs/specs/2_basic-design/component-design.md`
  （`docs/specs/2_basic-design/wireframes.drawio`はXML図表のため対象外、
  整形式・2ページ構成であることは別途Pythonで検証済み）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件

## コミット前レビュー結果

対象: `review_diff_layout.txt`（`src/pages/ComparisonPage.vue`、`screen-design.md`、`component-design.md`）

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- なし

### Low / 改善提案
- **[表示] 横並びによりピッチ図の選手ラベルの実効フォントサイズが縮む中間幅が生じる**:
  `flex-basis: 520px`まで縮むケースで実効フォントサイズが約6.7pxまで縮小する可能性。
  ブラウザ確認済みで許容範囲と判断
- **[運用/ドキュメント] 削除したワイヤーフレームの過去版への導線が消えている**: 「過去バージョンは
  git履歴を参照」の一文を添えると親切（リンク切れ自体は無し、docs全体を走査して確認済み）
- **[テスト] `.comparison-page__main`のDOM契約を固定するテストが無い**: 構造変更を検知する
  アサーションが無いため、将来ラッパーを剥がす変更に気づけない
- **[軽微] screen-design.mdの行折り返しが不自然**: レンダリング結果への実害なし

### 問題なし
- セキュリティ①〜④: 新規文字列リテラルの追加なし、シークレット・URL等の混入なし
- 既存テストが壊れない理由: セレクタが`.comparison-page__main`の外側のみを見ており、
  ラッパー追加は原理的に影響しない（空振りではなく構造的に無関係と確認）
- VSバッジの位置決め: `position:relative`の包含ブロックは変わらず、中央寄せ計算に影響なし
- 縦方向の余白: `gap:24px`がrow-gapとしても効くため、折り返し時も従来と同じ間隔
- フレックス計算の退化ケース: 単独行・超広幅いずれも潰れ・溢れは起きない
- アニメーションへの影響なし: SVG内部のuser単位のtransformは描画幅に比例するため相対的な見え方は不変
- 性能: 計算量・I/Oの変化ゼロ、DOM 1ノード+CSS7行の追加のみ
- 運用: component-design.md/screen-design.mdの記述が実装と一致、requirements-definition.mdは
  レイアウトに踏み込んでおらず更新不要（正しい判断）

### 未検証
- wireframes.drawioのページ名とscreen-design.mdの参照名の厳密な一致（依頼時点では未確認、
  コミット前に確認するよう推奨された）
- モバイル幅（〜400px）での実描画確認
- npm run test/lint/typecheck/build は本レビューでは未実行（依頼元報告に依拠、
  ただしセレクタの実地確認で裏付け済み）

### 総合評価
Critical/High/Medium いずれも指摘なし。変更はテンプレートのラッパー1段追加とCSSのフレックス
指定に限定され、props・算出ロジック・DOM順序・アニメーション・アクセシビリティ属性のいずれにも
手が入っていない。**このままコミットしてよい。**

### 対応
- 未検証事項「wireframes.drawioのページ名とscreen-design.mdの参照名の一致」: メイン側でPythonに
  よるクロスチェックを実施し、`wireframe-formation-list`/`wireframe-comparison`の両方が
  ドキュメント参照名と完全一致することを確認
- Low 4件: いずれも実害がないため、申し送りとして残置

---

## レビュー完了（2026-09-12）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - 横並び時の中間幅でのラベル判読性（実害小、ブラウザ確認済みで許容範囲と判断）
  - `.comparison-page__main`の構造を固定するテストが無い
  - screen-design.mdの行折り返し整形（実害なし）

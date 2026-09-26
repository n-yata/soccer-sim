# コミット前レビューレポート

## 第1回（2026-09-26）
- 対象: アクセシビリティ監査で見つかった問題の修正差分（`FreeLayoutPitchDiagram.vue/.test.ts`、`HalftimeTacticsModal.vue` + 新規`.test.ts`、`RadarChart.vue/.test.ts`、`CupPage.vue` + 新規`.test.ts`）
- 結果: Critical 0件 / High 2件 / Medium 6件 / Low 8件

### Critical（即時対応必須）
なし

### High（優先対応）

**H-1. 親SVGの`role="img"`が子要素をアクセシビリティツリーから剪定し、選手circleのtabindex/role/aria-labelがスクリーンリーダーに露出しない**
`role="img"`は「サブツリー全体を1枚の画像として扱う」ため、キーボード操作自体（WCAG 2.1.1）は成立してもスクリーンリーダーからは「選手を選んで動かしている」ことが認知できない。既存テストは属性の有無しか見ないためこの剪定を検知できず、通ってしまう。

**H-2. `role="button"`なのにEnter/Space未対応（ARIA契約違反）**
`role="button"`はEnter/Spaceでの活性化を約束するが、`onKeyDown`は矢印キー以外を無視する。ロール宣言と実装が不一致。

### Medium（対応推奨）

- **M-1**: `HalftimeTacticsModal.vue`のフォーカス復帰先が開いている間にDOMから取り除かれていた場合、フォーカスが迷子になる
- **M-2**: `RadarChart`の`aria-live`が`aria-label`の変化を再通知する保証が無く、かつドラッグ中の高頻度更新で読み上げ洪水になりうる
- **M-3**: 矢印キーのオートリピートで、キー押下のたびに`update-position-end`（localStorage書き込み）が走る
- **M-4**: `CupPage.test.ts`の勝者テストが実質恒真（敗者にクラスが付いていても通る）
- **M-5**: キーボード操作対応が要件定義書等のドキュメントに未反映
- **M-6**: `CupPage`の勝者アイコンがCSS `::before`生成コンテンツで、読み上げがAT依存

### Low / 改善提案
矢印キー以外でのpreventDefault非実行（妥当）、`querySelectorAll`頻度（問題なし）、タブストップ増加、モード切替時のフォーカス喪失、テスト後片付け、フォーカストラップテストのイベント発火経路、aria-label未更新、その他（詳細はサブエージェントの報告を参照。いずれも対応または申し送り済み）

### 対応
- H-1: `FreeLayoutPitchDiagram.vue`を`role="group"`のラッパーdiv構造に変更。SVG自体から`role="img"`を削除し、装飾要素・選手ラベルに`aria-hidden="true"`を追加
- H-2: 選手circleから`role="button"`を削除（tabindex/aria-labelは維持）
- M-1: `previouslyFocusedElement?.isConnected`を確認し、falseなら`document.body`への一時フォールバックを追加
- M-2: `aria-live`を別要素（`role="status"`）に分離し、500msデバウンスした`liveLabel`を表示
- M-3: `update-position`（keydown毎）と`update-position-end`（keyup時の1回のみ）に分離
- M-4: `winnerId`から勝者/敗者を一意に決定し、両方を検証するテストに書き換え
- M-5: `requirements-definition.md`・`repository-structure.md`・`functional-overview.md`を更新（`test-screen-02-comparison.md`への行追加のみ申し送り）
- M-6: `::before`を削除し、`aria-hidden`付き絵文字＋視覚的に隠したテキストに変更

## 第2回（2026-09-26）— 修正後の再レビュー
- 対象: 第1回の指摘への対応差分
- 結果: 新たなCritical/High無し。前回指摘（H-1・H-2・M-1〜M-6）はすべて解消を確認（M-5の単体テスト仕様書への行追加のみ申し送りとして残存、認識済み）

### 前回指摘の解消状況
- H-1: 解消（role="group"の子として選手circleが正しく露出する構造を確認）
- H-2: 解消（role属性なし、矢印キー移動機能は維持）
- M-1: 解消（isConnected確認・フォールバック・タイマー除去まで検証）
- M-2: 解消（aria-live分離・デバウンス・タイマーリーク無し）
- M-3: 解消（ドラッグ側の状態変数と完全分離、混線なし）
- M-4: 解消（恒真ではなくなったことを確認）
- M-5: 概ね解消（申し送り1点を除き反映済み）
- M-6: 解消（::beforeは残っていない）

### 新たな指摘
Critical/High: なし。Low 6件（フォーカスアウトラインのクリップ懸念、可視ヒント文言の未更新、blur時の未確定移動、キー操作の微調整手段の欠如、テスト名と検証内容のズレ、body tabindexの残存範囲）はいずれも実害小・申し送りで対応

### 総合評価
Critical/High指摘なし。コミットして問題ない。

## レビュー完了（2026-09-26）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Low）: フォーカスアウトラインのクリップ懸念、キーボード操作の可視ヒント未追加、`@blur`での未確定移動の取りこぼし、キー操作の微調整手段（Shift併用等）の欠如、`docs/specs/4_unit-test/test-screen-02-comparison.md`へのアクセシビリティ行未追加。いずれも実害が小さいと判断し、次回作業への申し送りとして記録する。

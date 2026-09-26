# 設計書

## アーキテクチャ概要

本作業は既存のUIレイヤー（`pages/`, `components/`）に対するスタイル・マークアップの改修のみで、
`architecture-overview.md`の3層構成（UI / composables / data）は変更しない。新規コンポーネント・
新規composableは追加しない。既存ファイルの`<style scoped>`ブロックへの追記・修正が中心。

## コンポーネント設計

### 1. レスポンシブ点検・修正（対象: 全7画面 + 共通コンポーネント）

**責務**:
- 375px/768px幅での崩れの洗い出しと修正
- 既存の640px境界の`@media`に加え、768px境界のクエリが必要な箇所へ追加

**実装の要点**:
- 環境制約確認: `mcp__claude-in-chrome__resize_window`が使えるか最初に試す
  （前回`retrospective.md`で「本環境で機能しない」と記録されているため、最初に再確認する）。
  - 使える場合: 実ブラウザで375px/768pxに設定し目視確認する。
  - 使えない場合: 開発サーバー（`npm run dev`）を起動し、Chrome拡張の`javascript_tool`で
    `document.documentElement.clientWidth`をログ出力させながら`resize_window`を再試行、
    それでも不可なら**CSSレビュー + 既存テストの`getComputedStyle`アサーション追加**で代替する
    （前回振り返りの改善提案どおり）。
- 既存のブレークポイント値はコメントのみ（`tokens.css`に`--breakpoint-*`変数は無い。
  CSSカスタムプロパティは`@media`条件式に使えないため、各ファイルの`@media (max-width: ...)`に
  直接数値を書く既存パターンを踏襲する）。
- タップ領域点検: `ComparisonControls.vue`、`FreeLayoutControls.vue`、`QuizQuestionCard.vue`の
  選択肢ボタン、`FormationCard.vue`のカード全体クリック領域を対象に、`min-width`/`min-height`
  または`padding`で44px相当を確保する。

### 2. アニメーション・トランジション追加

**責務**:
- 状態変化のある対話的コンポーネントに`transition`を追加
- 新規`animation`追加時は`prefers-reduced-motion`を対で実装

**実装の要点**:
- 対象コンポーネント（`transition`未実装、要求内容ギャップ一覧より）:
  `RadarChart.vue`, `HalftimeTacticsModal.vue`, `FreeLayoutPitchDiagram.vue`,
  `ComparisonControls.vue`, `BackButton.vue`, `TermAnnotatedText.vue`, `TermPopover.vue`,
  `QuizQuestionCard.vue`, `SquadConditionControls.vue`
- 各コンポーネントの性質に応じた`transition`対象:
  - ボタン類（`BackButton`, `ComparisonControls`, `FreeLayoutControls`）: `background-color`,
    `transform`（ホバー・フォーカス時の微小な浮き上がり）
  - モーダル（`HalftimeTacticsModal`）: 開閉時の`opacity`/`transform`フェード（背景オーバーレイと
    モーダル本体の両方）
  - `RadarChart.vue`: SVGの`<polygon>`座標変化に`transition: d 0.3s ease` またはCSS
    `transition`が効かない場合はSVG `<animate>`要素で代替（`d`属性は多くのブラウザで
    `transition`対象外のため、実装時に挙動を確認して決める）
  - `TermAnnotatedText.vue`/`TermPopover.vue`: 開閉時の`opacity`フェード
  - `QuizQuestionCard.vue`: 選択肢クリック時の正誤表示フェードイン
- `prefers-reduced-motion: reduce`時は、`transition-duration: 0.01ms !important` あるいは
  `transition: none`で無効化する（既存`ComparisonPage.vue`のパターンに合わせる）。

### 3. アクセシビリティ点検

**責務**:
- モバイル幅特有のa11y問題（タップ領域・コントラスト）の検出と修正
- 新規アニメーションのreduced-motion対応の網羅

**実装の要点**:
- 新規`transition`/`animation`を追加した箇所は、追加と同じコミット内で
  `prefers-reduced-motion`対応も実装する（後付けにしない）。
- 既存のa11y監査（`.steering/20260926-a11y-audit/`）で確立したパターン
  （キーボード操作・`role`属性等）を踏襲し、新規に導入した動きがキーボード操作の
  フォーカスリングを隠さないことを確認する。

## データフロー

本作業はスタイル・マークアップの改修のみで、データフロー（props/emit/state管理）に変更はない。

## エラーハンドリング戦略

該当なし（表示層の修正のみで、エラーハンドリングロジックの変更はない）。

## テスト戦略

### ユニットテスト
- 既存の`*.test.ts`が全て通ることを確認する（スタイル変更で壊れやすいのは
  `getComputedStyle`ベースのアサーション）。
- レスポンシブ確認をブラウザ自動操作で代替できない場合、対象コンポーネントの
  `*.test.ts`に`@media`適用後の`getComputedStyle`アサーションを追加する
  （前回振り返りの改善提案に基づく）。

### 統合テスト
- 該当なし（`architecture-overview.md`によりE2E/結合テストは対象外）。

## 依存ライブラリ

新規追加なし。

## ディレクトリ構造

変更なし。既存ファイルの`<style scoped>`ブロックへの追記・修正のみ
（`src/pages/*.vue`, `src/components/*.vue`, `src/components/*.test.ts`）。

## 実装の順序

1. 環境制約の再確認（`resize_window`が使えるか）と、使えない場合の代替方針の確定
2. モバイル/レスポンシブ点検・修正（画面ごとに）
3. アニメーション・トランジション追加（コンポーネントごとに、reduced-motion対応込み）
4. アクセシビリティ点検（レスポンシブ・アニメーション作業の中で見つかった問題を都度修正）
5. 品質チェック（lint/typecheck/test）
6. ドキュメント更新（影響があれば）

## セキュリティ考慮事項

該当なし（CSS/マークアップの改修のみ）。

## パフォーマンス考慮事項

- CSS `transition`/`animation`は`transform`/`opacity`を優先し、レイアウト再計算を伴う
  プロパティ（`width`/`height`/`top`/`left`等）のアニメーションは避ける。

## 将来の拡張性

- 今回`@media`の数値がファイルごとにハードコードされている状態は変えない
  （`tokens.css`にCSSカスタムプロパティとしてブレークポイントを持たせる設計変更は、
  スコープ外の大きめの変更のため見送る。必要になれば別タスクとして起票する）。

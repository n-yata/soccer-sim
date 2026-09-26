# 設計書

## アーキテクチャ概要

新規レイヤー追加は無し。既存コンポーネントへのアクセシビリティ属性・キーボードハンドラの追加に限定する。

## コンポーネント設計

### 1. `components/FreeLayoutPitchDiagram.vue`（変更）

**変更点**:
- 各選手`<circle>`に`tabindex="0"` `role="button"` `aria-label`（チーム名+ポジションラベル）を追加
- `@keydown`ハンドラ`onKeyDown(team, item, event)`を追加。矢印キー（Left/Right/Up/Down）で、
  `item.cx`/`item.cy`（画面座標）にステップ幅`KEYBOARD_STEP=6`を加減し、既存の
  `cyToX`/`cxToDepth`で実座標へ逆変換、`clampToPitchRange`でクランプする
- キーボード操作は「1回の押下＝1つの確定した移動」であるため、ドラッグのような
  `update-position`（表示用）/`update-position-end`（永続化用）の分離は不要。両方を
  同時にemitする（ドラッグのpointermoveのような高頻度連打ではないため、性能上の懸念もない）
- `:focus-visible`のCSSアウトラインを追加

### 2. `components/HalftimeTacticsModal.vue`（変更）

**変更点**:
- `modalRef`（ダイアログ本体）・`closeButtonRef`（閉じるボタン）のrefを追加
- `onMounted`で`document.activeElement`を`previouslyFocusedElement`に保存し、
  `closeButtonRef`へフォーカスを移す
- `onBeforeUnmount`で`previouslyFocusedElement`へフォーカスを戻す（既存のEscapeリスナ解除と同じ場所）
- `onTabKeydown(event)`: モーダル内のフォーカス可能要素一覧（`querySelectorAll`）を取得し、
  最後の要素で`Tab`、最初の要素で`Shift+Tab`が押されたときに反対側へ折り返す
  （フォーカストラップ）。`FreeLayoutPitchDiagram`のcircle要素も
  `[tabindex]:not([tabindex="-1"])`セレクタで自然に対象に含まれる

### 3. `pages/CupPage.vue`（変更）

**変更点**:
- `.cup-page__winner`に`font-weight: 700`と`::before { content: "🏆 "; }`を追加し、
  色以外の視覚的手段を併用する

### 4. `components/RadarChart.vue`（変更）

**変更点**:
- `<svg>`に`aria-live="polite"`を追加。`aria-label`（`chartLabel`）の変化が
  スクリーンリーダーへ伝わるようにする

### 5. テスト新規作成

- `components/HalftimeTacticsModal.test.ts`（新規）: フォーカス管理・フォーカストラップ・
  role/aria-modal・Escape・confirm/cancelの基本挙動
- `pages/CupPage.test.ts`（新規）: ラウンド構成・勝者表示・リンク・戻るボタン

## テスト戦略

- `FreeLayoutPitchDiagram.test.ts`: tabindex/role/aria-labelの存在、矢印キーでのemit、
  範囲外への移動のクランプ、矢印キー以外での非発火を追加
- `HalftimeTacticsModal.test.ts`: 上記「3. テスト新規作成」参照
- `CupPage.test.ts`: 上記「3. テスト新規作成」参照
- `RadarChart.test.ts`: `aria-live="polite"`の存在を検証するテストを1件追加

## 実装の順序

1. `FreeLayoutPitchDiagram.vue`のキーボード対応（Critical）
2. `HalftimeTacticsModal.vue`のフォーカス管理（High）
3. `CupPage.vue`の色以外の手段追加（Medium）
4. `RadarChart.vue`のaria-live追加（Medium）
5. 各対応するテストの追加・実行
6. 型検査・リント・テスト・ビルド

## セキュリティ考慮事項

- 外部入力を扱わない画面表示のみの変更のため、追加のセキュリティ対策は不要。

## パフォーマンス考慮事項

- キーボードイベントは離散的（押下ごとに1回）であり、ドラッグのような高頻度イベントに
  起因する性能上の懸念はない。

## 将来の拡張性

- 今回追加したフォーカストラップのパターン（`onTabKeydown`）は、将来モーダルを追加する際に
  そのまま踏襲できる。

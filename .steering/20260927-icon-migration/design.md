# 設計書

## アーキテクチャ概要

既存のVue3 + TypeScript静的SPA（バックエンド無し）に、アイコン専用のnpm依存
`@lucide/vue`を1つ追加する（計画時点では`lucide-vue-next`を想定していたが非推奨のため
変更。経緯は本ファイル「依存ライブラリ」節参照）。アプリ側の変更は「共通ラッパー
コンポーネント1つ」+「各画面・コンポーネントでの絵文字→`<AppIcon>`置換」の2層構造。

```
@lucide/vue（アイコンSVGコンポーネント群）
        ↓ import
AppIcon.vue（aria-hidden/focusable/サイズを一元管理する薄いラッパー）
        ↓ 使用
各Vueコンポーネント・ページ（AppHeader / FormationCard / ComparisonPage 等）
```

## コンポーネント設計

### 1. `AppIcon.vue`（新規）

**責務**:
- lucideアイコンコンポーネントを受け取り、`aria-hidden="true"` + `focusable="false"`を
  常に付与して描画する（装飾用途がデフォルトという方針の実装）
- `size` prop（`sm`/`md`/`lg`）に応じたCSSクラスを付与し、`tokens.css`の`--icon-*`変数で
  実サイズを決める

**実装の要点**:
```vue
<template>
  <component
    :is="icon"
    class="app-icon"
    :class="`app-icon--${size}`"
    aria-hidden="true"
    focusable="false"
  />
</template>

<script setup lang="ts">
import type { LucideIcon } from "@lucide/vue";

withDefaults(
  defineProps<{ icon: LucideIcon; size?: "sm" | "md" | "lg" }>(),
  { size: "md" },
);
</script>

<style scoped>
.app-icon {
  flex: none;
}
.app-icon--sm { width: var(--icon-sm); height: var(--icon-sm); }
.app-icon--md { width: var(--icon-md); height: var(--icon-md); }
.app-icon--lg { width: var(--icon-lg); height: var(--icon-lg); }
</style>
```
- 色prop・strokeWidth propは作らない（`currentColor`継承で十分。必要になってから追加する）
- `<component :is="icon">`の描画結果（svg）はAppIconのルート要素としてVueのスコープIDが
  付与されるため、scoped CSSがそのまま効く

### 2. `PageHeader.vue`（スロット追加）

**責務**:
- 既存の`title`（文字列prop）の前にアイコンを差し込めるようにする

**実装の要点**:
```vue
<h1 class="page-header__title"><slot name="title-icon" />{{ title }}</h1>
```
```css
.page-header__title {
  display: inline-flex;
  align-items: center;
  gap: var(--space-sm);
  /* 既存のmargin/font-size/font-weightは維持 */
}
```
- `LucideIcon`型をpropとして各ページへ波及させない（スロット経由に統一）
- スロット未使用のページ（`ComparisonPage`/`MatrixPage`）は現状のまま変化なし

### 3. 各画面・コンポーネントの絵文字置換

**責務**: 既存の絵文字リテラルを`<AppIcon :icon="..." />`+テキストの組へ置換する

**実装の要点**:
- 置換対象の各ボタン/リンクに`display:inline-flex; align-items:center; gap:var(--space-xs);`を
  追加し、アイコンとテキストの縦位置を揃える（既存の`min-height:44px`は維持）
- `HalftimeTacticsModal.vue`の閉じるボタンは`aria-label="閉じる"`を変更せず、中身のみ
  `<AppIcon :icon="X" />`に置換する
- `ComparisonPage.vue`の勝敗判定バナー（`::before { content: "🏆 "/"⚖️ " }`）は
  テンプレートへ実要素として移設する（詳細は「エラーハンドリング戦略」ではなく下記
  「データフロー」参照）

## データフロー

### 勝敗判定バナーのアイコン切り替え（ComparisonPage.vue）
```
1. matchup.overallEdge（"A" | "B" | "even"）が確定する
2. computed `verdictIcon` が overallEdge === "even" ? Scale : Trophy を返す
3. テンプレートの <AppIcon :icon="verdictIcon" size="lg" /> がそれに応じて描画される
4. 色は従来通り .comparison-page__verdict--A/B/even の color 指定に委ね、
   アイコンは stroke="currentColor" でその色を継承する
```

## 絵文字 → lucideアイコン 対応表（正本）

| # | 箇所 | 絵文字 | lucideアイコン |
|---|---|---|---|
| 1 | AppHeader.vue（ブランドマーク） | ⚽ | `Goal` |
| 2 | AppHeader.vue（ハンバーガー） | ☰ | `Menu` |
| 3 | AppHeader.vue（理解度チェック） | ✏️ | `PencilLine` |
| 4 | AppHeader.vue（用語集） | 📖 | `BookOpen` |
| 5 | BackButton.vue | ← | `ArrowLeft` |
| 6 | ComparisonControls.vue（入れ替え） | ⇄ | `ArrowLeftRight` |
| 7 | FreeLayoutControls.vue（ON） | ✅ | `Check` |
| 8 | FreeLayoutControls.vue（OFF） | 🖐️ | `Hand` |
| 9 | FreeLayoutControls.vue（リセット） | ↺ | `RotateCcw` |
| 10 | FormationCard.vue（選択中バッジ） | ✓ | `Check` |
| 11 | HalftimeTacticsModal.vue（見出し） | 🔧 | `Wrench` |
| 12 | HalftimeTacticsModal.vue（閉じる） | ✕ | `X` |
| 13 | HalftimeTacticsModal.vue（リセット） | ↺ | `RotateCcw` |
| 14 | HalftimeTacticsModal.vue（後半開始） | ▶ | `Play` |
| 15 | SquadConditionControls.vue（ON） | ✅ | `Check` |
| 16 | SquadConditionControls.vue（OFF） | 🎲 | `Dices` |
| 17 | SquadConditionControls.vue（組み直し） | 🔄 | `RefreshCw` |
| 18 | ComparisonPage.vue（用語集リンク） | 📖 | `BookOpen` |
| 19 | ComparisonPage.vue（試合シミュレート） | ⚽ | `Play` |
| 20 | ComparisonPage.vue（配置変更） | 🔧 | `Wrench` |
| 21 | ComparisonPage.vue（勝敗:A/B優位、CSS→テンプレート移設） | 🏆 | `Trophy` |
| 22 | ComparisonPage.vue（勝敗:互角、CSS→テンプレート移設） | ⚖️ | `Scale` |
| 23 | GlossaryPage.vue（titleスロット） | 📖 | `BookOpen` |
| 24 | MatrixPage.vue（凡例） | ✓ | `Check` |
| 25 | MatrixPage.vue（完了メッセージ） | 🎉 | `PartyPopper` |
| 26 | MatrixPage.vue（セル内マーク） | ✓ | `Check` |
| 27 | QuizPage.vue（用語集リンク） | 📖 | `BookOpen` |
| 28 | FormationListPage.vue（titleスロット） | ⚽ | `Goal` |
| 29 | FormationListPage.vue（理解度チェック） | ✏️ | `PencilLine` |
| 30 | FormationListPage.vue（用語集） | 📖 | `BookOpen` |
| 31 | FormationListPage.vue（Jリーグ外部リンク） | 🔗 | `ExternalLink` |

## エラーハンドリング戦略

該当なし（静的なアイコン描画のみで、実行時エラーが起きうる分岐は無い）。

## テスト戦略

### ユニットテスト
- `AppIcon.test.ts`（新規）: icon propに応じたsvg描画・`aria-hidden="true"`付与・
  `size`によるクラス切り替えを検証
- `HalftimeTacticsModal.test.ts`（既存に1件追加、任意・推奨）: 閉じるボタンの
  `aria-label="閉じる"`が維持されていることを検証

### 既存テストへの影響確認
- 絵文字を含む完全一致テキストアサーションは無いことをgrep確認済み（`toContain`の
  部分一致のみ、またはSVGはVue Test Utilsの`.text()`に寄与しない）
- 既存テストの修正は原則不要。実行して確認する

## 依存ライブラリ

**変更**: 計画時点では`lucide-vue-next`を想定していたが、実際にインストールしたところ
`npm warn deprecated lucide-vue-next@1.0.0: Package deprecated. Please use @lucide/vue instead.`
という警告が出た。公開品質を上げる目的の作業で非推奨パッケージを使うのは本末転倒のため、
後継の`@lucide/vue`に切り替えた（技術的理由によるスキップ・置き換え）。

```json
{
  "dependencies": {
    "@lucide/vue": "^1.48.0"
  }
}
```
importの書き方・`LucideIcon`型のexport・アイコン名（`BookOpen`/`ArrowLeft`等18種）は
`lucide-vue-next`と互換があることを`node -e`で実導入確認済み。1.x系のためsemverに
従った運用でよい（`^`のままメジャー固定）。

## ディレクトリ構造

```
src/
  components/
    AppIcon.vue          (新規)
    AppIcon.test.ts       (新規)
    AppHeader.vue          (変更)
    BackButton.vue         (変更)
    ComparisonControls.vue (変更)
    FreeLayoutControls.vue (変更)
    SquadConditionControls.vue (変更)
    FormationCard.vue      (変更)
    HalftimeTacticsModal.vue (変更)
    PageHeader.vue          (変更: #title-icon スロット追加)
  pages/
    ComparisonPage.vue      (変更: CSS content→テンプレート移設含む)
    FormationListPage.vue   (変更)
    GlossaryPage.vue        (変更)
    MatrixPage.vue          (変更)
    QuizPage.vue            (変更)
  styles/
    tokens.css              (変更: --icon-sm/md/lg 追加)
```

## 実装の順序

1. `npm install @lucide/vue`
2. `tokens.css`に`--icon-sm/md/lg`追加
3. `AppIcon.vue`新規作成 + `AppIcon.test.ts`作成
4. `PageHeader.vue`に`#title-icon`スロット追加
5. コンポーネント側置換（AppHeader / BackButton / ComparisonControls / FreeLayoutControls /
   SquadConditionControls / FormationCard / HalftimeTacticsModal）
6. ページ側置換（ComparisonPage[CSS移設含む] / FormationListPage / GlossaryPage /
   MatrixPage / QuizPage）
7. 検証（typecheck / lint / test / dev目視 / build）
8. ドキュメント更新（architecture-overview.md / screen-design.md / component-design.md /
   repository-structure.md / 詳細設計・単体テスト仕様書 / content-review-checklist.md）
9. コミット前レビュー → 振り返り → コミット

## セキュリティ考慮事項

- 新規依存`@lucide/vue`はビルド時にバンドルされるSVGコンポーネント集で、
  外部通信・動的評価を行わないため追加のセキュリティリスクは無い
- コミット前レビューで依存追加（A06 脆弱な依存関係）の観点を確認する

## パフォーマンス考慮事項

- 使用アイコンは約18種類、個別named importによりtree-shakingが効くため、
  バンドルサイズの増分は数KB程度の見込み（`npm run build`で実測確認する）

## 将来の拡張性

- `AppIcon`に`color`/`strokeWidth` propを後から追加しても既存呼び出しに影響しない
  （デフォルト値で後方互換）
- ブランドロゴを将来カスタムSVGにする場合も、`AppIcon`とは別コンポーネント
  （例: `AppLogo.vue`）として追加すればよく、既存のアイコン置換箇所には影響しない

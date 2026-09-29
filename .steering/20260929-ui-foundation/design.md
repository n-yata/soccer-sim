# 設計書

## アーキテクチャ概要

CSSの読み込みを**3層**に整理する。現状は最下層の「トークン」しか存在せず、
その上の2層（リセット／基盤）が丸ごと欠落している。本フェーズでこれを補う。

```
main.ts
  └─ import "./styles/tokens.css"   ← ① トークン層（既存・本フェーズで拡張）
        カスタムプロパティの宣言のみ。セレクタを持たない
  └─ import "./styles/base.css"     ← ② 基盤層（★新設）
        リセット + 要素既定スタイル。トークンを参照するため tokens の「後」に読む
           ↓ カスケード
     各 .vue の <style scoped>        ← ③ コンポーネント層（既存）
        トークンを参照するだけ。値を直書きしない
```

**読み込み順序は必須。** `base.css` は `var(--font-md)` 等を参照するため、
`tokens.css` より後に import しないと未定義値になる。

## コンポーネント設計

### 1. `src/styles/base.css`（新設）

**責務**:

- ブラウザ既定スタイルの打ち消し（ボックスモデル・マージン）
- アプリ全体のフォント・行間・文字色・背景色の既定値の提供
- フォーム要素へのフォント継承
- 全要素共通のフォーカスリング（アクセシビリティ）

**実装の要点**:

```css
/* 1. ボックスモデル ------------------------------------------------ */
*,
*::before,
*::after {
  box-sizing: border-box;
}

/* 2. マージンのリセット -------------------------------------------- */
body,
h1, h2, h3, h4, h5, h6,
p, figure, blockquote, dl, dd {
  margin: 0;
}

/* 3. ルート --------------------------------------------------------- */
:root {
  color-scheme: light;      /* ダークモード対応は Phase 3。現状はlight固定を明示 */
}

/* 4. body ----------------------------------------------------------- */
body {
  font-family: var(--font-sans);
  font-size: var(--font-md);
  font-weight: var(--weight-normal);
  line-height: var(--leading-normal);
  color: var(--color-text);
  background-color: var(--color-surface);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* 5. 見出しの既定ウェイト ------------------------------------------- */
h1, h2, h3, h4, h5, h6 {
  font-weight: var(--weight-semibold);
  line-height: var(--leading-tight);
}

/* 6. フォーム要素へのフォント継承（★効果が大きい） ------------------ */
button,
input,
select,
textarea {
  font: inherit;
  color: inherit;
}

/* 7. メディア要素 ---------------------------------------------------- */
img,
svg {
  display: block;
  max-width: 100%;
}

/* 8. フォーカスリング（a11y） --------------------------------------- */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

**技術的な制約・注意点**:

- **`font-family` に外部Webフォントを使わない。** `architecture-overview.md`
  「必要な外部依存: 無し（オフラインでも動作する静的サイト）」に違反するため。
- **`svg { display: block }` は `AppIcon.vue` の縦位置に影響しうる。**
  `AppIcon` は `inline-flex` のコンテナ内でテキストと並ぶ。`display: block` により
  ベースライン揃えが失われる場合があるので、全画面で目視確認すること
  （親側が `align-items: center` を持っていれば問題ない）。
- **見出しのマージンリセットはレイアウトを動かす。** 現在ブラウザ既定の `h2` マージン等に
  依存して余白が成立している箇所があれば、そのコンポーネント側で余白を明示的に補う。

### 2. `src/styles/tokens.css`（拡張）

**責務**: 値の唯一の正本を提供する。

**追加するトークン**:

```css
/* font family */
--font-sans:
  system-ui, -apple-system, "Segoe UI", "Helvetica Neue",
  "Hiragino Sans", "Hiragino Kaku Gothic ProN",
  "Yu Gothic UI", Meiryo, "Noto Sans JP", sans-serif;

/* font weight */
--weight-normal: 400;
--weight-medium: 500;
--weight-semibold: 600;
--weight-bold: 700;

/* line height */
--leading-tight: 1.25;    /* 見出し */
--leading-normal: 1.6;    /* UI・既定 */
--leading-relaxed: 1.8;   /* 読み物（解説文・用語集・クイズ） */
```

**フォントスタックの順序の理由**: 欧文用のシステムフォント（`system-ui` /
`-apple-system` / `Segoe UI`）を先頭に置き、日本語グリフを持つフォントを後ろに続ける。
`system-ui` は Windows では Segoe UI に解決されるが**日本語グリフを持たない**ため、
日本語だけが後続の `Yu Gothic UI` / `Meiryo` へフォールバックし、欧文＝Segoe UI・
和文＝游ゴシックという意図した組み合わせになる。

**変更するトークン（`--font-*` の rem 化）**:

| トークン | 現在 | 変更後 | 実効px | 用途 |
|---|---|---|---|---|
| `--font-xs` | `12px` | `0.75rem` | 12px（変化なし） | 補助テキスト・注記・バッジ |
| `--font-sm` | `13px` | `0.875rem` | **14px**（+1） | ラベル・ナビ・ボタン |
| `--font-md` | `15px` | `1rem` | **16px**（+1） | 本文（既定） |
| `--font-lg` | `18px` | `1.25rem` | **20px**（+2） | カード名・小見出し |
| `--font-xl` | `24px` | `1.5rem` | 24px（変化なし） | セクション見出し |
| `--font-2xl` | `28px` | `2rem` | **32px**（+4） | ページタイトル |

> **rem を使う理由**: ユーザーがブラウザの文字サイズ設定を変更したとき、`px` 固定では
> 拡大されない。`rem` にすることで OS/ブラウザの文字サイズ設定に追随する（a11y 要件）。

**色トークン（`--color-*`）は1つも変更しない。** Phase 2 の担当。

### 3. 各 `.vue` コンポーネント（21ファイル）

**責務**: トークンを参照するだけ。値を直書きしない。

**ウェイト再配分のルール（このフェーズの中核）**:

| 適用先 | トークン | 値 | 想定件数 |
|---|---|---|---|
| ページタイトル（`PageHeader` の `h1`） | `--weight-bold` | 700 | 1 |
| カード名・セクション見出し・スコア等の強調数値 | `--weight-semibold` | 600 | 15前後 |
| ナビリンク・ボタンラベル・バッジ・表ヘッダ | `--weight-medium` | 500 | 25前後 |
| 本文・説明文・注記 | `--weight-normal` | 400 | 残り |

> **`--weight-bold`(700) は5件以下に抑える。** これが「のっぺり感」解消の本体であり、
> 単なる置換作業ではない。**機械的に全部 500 へ置換してはいけない**。各箇所が
> 「見出しか・ラベルか・本文か」を判断して振り分けること。

**行間の割り当て**:

| 適用先 | トークン |
|---|---|
| 見出し（`h1`〜`h6`、カード名） | `--leading-tight` |
| UI要素（ボタン・ラベル・バッジ・表セル） | `--leading-normal` |
| 読ませる文章（優位ポイント・用語説明・クイズ設問・解説） | `--leading-relaxed` |

> 既存の `line-height: 1`（`HalftimeTacticsModal.vue:263` / `QuizQuestionCard.vue:190`）は
> アイコンや閉じるボタンの中央揃え目的と思われる。**トークンに `1` は用意しない。**
> これらは `line-height` を消して Flexbox の `align-items: center` で中央揃えに置き換える
> （`line-height: 1` による中央揃えは、フォント変更で崩れるため）。

**SVG 内の `font-size` 属性は対象外**: `MatchupPitchDiagram.vue` 等の SVG 図形内で
`font-size="7"` のように属性として書かれているものは CSS ではないため、本フェーズでは触らない。

## データフロー

本フェーズはスタイルのみの変更であり、データフロー・状態管理・イベント処理に変更はない。

## エラーハンドリング戦略

該当なし（CSS のみの変更で、実行時エラーが発生する経路を持たない）。

## テスト戦略

### 基準値（2026-09-29 実測）

```
Test Files  34 passed (34)
Tests      535 passed (535)
```

**この 34 / 535 を維持することが回帰の判定基準。**

### 既存テストへの影響予測

`getComputedStyle` で算出値を検証しているテストが存在する。いずれも**レイアウト**の検証で
タイポグラフィではないため、本フェーズでは影響しない想定だが、必ず実行して確認すること。

| ファイル | 検証内容 |
|---|---|
| `src/pages/ComparisonPage.test.ts:237-238` | `flexBasis` が `520px` / `320px` |
| `src/pages/ComparisonPage.test.ts:250` | `maxWidth` が `1400px` |
| `src/pages/FormationListPage.test.ts:123` | `maxWidth` が `1200px` |
| `src/pages/GlossaryPage.test.ts:86` | `@media (min-width: 769px)` の存在 |

> 🚨 **テストが落ちた場合、テストを緩めて通すことは禁止**（`AGENTS.md` / グローバル規約）。
> 実装側の原因を特定して直すか、**仕様変更が正当である根拠を design.md に追記したうえで**
> 期待値を更新すること。`expect(true).toBe(true)` 相当の骨抜きは絶対に行わない。

### 新規テスト

本フェーズで新規テストは追加しない。CSS の算出値検証は jsdom では外部CSSファイルを
解決しないため実効性が低く、`AGENTS.md` の「意味のないアサーションを書かない」原則に反する。
代わりに**受け入れ条件の目視確認**と `grep` による静的検証で担保する。

### 静的検証（受け入れ条件と対応）

```bash
# タイポグラフィの直書きが残っていないこと（いずれも 0 件になること）
grep -rn "font-size: *[0-9]"                 src/ --include=*.vue
grep -rn "font-weight: *\(bold\|normal\|[0-9]\)" src/ --include=*.vue
grep -rn "line-height: *[0-9]"               src/ --include=*.vue

# 700 の使用が 5 件以下であること
grep -rc "var(--weight-bold)" src/ --include=*.vue | grep -v ":0"

# 外部フォントを読み込んでいないこと（0 件になること）
grep -rn "fonts.googleapis\|fonts.gstatic\|@import url" src/ index.html
```

### 目視確認

`npm run dev` で起動し、**全5画面**（一覧 `/` ／比較 `/compare/:a/:b` ／相性表 `/matrix` ／
用語集 `/glossary` ／クイズ `/quiz`）を以下の3幅で確認する。

- 375px（狭小スマホ）／768px（タブレット）／1280px以上（デスクトップ）
- 確認項目: 横スクロールが出ない・要素が重ならない・文字が切れない・
  タップ領域が44pxを下回らない・フォーカスリングが見える

> `20260926-ui-ux-upgrade-v2` の振り返りに「ブラウザ自動操作の `resize_window` が
> 本環境で機能しない」との申し送りがある。**まず `resize_window` が使えるか試し、
> 駄目なら Chrome DevTools のデバイスツールバーで手動確認する**こと。

## 依存ライブラリ

**新規追加なし。** Webフォントパッケージ（`@fontsource/*` 等）も追加しない
（`architecture-overview.md` の「必要な外部依存: 無し」制約による）。

## ディレクトリ構造

```
src/
  main.ts                 # 変更: base.css の import を追加（tokens.css の後）
  styles/
    tokens.css            # 変更: --font-* を rem 化、--font-sans/--weight-*/--leading-* を追加
    base.css              # ★新規: リセット + 要素既定スタイル
  components/*.vue        # 変更: 16ファイル。font-size/weight/line-height をトークンへ
  pages/*.vue             # 変更: 5ファイル。同上
docs/specs/1_requirements/
  repository-structure.md    # 変更: src/styles/ の記載を追加（現在**未記載**）
  requirements-definition.md # 変更: §5 NFR 表にアクセシビリティ要件を追加
docs/specs/2_basic-design/
  screen-design.md           # 変更: 共通事項にタイポグラフィ体系の記述を追加
```

## 実装の順序

**この順序を守ること。** 3 を先に行うと、参照先のトークンが未定義で一時的に壊れる。

1. `tokens.css` にトークンを追加・変更する（`--font-sans` / `--weight-*` / `--leading-*` の追加、`--font-*` の rem 化）
2. `base.css` を新規作成し、`main.ts` から import する
3. **この時点で一度 `npm run dev` を起動し、目視で「フォントが変わったこと」を確認する**
   （ここが本フェーズで最も効果の大きい瞬間。以降の作業が空振りでないことを確かめる）
4. コンポーネントを1ファイルずつ、直書きのタイポグラフィ値をトークンへ置き換える
   （ウェイトは機械置換せず、見出し／ラベル／本文を判断して振り分ける）
5. 静的検証（`grep`）と `npm test` / `lint` / `typecheck` / `build` を通す
6. 全5画面 × 3幅の目視確認
7. ドキュメント3件を更新する

## セキュリティ考慮事項

- **外部フォントCDNを参照しない。** 外部ドメインへの接続は、オフライン動作要件を壊すと同時に、
  閲覧者のIPアドレスが第三者へ渡る経路を新設することになる。本フェーズではシステムフォントのみを使う。
- 本フェーズは静的CSSのみの変更で、ユーザー入力を扱わない。インジェクション経路は生じない。

## パフォーマンス考慮事項

- システムフォントのみを使うため、**Webフォントのダウンロードも FOUT/FOIT も発生しない**。
  レンダリング開始は現状より遅くならない。
- `base.css` は数十行程度で、バンドルサイズへの影響は無視できる。

## 将来の拡張性

- `color-scheme: light` を明示しておくことで、Phase 3 のダークモード対応時に
  `:root[data-theme="dark"]` / `prefers-color-scheme` を追加するだけで済む構造になる。
- `--font-*` を `rem` 化しておくことで、将来「文字サイズ変更UI」を追加する場合も
  `html { font-size: ... }` の1箇所で全体を拡縮できる。

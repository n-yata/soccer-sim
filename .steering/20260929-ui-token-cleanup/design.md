# 設計書

## アーキテクチャ概要

Phase 2 で分離したプリミティブ／セマンティックの2層構造を活かし、
**ダークモードをセマンティック層の再定義だけで実現する**。

```
プリミティブ層（値。ライト/ダークで共通）
  --color-neutral-0 … -900, --color-green-*, --color-blue-*, --color-red-* …
        ↓ ライトでの割り当て            ↓ ダークでの割り当て（★本フェーズで追加）
セマンティック層  :root { }              @media (prefers-color-scheme: dark) { :root { } }
  --color-canvas: neutral-50              --color-canvas: neutral-900
  --color-surface: neutral-0              --color-surface: neutral-800
  --color-text: neutral-900               --color-text: neutral-50
        ↓
コンポーネント層（★セマンティックのみ参照。値を持たない）
```

**この構造が成立する条件は「コンポーネントが値を直書きしていないこと」。**
直書きされた `#ffffff` はダークモードで反転しない。
したがって本フェーズは **「①ハードコード一掃 → ②ダークモード追加」の順序が必須**であり、
逆順にはできない。

## コンポーネント設計

### 1. ハードコード色の一掃（86 + 11 箇所）

**責務**: コンポーネントから生のカラー値を排除する。

**分類と対処方針**:

| 分類 | 例 | 対処 |
|---|---|---|
| A. 既存セマンティックで表せる | カード背景の `#ffffff` | `var(--color-surface)` へ置換 |
| B. セマンティックが不足している | 相性表セルの状態色 | **セマンティックトークンを新設**してから置換 |
| C. 半透明のオーバーレイ | モーダル背景の `rgba(0,0,0,.5)` | `--color-overlay` を新設 |
| D. 影の中の `rgba()` | `--shadow-*` の定義内 | トークン定義内なので**そのままでよい**（正本の側） |
| E. SVG 属性としての色 | `fill="#2563eb"` | 下記「SVG の扱い」を参照 |

> **B に該当する箇所で、安易に `--color-red-500` のようなプリミティブを直接参照しないこと。**
> プリミティブを参照するとダークモードで反転できない。必ず用途名のセマンティックを新設する。

**SVG の扱い（本フェーズで最も設計判断を要する部分）**:

`MatchupPitchDiagram.vue`（12件）・`FreeLayoutPitchDiagram.vue`（11件）・
`RadarChart.vue`（4件）・`FormationMiniPitch.vue`（2件）に色が集中している。
SVG では色を CSS プロパティとしても属性としても書けるため、方針を統一する。

**採用方針: CSS から当てる。**

```vue
<!-- 悪い例: 属性で直書き。CSS変数を参照できずダークモードで反転しない -->
<circle fill="#2563eb" />

<!-- 良い例: クラスを当て、CSS 側でトークンを参照する -->
<circle class="pitch__player pitch__player--team-a" />
```

```css
.pitch__player--team-a {
  fill: var(--color-team-a);
}
```

- `fill` / `stroke` は**CSS プロパティとしても有効**であり、CSS からなら `var()` が使える。
- Vue の動的バインド（`:fill="..."`）で色を渡している箇所は、
  **色ではなくクラス名を動的に切り替える**形へ変更する。
- ピッチの芝生など、要素数が多くクラス付与が冗長になる場合は、
  親要素に `fill: var(--color-pitch)` を当てて**継承**させる（`fill` は継承プロパティ）。

> ⚠️ **`20260926-ui-ux-upgrade-v2` の振り返りにある SVG の落とし穴を再確認すること。**
> 「`<polygon>` の `points`、`<circle>` の `r`/`cx`/`cy` は CSS transition の対象外。
> `r` は SVG2 のジオメトリプロパティだが Safari/iOS が未対応」。
> **`fill`/`stroke` はこの制約とは無関係で、CSS から安全に指定できる**が、
> ジオメトリ系プロパティを CSS へ移そうとはしないこと。

### 2. レイアウトコンテナの統一

**責務**: 全画面で共通の左右基準を提供する。

```css
/* コンテンツ最大幅 */
--width-narrow: 640px;    /* 単一カラムの読み物（クイズ） */
--width-medium: 1000px;   /* 一覧・定義リスト（用語集） */
--width-wide:   1200px;   /* カードグリッド（一覧） */
--width-full:   1400px;   /* 図表を並べる画面（比較・相性表） */

/* 左右ガター */
--gutter: var(--space-2xl);         /* デスクトップ */
--gutter-mobile: var(--space-md);   /* 640px 以下 */
```

**適用のルール**:

- `AppHeader` / `PageHeader` の内側にも**同じ最大幅と同じガター**を適用する。
  現在これらは最大幅を持たず、広い画面で本文と左端がずれる原因になっている。
- 画面ごとに最大幅が違ってよい。ただし**トークンから選ぶ**こと。直書きは禁止。
- ヘッダーは全画面共通コンポーネントであるため、**その画面の本文と同じ幅を使う必要がある**。
  実現方法は実装時に判断すること（有力案: `App.vue` またはルートメタで画面ごとの
  幅トークンを CSS 変数として供給し、ヘッダーがそれを参照する）。

> **2026-10-01 改定**: 上記「画面ごとに最大幅が違ってよい」の判断は撤回した。
> `route.meta.contentWidth` でヘッダーへ幅を供給する仕組みを実装し、一覧=wide(1200px)・
> 比較/相性表=full(1400px)・用語集=medium(1000px)・クイズ=narrow(640px) の4段階を実際に
> 出し分けたが、ユーザーレビューで「画面ごとに横幅が変わる」「相性表だけ左寄せに見える」
> という具体的な指摘を受けた。外枠の幅が画面遷移のたびに変わること自体が
> サイトとしての一貫性のなさとして体感されるため、**外枠（本文ルート要素・ヘッダー）は
> 全画面で `--width-wide`(1200px) に固定**し、`route.meta.contentWidth` と
> `--page-content-width` の仕組みごと削除した。`--width-full`/`--width-medium` は
> 使用箇所が無くなったため `tokens.css` から削除。`--width-narrow` のみ、クイズ画面の
> 読み物カラム（`.quiz-page__column`）という**外枠の内側の部分幅**として残した。
> 相性表(MatrixPage)の表が中央寄せコンテナの中で左寄りに見えた件は、表そのものに
> `margin: 0 auto` が無く、コンテナ幅より狭い表が素直に左詰めで描画されていたことが原因
> だったため、`.matrix-page__table` に `margin: 0 auto` を追加して解消した。
>
> さらに、外枠を`--width-wide`へ統一した後もユーザー実機では「まだ画面によって横幅が
> 数pxずれる」との指摘があった。`getBoundingClientRect()`で実測したところ、
> ページの縦の長さによって縦スクロールバーの有無が切り替わり、
> `document.documentElement.clientWidth`が約15px変動（スクロールバーがあると
> 1905px、無いと1920px @1920px物理幅）していたことが原因だった。`margin:0 auto`の
> 中央寄せはこの可変の基準幅から計算されるため、スクロールバーの有無で左端が
> 約7.5px（スクロールバー幅の半分）ずれていた。`base.css`の`:root`へ
> `scrollbar-gutter: stable`を追加し、スクロールバーの有無に関わらず常にその分の
> 余白を確保することで、全画面で基準幅を固定して解消した（`getBoundingClientRect()`
> による実測で5画面すべて352.5pxに一致することを確認済み）。
>
> **教訓**: レイアウト幅の統一は、スクリーンショットの目視だけでなく
> `getBoundingClientRect()`等による実測で複数画面を横並び比較しないと、
> スクロールバーのような見落としやすい要因による数px単位のずれを検出できない。

### 4. 「モダンに見えない」への対応（2026-10-01追加）

ユーザーレビューで「全体的にモダンじゃない」「最近のトレンドを理解していない」との
指摘を受けた。指摘者の感性を言語化できないまま個人の感覚で装飾（ヒーローのグラデーション、
カードのホバーリフト、大きめの角丸・柔らかい影）を足しても「無難に整えただけ」に
留まる懸念があったため、参照スタイルを**Linear / Vercel系**（ニュートラル基調、
アクセント色は最小限、角丸は小さめ、影はほぼ使わずborderで面を分ける、ホバーは
レイヤーを動かさずcolorのみ変化）に固定し、次のルールを機械的に適用した。

- `--radius-sm/md/lg/xl` を `6/10/16/20px` → `4/6/8/10px` へ縮小。
  丸みの強さ＝カジュアルさの演出に寄りすぎていたため。
- `--shadow-sm/md/lg` の不透明度・ぼかしを大幅に縮小（`shadow-md`は
  `0 2px 8px + 0 1px 2px` → `0 1px 3px`の単純な形へ）。面の境界は影ではなく
  `border: 1px solid var(--color-border)` で示す方針に統一。
- `PageHeader.vue`の`--hero`バリアントから、2方向のradial-gradientによる
  アンビエント演出を撤去。フラットな面のまま、タイポグラフィの大きさだけで強調する。
- `FormationCard.vue`のホバーから`translateY(-4px)` + `shadow-lg`の
  「浮き上がるカード」演出を撤去し、border-colorと背景色の変化だけに統一。

> **注記**: この対応は「見た目の方向性を定量的な参照点（著名プロダクトのスタイル）に
> 固定する」ことで、個人の感覚に依存した堂々巡りを避けるための判断。ユーザーからの
> 明示的な選択（Linear/Vercel系を指定の上で「任せる」）に基づく。

> **除外してよい `max-width`**: `FormationCard.vue` の `120px`（ミニピッチ図の寸法）、
> `HalftimeTacticsModal.vue` の `560px`（モーダル幅）、`ComparisonPage.vue` の
> `800px` / `360px`（コンテンツ内の要素幅）。これらはコンテナ幅ではないため対象外。
> **対象外とした箇所は理由を本ファイルへ追記すること。**

### 3. ブレークポイントの統一

**現状の問題**: `640px` / `480px` / `769px`（`min-width`）が混在。
`tokens.css` には「`@media` には直接使えないため値をコメントとして残す」と書かれているが、
**コメントは強制力を持たないため実際に守られていない**。

**採用方針: 2つに絞り、規約としてドキュメントへ書く。**

| 名前 | 境界 | 用途 |
|---|---|---|
| mobile | `max-width: 640px` | スマートフォン |
| tablet | `max-width: 900px` | タブレット（必要な画面のみ） |

- CSS カスタムプロパティは `@media` の条件式では使えない（仕様上の制約）。
  したがって**値の直書きは避けられない**。これを「トークン化できない」で終わらせず、
  **`screen-design.md` に一覧を書き、そこを正本とする**運用に切り替える。
- `QuizPage.vue` の `480px`、`GlossaryPage.vue` の `min-width: 769px` を上記へ寄せる。
  - `GlossaryPage.test.ts:86` が `min-width: 769px` の存在を検証している。
    **境界を変えるならテストの期待値も併せて更新する**（テストを消すのではなく更新する）。

### 4. ダークモードのセマンティック割り当て

```css
@media (prefers-color-scheme: dark) {
  :root {
    /* 面: ニュートラルを反転。ただし純黒は使わない */
    --color-canvas:        var(--color-neutral-900);
    --color-surface:       var(--color-neutral-800);
    --color-surface-sub:   var(--color-neutral-700);
    --color-surface-hover: var(--color-neutral-700);

    /* 文字: 純白は眩しいため neutral-50 を使う */
    --color-text:       var(--color-neutral-50);
    --color-text-muted: var(--color-neutral-200);
    --color-text-sub:   var(--color-neutral-300);

    /* 境界 */
    --color-border:        var(--color-neutral-700);
    --color-border-strong: var(--color-neutral-600);

    /* ブランド・チーム: 暗背景では彩度の高い色が沈むため、明るい側の階調へ寄せる */
    --color-primary:   var(--color-green-600);
    --color-team-a:    /* 明るい青。実装時に決定し実測する */;
    --color-team-b:    /* 明るい赤。実装時に決定し実測する */;
    /* -bg 系は淡い背景色のため、暗背景では「濃く暗いトーン」へ置き換える */
  }
}
```

**設計上の注意**:

1. **`color-scheme` を更新する。** Phase 1 で `color-scheme: light` を明示してある。
   本フェーズで `light dark` へ変更する。これによりフォームコントロールや
   スクロールバーもダークになる。
2. **純黒（`#000`）・純白（`#fff`）を使わない。** 目が疲れる。`neutral-900` / `neutral-50` を使う。
3. **チームカラーはそのままでは沈む。** `#2563eb`（青）は暗背景で視認性が落ちる。
   より明るい階調をプリミティブ層へ追加して割り当てる。
   **ただし「A＝青 / B＝赤」という対応関係は崩さない**
   （`functional-overview.md`「表示仕様 > カラーコーディング」が正本）。
4. **淡い背景色（`--color-team-a-bg` 等）は反転が単純でない。** ライトでは
   「ほぼ白に近い青」だが、ダークでは「暗い青みがかったグレー」にする必要がある。
   明度を反転させるのではなく、**用途（淡い面）に合う値を選び直す**こと。
5. **影はダークでほぼ見えなくなる。** 暗背景では影よりも**境界線**で階層を示す方が有効。
   `--shadow-*` をダークで弱め、`--color-border` の役割を強める方向で調整する。

## データフロー

スタイルのみの変更であり、データフロー・状態管理・イベント処理に変更はない。
ただし SVG の色指定を「属性の動的バインド」から「クラスの動的切り替え」へ変える箇所では、
**テンプレートの記述が変わる**（ロジックの意味は変えない）。

## エラーハンドリング戦略

該当なし。

## テスト戦略

### 基準値

**Phase 2 完了時点の `npm test` の件数を基準とする。** 着手時に実測して控えること。

### 既存テストへの影響予測

| ファイル | 検証内容 | リスク |
|---|---|---|
| `src/pages/GlossaryPage.test.ts:86` | `@media (min-width: 769px)` の存在 | **高**（ブレークポイント統一で境界値が変わる） |
| `src/pages/ComparisonPage.test.ts:250` | `maxWidth` が `1400px` | **高**（コンテナをトークン化するため） |
| `src/pages/FormationListPage.test.ts:123` | `maxWidth` が `1200px` | **高**（同上） |
| `src/pages/ComparisonPage.test.ts:237-238` | `flexBasis` が `520px` / `320px` | 低 |
| SVG 描画系コンポーネントのテスト | `fill` 属性値の検証があれば影響 | **要確認**（属性 → クラスへ変更するため） |

> 🚨 **テストを緩めて通すことは禁止。**
> 期待値を変える場合は、**変更が仕様として正しい根拠を本ファイルへ追記したうえで**更新する。
> とくに SVG のテストで `fill="#2563eb"` を検証している箇所を、クラス名の検証へ
> 置き換える場合は、**「クラスが付いていれば色が出ている」ことが実際に保証されるか**を
> 確認すること（CSS が別ファイルにある以上、クラス名検証は色の検証にはならない）。
> 保証できないなら、色の検証は目視確認へ移し、その旨を振り返りへ記録する。

### 新規テスト

- ダークモードの算出値検証は jsdom では実効性が低い（外部CSSを解決せず、
  `prefers-color-scheme` のエミュレートも困難）。**自動テストは追加しない。**
- 代わりに**ライト／ダーク両モードでの目視確認とコントラスト実測**で担保する。

### コントラスト比の実測（★必須。ライト／ダーク両方）

Phase 2 と同じ項目を**ダークモードでも**実測し、本ファイル末尾の表へ追記する。
判定基準: 通常文字 4.5:1 以上／大きい文字 3:1 以上。

### 目視確認

全5画面 × 3幅（375 / 768 / 1280以上）× **2モード（ライト／ダーク）**。
ダークモードの切り替えは Chrome DevTools の Rendering パネル
（`Emulate CSS prefers-color-scheme`）で行える。

追加の確認項目:

- [ ] 広い画面（1920px）でヘッダーと本文の左端が揃っている
- [ ] ダークでピッチ図・レーダーチャート・相性表が正しく描画されている
- [ ] ダークでフォーメーションA（青）/ B（赤）が識別できる
- [ ] 色以外の識別手段（チェック印・斜線模様）が両モードで機能している

## 依存ライブラリ

新規追加なし。

## ディレクトリ構造

```
src/
  styles/
    tokens.css        # 変更: 幅トークン・--color-overlay 等を追加。ダーク用の再定義ブロックを追加
    base.css          # 変更: color-scheme を light から "light dark" へ
  components/*.vue    # 変更: 直書き色の置換。SVG は属性 → クラスへ
  pages/*.vue         # 変更: 同上。コンテナ幅をトークンへ
docs/specs/2_basic-design/
  screen-design.md    # 変更: ブレークポイント一覧・コンテナ幅の運用ルールを追記（★ここが正本になる）
docs/specs/1_requirements/
  functional-overview.md  # 変更: 「表示仕様」にダークモードの扱いを追記
```

## 実装の順序

**①→② の順序は必須。逆順にはできない。**

1. **不足しているセマンティックトークンを洗い出し、追加する**
   （直書き 86 件を分類 A〜E に仕分けし、B/C に該当するものを先にトークン化する）
2. CSS の直書き色を置換する（SVG 以外。件数の少ないファイルから）
3. **SVG コンポーネントの色指定を属性からクラスへ移す**
   （`MatchupPitchDiagram` → `FreeLayoutPitchDiagram` → `RadarChart` → `FormationMiniPitch`）
4. `rgba()` 直書きを置換する（`--color-overlay` 等）
5. **静的検証で直書きが 0 件になったことを確認する**（ここがダークモード着手の前提条件）
6. 幅トークンを定義し、コンテナとヘッダーへ適用する
7. ブレークポイントを統一し、`screen-design.md` へ一覧を書く
8. **ダークモードのセマンティック再定義を追加する**
9. ダークで沈む色（チームカラー等）をプリミティブ層に追加して割り当てる
10. ライト／ダーク両モードでコントラストを実測し、AA 違反を修正する
11. `npm test` / `lint` / `typecheck` / `build`
12. 全5画面 × 3幅 × 2モードの目視確認
13. ドキュメント2件を更新する

## セキュリティ考慮事項

- 静的CSS・テンプレートのみの変更で、ユーザー入力を扱わない。
- ドキュメント更新時に実URL・鍵などの機密を記載しないこと。

## パフォーマンス考慮事項

- ダークモードはトークンの再定義のみで、要素数・再描画回数は変わらない。
- SVG の色指定を属性から CSS へ移すと、スタイル解決の対象要素が増えるが、
  本アプリの要素数（1画面あたり数十）では影響しない。

## 将来の拡張性

- 手動のテーマ切り替えUI（本フェーズではスコープ外）を将来追加する場合、
  `:root[data-theme="dark"]` のセレクタをダーク用ブロックに併記しておけば、
  ルート要素に属性を付けるだけで実現できる。**本フェーズで併記しておくことを推奨する**
  （コストがほぼゼロで、後から入れるより安い）。

## ハードコード色の分類結果と追加トークン（2026-10-01実装時に確定）

### 分類結果（実測74件の内訳）

| 値 | 分類 | 対処 | 該当箇所数 |
|---|---|---|---|
| `#ffffff` | A | `var(--color-surface)` | 多数（背景・SVGストローク共通） |
| `#374151` | A | `var(--color-text-muted)`（旧トークン値と一致） | 複数 |
| `#f0fdf4` | A | `var(--color-primary-soft)` | 複数 |
| `#15803d` | A | `var(--color-primary)` | QuizQuestionCard正解表示 |
| `var(--color-border, #e5e7eb)` 等のインラインフォールバック | A | フォールバックを削除し `var(--color-border)` のみに簡素化（tokens.cssが常にロードされるため到達不能な死んだ値） | RadarChart 2件 |
| `#1d4ed8` / `#1e3a5f` | B | チームA強調文字用トークンを新設（下記） | MatrixPage/ComparisonPage/FreeLayoutControls/SquadConditionControls |
| `#b91c1c` / `#5f1e1e` / `#7f1d1d` | B | チームB強調文字・danger系トークンを新設（下記） | 同上 + QuizQuestionCard |
| `#14532d` | B | success系トークンを新設 | QuizQuestionCard正解文字 |
| `#fef3c7` / `#fde68a` / `#d97706` | B | 相性表「未定義」セル専用トークンを新設 | MatrixPage |
| `rgba(15, 23, 42, 0.55)` / `rgba(15, 23, 42, 0)` | C | `--color-overlay` / `--color-overlay-transparent` を新設 | HalftimeTacticsModal |
| `rgba(0, 0, 0, 0.4)`（drop-shadow） | B | `--shadow-token` を新設（SVG選手トークンの影） | MatchupPitchDiagram/FreeLayoutPitchDiagram 各2件 |
| SVGの `fill`/`stroke` 属性直書き | E | フェーズ3で対応（クラス化） | MatchupPitchDiagram/FreeLayoutPitchDiagram/RadarChart/FormationMiniPitch |

### 追加するプリミティブ

```css
/* 青・赤スケールの拡張（既存のblue-600/red-500に追加） */
--color-blue-700: #1d4ed8;
--color-blue-900: #1e3a5f;
--color-red-700: #b91c1c;
--color-red-900: #7f1d1d;
--color-red-900-strong: #5f1e1e; /* 総合判定ボックス専用。red-900とは別値（既存デザインの踏襲） */
--color-green-900: #14532d;

/* 未定義（相性表）用アンバー */
--color-amber-100: #fef3c7;
--color-amber-200: #fde68a;
--color-amber-700: #d97706;
```

### 追加するセマンティック

```css
/* チーム強調文字（チップ・バッジ等、team-*-bg上に置く太字テキスト用） */
--color-team-a-accent-text: var(--color-blue-700);
--color-team-b-accent-text: var(--color-red-700);
/* チーム強調文字（総合判定ボックス等、大きな塗り面に置く文字用） */
--color-team-a-strong-text: var(--color-blue-900);
--color-team-b-strong-text: var(--color-red-900-strong);

/* 成功/危険（チームとは無関係な意味的フィードバック。クイズの正誤表示用）
   値は現状ブランドグリーン/チームBレッドと一致するが、意味が異なるため
   チーム用トークンとは別に持つ（将来チームカラーだけ変更しても連動しない） */
--color-success: var(--color-primary);
--color-success-bg: var(--color-primary-soft);
--color-success-text: var(--color-green-900);
--color-danger: var(--color-red-700);
--color-danger-bg: var(--color-red-50);
--color-danger-text: var(--color-red-900);

/* 相性表「未定義」セル */
--color-undefined-bg: var(--color-amber-100);
--color-undefined-bg-alt: var(--color-amber-200);
--color-undefined-border: var(--color-amber-700);

/* オーバーレイ（モーダル背景） */
--color-overlay: rgba(15, 23, 42, 0.55);
--color-overlay-transparent: rgba(15, 23, 42, 0);

/* SVG要素の小さな影（選手トークン） */
--shadow-token: 0 0.5px 1px rgba(0, 0, 0, 0.4);
```

> `--color-overlay`/`--color-overlay-transparent`はrgb三つ組(15,23,42)を直接埋め込む
> （neutral-900の値と同じ）。CSS変数は`rgba()`の引数内で個別に展開できないため、
> tokens.css側でこの１箇所にのみ直書きし、ここを正本とする（design.mdの分類Dと同じ扱い）。

## jsdomのCSS変数非解決によるテスト期待値の更新（2026-10-01実装時に判明）

`max-width: var(--width-wide)` のようにCSSカスタムプロパティを使った宣言は、**jsdomの
`getComputedStyle`では値が解決されず、`"var(--width-wide)"`という未解決の文字列がそのまま
返る**（実ブラウザでは`"1200px"`等の解決済み値が返る。jsdomの既知の制約）。

`FormationListPage.test.ts`・`ComparisonPage.test.ts`・`GlossaryPage.test.ts`・
`QuizPage.test.ts`に、`max-width`を直書きのpx値（例: `"1200px"`）で検証しているテストが
あり、本フェーズでトークン参照へ置き換えると**文字列が一致せず失敗する**。

**対応方針**: テストを緩めるのではなく、**期待値を「正しいトークン参照を使っているか」の
検証へ更新する**（例: `toBe("1200px")` → `toBe("var(--width-wide)")`）。これは後退ではなく、
むしろ検証の意図がより正確になる——「広い画面幅を活かせるmax-widthを持つ」という元のテスト
意図は、「正しい幅トークンを参照しているか」を検証することで引き続き担保される
（直書きpx値だと、将来トークンの実値を変更したときにテストが追随せず、
トークンから外れた直書き値へ戻っても検知できないという逆向きのリスクがあった）。

対象（実装時に該当テストを更新したら、ここにチェックを入れる）:
- [x] `FormationListPage.test.ts`: `.formation-list-page__body` の `maxWidth` →
      `"var(--width-wide)"` に更新済み
- [x] `ComparisonPage.test.ts`: `.comparison-page__body` の `maxWidth` →
      `"var(--width-full)"` に更新済み
- [x] `GlossaryPage.test.ts`: `max-width`を直接検証するテストは無かったため対象外
- [x] `QuizPage.test.ts`: `max-width`を直接検証するテストは無かったため対象外
- [x] `MatrixPage.test.ts`: `max-width`を直接検証するテストは無かったため対象外
      （design.md作成時点では想定していなかったが、MatrixPageにも本フェーズで
      `--width-full`を新規適用した。既存テストへの影響はなし）

## 対象外とした `max-width` の一覧

| ファイル:行 | 値 | 対象外とした理由 |
|---|---|---|
| `FormationCard.vue:98` | `120px` | ミニピッチ図の固定寸法。コンテナ幅ではなく図形サイズの指定 |
| `HalftimeTacticsModal.vue:196` | `560px` | モーダルダイアログの幅。画面コンテナ幅とは無関係 |
| `ComparisonPage.vue:637` | `800px` | `.comparison-page__pitch-overlay`（flexアイテム）の上限幅。
  flexレイアウト内の個別要素サイズ調整であり、画面全体のコンテナ幅ではない |
| `ComparisonPage.vue:651` | `360px` | `.comparison-page__radar`（flexアイテム）の上限幅。同上 |
| `ComparisonPage.vue:787` | `100%` | モバイル幅での固定幅リセット。相対値（`%`）のためそもそも
  マジックナンバーではなく対象外 |

## コミット前レビューからの申し送り（2026-10-01、review-report.md参照）

- **`--color-surface`を文字色・線色として使っている箇所**: `ComparisonPage.vue`のCTAボタン文字色、
  `QuizPage.vue`のボタン文字色、`HalftimeTacticsModal.vue`、`FormationCard.vue`のバッジ文字色、
  各ピッチ図・`RadarChart.vue`の`stroke`/`fill`で`var(--color-surface)`を使っている。
  現状`--color-surface: #ffffff`なので見た目は等価だが、意味としては「面の色」を
  「面の上に乗る文字・線の色」として流用しており、**Phase 8（ダークモード）で面色を
  暗くすると同時にこれらの文字も暗転して読めなくなる**。Phase 8着手時に
  `--color-text-inverse`（または`--color-on-primary`等）を新設し、置き換えること。
- **コンテナ幅テストの検証力**: `FormationListPage.test.ts`/`ComparisonPage.test.ts`の
  `maxWidth`検証はトークン参照の確認に留まり、トークンの実値（1200px相当であること）は
  検証していない。Phase 8着手前に、トークンの実値を検証する専用テストの追加を検討する。
- **`scrollbar-gutter: stable`の既知の限界**: Safari 18.2未満など非対応ブラウザでは、
  スクロールバー有無によるページ間の左端数pxずれが解消しない。影響は軽微と判断し、
  今回は対応を見送った。

## コントラスト比の実測結果

> 実装時にここへ記入すること（受け入れ条件 4 の証跡）。ライト／ダーク両方。

| モード | 前景 | 背景 | 実測比 | 基準 | 判定 |
|---|---|---|---|---|---|
| （実装時に記入） | | | | | |

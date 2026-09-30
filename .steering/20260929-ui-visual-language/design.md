# 設計書

## アーキテクチャ概要

Phase 1 で作った3層構造（トークン層 → 基盤層 → コンポーネント層）は変えない。
本フェーズは**トークン層の値の入れ替え**を主軸に据え、コンポーネント層は
「トークンを正しく参照するように直す」だけに留める。

```
① トークン層 tokens.css   ← ★ 本フェーズの主戦場。色・影・角丸を再設計
② 基盤層     base.css     ← body の背景色のみ変更（canvas 色へ）
③ コンポーネント層 *.vue   ← 直書きを剥がしてトークン参照へ。装飾の構成を見直す
```

**設計の要点**: セマンティックトークン（`--color-text` のような「用途」の名前）と
プリミティブトークン（`--color-neutral-500` のような「値」の名前）を分ける。
コンポーネントは**セマンティックトークンだけを参照する**。
これにより Phase 3 のダークモード対応は、セマンティック層の再定義だけで済む。

```
プリミティブ                セマンティック              コンポーネント
--color-neutral-900   →   --color-text          →   color: var(--color-text)
--color-neutral-50    →   --color-canvas        →   background: var(--color-canvas)
```

## コンポーネント設計

### 1. `src/styles/tokens.css` — プリミティブ層（新設）

**責務**: 色の生の値を持つ。コンポーネントからは直接参照させない。

```css
/* ---- ニュートラル（構造の主役） ---- */
--color-neutral-0:   #ffffff;
--color-neutral-50:  #f8fafc;
--color-neutral-100: #f1f5f9;
--color-neutral-200: #e2e8f0;
--color-neutral-300: #cbd5e1;
--color-neutral-400: #94a3b8;
--color-neutral-500: #64748b;
--color-neutral-600: #475569;
--color-neutral-700: #334155;
--color-neutral-800: #1e293b;
--color-neutral-900: #0f172a;

/* ---- ブランド（アクセントに限定） ---- */
--color-green-600: #16a34a;
--color-green-700: #15803d;   /* 既存 --color-primary と同値。維持 */
--color-green-800: #166534;
--color-green-50:  #f0fdf4;

/* ---- アクセント（選択状態。彩度を落とす） ---- */
--color-orange-700: #c2410c;  /* 旧 #ff6b35 から変更。ネオン感を除去 */
--color-orange-50:  #fff7ed;

/* ---- チームカラー（情報色。値は変更しない） ---- */
--color-blue-600: #2563eb;    /* フォーメーションA */
--color-blue-50:  #eff6ff;
--color-red-500:  #ef4444;    /* フォーメーションB */
--color-red-50:   #fef2f2;
```

### 2. `src/styles/tokens.css` — セマンティック層

**責務**: 用途名で色を提供する。**コンポーネントが参照してよいのはここだけ。**

```css
/* 面 */
--color-canvas:        var(--color-neutral-50);   /* ページ背景（★白から変更） */
--color-surface:       var(--color-neutral-0);    /* カード・パネル */
--color-surface-sub:   var(--color-neutral-100);  /* 表ヘッダ・くぼんだ面 */
--color-surface-hover: var(--color-neutral-100);

/* 文字 */
--color-text:       var(--color-neutral-900);
--color-text-muted: var(--color-neutral-700);
--color-text-sub:   var(--color-neutral-600);     /* ★AA を満たす値へ引き上げ */

/* 境界 */
--color-border:        var(--color-neutral-200);
--color-border-strong: var(--color-neutral-300);

/* ブランド・状態 */
--color-primary:      var(--color-green-700);
--color-primary-soft: var(--color-green-50);
--color-accent:       var(--color-orange-700);
--color-accent-bg:    var(--color-orange-50);

/* チーム（情報色。functional-overview.md の正本） */
--color-team-a:    var(--color-blue-600);
--color-team-a-bg: var(--color-blue-50);
--color-team-b:    var(--color-red-500);
--color-team-b-bg: var(--color-red-50);
```

> 🚨 **`--color-text-sub` は現行 `#6b7280`（白背景で約 4.8:1）から
> `#475569` へ引き上げる。** 現行値は AA の 4.5:1 をかろうじて超えるだけで、
> 背景をわずかでも濃くすると即座に割る。`--color-canvas` を白から `#f8fafc` へ
> 変える本フェーズでは危険なため、余裕のある値へ移す。

> 🚨 **`--color-primary-end`（`#115e59`）は削除する。** グラデーション専用の
> トークンであり、グラデーション廃止に伴って参照元がなくなる。
> **削除前に `grep -rn "color-primary-end" src/` で残参照が 0 件であることを確認すること。**

### 3. 影・角丸トークン

```css
/* 段差（3段階） */
--shadow-sm: 0 1px 2px rgba(15, 23, 42, 0.06);
--shadow-md:
  0 2px 8px rgba(15, 23, 42, 0.08),
  0 1px 2px rgba(15, 23, 42, 0.04);
--shadow-lg: 0 12px 32px rgba(15, 23, 42, 0.12);

/* 角丸（3段階 + pill） */
--radius-sm: 6px;    /* バッジ・小ボタン */
--radius-md: 10px;   /* ボタン・入力・表セル */
--radius-lg: 16px;   /* カード・パネル・モーダル */
--radius-pill: 999px;
```

**用途の対応**:

| トークン | 用途 |
|---|---|
| `--shadow-sm` | 地に接している要素（表ヘッダ・チップ） |
| `--shadow-md` | カード・パネル（既定） |
| `--shadow-lg` | 浮遊物（モーダル `HalftimeTacticsModal` ・ポップオーバー `TermPopover`） |

> **`--shadow-card` と `--radius-card` は廃止する。** それぞれ `--shadow-md` /
> `--radius-lg` へ置き換える。`--shadow-card` は17箇所、`--radius-card` も複数箇所から
> 参照されているため、**置換漏れがないか grep で確認すること**。

### 4. `src/components/PageHeader.vue` — グラデーション廃止

**責務**: 変更なし（タイトル・サブタイトル・戻るボタン・アクションスロット）。

**実装の要点**:

| 項目 | 現在 | 変更後 |
|---|---|---|
| 背景 | `linear-gradient(90deg, #15803d, #115e59)` | `var(--color-surface)` |
| 下境界 | なし | `1px solid var(--color-border)` |
| タイトル色 | `#ffffff` | `var(--color-text)` |
| サブタイトル | `#ffffff` + `text-shadow` | `var(--color-text-sub)`、`text-shadow` は**削除** |
| タイトルサイズ | `--font-2xl` | `--font-2xl`（Phase 1 で 32px 化済み。維持） |

**連鎖する変更（見落としやすい）**:

- `BackButton.vue` はヘッダー上の白文字前提の配色になっている可能性がある。**必ず確認する。**
- `FormationListPage.vue` の J リーグ外部リンクは
  `border: 1px dashed rgba(255,255,255,0.6)` / `color: #ffffff` で、**背景が白になると
  完全に見えなくなる**。通常のテキスト色・境界色へ変更すること。
- `PageHeader.vue` のコメントにある「白文字とのコントラストのために `--color-primary` を
  暗めにしている」という設計理由は**失効する**。コメントも併せて更新すること。

### 5. `src/components/FormationCard.vue` — 選択表現の変更

| 項目 | 現在 | 変更後 |
|---|---|---|
| 枠線 | `3px solid var(--color-border)` | `1px solid var(--color-border)` |
| 角丸 | `--radius-card` | `--radius-lg` |
| 影 | `--shadow-card` | `--shadow-md` |
| 選択時 | 枠色をオレンジへ＋背景 `#fff4ec`＋文字色 `#b44712` | 枠色 `--color-accent` ＋ `box-shadow: 0 0 0 2px var(--color-accent)` のリング ＋ 背景 `--color-accent-bg`。**文字色は変えない** |
| ホバー | `translateY(-2px)` ＋ 影強調 | `--shadow-lg` への影変化のみ（移動をやめる） |

> **選択時に文字色を変えていたのは、太い枠＋濃い背景に対する調整だった。**
> 背景を淡いトーンに留めれば文字色は `--color-text` のままで AA を満たせる。
> ただし**実測して確認すること**。

> ⚠️ `20260911-ui-redesign-sporty` の振り返りに記録されたレイアウトジャンプの再発に注意。
> 枠線幅を状態で変えるとカードの寸法が変わる。**リングは `box-shadow` で表現し、
> `border-width` は状態によらず 1px で固定する**（`box-shadow` はフロー幅に影響しない）。

### 6. 各画面の装飾見直し

| 対象 | 変更内容 |
|---|---|
| `FormationListPage.vue` フッター注記 | `font-style: italic` を**削除**。`--color-primary-soft` 背景の控えめなチップへ |
| `FormationListPage.vue` Jリーグリンク | 白前提の配色を通常配色へ（上記4参照） |
| `ComparisonPage.vue` 総合判定 | チームカラーのグラデーションカード → 単色の淡い背景＋左端のカラーバーで所属を示す |
| `ComparisonPage.vue` 優位ポイント | 太い色枠のカード → 1px境界＋見出しのみチームカラー |
| `MatrixPage.vue` セル | 彩度を落とし、`--color-*-bg` 系の淡いトーンで塗る。凡例も追随 |
| `MatchupPitchDiagram.vue` | 芝生グラデーション・ストライプの強度を下げる（緑自体は維持） |
| `HalftimeTacticsModal.vue` | 影を `--shadow-lg` へ |
| `TermPopover.vue` | 影を `--shadow-lg` へ |

## データフロー

本フェーズはスタイルのみの変更であり、データフロー・状態管理・イベント処理に変更はない。

## エラーハンドリング戦略

該当なし（CSS のみの変更）。

## テスト戦略

### 基準値

**Phase 1 完了時点の `npm test` の件数を基準とする**（Phase 1 の基準は 34ファイル / 535テスト）。
着手時に自分で実測し、ズレていたらシャビに報告すること。

### 既存テストへの影響予測

Phase 1 と異なり、**本フェーズはレイアウトに影響する変更を含むため、
算出値を検証しているテストが落ちる可能性が高い**。

| ファイル | 検証内容 | リスク |
|---|---|---|
| `src/pages/ComparisonPage.test.ts:237-238` | `flexBasis` が `520px` / `320px` | 中 |
| `src/pages/ComparisonPage.test.ts:250` | `maxWidth` が `1400px` | 中 |
| `src/pages/FormationListPage.test.ts:123` | `maxWidth` が `1200px` | 中 |
| `src/pages/GlossaryPage.test.ts:86` | `@media (min-width: 769px)` の存在 | 低 |
| `src/components/FormationCard.test.ts` | `classes()` による選択状態の検証 | **高**（選択表現を変更するため） |

> 🚨 **テストを緩めて通すことは禁止。** 選択状態の表現方法を変えた結果として
> 期待値が変わる場合は、**何をどう変えたから期待値がこう変わるのかを design.md に追記し、
> 振る舞いとして正しいことを確認したうえで**期待値を更新する。
> クラス名の検証が実態を検証しなくなる（例: クラスは付くが見た目が変わらない）状態にはしない。

### コントラスト比の実測（★必須）

**目視判断は不可。** 変更したすべての「文字色 × 背景色」の組み合わせについて、
Chrome DevTools の Inspect（要素のカラーピッカーにコントラスト比が表示される）か
同等のツールで実測し、結果を `design.md` の末尾へ表として追記すること。

最低限、以下は必ず実測する。

- `--color-text` × `--color-canvas`
- `--color-text` × `--color-surface`
- `--color-text-sub` × `--color-surface`（本フェーズで値を引き上げる箇所）
- `--color-text-sub` × `--color-canvas`
- ページヘッダーのタイトル・サブタイトル（白文字から変わるため全画面）
- 選択中カードの文字 × `--color-accent-bg`
- 相性表の各セル（行有利／列有利／互角／未定義）の文字 × 背景
- チームA/B見出しの文字 × 各 `-bg`

判定基準: 通常文字 **4.5:1 以上**、大きい文字（24px以上、または19px以上かつ太字）**3:1 以上**。

### 目視確認

Phase 1 と同じ（全5画面 × 375px / 768px / デスクトップ幅）。加えて本フェーズでは:

- [ ] 色だけに頼った情報伝達がないこと（相性表のチェック印など、色以外の手段が残っていること）
- [ ] `prefers-reduced-motion` 有効時にアニメーションが無効化されること（退行確認）

## 依存ライブラリ

新規追加なし。

## ディレクトリ構造

```
src/
  styles/
    tokens.css          # 変更: プリミティブ層/セマンティック層へ再編。影・角丸も再設計
    base.css            # 変更: body の背景を --color-canvas へ
  components/
    PageHeader.vue      # 変更: グラデーション廃止（★連鎖影響が大きい）
    BackButton.vue      # 変更: 白背景前提への追随
    FormationCard.vue   # 変更: 枠線・選択表現・ホバー
    MatchupPitchDiagram.vue   # 変更: 芝生装飾の強度
    HalftimeTacticsModal.vue  # 変更: 影
    TermPopover.vue           # 変更: 影
    （その他、--shadow-card / --radius-card を参照している全コンポーネント）
  pages/
    FormationListPage.vue  # 変更: フッター注記・Jリーグリンク
    ComparisonPage.vue     # 変更: 総合判定・優位ポイント
    MatrixPage.vue         # 変更: セル配色・凡例
    GlossaryPage.vue       # 変更: カード
    QuizPage.vue           # 変更: 設問カード
docs/specs/1_requirements/
  functional-overview.md   # 変更: 「表示仕様」を実装に合わせる
docs/specs/2_basic-design/
  screen-design.md         # 変更: 全5画面のレイアウト記述（★記述量が多い）
  wireframes.drawio        # 変更: ワイヤーフレーム（★下記の注意を必読）
```

## 実装の順序

1. **トークン層を再設計する**（プリミティブ層 → セマンティック層 → 影・角丸）
2. `base.css` の `body` 背景を `--color-canvas` へ変更する
3. **この時点で全5画面を目視する。** カードが面として浮いて見えることを確認する
4. `PageHeader.vue` のグラデーションを廃止し、**連鎖する `BackButton` ・
   Jリーグリンクの配色崩れをその場で直す**
5. `FormationCard.vue` の枠線・選択表現を変更する（レイアウトジャンプに注意）
6. `--shadow-card` / `--radius-card` の参照を全ファイルで置換し、旧トークンを削除する
7. 各画面の装飾を1画面ずつ見直す（一覧 → 比較 → 相性表 → 用語集 → クイズ）
8. **コントラスト比を全変更箇所で実測**し、AA を割る箇所を修正する
9. `npm test` / `lint` / `typecheck` / `build`
10. 全5画面 × 3幅の目視確認
11. ドキュメント3件を更新する（`wireframes.drawio` は最後。下記注意を必読）

## drawio 更新時の注意（過去に事故が起きている）

`.steering/20260911-ui-redesign-sporty/retrospective.md` に記録された失敗を繰り返さないこと。

1. **`import-diagram` の `add` モードでテスト用の簡略データを送ると、それが本番データとして
   残る。** 実際に `note` セル（実装コンポーネントへの参照）が欠落したままファイル化された。
   **小分けに試さず、完成版を1回で送る**か、**送信後に必ず export して内容を検証する**。
2. **既存ページを壊していないか確認する。** 過去に旧ページの内容を欠落させ、
   `git show HEAD:<path>` から復元する羽目になっている。更新後は
   `git diff` で意図しないページが変更されていないことを確認すること。
3. **`git worktree` はコミット済みの状態から分岐する。** main 側の作業ツリーに
   未コミットの drawio 変更が残っていても worktree には引き継がれない。

## セキュリティ考慮事項

- 本フェーズは静的CSSと設計ドキュメントのみの変更で、ユーザー入力を扱わない。
- ドキュメント更新時、実URL・鍵などの機密を記載しないこと（プレースホルダを使う）。

## パフォーマンス考慮事項

- グラデーションを廃止し単色塗りにするため、描画コストはわずかに下がる。
- 影を3段階へ増やすが、同時に描画される要素数は変わらないため影響は無視できる。

## 将来の拡張性

- プリミティブ層とセマンティック層を分離することで、Phase 3 のダークモード対応は
  **セマンティック層の再定義のみ**で完結する（プリミティブ層とコンポーネント層は無変更）。
  これが本フェーズで層を分ける最大の理由である。

## コントラスト比の実測結果

2026-10-01 実測。WCAG 2.1のsRGB相対輝度式で算出（`(L1+0.05)/(L2+0.05)`）。
実測は claude-in-chrome の `javascript_tool` でブラウザ上のJSとして計算式を実行し、
実際の16進カラー値（`getComputedStyle`で確認した実効値含む）を入力した。

| 前景 | 背景 | 実測比 | 基準 | 判定 |
|---|---|---|---|---|
| `--color-text`(#0f172a) | `--color-canvas`(#f8fafc) | 17.06:1 | 4.5:1 | ✅ |
| `--color-text`(#0f172a) | `--color-surface`(#ffffff) | 17.85:1 | 4.5:1 | ✅ |
| `--color-text-sub`(#475569) | `--color-surface`(#ffffff) | 7.58:1 | 4.5:1 | ✅ |
| `--color-text-sub`(#475569) | `--color-canvas`(#f8fafc) | 7.24:1 | 4.5:1 | ✅ |
| ページヘッダー タイトル（`--color-text`）× `--color-surface` | | 17.85:1 | 4.5:1 | ✅（全5画面で同一配色） |
| ページヘッダー サブタイトル（`--color-text-sub`）× `--color-surface` | | 7.58:1 | 4.5:1 | ✅（全5画面で同一配色） |
| 選択中カードの文字（`--color-text`）| `--color-accent-bg`(#fff7ed) | 16.81:1 | 4.5:1 | ✅ |
| 相性表セル 行有利 文字(#1d4ed8) | `--color-team-a-bg`(#eff6ff) | 6.16:1 | 4.5:1 | ✅ |
| 相性表セル 列有利 文字(#b91c1c) | `--color-team-b-bg`(#fef2f2) | 5.91:1 | 4.5:1 | ✅ |
| 相性表セル 互角 文字（`--color-text-sub`）| `--color-surface-sub`(#f1f5f9) | 6.92:1 | 4.5:1 | ✅ |
| 凡例 行が有利 文字(#1d4ed8) | `--color-team-a-bg` | 6.16:1 | 4.5:1 | ✅（相性表セルと同色） |
| 凡例 列が有利 文字(#b91c1c) | `--color-team-b-bg` | 5.91:1 | 4.5:1 | ✅（相性表セルと同色） |
| チームA見出し文字（`--color-team-a` #2563eb）| `--color-surface`(#ffffff) | 5.17:1 | 4.5:1 | ✅ |
| チームB見出し文字（`--color-team-b` #ef4444）| `--color-surface`(#ffffff) | 3.76:1 | ★3:1（大きい文字） | ✅ **実測font-size:24px, font-weight:600を`getComputedStyle`で確認済み。WCAGの「大きい文字」定義（24px以上は太字不問）に該当するため3:1基準を適用し合格** |

### 判定できなかった／対象外とした組み合わせ

- `--color-accent`(#c2410c) をテキスト色として使っている箇所は**実装上存在しない**
  （`--color-accent`は選択中カードの`border-color`としてのみ使用。テキスト色は
  `--color-text`のまま変更していないため、実測対象から除外した）。
- ダークモードは Phase 3 のスコープのため本フェーズでは未実測。

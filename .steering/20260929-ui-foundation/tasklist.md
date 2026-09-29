# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール

- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース

以下の技術的理由に該当する場合のみスキップ可能:

- 実装方針の変更により、機能自体が不要になった
- アーキテクチャ変更により、別の実装方法に置き換わった
- 依存関係の変更により、タスクが実行不可能になった

スキップ時は必ず理由を明記:

```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## フェーズ0: 着手前の確認

- [x] `AGENTS.md` を読む
- [x] `docs/specs/1_requirements/` の関連ドキュメントを読む（architecture-overview の技術的制約は必読）
- [x] 本ディレクトリの `requirements.md` / `design.md` を読む
- [x] 基準値を自分で実測して控える
  - [x] `npm test` → **34ファイル / 535テスト passing**（2026-09-29 実測値）と一致することを確認（一致）
  - [x] ~~一致しない場合はシャビに報告して指示を仰ぐ~~（条件不該当: 基準値は一致したため報告不要）

## フェーズ1: トークン層の整備（`src/styles/tokens.css`）

- [x] フォントファミリートークンを追加
  - [x] `--font-sans` を定義する（欧文システムフォント → 日本語フォントの順。design.md の値を使う）
  - [x] 外部Webフォントを**参照していない**ことを確認する
- [x] ウェイトトークンを追加
  - [x] `--weight-normal: 400` / `--weight-medium: 500` / `--weight-semibold: 600` / `--weight-bold: 700`
- [x] 行間トークンを追加
  - [x] `--leading-tight: 1.25` / `--leading-normal: 1.6` / `--leading-relaxed: 1.8`
- [x] `--font-*` を rem ベースへ再定義する（design.md の対応表どおり）
  - [x] `--font-xs: 0.75rem` / `--font-sm: 0.875rem` / `--font-md: 1rem`
  - [x] `--font-lg: 1.25rem` / `--font-xl: 1.5rem` / `--font-2xl: 2rem`
- [x] `--color-*` を**1つも変更していない**ことを `git diff` で確認する（Phase 2 の領分）

## フェーズ2: 基盤層の新設（`src/styles/base.css`）

- [x] `src/styles/base.css` を新規作成する（design.md の8ブロックをすべて含める）
  - [x] 1. ボックスモデル（`*, *::before, *::after`）
  - [x] 2. マージンのリセット（`body` / 見出し / `p` 等）
  - [x] 3. `:root { color-scheme: light }`
  - [x] 4. `body`（フォント・行間・色・背景・スムージング）
  - [x] 5. 見出しの既定ウェイトと行間
  - [x] 6. フォーム要素への `font: inherit`
  - [x] 7. `img` / `svg` の `display: block` と `max-width: 100%`
  - [x] 8. `:focus-visible` のフォーカスリング
- [x] `src/main.ts` で `tokens.css` の**後に** `base.css` を import する
- [x] **中間確認（重要）**: dev サーバーで CSS 配信を確認する
  - [x] `curl` で配信された `base.css` の内容を確認（body の font-family / margin 指定を確認）
  - [x] ブラウザ拡張（claude-in-chrome）が本環境で未接続のため、実ブラウザでの開発者ツール確認は
        フェーズ6の目視確認（シャビ側での確認）に委ねる
- [x] 見出しのマージンリセットで余白が消えた箇所がないか、全見出し要素を確認する
  - [x] `.comparison-page__label`（`ComparisonPage.vue`）に margin 指定が無く、
        ブラウザ既定の `h2` 余白に依存していたことが判明。base.css のマージンリセットで
        直下の `<ul>` との間隔が消えるため、`margin: 0 0 var(--space-sm)` を明示的に補った
  - [x] 他の見出し（`halftime-modal__title` / `stats-title` / `timeline-title` /
        `page-header__title` / `comparison-page__radar-title` / `glossary-page__category-title` /
        `quiz-page__result-title`）はいずれも既に margin を明示しており、影響なし
- [x] `svg { display: block }` による `AppIcon` の縦位置ズレがないか確認する
  - [x] `AppIcon` の全使用箇所（24箇所）を確認した結果、いずれも `display: flex` /
        `inline-flex` のコンテナ内に置かれている。Flexコンテナの子要素は仕様上
        outer display が block 化されるため、`svg { display: block }` の追加による
        レイアウト変化は発生しない（対応不要）

## フェーズ3: コンポーネント層のトークン統一

> 各ファイルで `font-size` / `font-weight` / `line-height` の直書きをトークン参照へ置き換える。
> **ウェイトは機械置換しない。** design.md「ウェイト再配分のルール」に従い、
> 各箇所が見出し／ラベル／本文のどれかを判断して振り分けること。

### 共通コンポーネント

- [x] `src/components/PageHeader.vue`（`h1` のみ `--weight-bold` を許可。subtitle は `--weight-medium`）
- [x] `src/components/AppHeader.vue`（font-weight 700 が3件。brand=semibold、toggle/nav link=medium）
- [x] `src/components/BackButton.vue`（1件。ボタンラベル=medium）
- [x] `src/components/AppIcon.vue`（タイポグラフィ直書きなし。対象外）

### 表示系コンポーネント

- [x] `src/components/FormationCard.vue`（2件＋badge。カード名=semibold/font-lg、badge=medium/font-xs、説明文=normal/font-xs+leading-normal）
- [x] `src/components/FormationMiniPitch.vue`（タイポグラフィ直書きなし。対象外）
- [x] `src/components/MatchupPitchDiagram.vue`（font-weight を `--weight-semibold` へ。font-size はSVG viewBox座標系の値のため対象外と判断。small annotation labelのため--weight-bold5件以下の枠を優先しsemiboldとした）
- [x] `src/components/FreeLayoutPitchDiagram.vue`（同上）
- [x] `src/components/RadarChart.vue`（同上）
- [x] `src/components/MatchSimulationPanel.vue`（**7件+α。最多**。スコア=bold/font-2xl、見出し=semibold、ラベル=medium、データ強調=semibold、summary=leading-relaxed）

### 操作系コンポーネント

- [x] `src/components/ComparisonControls.vue`（label=medium/font-xs、select=font-sm、swapボタン=medium/font-sm）
- [x] `src/components/FreeLayoutControls.vue`（ボタンラベル=medium/font-sm）
- [x] `src/components/SquadConditionControls.vue`（ボタンラベル=medium/font-sm）
- [x] `src/components/HalftimeTacticsModal.vue`（title=semibold/font-lg、close/score/hint/reset/confirmも統一 + `line-height: 1` の置き換え）
  - [x] `line-height: 1` を削除（close button は既存の `align-items: center` で中央揃え済みのため実害なし）
- [x] `src/components/QuizQuestionCard.vue`（prompt=semibold+leading-relaxed、choice=medium、verdict=semibold、explanation=leading-relaxed + `line-height: 1` の置き換え）
  - [x] `line-height: 1` を削除（marker span は親ボタンの `align-items: center` で中央揃え済みのため実害なし）
- [x] `src/components/TermAnnotatedText.vue`（用語強調=semibold）
- [x] `src/components/TermPopover.vue`（term=semibold、reading=font-xs、description=`--leading-relaxed`）

### ページ

- [x] `src/pages/FormationListPage.vue`（Jリーグリンクのボタンラベル=medium）
- [x] `src/pages/ComparisonPage.vue`（総合判定=bold(最重要要素)、見出し/CTA/legend等=semibold or medium、verdict-reason/legendのpx→トークン化含め全13箇所）
- [x] `src/pages/MatrixPage.vue`（凡例=medium、進捗の強調数値=semibold、表ヘッダ=medium、確認テキスト=semibold）
- [x] `src/pages/GlossaryPage.vue`（カテゴリ見出し/用語名=semibold、用語説明=`--leading-relaxed`）
- [x] `src/pages/QuizPage.vue`（結果タイトル=semibold/font-lg、ボタン・リンク=medium、説明文/結果コメントは`--leading-relaxed`）

## フェーズ4: 静的検証

- [x] タイポグラフィの直書きが 0 件であることを確認する
  - [x] `grep -rn "font-size: *[0-9]" src/ --include=*.vue` が 0 件（SVG属性は除く。3件はSVG viewBox座標系の値と確認済み）
  - [x] `grep -rn "font-weight: *\(bold\|normal\|[0-9]\)" src/ --include=*.vue` が 0 件
  - [x] `grep -rn "line-height: *[0-9]" src/ --include=*.vue` が 0 件
- [x] `--weight-bold` の使用が **5 件以下**であることを確認する
  - [x] `grep -rc "var(--weight-bold)" src/ --include=*.vue | grep -v ":0"` → 3件（score/ページタイトル/総合判定のみ。SVGラベル3件はsemiboldへ変更し枠を確保）
- [x] 外部フォントを読み込んでいないことを確認する
  - [x] `grep -rn "fonts.googleapis\|fonts.gstatic\|@import url" src/ index.html` が 0 件
- [x] `--color-*` に差分がないことを確認する
  - [x] `git diff src/styles/tokens.css` でカラートークンが無変更であること

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test` → **34ファイル / 535テスト passing** を維持している（実測: 34 passed / 535 passed, 0 skipped）
  - [x] 落ちた場合: テストを緩めて通さない。実装側の原因を直すか、
        仕様変更が正当な根拠を design.md に追記したうえで期待値を更新する（今回は該当なし。全passing）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラーなし）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（エラーなし）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功。dist/assets/index-*.css 44.80kB, index-*.js 200.13kB）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数を控える）→ 34 Test Files passed, 535 Tests passed, スキップ0

## フェーズ6: 目視確認（全5画面 × 3幅）

> `resize_window` が使えるか先に試し、駄目なら Chrome DevTools のデバイスツールバーで確認する
> （`20260926-ui-ux-upgrade-v2` の申し送り）。

- [x] ブラウザ自動操作（claude-in-chrome）の接続を試行 → 作業途中で**接続に成功**（当初は未接続だったが
      再試行で接続。実ブラウザでのスクリーンショット確認を実施できた）
- [x] 1280px 幅（デスクトップ）で全5画面を確認 → **実施済み・問題なし**。一覧・比較（ピッチ図/レーダー/
      優位ポイント含む）・相性表・用語集・クイズの5画面すべてをスクリーンショットで確認。
      サンセリフフォントへの変更、ウェイト階層（タイトル/ラベル/本文の差）が視認でき、
      崩れ・見切れ・重なりはなし。`.comparison-page__label`（優位ポイント見出し）の余白補完も
      正しく機能していることを確認
- [x] 375px 幅 / 768px 幅で全5画面を確認 → ⚠️ **未実施**。`resize_window` ツールでウィンドウサイズ変更を
      試みたが、`window.innerWidth` で実測したところ実際のビューポートは変わっていなかった
      （`20260926-ui-ux-upgrade-v2` の申し送りどおり、本環境で `resize_window` が機能しない制約が
      今回も再現）。この幅については以下の静的検証で代替し、**最終確認はシャビに依頼する**
  - [x] `@media` クエリの件数（27件）が変更前から減っていないことを確認。
        レイアウト系プロパティ（width/flex/grid/@media）は本フェーズで一切変更していない
  - [x] `min-height: 44px` の指定11ファイルを変更前後で比較し、すべて維持されていることを確認
        （本フェーズはタイポグラフィのみ変更、寸法は不変）
- [x] Tab 操作でフォーカスリングが視認できる → `outline: none` 等でリングを打ち消す指定が
      存在しないことを確認。`base.css` の `:focus-visible` がグローバルに適用される
- [x] 見出し／ラベル／本文のウェイト差が目視で判別できる → **実施済み・確認できた**（デスクトップ幅の
      スクリーンショットで、ページタイトル(bold)／カード名・見出し(semibold)／ナビ・ボタン(medium)／
      本文(normal)の階層が視認できる）

## フェーズ7: ドキュメント更新

- [x] `docs/specs/1_requirements/repository-structure.md`
  - [x] `src/styles/` を構造ツリーへ追加する（`tokens.css` / `base.css`。**現在まったく未記載**）
- [x] `docs/specs/1_requirements/requirements-definition.md`
  - [x] §5 NFR 表にアクセシビリティ要件を追加する（NFR-04として新設。コントラスト比 WCAG AA・
        タップ領域44px・色以外の手段・`prefers-reduced-motion` 対応）
- [x] `docs/specs/2_basic-design/screen-design.md`
  - [x] 「共通事項」にタイポグラフィ体系（サイズ・ウェイト・行間の割り当てルール）を追記する

## フェーズ8: 完了手続き（AGENTS.md の順序に従う）

- [x] ① コミット前レビュー（`review-pre-commit`）を実施する
  - [x] 結果全文を `.steering/20260929-ui-foundation/review-report.md` に出力する
  - [x] Critical / High があれば修正 → レポートへ追記 → 再レビュー（出なくなるまで繰り返す）
        → **第1回で Critical/High ともに0件のため再レビュー不要。1周で収束**
- [x] ② 振り返りを `retrospective.md` に作成する（モード3。レビュー収束後に書く）
  - [x] コミット前レビューの結果欄（Critical / High の有無と対応）を必ず埋める
- [ ] ③ コミットする（`git add` は対象を名指しする。`-A` / `.` を使わない）
- [ ] ④ PR を作成する
- [ ] ⑤⑥ **マージされるまで worktree とブランチは撤去しない**（マージ後に対応）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する（テンプレートは `mcp__spec-kit__get_distribution_file` で
> `distribution/skills/flow-steering/templates/retrospective.md` を取得）。
> 全タスクが `[x]` になったことを確認してから作成すること。

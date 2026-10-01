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

## フェーズ0: 着手前の確認（★ゲートあり）

- [x] **Phase 2（`feature/ui-visual-language`）がマージ済みであることを確認する**
      → PR #2、squashマージ済み（`master`@fb99ff3）。追って`wireframes.drawio`追従修正も
      `master`@34b5956で反映済み
- [x] `AGENTS.md` と `docs/specs/1_requirements/` の関連ドキュメントを読む
- [x] `.steering/20260926-ui-ux-upgrade-v2/retrospective.md` を読む（SVGプロパティの落とし穴。
      `<polygon>`の`points`・`<circle>`の`r`/`cx`/`cy`はCSS transition対象外、
      `prefers-reduced-motion`打ち消しブロックは`<style>`末尾に置く、を確認）
- [x] 基準値を実測して控える（`npm test` の件数）→ **34ファイル / 535テスト passing**
      （Phase 1・2と同一。並列実行はメモリ不足で落ちるため
      `npx vitest run --pool=forks --no-file-parallelism` を使用）
- [x] 直書き色の現在件数を実測して控える → **design.md作成時(86+11件)からPhase2の副次効果で
      ドリフトしている。実測値（2026-10-01時点）を正とする**
  - [x] `grep -rco "#[0-9a-fA-F]\{3,8\}" src/ --include=*.vue | grep -v ":0"` → **合計74件**
        （内訳: MatchupPitchDiagram 13, QuizQuestionCard 12, FreeLayoutPitchDiagram 12,
        MatrixPage 6, ComparisonPage 6, RadarChart 4, HalftimeTacticsModal 4,
        SquadConditionControls 3, FreeLayoutControls 3, ComparisonControls 3,
        TermPopover 2, MatchSimulationPanel 2, FormationMiniPitch 2, QuizPage 1,
        TermAnnotatedText 1。PageHeader/FormationListPageはPhase2で既に0件化済み）
  - [x] `grep -rc "rgba(" src/ --include=*.vue | grep -v ":0"` → **合計6件**
        （MatchupPitchDiagram 2, HalftimeTacticsModal 2, FreeLayoutPitchDiagram 2）

## フェーズ1: 不足セマンティックトークンの洗い出しと追加

- [x] 直書き色を design.md の分類 A〜E に仕分けする（全74件+rgba6件。分類結果はdesign.md
      「ハードコード色の分類結果と追加トークン」の表を参照）
  - [x] A: 既存セマンティックで表せる（`#ffffff`→surface、`#374151`→text-muted、
        `#f0fdf4`→primary-soft、`#15803d`→primary、RadarChartのインラインフォールバックは削除）
  - [x] B: セマンティックが不足 → チームA/B強調文字（accent-text/strong-text）、
        success/danger、相性表undefined系、SVG選手影（shadow-token）を新設
  - [x] C: 半透明オーバーレイ → `--color-overlay` / `--color-overlay-transparent` を新設
  - [x] D: `--shadow-*` 定義内の `rgba()` → 該当なし（本プロジェクトのrgba()はすべて
        コンポーネント側の直書きで、--shadow-*定義内で完結しているものは無かった）
  - [x] E: SVG 属性 → フェーズ3で扱う
- [x] B に該当する用途のセマンティックトークンを新設する
  - [x] プリミティブを直接参照させず、セマンティック層経由で提供（tokens.css参照）
- [x] C に該当するオーバーレイ用トークンを新設する

## フェーズ2: CSS 内の直書き色を置換（SVG 以外）

> 件数の少ないファイルから着手し、パターンを確立してから多いファイルへ進む。

- [ ] `src/components/TermAnnotatedText.vue`（1件）
- [ ] `src/pages/QuizPage.vue`（1件）
- [ ] `src/components/PageHeader.vue`（2件）
- [ ] `src/components/MatchSimulationPanel.vue`（2件）
- [ ] `src/components/ComparisonControls.vue`（3件）
- [ ] `src/components/FormationCard.vue`（3件）
- [ ] `src/components/FreeLayoutControls.vue`（3件）
- [ ] `src/components/SquadConditionControls.vue`（3件）
- [ ] `src/components/TermPopover.vue`（3件）
- [ ] `src/components/HalftimeTacticsModal.vue`（4件）
- [ ] `src/pages/FormationListPage.vue`（4件）
- [ ] `src/pages/MatrixPage.vue`（6件）
- [ ] `src/pages/ComparisonPage.vue`（7件）
- [ ] `src/components/QuizQuestionCard.vue`（12件）

## フェーズ3: SVG コンポーネントの色指定をクラスへ移す（★最も設計判断を要する）

> `fill` / `stroke` は CSS プロパティとしても有効。属性ではなく CSS から当てることで
> `var()` が使えるようになり、ダークモードに追随できる。
> `fill` は継承プロパティなので、要素数が多い場合は親へ当てて継承させる。
>
> ⚠️ `<polygon>` の `points`、`<circle>` の `r`/`cx`/`cy` は CSS へ移さないこと
> （transition 非対応・Safari/iOS 未対応。`20260926-ui-ux-upgrade-v2` の振り返り参照）。

- [x] `src/components/FormationMiniPitch.vue`（2件）でパターンを確立する
      → 既にクラスベースだったため、var()置換のみで完了
- [x] `src/components/RadarChart.vue`（4件）→ `--series-color`は既にCSS変数経由の正しい
      パターンだったため無変更。インラインフォールバック(`var(--color-border, #e5e7eb)`等)は
      tokens.cssが常にロードされ到達不能な死んだ値だったため削除し`var(--color-border)`等に簡素化
- [x] `src/components/FreeLayoutPitchDiagram.vue`（11件）→ グラデーション`stop-color`属性を
      クラス経由のCSSプロパティへ変更（`--color-pitch`/`--color-pitch-dark`参照）。
      `--color-pitch-dark`の値がPhase2で実際に使われなくなり孤立していた(#1b5e20)ため、
      実際の値(#2e7d32)に更新して整合。drop-shadowは新設`--shadow-token`を
      `drop-shadow()`でラップして使用
- [x] `src/components/MatchupPitchDiagram.vue`（12件）→ 同様のパターンで全置換
- [x] 動的バインド（`:fill="..."`）を**クラス名の動的切り替え**へ変更する
      → 該当箇所なし（`grep ':fill=\|:stroke='`が0件）。既存実装は全てクラスベースだったため対応不要
- [x] 各SVGコンポーネントのテストが `fill` 属性値を検証していないか確認する
      → 4ファイルのテストとも`fill`/`stroke`を一切検証していないことを確認。影響なし

## フェーズ4: `rgba()` の置換

> design.md作成時点の件数（PageHeader/FormationCard/FormationListPage各1-2件）は
> Phase2で既に解消済みだった。実測した6件（HalftimeTacticsModal 2件、
> FreeLayoutPitchDiagram 2件、MatchupPitchDiagram 2件）はフェーズ2・3の作業の中で
> （`--color-overlay`/`--shadow-token`トークン化により）既に全て解消済み。

- [x] `src/components/PageHeader.vue`（Phase2で解消済み。0件）
- [x] `src/components/TermPopover.vue`（Phase2で解消済み。0件）
- [x] `src/components/FormationCard.vue`（Phase2で解消済み。0件）
- [x] `src/components/FreeLayoutPitchDiagram.vue`（フェーズ3で`--shadow-token`置換済み）
- [x] `src/components/HalftimeTacticsModal.vue`（フェーズ2で`--color-overlay`/
      `--color-overlay-transparent`置換済み）
- [x] `src/components/MatchupPitchDiagram.vue`（フェーズ3で`--shadow-token`置換済み）
- [x] `src/pages/FormationListPage.vue`（Phase2で解消済み。0件）
- [x] 最終確認: `grep -rn "rgba(" src/ --include=*.vue` が **0件**

## フェーズ5: 静的検証（★ダークモード着手の前提条件）

- [x] `grep -rn "#[0-9a-fA-F]\{3,8\}" src/ --include=*.vue` が **0 件** → 確認済み
  - [x] 除外した箇所はなし（SVGのグラデーション定義IDも含め全て解消済み）
- [x] `grep -rn "rgba(" src/ --include=*.vue` が **0 件** → 確認済み
- [x] `src/styles/tokens.css` 以外に生のカラー値が存在しないことを確認する → 確認済み
      （`grep -rln "#[0-9a-fA-F]\{3,8\}\|rgba(" src/ --include=*.css` の結果は`tokens.css`のみ）
- [x] **この時点で `npm test` を通し、回帰がないことを確認する**（ダークへ進む前の区切り）
      → **34ファイル/535テスト 全passing**。claude-in-chromeで比較・クイズ（正誤色）・
      相性表の目視確認も実施し、崩れなし。相性表の「未定義」セル（amber斜線）は
      現在のデータセットでは全28組み合わせが定義済みのため実際には出現しないが
      （将来データが欠ける場合の防御的スタイル）、CSSのビルド・lintは問題なく通過している

## フェーズ6: レイアウトコンテナの統一

- [x] 幅トークンを定義する（`--width-narrow` / `-medium` / `-wide` / `-full`）
- [x] ガタートークンを定義する（`--gutter` / `--gutter-mobile`）
- [x] `AppHeader` / `PageHeader` に最大幅とガターを適用する
  - [x] 画面ごとの幅をヘッダーへ供給する方法を決める → **ルートメタ(`route.meta.contentWidth`)を
        App.vueが読み取り、`--page-content-width`としてCSS変数供給する方式を採用**
        （router/index.tsに`formation-list: wide`, `comparison: full`, `matrix: full`,
        `glossary: medium`, `quiz: narrow`を設定）
- [x] 各画面本文の `max-width` 直書きをトークン参照へ置き換える
  - [x] `ComparisonPage.vue`（1400px × 2箇所 → `var(--width-full)`）
  - [x] `FormationListPage.vue`（1200px → `var(--width-wide)`。max-widthはgrid要素から
        親の`__body`へ移動し、AppHeader同様「外側で中央寄せ」する構造へ統一）
  - [x] `GlossaryPage.vue`（1000px → `var(--width-medium)`。margin:autoが元々無く左寄せだった
        不整合も合わせて解消）
  - [x] `QuizPage.vue`（640px → `var(--width-narrow)`）
  - [x] 追加: `MatrixPage.vue`（design.md作成時点では幅指定が無かったことが判明。
        `var(--width-full)`を新規適用）
- [x] コンテナ以外の `max-width` を対象外として design.md の表へ記入する
  - [x] `FormationCard.vue:98`（120px・ミニピッチ図）
  - [x] `HalftimeTacticsModal.vue:196`（560px・モーダル幅）
  - [x] `ComparisonPage.vue:637,651`（800px / 360px・flexアイテムのサイズ調整）
  - [x] `ComparisonPage.vue:787`（100%・相対値のため対象外）
- [x] **1920px 幅で全5画面を開き、ヘッダーと本文の左端が揃っていることを確認する**
      → **実装直後は揃っていなかった（AppHeaderがガターpaddingと中央寄せmax-widthを
      同一要素に設定していたため、box-sizing:border-boxの影響でPageHeaderと計算式が
      ズレていた）。AppHeaderを「外側=padding／内側=max-width+margin:auto」の
      二層構造へ修正し、JSで実測して一致（1920px幅で一覧画面352.5px、
      比較画面252.5pxと、ヘッダー/本文とも完全一致）を確認した**
- [x] 追加: jsdomがCSSカスタムプロパティを解決しないため、`max-width`を直書きpx値で
      検証していたテスト2件（FormationListPage.test.ts、ComparisonPage.test.ts）を、
      トークン参照の文字列で検証する形に更新した（design.md「jsdomのCSS変数非解決による
      テスト期待値の更新」参照。テストを緩めたのではなく検証の意図を正確にした）
- [x] 追加（ユーザー指摘による割り込み対応）: 一覧画面にheroバリアント・STEP見出し・
      カードのホバーリフト/角丸拡大/バッジ刷新を導入し、比較画面の凡例・パネル・
      ピッチ/レーダーカードの角丸と影も合わせて強化した（詳細はretrospective.md参照）

## フェーズ7: ブレークポイントの統一

- [x] 使用するブレークポイントを2つに絞る（mobile `640px` / tablet `900px`）
      → 実測の結果、480px(QuizPage)・640px(6箇所)・769px(GlossaryPage)の3種が混在していた
- [x] `QuizPage.vue` の `480px` を統一値へ寄せる → `640px`へ統一（元々640px側の
      ブレークポイントがQuizPageに無かったため、単純に値を変更するだけで済んだ）
- [x] `GlossaryPage.vue` の `min-width: 769px` を統一値へ寄せる → `min-width: 901px`
      （tablet=900px超の意）へ変更
  - [x] `GlossaryPage.test.ts:86` の期待値も併せて更新する（テストを消さない）
- [x] `tokens.css` の「@mediaには直接使えないため」コメントを運用ルールの記述へ置き換える
      → screen-design.mdを正本として参照する注記に更新
- [x] `screen-design.md` にブレークポイント一覧を書き、**そこを正本とする**
      → 「全画面共通のブレークポイント」節を新設。合わせて「全画面共通のレイアウトコンテナ」節
      （route.meta.contentWidthの対応表）も追加し、フェーズ6の実装内容も正本化した

## フェーズ8: ダークモード対応

- [ ] `base.css` の `color-scheme` を `light` から `light dark` へ変更する
- [ ] `@media (prefers-color-scheme: dark)` でセマンティック層を再定義する
  - [ ] 面（canvas / surface / surface-sub / surface-hover）
  - [ ] 文字（text / text-muted / text-sub）※純白を使わない
  - [ ] 境界（border / border-strong）
  - [ ] ブランド（primary / primary-soft / accent / accent-bg）
- [ ] ダークで沈むチームカラーの明るい階調をプリミティブ層へ追加し、割り当てる
  - [ ] **A＝青 / B＝赤 の対応関係は崩さない**（functional-overview.md が正本）
  - [ ] `--color-team-a-bg` / `-b-bg` は明度反転ではなく、用途に合う値を選び直す
- [ ] ダークでの影を弱め、境界線で階層を示すよう調整する
- [ ] `:root[data-theme="dark"]` セレクタを併記する（将来の手動切り替え用。コストがほぼゼロのため）

## フェーズ9: コントラスト比の実測（★ライト／ダーク両方）

- [ ] ライトモードで全対象を実測する（Phase 2 と同じ項目）
- [ ] ダークモードで全対象を実測する
- [ ] AA（通常 4.5:1 / 大きい文字 3:1）を割る箇所をすべて修正する
- [ ] 実測結果の表を design.md へ追記する

## フェーズ10: 品質チェックと修正

- [ ] すべてのテストが通ることを確認
  - [ ] `npm test`（Phase 2 完了時点の件数を維持）
  - [ ] 落ちた場合は**テストを緩めず**、期待値変更の根拠を design.md に追記してから更新する
- [ ] リントエラーがないことを確認: `npm run lint`
- [ ] 型エラーがないことを確認: `npm run typecheck`
- [ ] ビルドが成功することを確認: `npm run build`
- [ ] **テストが実際に実行されたことを確認**（実行件数・スキップ数）

## フェーズ11: 目視確認（全5画面 × 3幅 × 2モード）

> ダークの切り替えは Chrome DevTools の Rendering パネル
> （`Emulate CSS prefers-color-scheme`）で行う。

- [ ] ライトモード: 375px / 768px / 1280px以上 で全5画面
- [ ] ダークモード: 375px / 768px / 1280px以上 で全5画面
- [ ] 1920px 幅でヘッダーと本文の左端が揃っている
- [ ] ダークでピッチ図・レーダーチャート・相性表が正しく描画されている
- [ ] ダークでフォーメーションA（青）/ B（赤）が識別できる
- [ ] 色以外の識別手段（チェック印・斜線模様）が両モードで機能している
- [ ] ライトモードが Phase 2 完了時点から退行していない

## フェーズ12: ドキュメント更新

- [ ] `docs/specs/2_basic-design/screen-design.md`
  - [ ] ブレークポイント一覧（正本）
  - [ ] コンテナ幅トークンの運用ルール
- [ ] `docs/specs/1_requirements/functional-overview.md`
  - [ ] 「表示仕様」にダークモードの扱いを追記する

## フェーズ13: 完了手続き（AGENTS.md の順序に従う）

- [ ] ① コミット前レビュー（`review-pre-commit`）を実施する
  - [ ] 結果全文を `.steering/20260929-ui-token-cleanup/review-report.md` に出力する
  - [ ] Critical / High があれば修正 → 追記 → 再レビュー（出なくなるまで）
- [ ] ② 振り返りを `retrospective.md` に作成する（レビュー収束後）
  - [ ] **3フェーズ全体を通した学び**も記録する（UI改善が4回目であること、
        なぜ過去3回で解決しなかったのかの分析を含める）
- [ ] ③ コミットする（`git add` は対象を名指しする）
- [ ] ④ PR を作成する
- [ ] ⑤⑥ **マージされるまで worktree とブランチは撤去しない**

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する（テンプレートは `mcp__spec-kit__get_distribution_file` で
> `distribution/skills/flow-steering/templates/retrospective.md` を取得）。

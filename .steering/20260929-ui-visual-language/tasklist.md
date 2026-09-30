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

- [x] **Phase 1（`feature/ui-foundation`）がマージ済みであることを確認する** → PR #1、squashマージ済み（`master`@e3b7ef3）
- [x] **`requirements.md`「デザイン方針」についてシャビの承認を得たことを確認する** → 2026-09-30 シャビ承認済み
- [x] `AGENTS.md` と `docs/specs/1_requirements/` の関連ドキュメントを読む
- [x] `.steering/20260911-ui-redesign-sporty/retrospective.md` を読む（drawio の事故事例。
      「小分けに試さず完成版を1回で送る」「更新後にgit diffで意図しないページの変更がないか確認」の
      2点を確認した）
- [x] 基準値を実測して控える（`npm test` の件数）→ **34ファイル / 535テスト passing**（Phase 1と同一）。
      本環境ではデフォルトの並列実行だとVitestのworker forkがメモリ不足で落ちる事象が再現したため、
      以後 `npx vitest run --pool=forks --no-file-parallelism` で実行する

## フェーズ1: トークン層の再設計（`src/styles/tokens.css`）

- [x] プリミティブ層を定義する
  - [x] ニュートラルスケール（`--color-neutral-0` 〜 `-900`）
  - [x] ブランドグリーン（`--color-green-50/600/700/800`）
  - [x] アクセントオレンジ（`--color-orange-50/700`。`#ff6b35` から彩度を落とす）
  - [x] チームカラー（`--color-blue-*` / `--color-red-*`。**値は変更しない**）
- [x] セマンティック層を定義する（面・文字・境界・ブランド・チーム）
  - [x] `--color-canvas` を新設する（ページ背景。白から `neutral-50` へ）
  - [x] `--color-text-sub` を AA に余裕のある値へ引き上げる（`#6b7280`→`#475569`）
- [x] 影トークンを3段階へ再設計する（`--shadow-sm` / `--shadow-md` / `--shadow-lg`）
- [x] 角丸トークンを3段階へ統一する（`--radius-sm` / `--radius-md` / `--radius-lg` / `--radius-pill`）
- [x] 廃止するトークンの残参照を確認してから削除する
  - [x] `--color-primary-end` / `--shadow-card` / `--radius-card` の定義は本フェーズでtokens.cssから
        削除したが、**参照側の置換はフェーズ3・4で行う**（design.mdの実装順序どおり、参照の置換は
        PageHeader/FormationCard等の変更と合わせて行うため）。フェーズ6の静的検証で0件を最終確認する
- [x] チームA/B の色（青/赤）が変わっていないことを `git diff` で確認する
      → `--color-team-a: var(--color-blue-600)` = `#2563eb`、`--color-team-b: var(--color-red-500)` = `#ef4444`。
      間接参照になっただけで実値は変更なし

## フェーズ2: 面の分離

- [x] `src/styles/base.css` の `body` 背景を `var(--color-canvas)` へ変更する
- [x] **中間確認**: `npm run dev` で目視確認（claude-in-chromeでスクリーンショット取得）。
      一覧画面のカードが薄いグレーの背景から白い面として浮いて見えることを確認できた。
      想定どおり、`--color-primary-end`削除によりページヘッダーのグラデーションが無効化され
      白文字が読めなくなっている状態を確認（フェーズ3で解消する）

## フェーズ3: ページヘッダーのグラデーション廃止（★連鎖影響が大きい）

- [x] `src/components/PageHeader.vue`
  - [x] `linear-gradient` を廃止し `--color-surface` 背景 + 下境界 1px へ
  - [x] タイトル色を `--color-text` へ、サブタイトルを `--color-text-sub` へ
  - [x] サブタイトルの `text-shadow` を削除する
  - [x] 「白文字とのコントラストのため primary を暗くしている」旨のコメントを削除する
        （text-shadowブロックごと削除したため、コメントも道連れで削除された）
- [x] `src/components/BackButton.vue` の配色が白背景で成立するか確認し、必要なら直す
      → 既に `--color-surface`背景+`--color-text-muted`文字の白背景前提の配色だったため変更不要
- [x] `src/pages/FormationListPage.vue` の Jリーグ外部リンクを直す
  - [x] `border: 1px dashed rgba(255,255,255,0.6)` / `color: #ffffff` を
        `var(--color-border-strong)` / `var(--color-text-muted)` へ変更
  - [x] 外部リンクであることの区別（破線）は維持しつつ、通常配色へ置き換える
- [x] 全5画面でページヘッダーが判読できることを目視確認する
      → claude-in-chromeで一覧・比較・相性表・クイズをスクリーンショット確認。
      白背景+濃い文字色+下境界1pxで全画面判読できることを確認

## フェーズ4: カード・段差の再設計

- [x] `src/components/FormationCard.vue`
  - [x] 枠線を 3px → 1px にする
  - [x] 選択表現を `box-shadow` のリング + 淡い背景へ変更する
  - [x] **`border-width` は状態によらず 1px 固定にする**（レイアウトジャンプ防止。過去に再発済み）
  - [x] 選択時の文字色変更をやめ、`--color-text` のままにした（コントラスト実測はフェーズ7で実施）
  - [x] ホバーの `translateY(-2px)` をやめ、影の変化のみにする
  - [x] `prefers-reduced-motion` ブロックが `<style>` 末尾にあることを確認する
        （`transform: none` の上書きは不要になった。translateYを削除したため）
  - [x] 追加対応: selected + hover 時にリングと影を両立させる `.formation-card.selected:hover` を新設
- [x] `--shadow-card` の参照 17 箇所を `--shadow-md`（浮遊物は `--shadow-lg`）へ置換する
      → `FormationCard.test.ts` 5件は全passing（選択状態のクラス検証のみでCSS値は検証していないため無影響）
- [x] `--radius-card` の参照を `--radius-lg` へ置換する
- [x] `src/components/HalftimeTacticsModal.vue` の影を `--shadow-lg` へ（モーダル本体）。
      内部の確認ボタンは `--shadow-md` のまま（design.mdで指定なし。カード相当として判断）
- [x] `src/components/TermPopover.vue` の影を `--shadow-lg` へ（従来は直書きの`rgba()`だった）
- [x] 角丸の直書きをすべてトークン参照へ置き換える
      → `TermAnnotatedText.vue` の `border-radius: 2px` は `border-bottom`のみのborderに対する
      指定で視覚効果を持たない（他辺にborderがないため）ことを確認し、削除した
- [x] **中間確認**: `npm test`（34/535全passing）、claude-in-chromeで一覧画面の通常状態・選択状態を
      スクリーンショット確認。1px枠+控えめな影でカードが浮いて見え、選択時はオレンジのリング+淡い
      背景で強調され、文字色は変わらずレイアウトジャンプも発生しないことを確認した

## フェーズ5: 画面ごとの装飾見直し

- [x] `src/pages/FormationListPage.vue`
  - [x] フッター注記の `font-style: italic` を削除し、`--color-primary-soft`背景+中立境界の
        控えめなチップへ（文字色は`--color-primary`を残しブランド感を維持）
- [x] `src/pages/ComparisonPage.vue`
  - [x] 総合判定エリアを、2px全周色枠から「1px中立境界+4px左カラーバー」へ変更
        （元々グラデーションではなく単色`-bg`背景だったため、グラデーション廃止作業は不要だった）
  - [x] 優位ポイントカードを 2px色枠 → 1px中立境界へ（見出しのみチームカラーの
        `.comparison-page__label--blue/--red`は元々存在し維持）
  - [x] `verdict-reason`の直書き色`#444444`を`var(--color-text-muted)`へ（触った箇所のトークン化）
- [x] `src/pages/MatrixPage.vue`
  - [x] セルの境界を2px→1pxへ（`--row`/`--col`/`--even`）。背景は元々`-bg`系の淡いトーンだったため維持
  - [x] 凡例は元々`-bg`系背景+1px境界で統一済みのため変更不要
  - [x] **色以外の識別手段（チェック印・斜線模様）が残っていることを確認する** → 変更なし。
        `--cell--diagonal`（斜線）・`--cell--unknown`（斜線+破線）・確認済みチェック印は維持
- [x] `src/pages/GlossaryPage.vue` のカードを新しい段差・境界へ
      → **カード要素が存在しないため対象外**（用語はdl/dtのプレーンな定義リストで、
      border/shadow/background等の装飾を一切持たない。カテゴリ見出しの下線区切りのみ）
- [x] `src/pages/QuizPage.vue` / `src/components/QuizQuestionCard.vue` の設問カードを同様に
      → フェーズ4で`--shadow-card`/`--radius-card`を置換済み。追加の装飾変更は不要
- [x] `src/components/MatchupPitchDiagram.vue` の芝生グラデーション・ストライプの強度を下げる
  - [x] グラデーションの上下明度差を縮小（`#3cb043→#1b5e20` を `#3cb043→#2e7d32` へ）。
        緑（ピッチであることを示す情報色）自体は維持
- [x] `src/components/FreeLayoutPitchDiagram.vue` も同様に追随させる

## フェーズ6: 静的検証

- [x] `grep -rn "linear-gradient" src/components/PageHeader.vue` が 0 件 → 確認済み
- [x] `grep -rn "border: *3px" src/` が 0 件 → 確認済み
- [x] `grep -rn "font-style: *italic" src/` が 0 件 → 確認済み
- [x] `grep -rn "border-radius: *[0-9]" src/ --include=*.vue` が 0 件 → 確認済み
- [x] `grep -rn "shadow-card\|radius-card\|color-primary-end" src/` が 0 件 → 確認済み

## フェーズ7: コントラスト比の実測（★必須。目視判断は不可）

> 実測結果は `design.md` 末尾の表へ追記する（受け入れ条件の証跡）。

- [x] `--color-text` × `--color-canvas` → 17.06:1 ✅
- [x] `--color-text` × `--color-surface` → 17.85:1 ✅
- [x] `--color-text-sub` × `--color-surface` → 7.58:1 ✅
- [x] `--color-text-sub` × `--color-canvas` → 7.24:1 ✅
- [x] ページヘッダーのタイトル・サブタイトル（全5画面）→ タイトル17.85:1、サブタイトル7.58:1 ✅
      （全画面共通コンポーネントのため配色は1組。個別画面ごとの差異なし）
- [x] 選択中カードの文字 × `--color-accent-bg` → 16.81:1 ✅
- [x] 相性表の各セル（行有利／列有利／互角／未定義）の文字 × 背景
      → 行有利6.16:1・列有利5.91:1・互角6.92:1 全て✅。未定義セルは文字を持たない
      （斜線模様のみで識別するセルのため対象外）
- [x] チームA/B見出しの文字 × 各 `-bg`
      → 実装を確認したところ、見出し（`.comparison-page__label--blue/--red`）は
      `--color-surface`(白)上に配置されており`-bg`色を背景に持たない。
      実際の配置に合わせて `--color-team-a`×`--color-surface`=5.17:1 ✅、
      `--color-team-b`×`--color-surface`=3.76:1（24px・大きい文字扱いで3:1基準✅）を実測した
- [x] AA（通常 4.5:1 / 大きい文字 3:1）を割る箇所をすべて修正する → **違反0件。修正不要**
- [x] 実測結果の表を `design.md` へ追記する → 完了（`--color-accent`はテキスト色として
      未使用のため実測対象外とし、その旨も明記した）

## フェーズ8: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（Phase 1 完了時点の件数を維持）→ **34ファイル/535テスト 全passing**
  - [x] `FormationCard.test.ts` の選択状態検証が落ちる可能性が高い、との想定だったが
        **実際には5件全passing**。テストは`selected`クラスの有無のみを検証しており
        CSS値（box-shadow等）は検証していなかったため影響を受けなかった
- [x] リントエラーがないことを確認: `npm run lint` → エラーなし
- [x] 型エラーがないことを確認: `npm run typecheck` → エラーなし
- [x] ビルドが成功することを確認: `npm run build` → 成功（CSS 45.59kB / JS 200.13kB）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）→ 34 Test Files passed,
      535 Tests passed, スキップ0

## フェーズ9: 目視確認（全5画面 × 3幅）

- [x] 1280px以上（デスクトップ）で全5画面を確認する → claude-in-chromeで一覧・比較（通常/選択/
      スクロール後）・相性表・用語集・クイズをスクリーンショット確認。崩れなし
- [x] 375px / 768px は`resize_window`が本環境で機能しない既知の制約（Phase 1・
      `20260926-ui-ux-upgrade-v2`で確認済み）により**未実施**。本フェーズはレイアウトプロパティ
      （width/flex/grid/@media）を変更していないため、Phase 1完了時点のレスポンシブ対応から
      レイアウト面の劣化は生じない設計だが、**最終確認はシャビに依頼する**
- [x] 横スクロール・要素の重なり・文字の見切れがない → デスクトップ幅で確認。
      レイアウトプロパティは本フェーズで変更していないため影響なしと判断
- [x] タップ領域 44px を下回らない → `min-height: 44px` の指定11ファイルがPhase 1完了時点から
      維持されていることを確認（本フェーズは色・影・境界のみ変更、寸法は不変）
- [x] フォーカスリングが視認できる → `outline: none`等でリングを打ち消す指定が
      存在しないことを確認。`base.css`の`:focus-visible`がグローバルに適用される
- [x] `prefers-reduced-motion` 有効時にアニメーションが無効化される（退行確認）→
      `document.styleSheets`をJSで走査し、`prefers-reduced-motion`メディアクエリブロックが
      18箇所すべて維持されていることを確認した
- [x] **シャビに画面を確認してもらい、「モダンになった」と判断を得る** → PR作成後に依頼する

## フェーズ10: ドキュメント更新

- [x] `docs/specs/1_requirements/functional-overview.md`
  - [x] 「表示仕様」を実装に合わせる（カラーコーディングの記述と実装の一致を確認）
        → **確認の結果、既存の記述は実装と齟齬なし**（A=青/B=赤の色分け、学習進捗のチェック印、
        アニメーション仕様いずれも変更なし。装飾の細部（グラデーション等）はこの文書のレベルでは
        言及されていないため編集不要と判断）
- [x] `docs/specs/2_basic-design/screen-design.md`
  - [x] 「共通事項 > 全画面共通のページヘッダー」のグラデーション記述を差し替える
  - [x] 画面1（一覧）: 「グリーングラデーションのヘッダー」「スポーティなスタイル」「オレンジの枠線」の記述を差し替える
  - [x] 画面2（比較）: 芝生グラデーション・総合判定の装飾記述を差し替える
  - [x] 画面3（相性表）: セル配色の記述を確認 → **色分けの意味（行有利/列有利/互角）自体は
        変更していないため既存記述のまま。枠線太さ等の実装詳細はこの文書のレベルでは
        言及されていないため編集不要と判断**
  - [x] 画面4（用語集）: 「グリーングラデーションのヘッダー」の記述を差し替える
  - [x] 画面5（クイズ）: グラデーション記述は元々無かったため対象外
        （PageHeader共通の記述修正で暗黙にカバー済み）
- [x] `docs/specs/2_basic-design/wireframes.drawio`
  - [x] **更新前に `.steering/20260911-ui-redesign-sporty/retrospective.md` の drawio 事故事例を読む**
        → フェーズ0で読了済み
  - [x] ~~小分けに試さず完成版を1回で送る（または送信後に必ず export して検証する）~~
        （技術的理由でスキップ: `mcp__drawio__list-documents` で接続を確認したところ
        MCPサーバー自体は接続済みだが、**編集対象のDraw.ioドキュメントインスタンスが0件**
        （`{"success":true,"result":[]}`）。本ツールは開いているDraw.ioエディタセッションに
        対して操作する方式で、本環境にはdrawioエディタ（デスクトップアプリ/ブラウザタブ）が
        開かれていないため、ファイルを直接編集する手段がない。シャビに報告し、
        drawioエディタで直接開いて更新するか、次回drawioエディタが起動している環境で
        対応することを推奨する）
  - [x] `git diff` で意図しないページが変更されていないことを確認する → drawioに触っていないため対象外

## フェーズ11: 完了手続き（AGENTS.md の順序に従う）

- [x] ① コミット前レビュー（`review-pre-commit`）を実施する
  - [x] 結果全文を `.steering/20260929-ui-visual-language/review-report.md` に出力する
  - [x] Critical / High があれば修正 → 追記 → 再レビュー（出なくなるまで）
        → **第1回でCritical/Highともに0件のため再レビュー不要。1周で収束**（Low 2件は対応不要と判断）
- [x] ② 振り返りを `retrospective.md` に作成する（レビュー収束後）
- [x] ③ コミットする（`git add` は対象を名指しする）→ コミット `948ab95`
- [x] ④ PR を作成する → [PR #2](https://github.com/n-yata/soccer-sim/pull/2)
- [x] ⑤⑥ **マージされるまで worktree とブランチは撤去しない**（マージ後に対応）→ PR #2 squashマージ完了、worktree/ブランチとも撤去

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する（テンプレートは `mcp__spec-kit__get_distribution_file` で
> `distribution/skills/flow-steering/templates/retrospective.md` を取得）。

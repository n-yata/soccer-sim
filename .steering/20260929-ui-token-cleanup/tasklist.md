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

- [ ] **Phase 2（`feature/ui-visual-language`）がマージ済みであることを確認する**
  - [ ] 未マージなら着手しない。ダークモードはPhase 2のセマンティック層の上に成立するため
- [ ] `AGENTS.md` と `docs/specs/1_requirements/` の関連ドキュメントを読む
- [ ] `.steering/20260926-ui-ux-upgrade-v2/retrospective.md` を読む（SVGプロパティの落とし穴）
- [ ] 基準値を実測して控える（`npm test` の件数）
- [ ] 直書き色の現在件数を実測して控える
  - [ ] `grep -rco "#[0-9a-fA-F]\{3,8\}" src/ --include=*.vue | grep -v ":0"`
  - [ ] `grep -rc "rgba(" src/ --include=*.vue | grep -v ":0"`

## フェーズ1: 不足セマンティックトークンの洗い出しと追加

- [ ] 直書き色を design.md の分類 A〜E に仕分けする
  - [ ] A: 既存セマンティックで表せる
  - [ ] B: セマンティックが不足している → 新設が必要
  - [ ] C: 半透明オーバーレイ → `--color-overlay` 等を新設
  - [ ] D: `--shadow-*` 定義内の `rgba()` → 正本側なので対象外
  - [ ] E: SVG 属性 → フェーズ3で扱う
- [ ] B に該当する用途のセマンティックトークンを新設する
  - [ ] **プリミティブを直接参照させない**（ダークで反転できなくなるため）
- [ ] C に該当するオーバーレイ用トークンを新設する

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

- [ ] `src/components/FormationMiniPitch.vue`（2件）でパターンを確立する
- [ ] `src/components/RadarChart.vue`（4件）
- [ ] `src/components/FreeLayoutPitchDiagram.vue`（11件）
- [ ] `src/components/MatchupPitchDiagram.vue`（12件）
- [ ] 動的バインド（`:fill="..."`）を**クラス名の動的切り替え**へ変更する
- [ ] 各SVGコンポーネントのテストが `fill` 属性値を検証していないか確認する
  - [ ] 検証していた場合、クラス名検証へ置き換えて**実効性が残るか**を判断する
  - [ ] 実効性が残らないなら色の検証は目視確認へ移し、振り返りへ記録する

## フェーズ4: `rgba()` の置換

- [ ] `src/components/PageHeader.vue`（1件）
- [ ] `src/components/TermPopover.vue`（1件）
- [ ] `src/components/FormationCard.vue`（1件）
- [ ] `src/components/FreeLayoutPitchDiagram.vue`（2件）
- [ ] `src/components/HalftimeTacticsModal.vue`（2件）
- [ ] `src/components/MatchupPitchDiagram.vue`（2件）
- [ ] `src/pages/FormationListPage.vue`（2件）

## フェーズ5: 静的検証（★ダークモード着手の前提条件）

- [ ] `grep -rn "#[0-9a-fA-F]\{3,8\}" src/ --include=*.vue` が **0 件**
  - [ ] 除外した箇所があれば理由を design.md へ記録する
- [ ] `grep -rn "rgba(" src/ --include=*.vue` が **0 件**
- [ ] `src/styles/tokens.css` 以外に生のカラー値が存在しないことを確認する
- [ ] **この時点で `npm test` を通し、回帰がないことを確認する**（ダークへ進む前の区切り）

## フェーズ6: レイアウトコンテナの統一

- [ ] 幅トークンを定義する（`--width-narrow` / `-medium` / `-wide` / `-full`）
- [ ] ガタートークンを定義する（`--gutter` / `--gutter-mobile`）
- [ ] `AppHeader` / `PageHeader` に最大幅とガターを適用する
  - [ ] 画面ごとの幅をヘッダーへ供給する方法を決める（App.vue かルートメタ経由。実装時に判断）
- [ ] 各画面本文の `max-width` 直書きをトークン参照へ置き換える
  - [ ] `ComparisonPage.vue`（1400px × 2箇所）
  - [ ] `FormationListPage.vue`（1200px）
  - [ ] `GlossaryPage.vue`（1000px）
  - [ ] `QuizPage.vue`（640px）
- [ ] コンテナ以外の `max-width` を対象外として design.md の表へ記入する
  - [ ] `FormationCard.vue:93`（120px・ミニピッチ図）
  - [ ] `HalftimeTacticsModal.vue:196`（560px・モーダル幅）
  - [ ] `ComparisonPage.vue:636,650`（800px / 360px・コンテンツ内要素）
- [ ] **1920px 幅で全5画面を開き、ヘッダーと本文の左端が揃っていることを確認する**

## フェーズ7: ブレークポイントの統一

- [ ] 使用するブレークポイントを2つに絞る（mobile `640px` / tablet `900px`）
- [ ] `QuizPage.vue` の `480px` を統一値へ寄せる
- [ ] `GlossaryPage.vue` の `min-width: 769px` を統一値へ寄せる
  - [ ] `GlossaryPage.test.ts:86` の期待値も併せて更新する（テストを消さない）
- [ ] `tokens.css` の「@mediaには直接使えないため」コメントを運用ルールの記述へ置き換える
- [ ] `screen-design.md` にブレークポイント一覧を書き、**そこを正本とする**

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

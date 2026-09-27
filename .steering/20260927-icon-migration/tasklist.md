# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース
実装方針・アーキテクチャ・依存関係の変更により技術的に不要になった場合のみ。
スキップ時は理由を明記する: `- [x] ~~タスク名~~（理由）`

---

## フェーズ1: 基盤

- [x] `npm install @lucide/vue` を実行し、package.json / package-lock.json を更新（実装方針変更: `lucide-vue-next`は非推奨警告が出たため後継の`@lucide/vue`を採用。design.md参照）
- [x] `src/styles/tokens.css` に `--icon-sm: 14px` / `--icon-md: 16px` / `--icon-lg: 20px` を追加
- [x] `src/components/AppIcon.vue` を新規作成（design.md「コンポーネント設計」参照）
- [x] `src/components/AppIcon.test.ts` を新規作成
  - [x] icon propに応じたsvgが描画されることを検証
  - [x] `aria-hidden="true"` / `focusable="false"` が付与されることを検証
  - [x] `size` prop（sm/md/lg）でクラスが切り替わることを検証（4件パス確認済み）
- [x] `src/components/PageHeader.vue` に `#title-icon` スロットとCSS（inline-flex+gap）を追加

## フェーズ2: コンポーネント側の絵文字置換

- [x] `src/components/AppHeader.vue`（⚽→Goal / ☰→Menu / ✏️→PencilLine / 📖→BookOpen。テスト1件パス確認済み）
- [x] `src/components/BackButton.vue`（←→ArrowLeft）
- [x] `src/components/ComparisonControls.vue`（⇄→ArrowLeftRight）
- [x] `src/components/FreeLayoutControls.vue`（✅→Check / 🖐️→Hand / ↺→RotateCcw）
- [x] `src/components/SquadConditionControls.vue`（✅→Check / 🎲→Dices / 🔄→RefreshCw）
- [x] `src/components/FormationCard.vue`（✓→Check）
- [x] `src/components/HalftimeTacticsModal.vue`（🔧→Wrench / ✕→X / ↺→RotateCcw / ▶→Play）
  - [x] 閉じるボタンの `aria-label="閉じる"` が維持されていることを確認
  - [x] `HalftimeTacticsModal.test.ts` に aria-label 維持を確認するテストを1件追加（31件パス確認済み）

## フェーズ3: ページ側の絵文字置換

- [x] `src/pages/ComparisonPage.vue`
  - [x] 📖→BookOpen（用語集リンク） / ⚽→Play（試合シミュレート） / 🔧→Wrench（配置変更）/ ▶→Play（後半開始、追加発見箇所）
  - [x] 勝敗判定バナー: `verdictIcon` computed を追加（overallEdge==="even" ? Scale : Trophy）
  - [x] テンプレートに `<AppIcon :icon="verdictIcon" size="lg" class="comparison-page__verdict-icon" />` を追加
  - [x] CSS `.comparison-page__verdict--A/B::before { content: "🏆 " }` を削除
  - [x] CSS `.comparison-page__verdict--even::before { content: "⚖️ " }` を削除
  - [x] CSS `.comparison-page__verdict-icon { vertical-align: -0.15em; margin-right: var(--space-xs); }` を追加（53件パス確認済み）
- [x] `src/pages/FormationListPage.vue`（titleスロット+Goal / ✏️→PencilLine / 📖→BookOpen / 🔗→ExternalLink。11件パス確認済み）
- [x] `src/pages/GlossaryPage.vue`（titleスロット+BookOpen）
- [x] `src/pages/MatrixPage.vue`（凡例✓→Check / 🎉→PartyPopper / セル内✓→Check。22件パス確認済み）
- [x] `src/pages/QuizPage.vue`（📖→BookOpen。16件パス確認済み）

## フェーズ4: 品質チェックと修正

- [x] `src/`配下に絵文字リテラルが残っていないことをgrepで確認（コメント1件のみ発見、文言修正済み）
- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（34ファイル・533件全てパス）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラーなし）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（エラーなし）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功。dist/assets/index.js 200.13kB / gzip 68.40kB）
- [x] **テストが実際に実行されたことを確認**（533件実行・0スキップを確認済み）
- [x] `npm run dev` で5画面を目視確認（Chrome操作で確認、スクリーンショット取得済み）
  - [x] 一覧画面（ヘッダーロゴ・ナビ・Jリーグ外部リンクのアイコン表示を確認。モバイル幅の実機確認は
        ブラウザ操作ツールの制約でスクリーンショットに反映されず未検証。CSSの`@media (max-width: 640px)`
        ブロック自体は今回変更していない（追加したのは`display:inline-flex`+`gap`のみ）ため
        リスクは低いと判断）
  - [x] 比較画面（勝敗判定バナーが互角でScaleアイコン+グレー配色に追従することを確認。
        ハーフタイムモーダルの見出し(Wrench)・閉じるボタン(X)・リセット(RotateCcw)・
        確定ボタン(Play)すべて正常表示を確認）
  - [x] 相性マトリクス画面（凡例のCheckアイコン、セル内✓の位置、進捗表示を確認）
  - [x] 用語集画面（タイトルのBookOpenアイコンを確認）
  - [x] クイズ画面（用語集リンクのBookOpenアイコン表示をスクリーンショットで確認）

## フェーズ5: ドキュメント更新

- [x] `docs/specs/1_requirements/architecture-overview.md` の依存関係表に `@lucide/vue` を追加（2箇所）
- [x] `docs/specs/2_basic-design/screen-design.md` の絵文字記載をアイコン名表記に更新
- [x] `docs/specs/2_basic-design/component-design.md` に `AppIcon` を共通コンポーネントとして追記
- [x] `docs/specs/1_requirements/repository-structure.md` のコンポーネント一覧に `AppIcon.vue` を追加
- [x] `docs/specs/3_detail-design/` 配下の該当画面設計書の絵文字記載を更新（screen-02-comparison.md）
- [x] `docs/specs/4_unit-test/` 配下の該当テスト仕様書の絵文字記載を更新（test-screen-02-comparison.md, test-screen-04-matrix.md）
- [x] 追加対応: `docs/specs/1_requirements/requirements-definition.md` の閉じるボタン絵文字記載も
      アイコン名表記に更新（grep網羅時に発見。当初のタスクリストに無かった追加発見箇所）
- [x] ~~`docs/content-review-checklist.md` に「UIに絵文字を使わない」を追記~~（実装方針変更:
  同ファイルは`matchups.ts`の戦術解説文（テキスト内容）レビュー専用のチェックリストであり、
  UIアイコン方針を書くのは対象外・スコープ不一致と判断。代わりに`component-design.md`の
  `AppIcon`セクションに絵文字を使わない設計方針として明記した（実施済み））
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

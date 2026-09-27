# 要求内容

## 概要

アプリ全体で絵文字（⚽🏆✏️📖🔗等・全31箇所）をアイコン代わりに使っている状態を、
`@lucide/vue`のSVGアイコンセットへ全面置換する。

## 背景

soccer-simは個人学習用に作ってきたが、サイト公開に向けて品質を上げるフェーズに入った。
絵文字はOS/ブラウザによって見た目が変わり、統一感を欠くうえ「個人開発感」が出やすい。
公開準備の第一弾として、まずアプリの見た目の一貫性を底上げする。

（経緯: 直近でJリーグ外部リンクの配置レビューを通じて、UI全体の絵文字利用について
「センスがない」という指摘があり、アイコン刷新に着手することになった）

## 実装対象の機能

### 1. 共通アイコンコンポーネントの新設
- `src/components/AppIcon.vue`を新規作成し、`@lucide/vue`のアイコンを
  `aria-hidden="true"` / `focusable="false"` 付きで統一的に描画する
- サイズは`sm`/`md`/`lg`の3段階（`tokens.css`の`--icon-*`変数で管理）
- 色は指定せず`currentColor`継承（既存のCSS変数体系をそのまま活かす）

### 2. `PageHeader.vue`へのタイトルアイコン用スロット追加
- `title`propの前にアイコンを差し込めるよう、名前付きスロット`#title-icon`を追加する
- スロット未使用時は現状のレイアウトを維持する

### 3. 全31箇所の絵文字をlucideアイコンへ置換
- 対応表は`design.md`を正本とする
- 装飾用途（テキストラベル併記、25箇所）は`AppIcon`の既定`aria-hidden`で対応
- 唯一の例外（`HalftimeTacticsModal.vue`の閉じるボタン、記号のみ）は既存の
  `aria-label="閉じる"`を維持したまま中身だけ置換する

### 4. `ComparisonPage.vue`のCSS `content:`埋め込み絵文字（🏆/⚖️）の移設
- `::before { content: "🏆 " }` / `::before { content: "⚖️ " }` は
  SVGを差し込めないため、テンプレート側の実要素（`<AppIcon>`）へ移設する

### 5. ドキュメント更新
- `architecture-overview.md`の依存関係表に`@lucide/vue`を追記
- `screen-design.md` / `component-design.md` / `repository-structure.md` /
  詳細設計・単体テスト仕様書の該当絵文字記載をアイコン名表記に更新
- `docs/content-review-checklist.md`に「UIに絵文字を使わない」規約を追記（再混入防止）

## 受け入れ条件

### 共通アイコンコンポーネント
- [ ] `AppIcon.vue`が`icon`propに渡したlucideコンポーネントを描画する
- [ ] 描画されたSVGに`aria-hidden="true"`と`focusable="false"`が付与される
- [ ] `size`prop（`sm`/`md`/`lg`）に応じて`--icon-*`のCSS変数サイズが適用される
- [ ] `AppIcon.test.ts`でこれらが検証されている

### 絵文字の置換
- [ ] `src/`配下のVueテンプレート・CSSに絵文字リテラルが1つも残っていない（grep確認）
- [ ] `HalftimeTacticsModal.vue`の閉じるボタンで`aria-label="閉じる"`が維持されている
- [ ] `ComparisonPage.vue`の勝敗判定バナーで、アイコンが`overallEdge`（A/B/even）に応じて
      Trophy/Scaleに切り替わり、色（青/赤/グレー）に追従する

### 品質
- [ ] `npm run typecheck` / `npm run lint` / `npm run test`が全て成功する
- [ ] `npm run build`が成功する
- [ ] `npm run dev`で5画面（一覧・比較・相性マトリクス・用語集・クイズ）を目視確認し、
      レイアウト崩れ（アイコンとテキストの縦位置ズレ、モバイル幅での折り返し崩れ）が無い

### ドキュメント
- [ ] `architecture-overview.md`の依存関係表に`@lucide/vue`の記載がある
- [ ] 設計・テスト仕様書の絵文字記載がアイコン名表記に更新されている

## 成功指標

- 絵文字リテラルがソースコード（`src/`）から完全に無くなること
- 既存のVitestテスト（絵文字非依存であることを確認済み）が全て継続して通ること

## スコープ外

以下はこのフェーズでは実装しない:

- 専用ブランドロゴ（サッカーボールのカスタムSVG等）の作成（セット中の汎用アイコン`Goal`で代替する）
- `docs/specs/2_basic-design/wireframes.drawio`内の絵文字3箇所の更新（図の更新コストが高いため後続タスク）
- サイト公開準備の他の項目（SEO/OGP、独自ドメイン、アクセシビリティ監査全般等）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` - 要件定義書
- `docs/specs/1_requirements/functional-overview.md` - 機能概要
- `docs/specs/1_requirements/architecture-overview.md` - アーキテクチャ概要（依存関係表の更新対象）
- `C:\Users\yata1\.claude\plans\rustling-enchanting-pancake.md` - 承認済み実装プラン（本要求の詳細設計の元）

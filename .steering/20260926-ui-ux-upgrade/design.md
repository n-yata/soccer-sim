# 設計書

## アーキテクチャ概要

既存の3層構成(UI/composables/data)は変更しない。本タスクはUIレイヤー内の
スタイル・コンポーネント構成の整理に閉じる。

```
src/
├── styles/
│   └── tokens.css          # スペーシング・フォントサイズ・角丸スケールを追加
├── components/
│   ├── AppHeader.vue        # 新設: 全ページ共通のグローバルナビ
│   ├── BackButton.vue       # 新設: 「← 戻る」ボタン(4ページで重複していたものを抽出)
│   └── PageHeader.vue       # 新設: グラデーションヘッダー(一覧/用語集で重複していたもの)
├── App.vue                  # AppHeaderを追加
└── pages/*.vue               # 各ページ: トークン適用・レスポンシブ対応・共通コンポーネント差し替え
```

## 実装後の判断メモ

### FormationListPageのナビゲーション二重表示について

`AppHeader`導入後も`FormationListPage.vue`は独自の相性表/リーグ戦/カップ戦/理解度チェック/
用語集リンクを`PageHeader`のスロット内に維持しており、トップページでは同じ遷移先へのリンクが
2組（グローバルナビ＋ページ固有アクション）並ぶ。

意図的に残す判断とした理由:
- `FormationListPage.test.ts`が「相性表を見る」ボタン・用語集リンク・理解度チェックリンクの
  存在と遷移先を直接テストしており、削除すると正当な既存テストを壊す
- 視覚的な重複はあるが、機能的な矛盾（片方だけ壊れる等）は無い

次にこの重複を解消する場合は、先にテストの参照先を`AppHeader`側のセレクタへ移してから、
`FormationListPage.vue`側の重複リンクを削除する順序にすること（テストを先に壊さない）。

## コンポーネント設計

### 1. AppHeader.vue(新設)

**責務**:
- 全ページ共通のグローバルナビゲーション。一覧・比較(現在の組み合わせがあればそこへ)・
  マトリクス・リーグ戦・カップ戦・クイズ・用語集への遷移導線を常時提供
- 現在地(アクティブなルート)をハイライト表示
- モバイル幅(〜640px)ではハンバーガーメニューに折りたたむ

**実装の要点**:
- `useRoute()`で現在のルート名を取得し、該当ナビ項目に`aria-current="page"`を付与
- カップ戦導線は`FormationListPage.vue`の既存ロジック(`formations.length === 8`)と
  同じ条件で出し分ける。**実装時に変更**: `components/`は`data/`配下の静的データ定義に
  直接依存できないため、`AppHeader.vue`自身は`formations`をimportしない。定数
  `CUP_REQUIRED_FORMATION_COUNT`は`data/formations.ts`にexportし、判定は`App.vue`の
  `computed`が行って`showCupLink` propsとして`AppHeader.vue`へ渡す
  （コミット前レビュー指摘対応。`review-report.md`参照）
- ハンバーガーの開閉状態は`ref`でコンポーネント内に閉じる(他コンポーネントから参照しない)
- ロゴ/タイトル部分はホームへの`router-link`にする

### 2. BackButton.vue(新設)

**責務**:
- 「← 戻る」ボタンの表示とクリック時の戻り先解決(履歴があれば`router.back()`、
  無ければフォールバック先へ`router.push`)を1箇所に集約する
  (現状MatrixPage/QuizPage/LeaguePage/CupPageで同一ロジックが4重コピーされている)

**実装の要点**:
- props: `fallbackTo: string`(履歴が無い場合の遷移先。デフォルト`"/"`)
- 内部で`window.history.state?.back`判定 + `router.back()` / `router.push(fallbackTo)`を行う
- スタイルは新設トークンを使用し、他のセカンダリボタンとクラス命名を揃える

### 3. PageHeader.vue(新設)

**責務**:
- グラデーション背景のページヘッダー(タイトル+サブタイトル)を表示する
  (現状FormationListPage/GlossaryPageで同一スタイルが重複)

**実装の要点**:
- props: `title: string`, `subtitle?: string`
- デフォルトスロットでヘッダー右側のアクション領域(ボタン・リンク群)を差し込めるようにする
- レスポンシブ: 640px以下で`padding`を縮小し、アクション領域を折り返す

### 4. 既存ページの改修(FormationListPage / MatrixPage / GlossaryPage / QuizPage / LeaguePage / CupPage / ComparisonPage)

**共通の改修方針**:
- ハードコードされた`#hex`色を`var(--color-*)`または新設トークンへ置換
  (絵文字・SVG塗り等トークン化不要な箇所は除く)
- `font-size`/`border-radius`/余白の値を新設トークンスケールへ揃える
- `@media (max-width: 640px)`を基準にモバイル対応を追加(タブレットは`768px`を目安に
  必要な箇所のみ追加)
- 「戻る」ボタンを`BackButton.vue`に置換
- `AppHeader.vue`導入に伴い、各ページが個別に持っていた他画面への導線
  (一覧画面ヘッダー内のリンク群)は`AppHeader.vue`に統合し、ページ側の重複導線は削除する

**個別対応**:
- `MatrixPage.vue`: セル`48px`固定×フォーメーション数のテーブルはモバイルで
  横スクロール必須のまま(セル数が可変でレイアウト変更の影響が大きいため、
  スコープを「セルサイズを640px以下でやや縮小」に留め、テーブル構造自体は変えない)
- `LeaguePage.vue`: `.league-page__table{min-width:640px}`は維持しつつ、
  テーブルラッパーに`overflow-x:auto`があることを確認し無ければ追加する
- `ComparisonPage.vue`: `.comparison-page__pitch-overlay{max-width:800px}`は
  640px以下で`max-width:100%`に緩和し、`.comparison-page__main`のflex-basisを
  縮小してモバイルでピッチ図が縦積みになるようにする
- `FormationListPage.vue`/`GlossaryPage.vue`: 独自の`<header>`実装を`PageHeader.vue`へ
  差し替える

## データフロー

### グローバルナビからの画面遷移
```
1. ユーザーがAppHeader.vueのナビ項目をクリック
2. router-linkが該当ルートへ遷移(vue-router標準機能。新規ロジック不要)
3. AppHeader.vue自身はuseRoute()で現在地を再評価し、アクティブ状態の表示を更新
```

### 戻るボタンの遷移解決(BackButton.vue)
```
1. ユーザーが「← 戻る」をクリック
2. window.history.state.backの有無を判定
3. 履歴があればrouter.back()、無ければprops.fallbackTo(既定"/")へrouter.push()
```

## エラーハンドリング戦略

本タスクは表示・スタイルの変更が主でロジック変更を伴わないため、新規のエラーハンドリングは
発生しない。既存の各ページのエラー表示(該当データが見つからない場合の文言等)はそのまま維持する。

## テスト戦略

### ユニットテスト
- `AppHeader.vue`: 現在地に応じたアクティブ表示の切り替え、カップ戦導線の出し分け条件
  (`formations.length === 8`)
- `BackButton.vue`: 履歴あり/なしでの遷移先分岐

### 統合テスト
該当なし(本プロダクトは実DBを持たないため結合テストは対象外。`repository-structure.md`参照)

### 手動確認
- 375px/768px/1280px幅で全8ページを目視確認(横スクロールの有無、要素の重なり)
- 既存のVitestテスト・型チェック・ビルドが通ることを確認(UI変更によるロジック破壊がないか)

## 依存ライブラリ

新規追加なし。既存のVue 3 + Vue Routerのみで実装する。

## ディレクトリ構造

```
src/
├── styles/tokens.css          # 変更: スペーシング/フォントサイズ/角丸スケール追加
├── components/
│   ├── AppHeader.vue          # 新規
│   ├── BackButton.vue         # 新規
│   └── PageHeader.vue         # 新規
├── App.vue                    # 変更: AppHeader追加
└── pages/
    ├── FormationListPage.vue  # 変更: PageHeader/AppHeader導入、トークン適用、レスポンシブ
    ├── ComparisonPage.vue     # 変更: BackButton導入、トークン適用、レスポンシブ強化
    ├── MatrixPage.vue         # 変更: BackButton導入、トークン適用、レスポンシブ
    ├── GlossaryPage.vue       # 変更: PageHeader導入、トークン適用、レスポンシブ
    ├── QuizPage.vue           # 変更: BackButton導入、トークン適用、レスポンシブ
    ├── LeaguePage.vue         # 変更: BackButton導入、トークン適用、レスポンシブ
    └── CupPage.vue            # 変更: BackButton導入、トークン適用、レスポンシブ
```

## 実装の順序

1. `tokens.css`にスペーシング・フォントサイズ・角丸スケールを追加
2. `BackButton.vue` / `PageHeader.vue`(依存の少ない小コンポーネント)を新設
3. `AppHeader.vue`を新設し`App.vue`に組み込む
4. `FormationListPage.vue`をPageHeader/AppHeader導入に合わせて改修(重複導線の削除)
5. 残り6ページ(Comparison/Matrix/Glossary/Quiz/League/Cup)をBackButton導入・
   トークン適用・レスポンシブ対応で順次改修
6. 全体を通した375px/768px/1280px目視確認
7. テスト(新規コンポーネント分)・型チェック・lint・ビルド確認

## セキュリティ考慮事項

該当なし(表示・スタイルの変更のみで、ユーザー入力・外部通信を扱わない)。

## パフォーマンス考慮事項

該当なし(静的CSS変更が主体で、追加の計算・API呼び出しは発生しない)。

## 将来の拡張性

トークンスケールと共通コンポーネント(AppHeader/BackButton/PageHeader)を整備することで、
今後ページを追加する際にスタイルの重複を作らずに済む土台を作る。

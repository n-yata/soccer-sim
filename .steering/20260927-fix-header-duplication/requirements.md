# 要求内容

## 概要

3つのユーザー指摘に対応する。①`AppHeader`と各画面`PageHeader`の間でナビ導線が重複している
問題の削除、②`wireframes.drawio`が初期実装時点のまま更新されていない問題の最新化、
③各画面が横幅を活かせず縦積みでスクロールを増やしている問題のレイアウト見直し。

## 背景

- ユーザー指摘1: 「ヘッダーと、各画面の内容重複しておかしいね。こうしている意図はなに？」
  → 調査の結果、`AppHeader`導入時に各画面側の旧ナビ（相性表/理解度チェック/用語集への
  ボタン・リンク）を消し忘れたことが原因と判明。意図的な設計ではない。
- ユーザー指摘2: 「そもそもdrawioの画面一覧は最新化されているの？」
  → 調査の結果、`wireframes.drawio`は`wireframe-formation-list`/`wireframe-comparison`の
  2ページのみで、内容はFR-01〜FR-06実装時点（プロジェクト初期）のまま。`AppHeader`未反映、
  フォーメーション6種類中2つが「拡張候補」表記（実際は8種類確定済み）、比較画面はA/B切替・
  自由配置・選手個体差・試合シミュレーション・ハーフタイム采配が未反映と判明。
- ユーザー指摘3: 「全体の画面デザイン全然ダメ。なぜ画面左側に余白がたくさん残っているのに、
  縦にどんどん配置して画面スクロールしないと見れない箇所を増やすのかがわからない。」
  → 調査の結果、`FormationListPage`のカード一覧が`max-width:640px`＋「最大3列」固定で、
  8種類のカードが3列×3行に伸びている等、複数ページで横幅を活かせていないことを確認。

## 実装対象の機能

### 1. ヘッダー重複の削除
- `FormationListPage.vue`の`PageHeader`スロットから、`AppHeader`と重複する3項目
  （相性表を見る・理解度チェック・用語集）を削除する（Jリーグ外部リンクは重複ではないため残す）
- `ComparisonPage.vue`/`QuizPage.vue`の`PageHeader`スロットから、`AppHeader`と重複する
  用語集リンクを削除する
- 上記に対応するテスト・関連ドキュメント（screen-design.md/component-design.md/
  screen-01,02,05-*.md/test-screen-01,02,05-*.md）を整合させる

### 2. wireframes.drawioの最新化
- `wireframe-formation-list`/`wireframe-comparison`の2ページに、`AppHeader`帯・
  パートA適用後のヘッダー構成・現在実装済みの主要機能ブロックを反映する

### 3. レイアウト密度の見直し
- `FormationListPage.vue`のカードグリッドの`max-width`を引き上げ、広い画面幅でより多くの
  列数を使えるようにする
- `GlossaryPage.vue`の用語リストを、広い画面幅で2カラム表示にする
- `ComparisonPage.vue`にページ全体の上限幅を導入し、広い画面で中央寄せする
- `MatrixPage.vue`/`QuizPage.vue`は現状維持（判断理由をdesign.mdに記録）

## 受け入れ条件

- [ ] `AppHeader`の一覧/相性表/理解度チェック/用語集と重複するリンク・ボタンが、各画面の
      `PageHeader`から削除されている
- [ ] Jリーグ外部リンクは`FormationListPage`に残っている
- [ ] `wireframes.drawio`の2ページが、現在のヘッダー構成・主要機能を反映している
- [ ] `FormationListPage`が広い画面幅（1568px相当）でカード一覧の列数を増やし、
      3行以内に収まる
- [ ] `GlossaryPage`が広い画面幅で用語リストを2カラム表示する
- [ ] `ComparisonPage`が広い画面幅でコンテンツ全体を中央寄せする
- [ ] 375px/768px幅で新たなレイアウト崩れ・横スクロールが発生しない
- [ ] 既存テストがすべて通り、削除対象のテスト・追加した検証テストが反映されている
- [ ] `npm run lint` / `npm run typecheck` / `npm run build`が成功する
- [ ] 関連ドキュメント（画面設計書・詳細設計書・単体テスト仕様書）が実装と整合する

## 成功指標

- 定量: 受け入れ条件をすべて満たし、テストスイートが全パスすること
- 定性: 5画面すべてでナビの重複が無く、広い画面幅で縦スクロール量が体感的に減っていること

## スコープ外

- `MatrixPage`/`QuizPage`のレイアウト変更（現状維持と判断）
- ハーフタイム采配モーダル等、drawioでの詳細な内部UI再現（主要ブロックの配置に留める）
- 新機能の追加（今回は既存UIの整理・最新化のみ）

## 参照ドキュメント

- `docs/specs/2_basic-design/screen-design.md`
- `docs/specs/2_basic-design/component-design.md`
- `docs/specs/2_basic-design/wireframes.drawio`
- 承認済みプラン: `C:\Users\yata1\.claude\plans\immutable-hatching-feigenbaum.md`

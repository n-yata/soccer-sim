# 設計書

## アーキテクチャ概要

既存のUIレイヤー（`pages/`, `components/`）に対するマークアップ・CSS整理と、ドキュメント
（`docs/specs/`, `wireframes.drawio`）の追随が中心。新規コンポーネント・新規composableは
追加しない。`architecture-overview.md`の3層構成は変更しない。

## パートA: ヘッダー重複の削除

### 対象と変更内容

- `FormationListPage.vue`: `PageHeader`スロットから「相性表を見る」ボタン（`goToMatrix`ごと）・
  「理解度チェック」リンク・「用語集」リンクを削除。「Jリーグ外部リンク」のみ残す。
  CSSは`.formation-list-page__matrix-button`（本体+hover）を削除、
  `.formation-list-page__glossary-link`/`.formation-list-page__quiz-link`をセレクタ群から除去し
  `.formation-list-page__jleague-link`単独のルールに整理する。
- `ComparisonPage.vue`: `PageHeader`スロットの用語集`router-link`を削除。
  `.comparison-page__glossary-link`とそのhover・`prefers-reduced-motion`エントリを削除。
  スロットが空になるため`PageHeader`の`v-if="$slots.default"`によりアクション領域自体が
  非表示になる（既存の仕組みをそのまま利用、追加実装不要）。
- `QuizPage.vue`: 同様に用語集`router-link`と対応CSSを削除。
- `MatrixPage.vue`/`GlossaryPage.vue`: 変更なし（スロット未使用のため重複なし）。

### テスト

- `FormationListPage.test.ts`: 「用語集リンク」「理解度チェックリンク」「相性表を見るボタン」の
  3テストを削除。Jリーグ外部リンクのテストは残す。
- `ComparisonPage.test.ts`: 「用語集画面へのリンクが'/glossary'を指す」テストを削除。
- `QuizPage.test.ts`: 「用語集画面へのリンクが'/quiz'ではなく'/glossary'を指す」テストを削除。

## パートB: wireframes.drawio の最新化

`mxfile`形式のXMLを直接編集する（draw.io GUIは使わない。`<mxCell>`の`style`/`value`/
`mxGeometry`を手で追記・修正する）。

- 両ページの先頭に`AppHeader`相当の帯（高さ~50px、白背景・下線・ブランド名+ナビ4項目）を追加。
- `wireframe-formation-list`: `PageHeader`部分をパートA後の状態に更新。フォーメーションカードを
  8種類に更新し「拡張候補」プレースホルダーを削除。
- `wireframe-comparison`: `PageHeader`部分をパートA後の状態に更新。凡例・A/B切替コントロール・
  自由配置/選手個体差トグル・ピッチ図+レーダー・優位ポイント・シミュレートボタンの主要ブロックを
  配置する。モーダル等の内部詳細は注記テキストで済ませる（プラン記載のスコープ判断のとおり）。
- `screen-design.md`のワイヤーフレーム参照文言に矛盾が生じていないか確認する。

## パートC: レイアウト密度の見直し

| ページ | 変更 |
|---|---|
| `FormationListPage.vue` | `.formation-list-page__grid`の`max-width`を`640px`→`1200px`に引き上げ。`grid-template-columns: repeat(auto-fill, minmax(160px, 1fr))`は維持（列数は画面幅に応じて自動増減）。コード内コメント「最大3列の可変グリッド」を「画面幅に応じて列数が増減する可変グリッド」に修正 |
| `GlossaryPage.vue` | `.glossary-page__body`の`max-width`を`720px`→`1000px`に引き上げ。カテゴリ内の`<dl>`に`columns: 2`（768px超で2カラム、以下は1カラムに戻す`@media`）を追加。`<dt>`/`<dd>`のペアが段抜けしないよう`break-inside: avoid`を付与する |
| `ComparisonPage.vue` | `.comparison-page__body`/`.comparison-page__error`に`max-width: 1400px; margin: 0 auto;`を追加し中央寄せする |
| `MatrixPage.vue` | 変更なし |
| `QuizPage.vue` | 変更なし（1問集中の読み物UIとして狭幅を維持する判断。理由は本セクションに記録済み） |

**ブレークポイント`769px`について**: 既存のモバイル/デスクトップ境界は`640px`に統一されている
（`AppHeader`のハンバーガー化、各ページの`@media (max-width: 640px)`）。`GlossaryPage`の2カラム
段組みだけ`min-width: 769px`という別の値を採用したのは、既存の640px境界とは性質が異なる
判断軸（「モバイルかどうか」ではなく「2カラムを組める横幅があるか」）のため。用語の
「用語（読み方）」＋説明文1件あたり最低400px前後は欲しく、2カラムなら800px前後、
サイドパディング込みで769px以上を目安にした。既存の640px境界へ統一する（2カラムの開始も
640pxにする）ことも検討したが、640〜768pxの中間幅で2カラムにすると説明文が窮屈に折り返る
ため、あえて別の境界を採用した（2026-09-27、コミット前レビューでの指摘を受けて判断理由を記録）。

### テスト戦略

- 本環境では`mcp__claude-in-chrome__resize_window`がビューポート幅を実際には変えない
  （前回UI/UX作業で確認済みの既知の制約）。CSSレビュー＋既存テストへの`getComputedStyle`
  アサーション追加で代替する。
- `FormationListPage.test.ts`に、グリッドの`max-width`が引き上がっていることを検証する
  アサーションを追加する（`getComputedStyle`で`max-width`を読み取る）。
- `GlossaryPage.test.ts`に、`<dl>`の`columns`スタイルが設定されていることを検証する
  アサーションを追加する。

## 実装の順序

1. パートA（ヘッダー重複削除）: コード→テスト→ドキュメント
2. パートC（レイアウト密度）: コード→テスト（パートAとCは同じファイルを触るため、
   Aで一度整理してからCのレイアウト変更を重ねる方が差分が追いやすい）
3. パートB（drawio最新化）: パートA・Cの結果を反映してドキュメントを更新（実装が固まってから
   最後に反映するのが手戻りが少ない）
4. 品質チェック（lint/typecheck/test/build）→ブラウザ目視確認
5. コミット前レビュー→振り返り→コミット→マージ

## セキュリティ・パフォーマンス考慮事項

該当なし（CSS/マークアップ・ドキュメントの変更のみ）。

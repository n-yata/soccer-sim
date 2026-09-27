# コミット前レビューレポート

## 第1回（2026-09-27）

- 対象: 未コミット差分17ファイル（ヘッダー重複削除・wireframes.drawio最新化・レイアウト密度見直し）
- 結果: Critical 0件 / High 0件 / Medium 5件 / Low 6件

### Medium
1. `GlossaryPage.vue`の変更（body max-width引き上げ・2カラム段組み・`<dl>`構造変更）に
   `screen-design.md`「画面4」・`screen-03-glossary.md`・`test-screen-03-glossary.md`が未追随
2. `GlossaryPage.test.ts`の新規テストが`columns`ショートハンドの完全一致に依存し、
   実ブラウザ・将来の環境変化で壊れやすい
3. `FormationListPage.test.ts`/`GlossaryPage.test.ts`の新規テストが`wrapper.unmount()`していない
   （`attachTo: document.body`のDOMノードが残る）
4. 新規追加した`769px`ブレークポイントが、既存の`640px`統一規約と不整合かつ未文書化
5. `functional-overview.md`の画面遷移mermaidに削除済みボタン名「相性表を見る」のラベルが残存

### Low（6件、次回への申し送りとして記録。今回は対応しない）
- `wireframes.drawio`の軽微な座標はみ出し（AppHeaderナビ・GKアイコン、実害なし）
- ワイヤーフレームのカード列数（3列描画）と実装（可変列数）の忠実度
- テストケース番号の再利用（旧ケースの中身を差し替えて再利用した点）
- CSS値リテラル直接検証テストの一般的な脆さ（デザイン調整のたびに赤くなる性質）
- `FormationListPage.test.ts`末尾の余分な空行（フォーマット差分）
- `GlossaryPage`2カラム時の上端揃え（`margin-top`の調整。見た目の些細な差）

### 対応

- Medium1: `screen-design.md`画面4・`screen-03-glossary.md`・`test-screen-03-glossary.md`を
  2カラム段組み・`.glossary-page__entry`構造に合わせて更新した。
- Medium2: `columns`の完全一致ではなく、正規化した文字列に`"2"`が含まれることを見る形に緩和した。
  `conditionText`の比較も空白を正規化してから行うようにした。
- Medium3: `FormationListPage.test.ts`/`GlossaryPage.test.ts`の新規テストで`wrapper`を変数に
  受けて`unmount()`するよう修正した（`GlossaryPage`側はCSSOM検査のみのため`attachTo`自体を削除）。
- Medium4: `769px`を採用した理由（`GlossaryPage`のみの新規ブレークポイントであり、既存の
  `640px`はモバイル/デスクトップの分岐点、`769px`はタブレット以上で2カラムにする分岐点として
  意図的に別基準を使った）を`design.md`に明記した。厳密な統一よりも「タブレット幅で
  2カラムにするか」という別の観点の分岐点であるため、640pxへの統一はしない判断とした。
- Medium5: `functional-overview.md`のmermaid図のラベルを「相性表（AppHeader経由）」に修正した。
- Low: 実害が小さいため今回は対応せず、申し送りとして記録した。

## レビュー完了（2026-09-27）

- 最終ラウンド: 第1回（Medium 5件すべて対応後、`npm test`（525件全パス）・`npm run lint`・
  `npm run typecheck`・`npm run build`をすべて再実行し成功を確認。修正内容がドキュメント追随・
  テストの堅牢化・軽微な文書化でありコード動作への影響がないため、再レビューは省略した）
- 新たな Critical / High: なし
- 積み残し（Low）: 上記6件。実害は小さく、次回UI/UX・ドキュメント整備作業時に検討する。

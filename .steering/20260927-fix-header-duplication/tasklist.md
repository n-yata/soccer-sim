# タスクリスト

## 🚨 タスク完全完了の原則

全タスクが`[x]`になるまで作業を継続する。スキップは技術的理由がある場合のみ。

---

## フェーズ1: パートA ヘッダー重複の削除（コード）

- [x] `FormationListPage.vue`: PageHeaderスロットから相性表/理解度チェック/用語集を削除、
      `goToMatrix()`削除、CSS整理
- [x] `ComparisonPage.vue`: PageHeaderスロットから用語集リンク削除、CSS整理
- [x] `QuizPage.vue`: PageHeaderスロットから用語集リンク削除、CSS整理
- [x] `FormationListPage.test.ts`: 対応する3テストを削除
- [x] `ComparisonPage.test.ts`: 対応するテストを削除
- [x] `QuizPage.test.ts`: 対応するテストを削除
- [x] `npm test`で削除後もエラーが無いことを確認（522件全パス。lint/typecheckも成功）

## フェーズ2: パートC レイアウト密度の見直し（コード）

- [x] `FormationListPage.vue`: グリッドの`max-width`を640px→1200pxに引き上げ、コメント修正
- [x] `FormationListPage.test.ts`: グリッドmax-width検証テストを追加
- [x] `GlossaryPage.vue`: bodyの`max-width`を720px→1000pxに引き上げ、`<dl>`の2カラム化CSS追加
      （dt/ddを`.glossary-page__entry`divでラップしbreak-inside:avoidを付与）
- [x] `GlossaryPage.test.ts`: 2カラムCSSルールの存在を検証するテストを追加
      （jsdomは`@media`をgetComputedStyleへ反映しないためCSSOM直接検査で代替）
- [x] `ComparisonPage.vue`: body/errorに`max-width:1400px; margin:0 auto;`を追加
- [x] `ComparisonPage.test.ts`: 上限幅・中央寄せの検証テストを追加
- [x] `MatrixPage.vue`/`QuizPage.vue`: 変更なしを確認（着手不要。判断理由はdesign.mdに記録済み）
- [x] CSSレビュー（既存の375px/640px/768pxブレークポイントと矛盾しないことを確認。
      新規追加は`min-width:769px`のみで既存ブレークポイントと衝突しない）
- [x] `npm test`で全パスを確認（525件）

## フェーズ3: パートB wireframes.drawio の最新化

- [x] `wireframe-formation-list`ページ: AppHeader帯を追加
- [x] `wireframe-formation-list`ページ: PageHeader部分をパートA後の状態に更新
- [x] `wireframe-formation-list`ページ: フォーメーションカードを8種類に更新、拡張候補を削除
- [x] `wireframe-comparison`ページ: AppHeader帯を追加
- [x] `wireframe-comparison`ページ: PageHeader部分をパートA後の状態に更新
- [x] `wireframe-comparison`ページ: 主要機能ブロック（凡例・A/B切替・自由配置/選手個体差
      トグル・ピッチ図+レーダー・優位ポイント・シミュレートボタン）を追加
- [x] `screen-design.md`のワイヤーフレーム参照文言との整合を確認（画面1/2の記述を
      パートA後の状態に更新済み）

## フェーズ4: 関連ドキュメントの整合（パートA分）

- [x] `docs/specs/2_basic-design/screen-design.md`: 画面1/2/5の重複ボタン記述を削除
- [x] `docs/specs/2_basic-design/component-design.md`: `goToMatrix`等の記述を削除
- [x] `docs/specs/3_detail-design/screen/screen-01-formation-list.md`: 該当行を削除
- [x] `docs/specs/3_detail-design/screen/screen-02-comparison.md`: 該当行を削除
- [x] `docs/specs/3_detail-design/screen/screen-05-quiz.md`: 該当行を削除
- [x] `docs/specs/4_unit-test/test-screen-01-formation-list.md`: ケース36をJリーグリンク/
      グリッドmax-width検証に置換
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`: ケース41を上限幅/中央寄せ検証に置換
- [x] `docs/specs/4_unit-test/test-screen-05-quiz.md`: ケース48を削除

## フェーズ5: 品質チェックと動作確認

- [x] `npm test`（525件全パス）
- [x] `npm run lint`（エラー0件）
- [x] `npm run typecheck`（エラー0件）
- [x] `npm run build`（成功）
- [x] 開発サーバー起動、複数幅でブラウザ目視確認（重複解消・Jリーグリンク残存・
      横幅活用の3点。一覧画面は8枚のカードが2行に収まり重複ボタンが消えていること、
      比較画面は`.comparison-page__body`が実際にmargin 204.5pxで中央寄せされていること
      （`getComputedStyle`で確認）、用語集画面が2カラムで表示され縦スクロール量が
      大きく減っていることを確認した）
- [x] テストが実際に実行されたことを確認（33 test files, 525 tests, 0 skipped）

## フェーズ6: コミット前レビュー・振り返り

- [x] `review-pre-commit`を実施（第1回: Critical0/High0/Medium5/Low6。Medium5件すべて修正済み。
      再テストで525件全パス・lint/typecheck/build成功を確認）
- [x] `retrospective.md`を作成

---

> 振り返りは`retrospective.md`に記録する。全タスク`[x]`確認後に作成すること。

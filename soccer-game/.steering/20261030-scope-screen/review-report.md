# コミット前レビューレポート

## 第1回（2026-10-30）
- 対象: 作業ツリーの未コミットの変更すべて（ゲームの表現範囲 S-10。`.steering/20261030-scope-screen/` を含む）
- レビュー役: サブエージェント（opus。セキュリティ観点を含むため）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 5件

## コミット前レビュー結果
対象: 作業ツリーにある未コミットの変更すべて。S-10 の新規（scope_screen.gd/.tscn/.uid、scope_screen_test.gd/.uid）、simplification_list.gd、app_theme.tres、main_shell.gd、title_screen.tscn、tutorial_screen_test.gd、screen-10/screen-01 の仕様書、.steering/20261030-scope-screen/ の3ファイル。

### Critical
指摘なし

### High
指摘なし

### Medium
指摘なし

### Low / 改善提案
1. **画面がまだ無いとき、一言と「準備中」が両方出る**（title_screen.tscn の ScopeSub・SettingsSub）
   - RecordsSub は、カードが押せない間は隠して「準備中」だけを出す。新しい ScopeSub/SettingsSub にはこの処理が無いので、押せない間は一言と「準備中」が縦に2つ並ぶ。
   - 本番では S-10 も S-12 も登録済みなので、実際には起きない。起きるのは `apply_availability` に画面の一部だけを渡すテストのときだけ。戦績と表示の規則をそろえるなら、`apply_availability` で一言を `is_available` に合わせて出し入れするとよい。
2. **一言の文言が基本設計とずれている**
   - 基本設計 screen-design.md は「実戦との違いを知る」「音量・ヒント表示」。詳細設計 screen-01-title.md（もとからある記述）と実装は「実戦との違い」「音量・ヒント」。正本の階層に従って、基本設計を直すか、意図して短くしたことを記録しておくとよい。
3. **`lead_texts()` の2番目の要素が画面を見ていない**（scope_screen.gd）
   - 返しているのは定数そのもの。将来2番目を確かめるテストを書くと、何も検証しない恒真のテストになる。LeadText のラベルの `.text` を返すとよい。
4. **テストで足りないところ**
   - ヘッダーの「← 戻る」（`back_pressed` に `_go_back` をつなぐ部分）を通る経路は確かめていない。
   - タイトルの一言の文を確かめるテストは無い。
5. **運用**: tasklist.md の全テスト・変異の確認・retrospective.md が未完了。コミットの前に完了の印を付け、振り返りを足すこと。

### 問題なし
- **セキュリティ ①ハードコーディング**: URL、エンドポイント、シークレット、キー、クラウドのアカウント情報、仕様書や .steering の機密情報は、どれも無い。res:// のパスと、画面に出す固定の文だけ。
- **②認証・認可**: 該当しない。
- **③インジェクション**: 表示は Label（BBCode を解釈しない）だけで、値は同梱の simplifications.json から来る。
- **④情報漏洩**: ログやファイルへの出力は増えていない。
- **SimplificationList の変更が S-08 に与える影響**: S-08 の側も同じ表示になる前提（requirements.md）で、tutorial_screen_test.gd も「ID 名前」に直されている。
- **テーマ CautionLabel**: 色は #FBBF77 に一致し、screen-common.md の caution とも合う。既存の型は変えていない。
- **開き直したときの重複**: 子を外してから queue_free するので、カードは重複しない。テストもある。
- **ScrollContainer**: 横スクロールは止めてあり、2列でもはみ出さない。
- **main_shell.gd**: 登録したパスは、新規の .tscn の実際の場所と一致する。
- **性能**: 一覧は開くたびに件数ぶんのラベルを作るだけ。
- **テスト**: 恒真や空振りのアサーションは無い。
- **改行コード**: 新規ファイルは LF。

### 未検証
- Godot とテストは実行していない。
- 実機での見た目（caution の色が地の上で読めるか、小さなカードの一言が収まるか）。
- 既存コード全体の監査はしていない（差分と直近の呼び出し元まで）。

### 総合評価
Critical と High の指摘は無い。セキュリティ上の懸念も無い。コミットしてよい状態。ただし、全テストが通ったことを確かめ、tasklist と振り返りを仕上げてからにすること。

## 対応（2026-10-30）

1. 直した。`apply_availability` で、小さなカードの一言（戦績・表現範囲・設定）を `is_available` に合わせて出し入れする（`_card_subs`）。戦績だけの個別の処理は外した。
2. 基本設計 screen-design.md の一言を「実戦との違い」「音量・ヒント」にそろえ、小さなカードの幅に収めるため短くしたことを書き添えた。
3. 直した。`lead_texts()` は LeadText のラベルの `.text` を返す。テストで2番目の文も確かめる。
4. 足した。ヘッダーの「← 戻る」でタイトルへ戻るテスト、タイトルの一言の文と押せない間に隠れることのテスト。
5. 下の全テスト・変異・振り返りで完了。

あわせて screen-10-scope.md のノード構成を実際の構成（MarginContainer、Lead と LeadText、スクリプトの部品の SimplificationList）に直した。

## レビュー完了

Critical・High の指摘は無い。Low はすべて対応した。

# 設計

## 1. タイトルの小さなカード
- `TitleScreen.SMALL_COLUMNS`・`SMALL_COLUMNS_WITH_TUTORIAL` を 2 にする（1つにまとめる）。`.tscn` の `columns` も 2。
- 戦績の一言の `.replace(" ", "\n")` をやめる（幅 276px に「5勝 2分 3敗」が入る）。

## 2. 手のボタンの改行
- `MatchTexts.BUTTON_LINE_BREAKS: Dictionary`（名前 → 1行目の文字数）と `slot_button_text(family, action) -> String`
  （改行の位置があれば `\n` を入れた名前、無ければ `slot_name` のまま）。
  - パスコースを切る → パスコースを／切る、ドリブルのコースを切る → ドリブルの／コースを切る、
    シュートコースを塞ぐ → シュート／コースを塞ぐ、背後へのロングボール → 背後への／ロングボール
- `ChoicePanel._add_button` は `slot_button_text` を使う。番号は1行目に付ける。
  折り返しの指定（ARBITRARY）は、決めた改行で足りないときの保険として残す。
- ボタンの幅（16:9 で 234px、内側 218px・24px の字で約9文字）に入らない名前（番号を含めて9文字を超える＝名前8文字以上）に
  改行の位置を持たせる。テストで、ボタンに出るすべての名前を調べて固定する。

## 3. ヘッダーの上の余白
- S-02（`.tscn` の Layout の `offset_top = 24`）、S-07・S-09・S-10・S-11・S-12（`_build` の layout に `offset_top = 24`）。
  画面の大きさは 720px なので、本体は 576px（screen-common.md §1.1 の寸法どおり）。

## テスト
- `choice_panel_test`: 長い名前のボタンの文字が決めた位置で改行される。短い名前は1行。
- `match_texts_test`（あれば）: 改行の位置の名前が実在する・8文字以上の名前がすべて改行の位置を持つ。
- `title_screen_test`: 列の数の期待値を 2 にする。
- ヘッダーの余白: 各画面のテストで Layout の offset_top を確かめる（1画面1行）。

## 変更するドキュメント
- screen-01-title.md（4列・5列 → 2列）、screen-common.md（ChoicePanel の改行）、screen-03-match.md（手のボタン）。docs/specs 全体を検索し .drawio も見る。

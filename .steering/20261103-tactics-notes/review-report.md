# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: ステージ済みの差分（FR-17 戦術の解説。52ファイル。game/content・data・domain・application・ui・tests、docs/specs、.steering）
- 結果: Critical 0件 / High 1件 / Medium 2件 / Low 4件

## コミット前レビュー結果

対象: `git diff --cached` のステージ済み52ファイル。差分はすべて読んだ。直接の呼び出し先として SaveDataReader・StylePicker・TeamStyles/TeamSetup.duplicate_deep・MatchController.opponent_setup・App.library が index 上にあることも確かめた。Godot のテストは指示どおり実行していない。

### Critical（即時対応必須）
なし

### High（優先対応）
- [セキュリティ A08 / バグ] `condition: {}` が検査を通り、すべての陣形の組み合わせに当たるルールになる（fail open）: `CommentaryContentReader._formation_condition` と `_style_condition` は、先頭の `if condition.is_empty(): return` で抜ける。`SaveDataReader.object()` は値が空の Dictionary `{}` でも誤りにせず `{}` を返す。そのため `"condition": {}` と書かれた FORMATION ルールは誤りが0件のまま読み込まれ、`viewer_tags` と `opponent_tags` が空になる。`CommentaryGenerator._has_all(tags, [])` は常に true なので、16通りすべての組み合わせに当たり、同じテーマの後ろのルールも消す。STYLE ルールの場合は逆に、一度も当たらないルールが黙って残る。既存のテストが確かめているのは `{"viewer_tags": [], "opponent_tags": []}` だけで、`{}` は試していない。→ 早期 return をやめ、キーが無ければ誤りを積む。`{}` のテストを足す。

### Medium（対応推奨）
- [バグ] テストの期待値が実装の写しになっている: `test_formation_notes_against_an_opponent_shows_both_sides` の期待値は `_rule_text("R20").replace("相手", "こちら")` で、実装と同じ置き換えをしている。`contains("こちらの攻撃的MF3枚")` を1件足してあるので恒真ではないが、R10 側は写しの比較だけになっている。→ 相手側の2件は、期待する語句の `contains` と `not_contains("相手")` で確かめる。
- [バグ] content テストが空のカタログでは空振りする: `commentary_content_test.gd` は `before()` でカタログを1回読むだけで、読み込みに失敗した（空のカタログ）ときに、ループを回す3つのテストが0回のループのまま通る。→ 各テストの先頭で、陣形が4件・ルールが空でないことを確かめる。

### Low / 改善提案
- [運用] `halftime_screen.gd` の `_redraw_matchup` で、1行の途中にタブが3つ入っている（行継続の `\` が抜けた痕）。動作は正しいが読みにくい。
- [バグ] `_ids` は配列の中の重複を誤りにしない。害は小さい。
- [バグ] STYLE ルールについて、守備方式×攻撃方式の8通りがそろっているかを読み込み時には確かめていない（content テストで担保されている）。
- [運用] `matchup_rules.json`・`styles.json` は2スペース、`formations.json` はタブでインデントしている。見た目だけの違い。

### 問題なし
- ①ハードコーディング・シークレット: 差分に URL・キー・トークン・アカウント情報は無い。docs と .steering にも機密は無い。
- ②認証・認可: 対象外（ローカルの同梱データと画面だけ）。
- ③インジェクション・表示: 解説の文は NotesView の `Label.text` に代入するだけで、RichTextLabel や BBCode は使っていない。MiniPitch に出すのは数値と固定の記号（▲＝▼）だけ。
- ④情報漏洩: エラーは push_error に「場所: 理由」を出すだけ。
- A08（上の1件を除く）: 最上位の型、format_version、件数の上限、ID の正規表現（`^...$` で固定）、4方式がそろうこと、kind と ID の対応、守備方式と攻撃方式の組、原則と単純化の ID の存在、fallback の必須を確かめている。誤りが1件でもあれば ContentRepository は空のカタログを返す（fail closed）。
- バグ: StylePicker は値を写して持つ。`_redraw_matchup` は初期化前を除外している。`matchup_counts` は陣形が無ければ空。同じ陣形どうしは相手側を出さない。ルール文に「こちら」が無いことはテストで担保されている。27件の文を目で確かめ、置き換えで意味が崩れる文は無かった。
- テスト: reader のテストは本物の JSON を1か所ずつ壊して確かめていて空振りしない。generator・formation_tags・notes_view のテストも具体的な入力に対する出力を確かめている。
- 性能: ルールは26件・陣形は4つで線形に回すだけ。I/O は起動時の読み込みだけ。
- 運用: data-definition.md・画面詳細設計・component-design に新しい項目・制約・fallback が書かれている。revert で戻せる。

### 未検証
- テストの実行結果（Godot を実行しない指示のため）。特に、未知の陣形のテストの2回目の呼び出しが assert_error の外で push_error を出すことを gdUnit が失敗とみなさないか。
- 新しい .gd の改行コード。
- 実際の画面の見た目（NotesView のスクロール、MATCHUP_CELL 76×40 に「1−0▲」が収まるか）。
- 未ステージの変更（別セッションの作業）と組み合わせたときの整合。

### 総合評価
Critical はなし、High は1件（`condition: {}` が検査をすり抜ける fail open）。これを直し、`{}` のテストを足してからコミットすることを勧める。

### 対応
- High: `_formation_condition`・`_style_condition` の早期 return を消した（条件が空でも、キーが無い誤りを積む）。`test_an_empty_condition_is_an_error_for_both_kinds` を足した（最初の FORMATION ルールと最後の STYLE ルールの condition を `{}` にすると `rules[i].condition.` の誤りが出る）。修正前に落ちる（Red）ことを確かめてから直した。
- Medium（実装の写し）: 相手側の2件について、置き換えた後の語句（「こちらの攻撃的MF3枚」「こちらの守備的MF2枚」）が入ること・「相手」が残らないことを確かめる行を足した。
- Medium（空振り）: `_assert_loaded()`（陣形4件・ルール 18+8 件・代わりの文がある）を、ループを回す3つのテストの先頭で呼ぶようにした。
- Low（タブ）: `\` と改行で2行に分けた。
- Low（そのほか）: 重複 ID・方式ルールの網羅は content テストで担保、インデントは見た目だけのため直さない。
- 未検証のうちテストの実行は、修正後に対象のスイートを流して確かめた（reader 16件・content 7件・library 15件・画面 18件、すべて成功。未知の陣形のテストも通っている）。新しい .gd は LF。画面の見た目は未確認（スクリーンショットは未実施）。

## 第2回（2026-11-03）— 修正後の再レビュー
- 対象: 第1回の修正箇所とその周辺（commentary_content_reader.gd の `_formation_condition`・`_style_condition`、reader・content・library のテスト、halftime_screen.gd の `is_first_half` の行）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

### 前回指摘の解消状況
- High（condition `{}` のすり抜け）: 解消。キーが無いと `SaveDataReader.array`・`text` が型の誤りを積む（件数の検査より前に型を見る）。`{}` の FORMATION ルールは3件、STYLE ルールは2件の誤りになる。condition がオブジェクトでない場合も、誤りが重なるだけで `read_rules` は結果を空にし、ContentRepository は空のカタログを返す（fail closed）。テストは誤りの場所と、結果が空・fallback が null であることを確かめている
- Medium（library のテストが実装の写し）: 解消。置き換えた後の語句を固定の文字列で確かめている（R20・R10 の「相手」はどちらも1回だけで、検証として意味がある）
- Medium（content テストの空振り）: ほぼ解消（Low 1 に残り1件）
- Low（行中のタブ）: 解消

### Low
1. `test_every_formation_and_style_has_a_profile` が `_assert_loaded()` を呼んでいない（同じスイートのほかのテストが落ちるので実害は小さい）。`_assert_loaded()` は方式の件数を確かめていない
2. data-definition.md の「いずれかが1件以上」は、片方のキーを省いてよいとも読める。実装は両方のキーを必須にしている（fail closed の向き）

### 問題なし
- `_style_condition` は片方が空なら早期に抜け、空文字で `STYLE_KINDS` を引かない。`_style_id` は未知の方式を誤りにして `""` を返す
- 修正箇所の周辺にハードコーディング・インジェクション・情報漏洩は無い

### 未検証
- Godot でのテストの実行（レビュー役は実行していない）
- `\` の直後の CRLF を行の継続として扱うこと

### 対応
- Low 1: `_assert_loaded()` に方式が4件あることを足し、`test_every_formation_and_style_has_a_profile` の先頭でも呼ぶようにした
- Low 2: data-definition.md を「両方のキーが必須（空の配列は可）で、いずれかが1件以上」に直した
- 未検証のテストの実行は、修正後に対象のスイートと全体テストを流して確かめた（halftime_screen.gd の `\` の継続も、S-05 のテストが通ることで確かめた）

## レビュー完了（2026-11-03）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Low）: `_ids` が配列の中の重複を誤りにしない（害は小さい）、方式ルールの8通りの網羅は読み込み時ではなく content テストで確かめる、JSON のインデントの違い（見た目だけ）

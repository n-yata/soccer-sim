# コミット前レビューレポート

## 第1回（2026-11-05）
- 対象: choice_panel.gd、match_board_panel.gd、move_detail_view.gd（新規）、tutorial.json、choice_panel_test・match_board_panel_test・match_screens_test、仕様書の該当差分。並行セッションの差分（駒の動き）は対象外
- 結果: Critical 0件 / High 0件 / Medium 3件 / Low 6件

## コミット前レビュー結果

対象: 手のボタンを「番号と行動の名前」だけにし、行き先・判断材料・説明を「詳細」ボタンで開くポップアップ（MoveDetailView）へ移した変更。対象ファイルは choice_panel.gd、match_board_panel.gd、move_detail_view.gd（新規）、tutorial.json、関連する3つのテスト、仕様書の該当差分。並行セッションの差分は見ていない。ファイルは一切書き換えていない。

### Critical
指摘なし

### High
指摘なし

### Medium
1. **[バグ] バックパスの詳細に空白だけの行が出る（テストでは見つからない）**
   - 場所: `match_board_panel.gd` の `_detail_hint_line`。
   - 原因: `move_hints.gd` では、バックパスに「行き先あり・人数を比べない（is_compared=false）」のヒントが付く。このとき `hint_tag` も `hint_counts` も空になる。そのため `"%s　%s"` は全角スペース1文字になる。Godot の `strip_edges()` が消すのはコード 32 以下の文字だけで、U+3000 は残る。`MoveDetailView.open` は `is_empty()` の行しか除かないので、ヒント ON でバックパスを選ぶと、行き先と説明の間に空白の行が出る。「読み次第」「オフサイド」などで人数が空のときは、末尾に全角スペースが残る。
   - テストで見つからない理由: `test_the_detail_explains_the_rule_of_the_chosen_move` は `ends_with(rule)` で比べているので、この行があっても通ってしまう。
   - 修正例: 空でない部分だけを集めてつなぐ。あわせて、バックパスでは詳細の本文が `is_equal("<行き先>\n<規則>")` になることを確かめるテストを足すとよい。

2. **[バグ/運用] ポップアップを開いたまま、メニューと戻るキーが下で動く**
   - 前提: MoveDetailView は BoardPanel の子なので、暗い幕は BoardPanel（高さ 600px）しか覆わない。上部バーのメニューボタンは押せたまま残る。
   - (a) Android の戻るキー（`MatchMenuHost.handle_back`）は、ポップアップを閉じずにメニューを開く。ほかの重ねる部品と振る舞いが違う。
   - (b) ポップアップを開いたままメニューの設定でヒントを切り替えると、`set_show_hints` から `_on_action_selected` が呼ばれ、`_detail_lines` は作り直される。しかし開いているポップアップの文は古いまま残る。ヒントを OFF にしても判断材料の行が見え続ける。
   - 修正例: `set_show_hints` の最後に、開いていれば開き直す処理を足す。戻るキーは MatchScreen の `route_back` で、ポップアップが開いていれば先に閉じて true を返す。ほかに、ポップアップを開いている間は `_can_open_menu` を偽にする手もある。

3. **[運用/ドキュメント] screen-03-match.md に古い記述が残っている**
   - 「ターンを始める」2.: `ChoicePanel.show_options(_options, snapshot.turn_kind, snapshot.user_has_ball, _hints)` と引数が4つのままで、「枠の並びで1列に並べ」と書いてある。実装は引数3つ・2列。
   - 部品の木: `PrimaryButton` が新しい `PrimaryRow`（HBoxContainer）の中に移ったこと、`DetailButton` があること、`MoveDetailView`（BoardPanel の最後の子）があることが書かれていない。ChoicePanel の注記「攻撃の手は6つで2列×3段。奇数個の局面は最後の1つを列の幅いっぱい」は、今回の「4つまで」と食い違う。実装（GridContainer）は最後の1つを幅いっぱいにしない（攻撃3手のとき③は半分の幅）。

### Low / 改善提案
- [バグ/テスト] `test_the_detail_button_works_only_while_a_move_is_chosen` の「決定後にポップアップが閉じている」は空振りしている。決定の前に一度も開いていないため。開いてから決定し、閉じることを確かめるべき。
- [バグ/テスト] ヒントの札と人数の行（例「+1　1対0」）が詳細に出ることを確かめるテストが無い。
- [運用/UX] 「閉じる」でポップアップを隠しても、フォーカスが「詳細」ボタンに戻らない。キー操作だとフォーカスを失う。
- [品質] `match_texts.gd` の `choice_target_line` のコメント「手のボタンの2行目（行き先）」が古くなっている。今は詳細の1行目。
- [品質] 見出しは中身の手の名前（「スルーパス」）で、1行目は「スルーパス → 敵陣・中央」なので、名前が2回出る。押したボタンの「① ショートパス」とも名前が違う。見出しに番号と枠の名前を添えるか、1行目は `→ 敵陣・中央` だけにすると対応が分かりやすい。
- [品質] `unbind()` でポップアップを閉じていない。今は次の `start_turn` で閉じるので実害は無いが、`_state = IDLE` と一緒に閉じておく方が安全。

### 問題なし
- セキュリティ①〜④: ハードコーディングなし（tutorial.json の変更は案内文だけ）。認証・認可はこのオフラインのゲームには無い。外部入力は無く、Label の text は内部の固定の文で BBCode も使っていない。ログもエラー出力も足していない。OWASP Top 10 に当たるものは無い。
- 状態のリセット: `start_turn` は「詳細」を押せなくしてポップアップを閉じる。`_on_turn_resolved` は「詳細」を隠しポップアップを閉じる。`_on_detail_pressed` は READY のとき以外は受け付けない。前のターンの詳細の見出しと行は、選び直すたびに作り直される。
- ModalOverlay の幕が BoardPanel 内のクリックを止めるので、ポップアップを開いている間は手のボタンも「決定」も押せない。メニューを重ねてもフォーカスの閉じ込めは衝突しない。
- `ChoicePanel.show_options` の古い引数を渡している呼び出し元は残っていない（TargetInfo／target_info_text の残りも無い）。
- 性能: 新しい計算量の増加や I/O は無い。2フレーム待つ await を消したので、むしろ減っている。
- `test_every_move_button_is_visible_without_scrolling_on_the_match_screen` は、画面の実寸で全ボタンが SideScroll の中に収まり、スクロール量が 0 であることを確かめている。

### 未検証
- テストは実行していない。Godot での実機表示も見ていない（ポップアップの見た目、2列のボタンで長い手の名前の折り返し）。
- wireframes.drawio は「詳細」を含む文字列を抜き出して確かめただけで、図の配置は見ていない。
- `strip_edges()` が U+3000 を消さないことは、Godot 4 の実装に基づく判断で、実行しての確認はしていない。

### 総合評価
Critical／High は指摘なし。コミットは可能な水準。Medium 1 は小さな修正で直るので、コミット前に直すことを勧める。Medium 2・3 も同じコミットか直後に直すとよい。

### 対応
- Medium 1（バックパスの空白の行）: 判断材料の行は、ヒントの札と人数のうち空でないものだけをつなぎ、どちらも無ければ出さないようにした。本文全体を手ごとに `is_equal` で確かめるテストを足した
- Medium 2（戻る操作・ヒントの切り替え）: 戻る操作は、メニューが開いていなければ先に詳細を閉じる（`MatchScreen.handle_back`。テストを足した）。開いたままヒントを切り替えたら、判断材料の行を出し直す（テストを足した）
- Medium 3（仕様書）: screen-03-match.md の部品の木（`PrimaryRow`・`DetailButton`・`MoveDetailView`）、ChoicePanel の注記、「ターンを始める」の引数を直した
- Low（決定で閉じるテストの空振り）: 開いてから決定し、閉じることを確かめる形にした
- Low（判断材料の行のテスト）: Medium 1 のテストで確かめる
- Low（フォーカス）: 「閉じる」・戻る操作で、フォーカスを「詳細」に戻す（`close_detail`）
- Low（古いコメント・見出しの重複）: 見出しを「① ショートパス（スルーパス）」の形にし、1行目を「行き先: 敵陣・中央」にした。使わなくなった `MatchTexts.choice_target_line` とそのテストを消した
- Low（unbind）: `unbind` でポップアップを閉じる

## レビュー完了（2026-11-05）
- 最終ラウンド: 第1回（Critical / High が無かったため再レビューなし。修正後に全体テスト 1140 件成功・137 秒）
- 新たな Critical / High: なし
- 積み残し: なし

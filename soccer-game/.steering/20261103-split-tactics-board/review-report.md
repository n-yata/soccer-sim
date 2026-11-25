# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: tactics_board.gd・board_painter.gd の差分、新規の board_geometry.gd・board_reveal.gd・result_effect_painter.gd・board_geometry_test.gd（と .uid）、component-design.md・repository-structure.md の該当箇所、`.steering/20261103-split-tactics-board/`。別セッション（手の選択の簡素化）の作業ファイルは対象外
- レビュー役: general-purpose（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 4件

## コミット前レビュー結果
対象: tactics_board.gd・board_painter.gd の差分、新規の board_geometry.gd・board_reveal.gd・result_effect_painter.gd・board_geometry_test.gd（と .uid）、component-design.md・repository-structure.md の該当箇所、.steering/20261103-split-tactics-board/。別セッションの作業ファイルは見ていない。ファイルへの書き込みはしていない。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
1. 【運用・保守性】BoardReveal の `shift`・`effect`・`effect_progress` が公開の var なので、外から書き換えられる。いまの呼び出し元は TacticsBoard の中継だけ（`grep` で `_reveal` 以外からの参照が無いことを確認した）なので実害はない。気になるなら、`effect` を読み取り専用のプロパティにする方法がある。
   ```gdscript
   var effect: Dictionary:
       get: return _effect
   var _effect: Dictionary = {}
   ```
   リファクタリングの範囲を超えるので、見送ってよい。
2. 【バグ（無害）】`start_shift` の中で `_reveal.stop()`・`clear_effect()` を呼び、さらに `BoardReveal.start()` の中でも同じものを呼ぶので、1回の開示で stop と clear が2回ずつ走る。2回目の stop が来る時点で `_landing_pending` は false なので、`landed` は二重には出ない。`changed` は余分に2回出るが、`queue_redraw` は何度呼んでも描き直しは1回なので実害はない。順番（止める → 着地の受け手が動く → いまの盤面で拍を組む）は元のコードと同じ。おまけとして、着地の受け手が中で `start_shift` を呼び直したとき、元のコードは入れ子の Tween を kill せずに上書きしていた。新しいコードでは start() の中の stop() がその Tween を kill するので、むしろ安全になっている。
3. 【運用・ドキュメント】tactics_board.gd の中継の関数のうち、`plan_area_at`・`piece_step`・`piece_radius`・`piece_center`・`slot_center`・`_ball_point` は `##` のコメントが消えた（説明は BoardGeometry 側に移っている）。公開の面として残すなら、「BoardGeometry.xxx を参照」の1行があるとエディタのヘルプで追いやすい。
4. 【バグ（テストの堅さ）】board_geometry_test の `top.get_center().x == SIZE.x / 2.0` は、float32 の Rect2 を `is_equal` で比べている。いまの値では丸めがちょうど 340.0 になるので通る（62件が通っている報告と矛盾しない）が、SIZE を変えると落ちやすい。`is_equal_approx(SIZE.x / 2.0, 0.001)` にしておくと安全。

### 問題なし（確認済み項目のリスト、観点ごと）
**セキュリティ**
- ① ハードコーディング・シークレット: 差分にも .steering の3ファイルにも、URL・キー・トークン・アカウント情報は無い（.steering は grep で確認）。出てくる定数は描画の寸法だけ。
- ② 認証・認可: 対象外。オフラインのゲームで、差分は UI の描画と位置の計算だけ。
- ③ インジェクション: 外から入る値はエリアのキーだけ。`PitchArea.from_key` が null を返すと空の Rect2 になり、その経路はテストしてある（"X-9"）。シェル・クエリ・ファイルの入出力は無い。
- ④ 情報漏洩: ログもエラーの出力も追加されていない。
- OWASP: 該当する項目は無い。A08 も、保存ファイルや外部データを読み込む処理が差分に無いので対象外。

**バグ・正しさ**（`git show HEAD:` と突き合わせた）
- 式・定数・既定値: GOAL_WIDTH_RATE 0.16・GOAL_DEPTH 8・PIECE_DIAMETER 26・PIECE_STEP 36・PIECE_ROW_RATES [0.50, 0.72]・PIECE_COLUMNS 2・GAP 6・MARGIN 2・MAX_PIECES 4・BALL_TOP_RATE 0.26・BALL_RADIUS 11 がすべて同じ値。cell_size・area_rect・plan_area_at（端を含まないこと・clampi）・goal_rect・ball_point・piece_step・piece_radius・piece_center・slot_center（`mini(slot, MAX_PIECES-1)`）の式も一字一句同じ。
- 開示の進行: start の手順（shift.start → `_result` の duplicate → `_landing_pending` を立てる → 1拍目が無いか keyframe≠0 ならすぐ `_land` → active でなければ return → Tween を組む → finished で stop）、stop の手順（kill → clear → 待っている着地があれば landed → 描き直し）、`_land` の条件（draws_mark・`_result_sec > 0`・is_inside_tree）、set_result_sec の is_finite がすべて元と同じ。`is_inside_tree()` を呼ぶノードが子ノードに変わったが、子は親と同時に木に入るので結果は同じ。
- 子ノードを _init で add_child する形: Tween は BoardReveal に結び付く。BoardReveal の process_mode は INHERIT なので、止まる・動く条件はボードと同じ。ボードを free すると子も消え、子に結び付いた Tween も一緒に止まる。パネルの中も tests/ui の中も、ボードの子を数えたり辿ったりするコード（get_child・get_children・find_child）は無い（grep で確認）。TacticsBoard を置いている .tscn も無く、作るのはコードの1か所（match_board_panel.gd:442）だけなので、名前 "Reveal" がぶつかることもない。
- シグナル: `landed → play_landed.emit` と `changed → queue_redraw` は _init で1回だけつないでいるので、二重にはつながらない。
- board_painter: `_quad` を `quad` に改名し、それを隠していたローカル変数を `corners` に変えた。`_quad(` の呼び残しは無い（grep で確認）。ResultEffectPainter の中身は元の `_draw_result_effect`・`_draw_ring`・`_draw_flag` と同じで、`_color` も BoardPainter のものと同じ。呼ぶ位置（立っているものの後、札の前）も変わっていない。
- 消した内部メンバ・定数（`_shift`・`_effect`・`_land`・`TacticsBoard.PIECE_*`・`GOAL_*`・`BALL_TOP_RATE` など）を外から読んでいる箇所は無い（game/ 全体を grep）。
- board_geometry_test: 実装をなぞったテストではない。並び方の向き・段・最後の位置で止まること・端ちょうどの境界・空のキー・狭い盤で縮むことを、関係として確かめている。狭い盤の不等式は 6 + 11×2 + 2 = 30 ≤ 30 で、境界ちょうどを突いているので空振りではない。

**性能**
- 中継が1段増えただけで、計算量は変わらない（cell_size を毎回計算し直すのは元のコードも同じ）。描画の呼び出しが1フレームに数百回になっても、1回あたり関数呼び出しが1つ増えるだけ。

**運用**
- 後方互換: 外から読まれている `MAX_PIECES`・`BALL_RADIUS` は BoardGeometry を指す定数として残っている。`MIN_CELL`・`THEME_TYPE`・`DRAWN_REASONS`・`HINT_HEIGHT` はそのまま。公開の関数の名前と引数、シグナル `area_pressed`・`play_landed` も変わっていない。const が別クラスの const を参照する形だが、BoardGeometry は TacticsBoard を参照しないので、循環にはならない。
- ドキュメント: component-design.md の注記と repository-structure.md の board2d/ の行は、実装の分け方と合っている。
- 切り戻し: 動作を変えないリファクタリングで、コミット1つを revert すれば戻せる。

### 未検証（確認できなかった範囲と理由）
- Godot のテストと実行時の挙動: 指示どおり実行していない。報告にあった「62件が通る」「スクリーンショットの差分がほぼ 0」は、私自身では確かめていない。
- .steering の3ファイル: 機密情報の grep だけで、内容の正しさは読んでいない。
- 改行コード: git が「LF は CRLF に置き換わる」と警告している。一方で差分は小さいので、作業ツリーでの扱いは正規化されているとみている。コミット後に毎回全行の差分が出ないかは確かめていない。

### 総合評価
Critical・High の指摘は無い。コミットしてよい。Low の4（float の is_equal を approx にする）は、ついでに直しておくのがおすすめ。コミットするときは、別セッションの変更を混ぜないよう、対象のファイルだけを stage すること。

### 対応
- Low 1: 直さない。いまの読み手は TacticsBoard の中継だけで、読み取り専用にするのは分割の範囲を超える。
- Low 2: 直さない。二重の stop・clear は無害で、順番を元に戻すための意図した形（実装レビューの指摘）。
- Low 3: 直した。中継の関数に「BoardGeometry の同名の関数」を指す1行を足した。
- Low 4: 直した。ゴールの中央の x を近似で比べる形にした。

## レビュー完了（2026-11-03）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: Low 1（BoardReveal の公開の var を読み取り専用にする）。実害は無い

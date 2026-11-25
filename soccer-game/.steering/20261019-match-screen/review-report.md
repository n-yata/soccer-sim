# コミット前レビューレポート

## 第1回（2026-10-21）
- 対象: 未コミットの差分すべて（S-03〜S-06・S-02 の試合開始・MatchController の S-03 要求と leave_result・テスト・設計書・ステアリング）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 5件
- 注: レビュー役の返答をそのまま記録する。ローカルの絶対パスの例示は無い（検索した文字列の種類だけを書いている）。

## コミット前レビュー結果

対象: `git status --untracked-files=all` の未コミット差分すべて。変更10ファイルは `git diff` で全行を見た。新規ファイルのうち、本体（board2d 3本、common 5本、S-03〜S-06 の .gd と .tscn）、テストの screen_test_helper.gd と match_flow_test.gd、steering の tasklist.md は全文を読んだ。それ以外の新規テストとステアリング文書は、検索による検査だけ行った（「未検証」を参照）。

**結論: Critical / High の指摘はない。**

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- 指摘なし

### Low / 改善提案
- **[バグ] 運ぶ先を持たない手のヒント文が、最後のヒントで上書きされる**（`game/ui/board2d/match_board_panel.gd` の `_on_action_selected` の後半）
  - ループの中で毎回 `info = MatchTexts.hint_counts(hint)` と代入している。同じ手にヒントが2件以上あり、最後の1件が人数を比べないヒントだと、前の「比べる人数」が空で上書きされ、説明が出ない。
  - 今のデータでは1つの手にヒントは1件と思われるので、実害は出にくい。
  - 直し方の例: 最初に空でない値を取ったら抜ける。
    ```gdscript
    for hint: ChoiceHint in _hints_for(family, action):
        var counts: String = MatchTexts.hint_counts(hint)
        if not counts.is_empty():
            info = "比べる人数 %s" % counts
            break
    ```
- **[運用] 画面の切り替えに失敗すると、操作できない状態のまま止まる**
  - 画面の切り替えは `call_deferred` で遅れて実行される。それより先に、S-02 は STARTING、S-04・S-05 は SUBMITTING、S-06 は LEAVING、S-03 のパネルは LEAVING へ移り、ボタンを無効にしている。
  - 切り替え先の画面が開けなかった場合、元の画面はその状態のまま残る。S-03〜S-05 は戻る操作も何もしないので、操作の手段が無くなる。
  - S-03 の `enter` で試合が始まっていないときは、push_error して return するだけで、盤面は空のまま、戻る操作も効かない。
  - どれも開発時の誤りでしか起きない（画面は4つとも登録済みで、通しの試合のテストで実際に開けることも確かめている）。今は申し送りでよい。
- **[運用] 寸法の値が2か所にある**
  - `FormationCard.FULL_SIZE (300, 260)` と、`formation_card.tscn` のルートの `custom_minimum_size` が同じ値を別々に持っている。
  - 両方に注記はある。食い違ったときにテストで気づけるよう、`.tscn` の値と `FULL_SIZE` が等しいことを確かめるテストを1本足すと安全。
- **[運用] tasklist.md のフェーズ5の記述が混乱している**（`.steering/20261019-match-screen/tasklist.md`）
  - 「repository-structure.md（§3.2 に S-03 の要求と…）」と書いてあるが、§3.2・§5.3 などの変更は実際には component-design.md に入っている。同じ文の後半では「repository-structure.md は変更なし」とも書いている。取り違えないよう書き直すとよい。
- **[バグ／テスト] 失敗の経路のテストが無い**（申し送り済み）
  - S-02 で `start_match` が false を返したときに `_refresh()` で READY へ戻す経路と、パネルで `submit_turn` が false を返したときに `start_turn()` で選び直させる経路は、テストが無い。
  - コードを読む限り、`_refresh()` は3項目が選ばれていれば READY に戻るので、正しく動く見込み。偽の MatchController（または失敗する OpponentPolicy）を差し込めば、テストで固定できる。

### 問題なし
- **セキュリティ①（ハードコーディング・シークレット）**
  - 変更と新規のすべてのファイルを、URL・WebSocket URL・api_key・secret・token・password・ARN・amazonaws で検索して、該当なし。
  - ローカルの絶対パス・ユーザー名・メールアドレス・claude.ai や artifact へのリンクも検索して、該当なし（`.steering/` と `docs/` を含む）。「Users」で1件ヒットしたが、識別子の `_user_setup_label` で無関係。
  - `.gitignore` に `.env`・`.env.*`・`export_presets.cfg*`・`*.keystore`・`.godot/` が入っていることを確かめた。`game/export_presets.cfg` が無視されることも `git check-ignore` で確かめた。export_presets.cfg も署名鍵も差分に含まれていない。
- **不可視文字・制御文字**
  - 行の途中のタブ・NUL・制御文字・ゼロ幅文字・BOM・双方向制御文字を検索して、0件。
  - 行頭以外のタブも0件。CR が入っているファイルも0件で、作業コピーは LF（Git の警告は autocrlf によるもので、問題ない）。
- **セキュリティ②〜④・OWASP**
  - オフラインの単体アプリで、差分に通信・永続化・認証・外部の入力・ログ出力（push_error 以外）は無い。push_error に出るのは陣形 ID と固定の文言だけで、機密は含まない。該当なし。
- **バグ・正しさ**
  - MatchController: S-03 を要求するのは、`start_match`・`submit_style_change`・`submit_halftime` が成功したときだけ。失敗の経路の early return より後に置かれている。`leave_result` は試合が終わる前なら push_error して false を返し、何も要求しない。テストの期待値の変更（要求の並び）も、実装と合っている。
  - 二度押しの防止: S-02 は STARTING、パネルは SUBMITTING・LEAVING、S-04・S-05 は SUBMITTING、S-06 は LEAVING で防いでいる。切り替えは deferred で遅れるが、その間に押されても状態の確認で弾かれる。
  - シグナルの後始末: S-03 の `exit` とパネルの `unbind` で、シグナルの接続を外している。画面は切り替えのたびに作り直すので、接続が残らない。
  - 盤面: `area_at` は盤面の大きさが0のとき、範囲の確認で空文字を返すので、ゼロ除算にならない。駒が上限を超えたときの「+N」、押したエリアの中で離したときだけ選ぶ判定も確かめた。
  - テーマ: 差分が参照するテーマの型（`TagLabel`・`CardTitleLabel`・`MutedLabel`・`SectionTitleLabel`・`KickOffSubLabel`・`KickOffLabel`・`AccentCard`・`PanelLabel` と新規の型）は、すべて app_theme.tres にある。
  - テスト: 恒真のアサーションは検索して見当たらない。通しの試合のテストは、MainShell の上で画面の操作だけを使い、S-01 から S-06 を通って S-01 へ戻り、2試合目の開始まで確かめている。
- **性能**
  - `_draw` は15エリアの固定のループで、件数に上限がある。`queue_redraw` は値を変えたときだけ呼んでいる。I/O は増えていない。
- **運用**
  - 差分は revert で戻せる（マイグレーションや外部への送信は無い）。
  - 設計の変更は component-design.md に反映済み。今回の範囲から外したもの（3D 演出、メニュー、終了処理）は、各ファイルの冒頭と design.md に書かれている。

### 未検証
- Godot でのテストの実行と、変異の結果は再実行していない（依頼元の報告による。437件すべて成功、変異は22個中21個を検出）。
- テストの一部（choice_panel・judge_reason_formatter・match_board_panel・match_screens・match_texts・tactics_board の各テスト）と、`.steering/` の design.md・requirements.md は、全文を読んでいない。検索による検査（恒真のアサーション、機密、絶対パス、不可視文字）だけ行った。
- 実機での見た目と、タッチ操作は見ていない。盤面はマウスのイベントだけを受けており、タッチはマウスのエミュレーションに頼っている。

### 総合評価
Critical / High はないので、コミットしてよい。Low の指摘は申し送りでよい。ただし、運ぶ先を持たない手のヒント文の件は、直すかテストで固定することを勧める。

### 対応
- Low（ヒント文の上書き）: 直す。最初の空でない「比べる人数」で抜ける。
- Low（寸法の値が2か所）: `formation_card.tscn` の値と `FULL_SIZE` が等しいことを確かめるテストを足す。
- Low（tasklist の記述）: フェーズ5の記述を書き直す。
- Low（画面の切り替えに失敗したときの止まり方）: 申し送る。開発時の誤り（画面が未登録・試合が始まっていない）でしか起きず、4つの画面が開けることは通しの試合のテストで確かめている。メニュー（中断）を作る作業で、試合中の画面から出る手段と合わせて見直す。
- Low（失敗の経路のテスト）: 申し送る。画面の操作では起こせない経路。失敗する OpponentPolicy を差し込むテストを、保存の作業で開始の経路を見直すときに足す。

#### 対応の結果
- ヒント文の上書き: 最初に空でない「比べる人数」で抜けるように直した。
- 寸法の写し: `formation_card.tscn` のルートの大きさと `FULL_SIZE` が等しいこと、小さい版から通常の大きさへ戻ることを確かめるテストを足した。
- tasklist の記述: フェーズ5を、ファイルごとに分けて書き直した。
- テストは 438 件すべて成功。
- 再レビューはしない。Critical / High の修正ではないため（スキルの規則: Medium / Low はループを回す理由にならない）。

## レビュー完了（2026-10-21）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Low）:
  - 画面の切り替えに失敗したとき、元の画面が操作できない状態で止まる（開発時の誤りでしか起きない。メニューの作業で見直す）。
  - `start_match`・`submit_turn` が false を返す経路のテストが無い（画面の操作では起こせない。保存の作業で、失敗する相手を差し込むテストを足す）。

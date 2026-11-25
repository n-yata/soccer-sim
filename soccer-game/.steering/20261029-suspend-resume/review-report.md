# コミット前レビューレポート

## 第1回（2026-10-29）
- 対象: 中断・再開（FR-14）。git diff の19ファイル（docs/specs の5ファイル、app.gd・match_controller.gd・match_screen_layout.gd・app_theme.tres・main_shell.gd・S-01/S-03/S-04/S-05、テスト4本）と、新規19本（suspend_keeper・save_data_reader・save_file_io・suspended_load・suspended_match_decoder/encoder/store・confirm_dialog・match_menu・match_menu_host・modal_overlay・new_match_gate・toast_view と各テスト）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 6件

## コミット前レビュー結果（中断・再開 FR-14）

対象: 依頼にあった git diff の 19 ファイルと、新規ファイル 19 本（suspend_keeper / save_data_reader / save_file_io / suspended_load / suspended_match_decoder / encoder / store / confirm_dialog / match_menu / match_menu_host / modal_overlay / new_match_gate / toast_view と各テスト）。直近の呼び出し元として match_setup_screen_test・team_layout.from_players・MatchRules.is_play_complete・functional-overview.md のエラーハンドリング表も確認した。ファイルは一切変更していない。

**結論: Critical・High の指摘はない。** Medium 1 件、Low 6 件。

### Critical（即時対応必須）
- 指摘なし

### High（優先対応）
- 指摘なし

### Medium（対応推奨）
- **[バグ] 再開しても `_has_unsaved` が false に戻らない**（`game/application/suspend_keeper.gd` の `load_for_resume`、`match_controller.gd` の `_open`）
  - 起きる手順: 試合中に保存が失敗する → メニューから中断し、保存のやり直しも失敗する（`_has_unsaved` は true のまま）→ タイトルに前の保存の再開カードが出る → 再開する。
  - 再開した直後は、メモリの状態と保存データが一致している。それでも `has_unsaved_progress()` は true を返す。
  - その結果、(a) メニューの「中断」で、根拠のない警告が出る。(b) 再開後の最初の保存が失敗しても、`_has_unsaved` が既に true なので `storage_failed(SUSPEND_SAVE)` が出ない（通知の漏れ）。
  - 次に保存が成功するか、`leave_result`・`delete()` を通るまで戻らない。
  - 修正例:
    ```gdscript
    func load_for_resume() -> MatchState:
    	if _store == null:
    		return null
    	var load: SuspendedLoad = _store.load()
    	if load.status == SuspendedLoad.Status.OK and is_resumable(load.state):
    		_resumable = null
    		_has_unsaved = false  # 読み直した状態は保存データそのもの
    		return load.state
    	...
    ```
  - 先に固定するテスト: 保存先の `suspended_match.json.tmp` の位置にディレクトリを作って書き込みを失敗させる → 1 ターン進める → `suspend_to_title()` が false → ディレクトリを消す → `resume()` → `has_unsaved_progress()` が false であることを確かめる。

### Low / 改善提案
- **[運用・バグ] 電源断のとき、本体と .bak を両方失う経路がある**（`save_file_io.gd` の `write` の手順 2〜4）
  - Godot の `FileAccess.close()` は fsync しない。しかも手順は「本体 → .bak」「.tmp → 本体」の 2 回の rename で、置き換えの形の rename ではない。そのため ext4・f2fs の rename 時の自動書き出しが効かない。
  - 電源断の後に本体が空や途中のまま残りうる。その時点で手順 4 が .bak を消していれば、直前の状態も残らない。
  - アプリが強制終了されるだけ（プロセスの kill）なら OS のキャッシュが残るので問題ない。NFR-08 が電源断まで求めるかを確かめて申し送る。
  - 対策案は 2 つ: 手順 4 の .bak の削除をやめて次の書き込みの最初に回す（常に 1 世代残す）か、手順 1 の後に `file.flush()` を入れたうえで .bak を残す。
- **[バグ] `drop_stale()` の削除失敗を見ていない**（`suspend_keeper.gd`）
  - 新しい試合 B の最初の保存が失敗し、前の試合 A の削除まで失敗すると、A が残る。その後 B を中断して保存のやり直しも失敗すると、`inspect()` が A を再開カードに出す（前の試合の取り違え）。
  - 書き込みも削除もできない状態でしか起きないので、Low とした。
  - 防ぎ方: `suspend_to_title` で、読み直した `state.match_id` がメモリ上の試合と違えば `_resumable` を null にする。
    ```gdscript
    var current_id: String = _state.match_id
    _state = null
    ...
    _keeper.inspect()
    if _keeper.resumable() != null and _keeper.resumable().match_id != current_id and not is_saved:
    	_keeper.forget()
    ```
- **[セキュリティ: A08・NFR-09] デコーダは項目どうしの整合を確かめていない**（`suspended_match_decoder.gd`）
  - 項目ごとの型・範囲・必須は、data-definition.md §2.1 どおりに閉じている（fail closed）。範囲外の値で落ちる経路も見つからなかった。
  - ただ、次のような組み合わせは通る:
    - `stage=HALFTIME` かつ `half=2`
    - `status=IN_PROGRESS` のまま、ハーフ 1 で `turn_number` が上限＋1
    - `turn_records` の最後と `state`（half・turn_number・ball_area）が食い違う
  - 外部通信のない単体ゲームで、被害は改変した本人の試合が変になることに限られる。仕様にも組み合わせの制約は書かれていない。そのため Low として申し送る。
  - 将来の作業で、少なくとも「`stage=HALFTIME` は `half=1` だけ」は検証に足すことを勧める。
- **[バグ・申し送り] 最終ターンの判定理由（SHOW_RESULT）からも中断できる**
  - そこで中断すると、`inspect()` が「最終ターンまで終えた IN_PROGRESS」として中断データを消し、結果画面 S-06 を通らずにタイトルへ戻る。
  - 今は戦績が無いので失うものはない。戦績の作業で終了処理を足すときに、`_can_open_menu` に `not is_match_over()` を足すか、`suspend_to_title` で終了処理へ回すこと。
- **[運用・テスト] テストの既定値が開発用 PC の保存先になる**（fail open）
  - オートロード App の `_ready` はテストより先に走る。そのため本物の `App.match_controller` は `user://` を保存先に持つ。
  - 今のテストはすべて差し替えるか、store 無しのコントローラを使う。`user://suspended_match.json` に触れる経路は見つからなかった（match_setup_screen_test も store 無しで差し替え済み）。
  - ただ、差し替えを忘れたテストが今後足されると、開発用 PC の中断データを静かに上書きする。
  - 対策案: テストの実行時にだけ渡すコマンドライン引数（`OS.get_cmdline_user_args()`）で `save_dir` を一時ディレクトリにする。または、テスト側の共通の `before` で本物のコントローラの store を null 相当に差し替える。
  - 補足: gdUnit の `create_temp_dir` も `user://tmp/` の下に作るが、保存データとは別の場所なので問題ない。
- **[ドキュメント] コメントが動作と食い違っている**（`match_menu_host.gd` 54〜55 行）
  - 「戻り値が false でもタイトルへ進む（通知は MainShell が出す）」とあるが、保存のやり直しに失敗しても新しい通知は出ない（`_has_unsaved` が既に true のため。メニューの確認で警告済み）。
  - コメントを「通知は最初の失敗で出し済み、確認で警告済み」に直すとよい。
- **[性能] 読み込みのたびに 2 回デコードしている**（`suspended_match_store.gd` の `load`。`_is_decodable` で 1 回、その後もう 1 回）
  - 中断データは最大でもおよそ 36 記録×配置 4 組×20 人で、数百 KB。読むのは起動時・中断時・再開時だけなので、今の規模なら実害はない。
  - 毎ターン同期で保存する処理も数百 KB 以下で、端末上では数十 ms 程度と見ている（実測はしていない）。
  - 直すなら `read` の検証で作った state を覚えておき、使い回す。

### 問題なし
- **セキュリティ①（ハードコーディング）**: シークレット・URL・クラウドの情報・ドキュメント内の機密はない。保存先は `App.save_dir`（既定 `user://`）で、外部通信もない。
- **セキュリティ②（認証・認可）**: 対象外（オフラインの単体アプリで、利用者は 1 人）。
- **セキュリティ③（入力の検証）**:
  - 保存データの読み込みは閉じている: 5MB の上限、JSON の最上位の型、全項目の型・範囲・区分値・エリアの形・件数の上限、選手 ID が陣形の選手と 1 対 1、基本エリアが陣形と一致、seq が連番、null の条件、文字列 2000 字の上限。
  - 1 つでも外れたら `null` を返して CORRUPTED になる。外れた値は既定値（-1・null・空）になり、`TeamLayout.from_players([])` などでも落ちない。
  - `ACTION_ENUMS[family]` や `ids[side]` は、区分値の検証を通った後でしか引かない。
  - シェル・DB・画面へのそのままの出力はない。
- **セキュリティ④（情報漏洩）**: `push_error` に保存データの中身を出していない。`errors()` は開発時の確認用だけ。
- **書き込みの手順**:
  - .tmp の書き込み失敗、本体 → .bak の rename 失敗、.tmp → 本体の rename 失敗の、どの時点で止まっても直前の状態（本体か .bak）が残る。読み込みは .tmp を読まずに消し、本体 → .bak の順に検証して使う。
  - `delete` は 3 ファイルとも消し、.bak から消したデータが戻ることはない。
- **通知**:
  - 保存の失敗は続く間 1 回だけ出し、成功で戻る。起動時の破損は、タイトルを開くまで MainShell が溜めてから出す。
  - 文言は functional-overview.md 770〜774 行と一致する。全種類に文言がある（テストあり）。
- **状態の取り違え**:
  - 新しい試合・再開では `_open` → `forget()` で再開カードを消す。
  - `start_match` の保存に失敗したら前の中断データを消す。
  - 再開は毎回保存データから読み直し、読めなければ削除・通知してタイトルへ戻る。
  - `leave_result` で削除する。
  - `NewMatchGate` は確認中の二度押しを防ぐ。タイトルの状態は BUSY・CONFIRMING で二度押しを防ぎ、戻る操作は確認を「やめる」と同じにする。
- **テストの空振り・恒真**: 見た範囲の新しいテストは、実際の保存・読み込み・削除・画面の要求を確かめている。恒真のアサーションは見当たらない。
- **ドキュメント**: component-design.md §3.2・§4.3、data-definition.md §2.1（配置の組）、screen-01-title.md、screen-common.md が実装と合っている。

### 未検証
- テストは実行していない（依頼元のバックグラウンド実行の結果を待つ）。
- Godot 4.7 の JSON パーサーに入れ子の深さの上限があるかは確かめていない。5MB 以内の深い入れ子でスタックが溢れないかは未確認。
- `app_theme.tres` の差分（色と型）、`.steering/20261029-suspend-resume/` の 3 ファイル、`title_resume_test.gd`・`match_menu_test.gd`・`suspended_match_codec_test.gd` の本文は、テスト名と保存先の使い方だけを見た。全文は読んでいない。
- Android の実機で rename・fsync がどう振る舞うかは確かめていない（上の電源断の指摘は推定）。

### 総合評価
Critical・High はないので、コミットしてよい。`_has_unsaved` の戻し忘れ（Medium）は、依頼で特に見てほしいと挙がっていた点そのもので、直すのは 1 行で済む。テストを先に固定してから、このコミットで一緒に直すことを勧める。Low は申し送りでよい。そのうち電源断の経路と、最終ターンの SHOW_RESULT からの中断の 2 つは、戦績の作業で実害になりうるので、必ず申し送ること。

### 対応
- Medium「再開しても `_has_unsaved` が戻らない」: `SuspendKeeper.load_for_resume` で `_has_unsaved = false` にした。指摘の手順どおりのテスト
  （`test_resuming_clears_the_unsaved_mark_so_the_next_failure_is_reported_again`。`.tmp` の位置にディレクトリを置いて書き込みを失敗させる）を足し、
  直した1行を外す変異でこのテストが落ちることを確かめた。
- Low「電源断で本体と .bak を両方失う経路」: 直さない。NFR-08 の対象は強制終了（プロセスの終了）で、そこでは OS のキャッシュが残る。
  電源断への備え（.bak を1世代残す・flush）は申し送り（`retrospective.md`）。
- Low「`drop_stale()` の削除失敗を見ていない」: 直さない。書き込みも削除もできない状態でだけ起きる。申し送り。
- Low「項目どうしの整合を見ていない」: 勧めのとおり「ハーフタイムは前半だけ」を検証に足した（テストと変異あり）。ほかの組み合わせは申し送り。
- Low「最終ターンの判定理由から中断できる」: 今は失うものが無いので直さない。戦績の作業で終了処理を足すときの必須事項として申し送り。
- Low「テストの既定値が開発用 PC の保存先」: 直さない（今は全テストが差し替え済み）。新しいテストでオートロードのコントローラを使うときの注意として申し送り。
- Low「コメントが動作と食い違う」（`match_menu_host.gd`）: 直した。
- Low「読み込みのたびに2回デコード」: 直さない（数百 KB で、読むのは起動時・中断時・再開時だけ）。申し送り。

同時に、実装検証（review-implementation。[必須]なし・総合 4.2/5）の[推奨]にも対応した。
- `SuspendedStatus`・`StartupResult` が `MatchController` の内側にあった → `AppScreens` へ移した（UI とアプリケーション層の両方が読む区分値のため）。仕様書も直した。
- 重ねた部品がキー操作を止めない → `ModalOverlay` が開いたら中の最初のボタンへフォーカスを移し、外へ出たら戻す（テストあり）。
- 古いコメント（`match_controller.gd` の2か所）→ 直した。
- 提案から: `SaveDataReader.integer` で整数にする前に範囲を見る（`1e300` のテストあり）、使っていない `check_base` 引数を外した、組み込みの `load()` を隠す変数名を `loaded` にした。

修正後の確認: 関係するスイート（codec・store・controller の中断・menu・title）がすべて成功。変異 18 個（足した2個を含む）がすべて検出された。全体のテストは下の「レビュー完了」に記す。

修正は Medium・Low と実装検証の[推奨]への対応だけで、Critical / High を直したものではないため、再レビューは行わない（review-pre-commit「Medium / Low はループを回す理由にならない」）。

## レビュー完了（2026-10-29）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）: 電源断への備え、`drop_stale` の削除失敗、項目どうしの整合（ハーフタイム以外）、最終ターンの判定理由からの中断（戦績の作業で必須）、
  テストの既定値の保存先、2回のデコード。詳細と検出の手段は `retrospective.md`「次回への改善提案」

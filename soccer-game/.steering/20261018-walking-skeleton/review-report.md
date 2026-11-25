# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: 変更6ファイル（`.gitignore`、`game/project.godot`、docs 4件）と新規ファイル全部（`.steering/20261018-walking-skeleton/` の3文書、`game/application/`、`game/ui/`（.gd・.tscn・.tres・.uid）、`game/tests/application/`、`game/tests/ui/`、`game/tests/fixtures/screens/`）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 4件
- 備考: 実装レビュー（review-implementation。総合 4.4/5、[必須] なし）の指摘は、このレビューの前に対応済み（tasklist.md に記録）

## コミット前レビュー結果

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ] **横向きのまま 180° 回すと、セーフエリアの余白が古い側に残る可能性がある**: `MainShell._apply_safe_area()` を呼び直すきっかけは `get_viewport().size_changed` だけ。`sensor_landscape` で左右が入れ替わってもビューポートの大きさは変わらないので、このシグナルは来ないと考えられる。すると切り欠きの余白は元の側に残り、反対側に移った切り欠きが内容に重なる（例外も警告も出ない）。→ (a) 左右に同じ余白（大きい方）を当てる、または (b) モバイルのときだけ `get_display_safe_area()` の変化を `_process` で見張る。どちらにしても、エミュレーターで回転させて確かめた結果を残すこと。

### Low / 改善提案
- [バグ] `side_margins` が退化した safe_area を考えていない。`get_display_safe_area()` が大きさ 0 の範囲を返すと、右の余白が画面幅 × 倍率になり、画面がつぶれる。→ `not safe_area.has_area()` なら 0 を返し、`Rect2i()` で余白が 0 になるテストを先に足す。
- [バグ／申し送り] Android の戻る操作は通知で届き、`ui_cancel` ではない。開いているダイアログを経由せず、直接 `handle_back()` に来る。screen-common.md §4.1 の「ダイアログが先に `ui_cancel` を受けたら MainShell まで届かない」は PC の Esc にしか当てはまらない。今はダイアログが無いので実害なし。`ConfirmDialog` を作る作業で、各画面の `handle_back()` がダイアログを閉じるところまで受け持つこと。文書にも書き分けるとよい。
- [バグ] `ScreenSwitcher.open()` で `scene.instantiate()` が null を返すと、null に対して `free()` を呼んでスクリプトエラーになる。→ null なら `push_error` して `false` を返す。
- [運用] `_switcher.open.call_deferred(...)` の戻り値は捨てられる。失敗は `push_error` だけで、リリースビルドでは「押しても何も起きない」に見える。今はカードを押せない設計なので問題ない。画面を足すとき、`SCREEN_SCENES` への足し忘れに注意（既存のテストと申し送りで一部カバーされている）。

### 問題なし
- セキュリティ①: 差分と新規ファイルに、URL／エンドポイント・API キー・トークン・パスワード・ARN／アカウント ID は無い。repository-structure.md の adb の手順は `<パッケージ名>` のプレースホルダ。`.gitignore` は既存の除外を保ち、`/game/override.cfg` を足している。
- ローカルの絶対パス／ユーザー名: 追跡予定のファイル（.uid・.steering・.tscn・.tres・docs・project.godot）に無い。.tscn／.tres の参照はすべて `res://`。
- セキュリティ②③: 該当なし（外部入力・永続化・通信が無い）。
- セキュリティ④: デバッグログは `OS.is_debug_build()` のときだけで、中身は戻る操作の出どころ・画面 ID・真偽値だけ。`push_error` もシーンのパスと画面 ID だけ。外部通信を加えるコードは無い（NFR-10）。
- 戻る操作・アプリの終了: `quit_on_go_back=false` を維持。`ui_cancel` は `is_action_pressed`（リピートなし）で受けて `set_input_as_handled()`。`route_back()` は `handle_back()` を1回だけ呼ぶ。画面が無いときは false（閉じる）。エミュレーターの記録がある。
- 画面の入れ替え: `call_deferred` で押されたボタンを処理の途中で外す問題を避けている。exit → remove_child → queue_free の順。対応が無い・AppScreen でないときは今の画面を保つ（テストあり）。`_exit_tree` で `App` のシグナルを外す（テストあり）。
- テスト: 恒真テストや空振りは無い。タイトルの `enter()` のテストが今は区別できないことは、コメントと tasklist に申し送られている。
- 性能・切り戻し・文書: 問題なし。

### 未検証
- 横向きで 180° 回したときに `size_changed` が来ないこと（Medium の前提）は推定。実機・エミュレーターでは確かめていない。
- Android の戻るキーが `ui_cancel` としても届かない（二重に呼ばれない）ことは、tasklist のエミュレーターの記録（ログ1行）に頼った。
- `.steering` の3文書は機密・パスの混入だけを調べた。

### 総合評価
Critical／High なし。コミットしてよい。Medium（回転時のセーフエリア）は、コミット前に直すか、エミュレーターで回転を確かめてから申し送ることを勧める。Low の `side_margins` の退化ケースは、先にテストを固定してから申し送ること。

### 対応
- Medium（回転時のセーフエリア）: 直した。案 (a) を採り、左右に同じ余白（大きい方）を当てる。どちら向きでも切り欠きに内容が重ならないので、回転のきっかけを見張る必要が無くなった（エミュレーターでの回転の確認も不要になった）。理由をコードのコメントと `screen-common.md` §1.1 に書いた。
- Low（退化した safe_area）: 直した。`Rect2i()` で余白が 0 になるテストを先に足し、失敗することを確かめてから、`not safe_area.has_area()` なら 0 を返すようにした。
- Low（Android の戻る操作とダイアログ）: 文書を書き分けた（`screen-common.md` §4.1。ダイアログを開いている画面は `handle_back()` でダイアログを閉じるところまで受け持つ）。実装は `ConfirmDialog` を作る作業で行う。
- Low（`instantiate()` の null）: 直した（null なら `push_error` して `false`）。
- Low（`call_deferred` の戻り値）: 直さない。今はカードを押せない設計で、`SCREEN_SCENES` への登録の漏れは、登録したシーンの実在のテストと、タイトルのテストの申し送りで扱う。
- テストは 101 件すべて成功。新たな Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: `call_deferred` で開いた画面の失敗が利用者には見えないこと（画面を足す作業で、`SCREEN_SCENES` への登録を確かめる。検出するテストは「登録したシーンが実在し AppScreen であること」）。Android の戻る操作でダイアログを閉じる処理（`ConfirmDialog` を作る作業。今はダイアログが無い）

# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: 保存の土台（データ層）

- [x] `SaveFileIO` のテスト → 実装
- [x] エンコーダ／デコーダの往復テスト（固定シードの試合の全ターン・続きの1ターン）→ 実装（項目の読み出しは `SaveDataReader` に分けた。配置の組には `attacker_side` を書く）
- [x] デコーダの範囲外のテスト（1つずつ壊して null）→ 検証の実装
- [x] `SuspendedMatchStore`・`SuspendedLoad` のテスト → 実装

## フェーズ2: アプリケーション層

- [x] `MatchController` の保存の時点と保存の失敗・`has_unsaved_progress` のテスト → 実装（保存の失敗の扱いと再開カード用の写しは `SuspendKeeper` に分けた）
- [x] `inspect_suspended`・`suspended_status`・`suspended_snapshot`・`resume`・`suspend_to_title`・`leave_result` のテスト → 実装
- [x] `App` に store・`storage_error` を足す（保存先 `save_dir` を外から渡せるようにし、テストは一時ディレクトリを使う）

## フェーズ3: UI

- [x] `ToastView` と `MainShell` の起動時の確認・通知の保持
- [x] `ConfirmDialog`・`MatchMenu`・`NewMatchGate`（重ねる土台 `ModalOverlay`、3画面で共通の `MatchMenuHost` を足した）
- [x] タイトルの再開カード・状態・CPU 対戦の確認
- [x] S-03〜S-05 のメニューと戻る操作
- [x] 画面テスト（一時ディレクトリはスイートの中で消えないので、テストごとに名前を変える）

## フェーズ4: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（実行件数・スイート数を確認）（途中で 10 分を超えたので、シードの探索と変換のテストの試合を覚えておく形にした）
- [x] 変異の確認（デコーダの検証・保存の時点。狙ったスイートだけ）（18 個すべて KILLED、約 2 分 40 秒。既存のファイルは作業ツリーで CRLF なので、アンカーを CRLF でも探す）
- [x] PC のウィンドウで、再開カード・メニュー・確認・通知を撮って確認（再開カードの中身が切れていた → 高さ 140px・縁 accent。ダイアログの地がボタンと同じ色だった → 地を bg に）

## フェーズ5: ドキュメント更新

- [x] 仕様書の更新（component-design.md の MatchController・§4.3 の実装の形、data-definition.md の配置の組、screen-01・screen-common・screen-design）
- [x] 実装後の振り返りを記録（`retrospective.md`）

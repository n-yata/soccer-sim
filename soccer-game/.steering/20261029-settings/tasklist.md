# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: ドメイン・データ層

- [x] `UserSettings`
- [x] `SaveFileIO.move_aside` を足し、`RecordStore` の退避を置き換える（既存のテストが通る）
- [x] `SettingsStore` のテスト（往復・キーごとの初期値・破損・新しい版・保存の失敗）→ 実装

## フェーズ2: アプリケーション層

- [x] `UserDataService` の設定のテスト → 実装（呼び出し側の `_init` を直す）

## フェーズ3: UI

- [x] バスのレイアウトと `AudioBuses`、`MainShell` の起動時の反映
- [x] `SettingsPanel`・`LicenseView`・`SettingsScreen`（`MainShell.SCREEN_SCENES`）
- [x] `SettingsOverlay` とメニューの「設定」、`MatchMenuHost` の戻る操作
- [x] ヒント表示の OFF と、試合中の切り替え（`MatchBoardPanel.set_show_hints`）
- [x] 書き出しの `include_filter` にライセンスの本文を足す

## フェーズ4: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（実行件数・スイート数を確認）
- [x] 変異の確認（キーごとの初期値・破損・保存の時点・ヒントの OFF。狙ったスイートだけ）（28 個のうち 27 個を検出、1 個は等価な変異）
- [x] PC のウィンドウで S-12・試合中の設定・ライセンスを撮って確認（試合中の設定で「閉じる」がはみ出したので、音量の行を1行にし「閉じる」を「ライセンス」の横に並べた）

## フェーズ5: ドキュメント更新

- [x] 仕様書の更新（component-design.md の実装の形、screen-12・screen-03・screen-common・screen-01）
- [x] 実装後の振り返りを記録（`retrospective.md`）

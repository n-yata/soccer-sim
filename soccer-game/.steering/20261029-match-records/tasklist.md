# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: ドメイン・データ層

- [x] `MatchRecord`・`RecordPeriod`（`MatchRecord.of`。推移は `ReviewAggregator.segments`）のテスト → 実装
- [x] `MatchRecordCodec` の往復・範囲外のテスト → 実装
- [x] `RecordStore` の冪等・上限・破損の退避・新しい版のテスト → 実装

## フェーズ2: アプリケーション層

- [x] `UserDataService` のテスト → 実装、`App.user_data`
- [x] `MatchFinalizer` と `MatchController` の終了処理・`leave_result`・起動時のやり直し・`FINALIZE_PENDING`・`retry_pending_finalize`・`final_record` のテスト → 実装（`AppScreens` の enum を設計どおりに）
- [x] 再開した試合の「最後の得点のスコア ＝ 盤面のスコア」のテスト

## フェーズ3: UI

- [x] `NewMatchGate` の `FINALIZE_PENDING` の確認
- [x] タイトルの戦績のカードの一言
- [x] S-06 の陣形・方式の推移
- [x] S-11 戦績（`MainShell.SCREEN_SCENES` に足す）
- [x] S-03 の最終ターンの判定理由ではメニューを開かない

## フェーズ4: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（実行件数・スイート数を確認）
- [x] 変異の確認（終了処理・RecordStore の検証と上限。狙ったスイートだけ）（31 個すべて検出。レビュー指摘の修正の後、目印が変わったものは回し直した）
- [x] PC のウィンドウで S-06・S-11・タイトルを撮って確認（一覧の勝敗のタグの幅をそろえた。タイトルの一言を3行に分けた）

## フェーズ5: ドキュメント更新

- [x] 仕様書の更新（component-design.md の実装の形、screen-01・06・11、screen-common）
- [x] 実装後の振り返りを記録（`retrospective.md`）

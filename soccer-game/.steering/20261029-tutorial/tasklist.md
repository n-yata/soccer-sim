# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: ドメイン

- [x] `SimplificationDef`・`TutorialStepDef`・`ContentCatalog` の項目
- [x] `MatchRules.create_scene` のテスト → 実装
- [x] `MoveOptions.restricted_to` のテスト → 実装

## フェーズ2: データ

- [x] 単純化カタログの見直し（SIM-01・SIM-04・SIM-09 の案。functional-overview.md）と `simplifications.json`
- [x] `TutorialContentReader` のテスト → 実装、`ContentRepository` から呼ぶ
- [x] `tutorial.json` と同梱データの検証テスト（盤面・選べる手・相手の手・7要素）

## フェーズ3: アプリケーション層

- [x] `ScriptedOpponent`・`MatchController.start_tutorial_step`・`App.new_tutorial_controller`・`LibraryService` のテスト → 実装

## フェーズ4: UI

- [x] `MatchBoardPanel` の段階のための口（`show_next`・`set_options_filter`・`set_interactive`・上下の入れ物）
- [x] `SimplificationList`
- [x] `TutorialScreen`（`MainShell.SCREEN_SCENES`）
- [x] タイトルのチュートリアルのカードの位置の切り替え

## フェーズ5: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（実行件数・スイート数を確認）
- [x] 変異の確認（狙ったスイートだけ）（20 個すべて検出。1個はテストの壊し方を直して検出できるようにした）
- [x] PC のウィンドウで各段階・単純化の一覧・タイトルを撮って確認（判定理由が下で切れるので説明を畳む。完了後の小さなカードを上へそろえる）

## フェーズ6: ドキュメント更新

- [x] 仕様書の更新（component-design.md・data-definition.md・screen-08・screen-01・screen-common）
- [x] 実装後の振り返りを記録（`retrospective.md`）

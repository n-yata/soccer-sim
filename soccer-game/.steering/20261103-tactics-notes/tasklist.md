# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: 静的データとドメイン

- [x] `styles.json`・`matchup_rules.json` を作り、`formations.json` に強み・弱み・原則 ID を足す（ルールは移植元からスクリプトで起こす）
- [x] `StyleDef`・`MatchupRuleDef`・`MatchupNote`・`ContentCatalog`・`FormationDef` の追加
- [x] `CommentaryContentReader` と `ContentRepository` の読み込み・検証（テスト先行）
- [x] `FormationTags`（テスト先行）
- [x] `CommentaryGenerator`（テスト先行）

## フェーズ2: アプリケーションと画面

- [x] `LibraryService` の5つの関数（テスト先行）
- [x] `NotesView`・`MiniPitch.show_matchup`（テスト先行）
- [x] S-02 の解説欄
- [x] S-04 の直前の噛み合わせ・選んだ方式の解説
- [x] S-05 の噛み合わせのミニピッチと解説
- [x] 本物のデータのテスト（`commentary_content_test.gd`）
- [x] `JudgeReasonFormatter` ほか、古くなった注記を直す

## フェーズ3: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（160秒・78スイート・1092件・失敗0。全体テストを3分以内に収める作業 `1995e73` の後）
- [x] 変異の確認（狙ったスイートだけ。17個すべて検出）
- [ ] PC のウィンドウで S-02・S-04・S-05 を撮って確認（シャビの指示でコミットを先にしたため未実施。見た目はシャビが遊んで確かめる）

## フェーズ4: ドキュメント更新

- [x] 仕様書の更新（data-definition・component-design・screen-02/04/05・screen-common・functional-overview・repository-structure の該当箇所）
- [x] 実装後の振り返りを記録（`retrospective.md`）

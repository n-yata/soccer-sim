# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを`[x]`にすること。スキップは技術的理由のときだけ、理由を明記する

---

## フェーズ1: 実装

- [x] 問題案をシャビに確かめる（2026-10-31 了承）
- [x] `principles.json`・`quiz.json`、`PrincipleDef`・`QuizQuestionDef`、`QuizContentReader`、`ContentCatalog`・`ContentRepository`
- [x] `VersionedJsonFile` を切り出し、`RecordStore` を移す。`QuizAnswer`・`QuizAnswerStore`
- [x] `UserDataService.quiz_progress()`・`save_quiz_answer()`、`LibraryService.principle()`・`quiz_questions()`、`App`
- [x] `QuizTexts`・`QuizScreen`、`MainShell.SCREEN_SCENES`、タイトルの一言
- [x] テスト（静的データ・読み込み・保存・サービス・画面・タイトル・シェル）

## フェーズ2: 品質チェックと修正

- [x] `tools/run-tests.sh` がすべて通る（72 スイート・969 件。2026-10-31）
- [x] 変異の確認（狙ったスイートだけ。15件すべて検出。最初に生き残った「最初の回答で数える」はテストの並びを直して検出）
- [x] PC のウィンドウで S-09 を撮って確認（図のはみ出しと、回答後に解説が隠れるのを直した）

## フェーズ3: ドキュメント更新

- [x] 仕様書の更新（screen-09・screen-01・screen-design・data-definition・component-design・repository-structure）
- [x] 実装後の振り返りを記録（`retrospective.md`）

# 設計

| 層 | ファイル | 役割 |
|---|---|---|
| ドメイン | `domain/principle_def.gd`・`quiz_question_def.gd`・`quiz_answer.gd` | 原則・場面問題・回答結果の値 |
| ドメイン | `domain/content_catalog.gd` | `principles`・`quiz_questions`・`principle(id)` を足す |
| データ | `data/quiz_content_reader.gd`（`QuizContentReader`） | `principles.json`・`quiz.json` の形と範囲（各チーム10人・LG ごとに2問以上・プレイテストちょうど2問・原則がカタログにある） |
| データ | `data/versioned_json_file.gd`（`VersionedJsonFile`） | 戦績から切り出した、JSON 1ファイルの読み込み（破損の退避・新しい版を書かない）と書き込み |
| データ | `data/record_store.gd` | `VersionedJsonFile` を使う形に直す（振る舞いは変えない。既存のテストで確かめる） |
| データ | `data/quiz_answer_store.gd`（`QuizAnswerStore`） | `quiz_answers.json`。上限 30,000 件で古いものから捨てる |
| アプリ | `application/user_data_service.gd` | `quiz_progress()`・`save_quiz_answer()`。読み込み・保存の失敗の通知を戦績と共通にする |
| アプリ | `application/library_service.gd`・`app.gd` | `principle()`・`quiz_questions()`。`UserDataService` に回答の保存先と問題を渡す |
| UI | `ui/common/quiz_texts.gd`（`QuizTexts`） | 文言。問題の文の `{M2-L1}` を試合の画面と同じ呼び名（`MatchTexts.area_name`）にする |
| UI | `ui/screens/s09_quiz/quiz_screen.gd`（`QuizScreen`） | 一覧／問題／回答後の3状態 |
| UI | `ui/main_shell.gd`・`ui/screens/s01_title/*` | 画面の登録、タイトルのカードの一言（`QuizSub`） |

## 決めたこと

- **問題の文のエリア**: `quiz.json` には `{A1-R1}` の形で書き、表示で「敵陣・右HS」にする。キーをそのまま出すと、試合の画面の
  呼び名と食い違い、図にもキーの表示が無いため。テストは `{…}` を拾って図の人数と照らし合わせる
- **回答後の操作の列**: 選択肢を隠して、正誤・「あなたの答え／正解」・解説・根拠の原則に替える（screen-design.md のレイアウト
  「回答後は操作の列を…に替える」）。選択肢を残すと解説が列の下に隠れ、回答しても変わらないように見えた（PC のウィンドウで確認）
- **場面の図の1マス**: 130×76。基準解像度 1280×720 で、図（650×456）と下の2行の文が本体に収まる
- **回答結果の保存を戦績と共通にする**: 破損・新しい版の手順（退避・.bak・書かない）が戦績と同じなので、`VersionedJsonFile` に1つにした
- **正答状況の分母**: `UserDataService` に問題の一覧を渡す（`quiz.json` に無い問題の回答は数えない）

## テスト

- `tests/content/quiz_content_test.gd`: 同梱データの誤り無し、原則がカタログの TP-01〜10、`{…}` がエリア、選択肢・解説の「N対M」が図と同じ、
  即時奪回の問題の周りの人数、噛み合わせの場面がゲームの基本配置、陣形の問題で M2-C に人がいるのは正解の陣形だけ
- `tests/data/quiz_content_reader_test.gd`: 本物を読んだ値、壊したデータごとの誤り
- `tests/data/quiz_answer_store_test.gd`: 追記と読み直し、上限、破損、新しい版
- `tests/application/user_data_service_test.gd`: 最新の回答で数える、無い問題を数えない、破損・新しい版・保存の失敗
- `tests/ui/quiz_screen_test.gd`・`title_screen_test.gd`・`main_shell_test.gd`: 画面の流れ、タイトルの一言、全画面の登録

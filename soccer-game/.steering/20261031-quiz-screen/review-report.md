# コミット前レビューレポート

## 第1回（2026-10-31）
- 対象: S-09 理解度チェックの変更一式（作業ツリーの差分 26 ファイルと未追跡の新規ファイル。データ・ドメイン・UI・静的データ・テスト・仕様書・`.steering/20261031-quiz-screen/`）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 3件

## コミット前レビュー結果

対象: 作業ツリーの差分（26ファイル）と未追跡の新規ファイル（S-09 理解度チェック。versioned_json_file・quiz_answer_store・quiz_content_reader・principle_def・quiz_question_def・quiz_answer・quiz_texts・quiz_screen・principles.json・quiz.json・新規テスト5本・.steering/20261031-quiz-screen/）。ファイルは何も変更していません。Godot とテストは実行していません。

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ] 保存に失敗した回答が、後で保存に成功すると正答状況から静かに消える: `UserDataService.save_quiz_answer` は、保存に失敗したときだけ回答をメモリの `_answers` に足します（`answers.append(answer)`）。次の回答の保存が成功すると `_answers = _quiz_store.load_all()` でディスクから読み直すため、前に失敗した回答（ディスクに無いもの）は、例外も通知も出ないまま集計から外れます。例として、1問目の書き込みが一時的に失敗して USER_DATA_SAVE が出て、2問目が成功すると、1問目は「未回答」に戻ります。失敗中は「回答を含めて数える」という今の仕様が、失敗から戻ると守られません。直し方は次の2つのどちらかです。
  - (a) 失敗した回答を `_pending` として持ち、次の append で一緒に書く。
  - (b) 「保存に失敗した回答は、次に保存が成功した時点で集計から消える」と screen-09 / component-design に明記し、そうなることをテストで固定する。
  戦績（append_record）は失敗した記録をメモリに足さないので、この食い違いは回答結果にだけ起きます。

### Low / 改善提案
- [性能] 回答1件ごとに、ファイルを2回読み（append の中の load_all と、成功した後の load_all）、全件を JSON.stringify し、.tmp/.bak の手順で書きます。件数の上限 30,000 件、ID 40文字のときで最大およそ 3.3MB になります。今の問題数（各学習目標2件程度）なら件数は小さく、問題ありません。数千回答えるあたりから、1回の回答に数十 ms の I/O がかかり始めます（Android の場合）。戦績と同じ設計なので、申し送りで構いません。
- [運用] `QuizAnswerStore` には `RecordStore.MAX_WRITE_BYTES` にあたる、書き込みの大きさの検査がありません。いまは「30,000件 × 1件の最大の大きさ < MAX_READ_BYTES 5MB」という計算で守っています。これは `test_a_full_file_of_the_longest_answers_still_fits_the_read_limit` で固定されているので、穴にはなっていません。answered_at などの項目を足すときに、計算の前提が崩れないよう注意してください。
- [運用] principles.json が読めないと principle_ids が空になり、quiz.json のすべての問題で「原則カタログに無いか重複」の誤りが出て、件数が膨らみます。原因は1件目の誤りで分かりますが、ログは見づらくなります。開発時だけの話です。

### 問題なし
- セキュリティ①（ハードコーディング）: 差分・新規ファイル・principles.json・quiz.json・仕様書の差分・.steering に、URL・エンドポイント・キー・トークン・クラウドのアカウント情報・ARN はありません（`https?://`・`api_key`・`secret`・`arn:` を grep で確かめました）。フォールバックの秘匿値もありません。
- セキュリティ②（認証・認可）: オフラインの単体アプリで、保護すべきリソースはありません。該当なし。
- セキュリティ③（インジェクション・A08）: `quiz_answers.json` は `JSON.parse_string` で読み、`ConfigFile.parse` は使っていません（Godot 4 の JSON は Object を組み立てません）。読み込み（`_decode`）では、format_version の完全一致、answers の件数 0〜30,000、question_id が ID の形（正規表現）、correct が bool、answered_at が日時の形かを確かめ、1つでも外れれば全体を破損として退避します。表示はすべて Label/Button の text で、BBCode は解釈しません。問題文・選択肢の文は同梱の静的データだけから来ます。
- セキュリティ④（情報漏洩）: 新しいログは push_error による静的データの誤りの通知だけで、利用者のデータは出しません。
- バグ: RecordStore の切り出しは振る舞いを保っています（version_of・_parse・_quarantine・can_write が、元の `_load_state == NEWER_VERSION or _is_quarantine_failed` と同じ意味）。`RecordStore.LoadState` と `MatchRecordCodec.version_of` を参照している残りは、grep で見つかりませんでした。
- バグ: quiz_progress は、古いものが先の並びで上書きするので最新の回答で数えます。quiz.json に無い問題は数えません。goal_id は読み込みで GOAL_IDS に限っているので、`progress[question.goal_id]` は落ちません。
- バグ: 読み込み・保存の失敗の通知を重ねていません。新しい版のときは、読み込みで NEWER を出して `_is_quiz_failing` を真にするので、保存の失敗は出ません。
- バグ: `Time.get_datetime_string_from_system(false, false)` の出力は DATETIME_PATTERN に合うので、書いた回答が次の読み込みで破損扱いになりません。
- バグ: QuizScreen は、未選択では回答できません。回答した後は選択肢を選べなくなり、戻ると一覧へ戻ります。一覧は開くたびに作り直し、カードは重複しません（テストあり）。選択肢の ID は ID の形なので、ノード名として使っても問題ありません。
- テスト: 新規テストは具体的な入力と期待値を確かめています。破損・新しい版・上限・失敗の通知1回の場合を含み、恒真のアサーションは見当たりませんでした。
- 運用: data-definition.md（30,000件の上限・ID の形・文字数・{エリアのキー} の書き方）、component-design.md、screen-01 / screen-09 に変更が反映されています。新しい版は書き込まないので、revert で戻せない変更はありません。

### 未検証
- テストは実行していません（依頼元の指示によるものです）。緑かどうかは、依頼元の全体の実行結果で確かめてください。
- quiz_screen.tscn・wireframes.drawio・.steering の中身は、機密の文字列の grep だけで、配置や記述は読んでいません。
- quiz.json の各問題の内容（人数と文の整合）は、tests/content/quiz_content_test.gd に任せ、目では確かめていません。

### 総合評価
Critical / High の指摘はなく、コミットしてよい状態です。Medium の1件（保存に失敗した回答が、後で保存に成功すると集計から消える）は、直すか、仕様書に明記してテストで固定するか、どちらかの扱いを決めてからコミットすることを勧めます。

### 対応
- Medium（保存に失敗した回答が、後で保存に成功すると集計から消える）: (a) で直した。`UserDataService` は保存に失敗した回答を `_unsaved_answers` に持ち（正答状況に含める）、次の回答のときに古いものから書き直す。今回の回答まですべて書けたら `true`、書けないものが残れば `false`（失敗が続く間の通知は1回だけ）。テスト `test_an_answer_that_failed_to_save_is_written_with_the_next_one` を足し、変異2つ（書き直さずに捨てる・集計に含めない）がどちらも検出されることを確かめた。component-design.md §3.4 の注記も直した
- Low 1（回答ごとの読み書き）: 直さない。戦績と同じ設計で、今の問題数（8問）では回答の件数が小さい
- Low 2（書き込みの大きさの検査が無い）: 直さない。件数の上限 × 1件の最大の大きさが読み込みの上限に収まることを、テストで固定してある
- Low 3（principles.json が読めないときの誤りの件数）: 直さない。開発時だけで、1件目の誤りで原因が分かる

## レビュー完了（2026-10-31）
- 最終ラウンド: 第1回（Critical / High が無いので再レビューは行わない。Medium の修正は、テストと変異で確かめた）
- 新たな Critical / High: なし
- 積み残し: Low 1〜3（上の理由で直さない。Low 2 はテストで固定済み）

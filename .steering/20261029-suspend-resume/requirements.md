# 要求内容

## 概要

試合の途中経過を端末に保存し、アプリを閉じても（強制終了を含む）次の起動時に中断した画面から再開できるようにする（FR-14）。
あわせて、保存の土台（書き込み途中で落ちても壊れない保存・読み込み時の検証）と、試合中のメニューからの中断を作る。

## 背景

P0 の FR-14 が未着手。戦績（FR-13）・設定（FR-15）・チュートリアルの完了もこの保存の土台に乗る。
スマホでは遊んでいる途中でアプリが落ちることがよくあり、シャビが実機で遊ぶときにも効く（2026-10-29 シャビの判断）。

## 実装対象の機能

### 1. 保存の土台（データ層）
- `SaveFileIO`: `.tmp` に書く → 本体を `.bak` へ → `.tmp` を本体へ → `.bak` を消す（component-design.md §4.3「書き込み手順」）。読み込みは本体、無いか壊れていれば `.bak`。`.tmp` は読まずに消す
- 中断データの JSON への変換（`SuspendedMatchEncoder`）と、検証つきの読み込み（`SuspendedMatchDecoder`。data-definition.md §2.1 の表を検査の根拠にする）
- `SuspendedMatchStore`: `load()`（NONE／OK／CORRUPTED）・`save(state)`・`delete()`

### 2. 保存の時点と失敗時の扱い（アプリケーション層）
- 保存の時点①〜④（functional-overview.md「確定事項」）。失敗しても試合は続け、`App.storage_error(SUSPEND_SAVE)` を出し、`has_unsaved_progress()` を真にする
- 起動時の後始末 `inspect_suspended()`、タイトル用の `suspended_status()`、`resume()`、`suspend_to_title()`
- 結果画面からタイトルへ戻るとき（`leave_result`）に中断データを消す

### 3. 画面
- タイトルの再開カード（「前半 7／15・4-3-3 対 4-4-2」とスコア）。押すと中断した画面へ
- 「CPU 対戦」を押したとき、中断中の試合があれば確認する（`NewMatchGate`・`ConfirmDialog`）
- 試合中の画面（S-03〜S-05）のメニュー（`MatchMenu`。「中断してタイトルへ」）。Android の戻る操作でメニューを開閉する
- 保存エラーの通知（`ToastView`。`MainShell` が1つだけ持つ。タイトルを開く前に出たエラーは、開いた後に出す）

## 受け入れ条件

### 保存の土台
- [ ] 保存した試合を読み込むと、すべての項目が元と同じになる。読み込んだ状態から同じ手で進めると、元の試合と同じ結果になる（試合の全ターンで確かめる）
- [ ] data-definition.md §2.1 の範囲外の値（不正なエリア・区分値・10人でない配置・陣形に無い選手・ターン数の超過・形式の版が新しい／無い・JSON でない・5MB 超）は CORRUPTED になる
- [ ] 書き込みの途中で止まった状態（`.tmp` だけ・`.bak` だけ・本体が壊れて `.bak` がある）から、直前に確定した状態を読める
- [ ] `delete()` は本体・`.bak`・`.tmp` をすべて消す

### 保存の時点と再開
- [ ] 試合の作成・ターンの確定・方式の選び直し・ハーフタイムの確定のたびに保存される
- [ ] 保存に失敗しても試合は続き、通知が1回出て、`has_unsaved_progress()` が真になる。次に成功したら偽に戻る
- [ ] 起動時: 破損なら削除して通知（SUSPEND_LOAD）。`FINISHED` なら削除。進行中なら RESUMABLE
- [ ] 再開すると、進行段階が示す画面（TURN→S-03、STYLE_CHANGE→S-04、HALFTIME→S-05）が要求され、スコア・ターン・局面・ボール・配置・陣形・方式が中断前と同じ
- [ ] 中断してタイトルへ戻ると再開カードが出る。結果画面からタイトルへ戻ると出ない

### 画面
- [ ] 再開カードは RESUMABLE のときだけ出る。押すと再開する（二度押しで2回遷移しない）
- [ ] 中断中の試合があるときの「CPU 対戦」は確認を出し、「やめる」なら何もしない
- [ ] S-03〜S-05 の「≡」でメニューが開き、「中断してタイトルへ」でタイトルへ戻る。保存に失敗していたら警告を添えて確認する
- [ ] 保存エラーの通知が `functional-overview.md`「エラーハンドリング」の文言で出る

## 成功指標

- シャビが実機で、試合の途中でアプリを閉じても続きから遊べる

## スコープ外

以下はこのフェーズでは実装しません（次の「終了処理と戦績」の作業で足す）:

- 試合終了時の戦績の記録と、その後に `FINISHED` で保存する終了処理（`FINALIZE_PENDING`・`retry_pending_finalize`・`final_record`）。今回は暫定で、最終ターンまで終えた `IN_PROGRESS` は再開の対象にせず、起動時と結果画面からタイトルへ戻るときに削除する
- `UserDataService` と、メニューの「設定」（設定の保存がまだ無いため、メニューの「設定」は「準備中」で押せなくする）
- 保存形式の変換（`SaveMigrator`。形式の版が 1 だけなので変換する対象が無い）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` - FR-14
- `docs/specs/1_requirements/functional-overview.md` - 確定事項（保存の時点・削除方針・起動時の扱い・再開先）、エラーハンドリング
- `docs/specs/2_basic-design/component-design.md` - §3.2 MatchController、§4.3 端末内保存
- `docs/specs/2_basic-design/usecase.md` - UC-05
- `docs/specs/3_detail-design/data/data-definition.md` - §2.1 中断データ
- `docs/specs/3_detail-design/screen/screen-01-title.md`・`screen-03-match.md`・`screen-04-style-change.md`・`screen-05-halftime.md`・`screen-common.md`

# 設計

## 層ごとの構成

| 層 | ファイル | 役割 |
|---|---|---|
| ドメイン | `domain/match_record.gd`（`MatchRecord`）・`domain/record_period.gd`（`RecordPeriod`） | 戦績1件と、陣形・方式の推移の1区切り。`MatchRecord.of(state, finished_at)` で試合の状態から作る（推移は `ReviewAggregator.segments`。時刻は呼び出し側が渡す） |
| データ | `data/match_record_codec.gd`（`MatchRecordCodec`） | 戦績のファイルの JSON への書き出しと、確かめながらの読み込み（`SaveDataReader`） |
| データ | `data/record_store.gd`（`RecordStore`） | `load_all`・`load_state`・`append`。退避・新しい版・上限 |
| アプリ | `application/user_data_service.gd`（`UserDataService`） | `records`・`append_record`・`totals`。最初に使うときに1回だけ読む。通知は `storage_failed` |
| アプリ | `application/match_finalizer.gd`（`MatchFinalizer`） | 終了処理（記録 → `FINISHED` → 保存）。`MatchController` の行数を増やさないため分ける |
| アプリ | `MatchController`・`SuspendKeeper`・`AppScreens`・`App` | 終了処理の呼び出し・やり直し・状態。`user_data` を足す |
| UI | `s11_records/records_screen.gd`（`RecordsScreen`）・`ResultScreen`・`TitleScreen`・`NewMatchGate`・`MatchScreen`・`MainShell` | 画面 |

## 終了処理の流れ

```
submit_turn
  └ resolve → 保存の時点①（IN_PROGRESS）
     └ 後半を終えた → MatchFinalizer.finalize(state, now)
          ① user_data.append_record(MatchRecord.of(...))   失敗 → null
          ② MatchRules.finish(state)
          ③ keeper.save(finished)                          失敗 → null
        成功 → _state = finished、_is_finalized = true

leave_result
  └ 済んでいない → finalize をやり直す
  └ 済んだ → keeper.delete()／なお失敗 → keeper.keep_pending(state)（FINALIZE_PENDING）
  └ _state を閉じてタイトル

inspect_suspended
  └ keeper.inspect(): FINISHED → 削除（FINALIZED）／最終ターンまで終えた IN_PROGRESS → pending にする
  └ pending があれば retry_pending_finalize() → FINALIZED／FINALIZE_FAILED

retry_pending_finalize
  └ finalize(pending, now) が成功 → keeper.delete()、true
```

- `user_data` が `null`（保存を確かめないテスト）なら、記録は成功した扱い（`store` が `null` のときと同じ）
- やり直しの終了日時は、やり直した時刻（最終ターンの時刻を持っていないため。並び順のずれは、やり直しの間に別の試合を終えたときだけ）
- `final_record()` は結果画面が開くたびに、今の試合の状態から作る（日時は最初に終了処理をした時刻）

## SHOW_RESULT からの中断

`MatchScreen._can_open_menu` に `not is_match_over()` を足す。`suspend_to_title` も試合が終わった後は `false` を返す（UI の誤りへの備え）。

## RecordStore

- 読み込み: `SaveFileIO.read` の検証は「読める、または新しい版」。読んだ文字列が新しい版なら `NEWER_VERSION`、読めれば `OK`、ファイルが無ければ `EMPTY`、それ以外は `CORRUPTED`
- 破損: 本体（無ければ `.bak`）を `.corrupt-<日時>` へ名前を変える。変えられなければ、そのファイルに上書きしないよう `append` は `false`
- `append`: 毎回読み直す（中身を持たない）。新しい版・退避できない破損 → `false`。同じ `match_id` → 書かずに `true`。足してから、件数 3,000・大きさ 4MB を超えなくなるまで古いもの（ファイルの先頭）から捨てる
- ファイルの中は記録した順。`UserDataService.records()` は終了日時の新しい順（同じ日時は後に記録した方が先）

## 検証（MatchRecordCodec）

data-definition.md §2.2 の表のとおり。陣形 ID は ID の形だけを確かめ、カタログにあるかは見ない（陣形を減らした後も、過去の戦績を破損にしないため。形の確認は実装検証の提案で足した）。
`result` とスコアの一致、`record_id` と `match_id` の一致、`match_id` の重複なし、推移の件数（1〜最大ターン×2＋2）、`half` 1〜2、`from_turn` 1〜最大ターン。

## UserDataService の通知

| 起きたこと | 通知 |
|---|---|
| 最初の読み込みで破損 | `USER_DATA_LOAD`（1回） |
| 最初の読み込みで新しい版 | `USER_DATA_NEWER`（1回） |
| `append_record` の失敗 | 新しい版なら `USER_DATA_NEWER`、それ以外は `USER_DATA_SAVE` |

## 画面

- **S-06**: `HistoryCard` に推移の行。各ハーフの最初は「前半: ● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 マンツーマン・カウンター型」、
  ハーフの途中の変化は「後半 4ターン目: CPU が守備方式をゾーンに変更」（変えた側・変えた方式ごとに1行）
- **S-11**: `ScreenHeader`、左に `TotalsCard`（440px）、右に `RecordList`（50件ずつ。下端までスクロールしたら足す）。
  行は「勝ち　2 – 1　10/17 19:42」と「● 4-3-3 ゾーン・保持型 対 ◆ 4-4-2 …」（前半）。0件は `EmptyState` と CPU 対戦（`NewMatchGate`）
- **S-01**: `RecordsCard` に一言のラベル `RecordsSub` を足す。`NewMatchGate` は `FINALIZE_PENDING` の確認を足す
- 文言は `ui/common/record_texts.gd`（`RecordTexts`）に集める

## テスト

- `tests/domain/match_record_test.gd`: 勝敗・推移（ハーフタイム・方式の選び直し）
- `tests/data/record_store_test.gd`: 往復・冪等・上限・破損の退避・新しい版・範囲外の項目
- `tests/application/user_data_service_test.gd`: 並び順・通算・通知
- `tests/application/match_controller_finalize_test.gd`: 終了処理・失敗・やり直し・起動時・`FINALIZE_PENDING`・再開後のスコア
- `tests/ui/records_screen_test.gd`・既存の結果・タイトル・試合画面のテストに追記
- 保存の失敗は、保存先をファイルにして作れなくする（`.tmp` が作れない）

## 受け入れた制約（コミット前レビュー L-3）

最終ターンの保存（保存の時点①）と終了処理の両方に失敗すると、中断データには1ターン前の `IN_PROGRESS` が残り、次の起動で
最終ターンをもう一度できる。戦績を記録できていた場合は、同じ試合 ID は記録されず最初の結果が残る（二重記録にはならない）。
保存が2回続けて失敗する場合に限るので受け入れる。

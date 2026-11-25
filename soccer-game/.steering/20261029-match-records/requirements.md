# 要求内容

## 概要

試合の終了処理（戦績の記録）と、戦績の閲覧（S-11）を作る（FR-13）。あわせて、中断・再開の作業で残した
「終了処理のやり直し」を仕上げる。

## 背景

中断・再開（`.steering/20261029-suspend-resume/`）で保存の土台はできたが、終わった試合は中断データを消すだけで、
結果がどこにも残らない。終了処理が無い間の仮の扱い（最終ターンまで終えた `IN_PROGRESS` を起動時に消す `DISCARDED`）を、
設計どおりの終了処理のやり直しに替える。

## 実装対象の機能

### 1. 試合の終了処理（確定事項「試合終了から破棄までの順序」）
- 後半を終えたターンの確定時に、戦績を記録し（同じ試合 ID があれば記録しない）、成功したら試合を `FINISHED` にして中断データを上書きする
- どちらかに失敗したら、中断データは `IN_PROGRESS` のまま残る
- 結果画面からタイトルへ戻るとき（`leave_result`）、終了処理が済んでいれば中断データを消す。済んでいなければやり直し、なお失敗したら消さずに残す
- 起動時（`inspect_suspended`）に最終ターンまで終えた `IN_PROGRESS` があれば、終了処理をやり直す（`FINALIZED`／`FINALIZE_FAILED`）。`FINISHED` は消す（`FINALIZED`）
- 残った試合は `suspended_status()` が `FINALIZE_PENDING` を返す。CPU 対戦の前に `retry_pending_finalize()` でやり直し、なお失敗したら「前の試合の戦績を記録できていません。新しい試合を始めると、その戦績は記録されません」と確かめる

### 2. 戦績の保存（`RecordStore`。data-definition.md §2.2）
- `match_records.json` に書く。書き込みは `SaveFileIO` の手順
- 件数の上限 3,000 件、書き込み後の大きさの上限 4MB。超えるなら古いものから捨てる
- 破損なら本体を `<名前>.corrupt-<YYYYMMDD-HHMMSS>` へ退避して初期状態（0件）。退避できなければ書き込まない
- 新しい版（`format_version` が今より新しい）なら0件で表示し、書き込まない

### 3. 戦績の参照（`UserDataService`。component-design.md §3.4）
- `records()`（新しい順）・`append_record()`・`totals()`。最初に使うときに1回だけ読む
- 読み込みの破損・新しい版、保存の失敗を `App.storage_error` で知らせる

### 4. 画面
- S-06 試合結果: 陣形・方式の推移（`final_record()`）を出す
- S-11 戦績: 通算の勝ち・引き分け・負けと、新しい順の一覧（最初に50件、下端で次の50件）。0件なら「まだ試合の記録がありません」と CPU 対戦
- S-01 タイトル: 戦績のカードの一言（「5勝 2分 3敗」／「まだ記録がありません」）、CPU 対戦の `FINALIZE_PENDING` の確認
- S-03 試合: 最終ターンの判定理由（試合終了の後）ではメニューを開かない（前の作業からの申し送り）

### 5. 前の作業からの申し送り
- 再開した試合で「`review()` の最後の得点のスコア ＝ `snapshot()` のスコア」を確かめるテスト

## 受け入れ条件

- [ ] 後半の最終ターンを確定すると、戦績が1件増え、中断データは `FINISHED` で保存される
- [ ] 戦績の保存に失敗すると、中断データは `IN_PROGRESS` のまま残り、`leave_result` でやり直して成功すれば消える。なお失敗すれば残り、`suspended_status()` が `FINALIZE_PENDING`
- [ ] 起動時に最終ターンまで終えた `IN_PROGRESS` があれば記録をやり直す。同じ試合を二重に記録しない
- [ ] `FINALIZE_PENDING` で CPU 対戦を押すと、やり直しが成功すれば確認なしで試合準備へ、失敗すれば確認を出す
- [ ] 戦績のファイルが壊れていれば退避して0件、新しい版なら0件で書き込まない。どちらも通知を1回出す
- [ ] 3,000 件を超える記録は古いものから捨てる
- [ ] S-11 で通算と新しい順の一覧が出る。50件を超えると下端で足す。0件なら CPU 対戦を出す
- [ ] S-06 に陣形・方式の推移が出る
- [ ] 最終ターンの判定理由の間はメニューを開けない
- [ ] 全テストが通る

## スコープ外

- 理解度チェックの結果・設定の保存（`UserDataService` の quiz・settings。それぞれの作業で足す）
- タイトルのチュートリアルの位置の切り替え（設定の作業）
- `SaveMigrator`（形式の版は 1 だけ）
- 戦績の消去（MVP では持たない）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` FR-13
- `docs/specs/1_requirements/functional-overview.md`「確定事項」「エラーハンドリング」
- `docs/specs/2_basic-design/component-design.md` §3.2・§3.4・§4.3
- `docs/specs/3_detail-design/data/data-definition.md` §2.2
- `docs/specs/3_detail-design/screen/screen-01-title.md`・`screen-06-result.md`・`screen-11-records.md`

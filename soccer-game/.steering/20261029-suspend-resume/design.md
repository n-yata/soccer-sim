# 設計書

## アーキテクチャ概要

```
MatchController ──save/load/delete──▶ SuspendedMatchStore ──▶ SaveFileIO（.tmp/.bak の手順）
      │                                     ├─ SuspendedMatchEncoder（MatchState → Dictionary）
      │                                     └─ SuspendedMatchDecoder（Dictionary → MatchState。検証。誤りなら null）
      └─ storage_failed(kind) ──▶ App.storage_error ──▶ MainShell の ToastView
```

ドメインはファイルを触らない（NFR-13）。変換と検証はデータ層に置く。

## コンポーネント設計

### 1. `SaveFileIO`（`data/save_file_io.gd`）
- `write(path, text) -> bool`: `.tmp` に書く → 本体があれば `.bak` へ → `.tmp` を本体へ → `.bak` を消す
- `read(path, is_valid: Callable) -> String`: `.tmp` があれば消す。本体を読み、`is_valid` が偽（または無い）なら `.bak` を読む。どちらも駄目なら空文字。
  大きさの上限（5MB）を超えるファイルは読まない
- `exists(path)`・`delete(path) -> bool`（本体・`.bak`・`.tmp`）

### 2. `SuspendedMatchEncoder` / `SuspendedMatchDecoder`（`data/`）
- エンコーダは data-definition.md §2.1 の形の Dictionary を作る。区分値は enum の名前、エリアは `"M2-L1"`
- 配置（`players`・`transition_origin`・記録の `players_before`・`players_at_judgement`）は、選手ごとに `player_id`・`base_area`・
  `fixed_area`・`current_area`・`moved_in_turn`。配置（`TeamLayout`）の現在エリアは `current_area` に書く
  （ターンの中の計算は配置の現在エリアを読み、選手の `current_area` は読まないため。読み込みでは両方に同じ値を入れる）
- デコーダは型・必須・範囲を検査し、1つでも外れたら null（誤りは `errors()` で読める。テストと開発時のログ用）
- 範囲の根拠: 陣形は `ContentCatalog`、ターン数の上限は `MatchRuleConfig`（1ハーフのターン数＋アディショナルタイムの最大ターン数）

### 3. `SuspendedMatchStore`（`data/suspended_match_store.gd`）と `SuspendedLoad`
- `_init(catalog, rules, dir = "user://")`。ファイル名は `suspended_match.json`
- `load() -> SuspendedLoad`（`status: Status { NONE, OK, CORRUPTED }`・`state`）。新しい版も CORRUPTED
- `save(state) -> bool`、`delete() -> bool`

### 4. `MatchController` の追加
- `_init` の最後に `store: SuspendedMatchStore = null` を足す（null なら保存しない。既存のテストとチュートリアル用）
- `signal storage_failed(kind: AppScreens.StorageErrorKind)`（App が `storage_error` へ中継する）
- 保存の時点: `start_match`（失敗したら古い中断データを消す。前の試合を再開してしまわないため）・`submit_turn`（判定の直後、開示より前）・
  `submit_style_change`・`submit_halftime`・`suspend_to_title`（未保存のときだけ）
- `enum SuspendedStatus { NONE, RESUMABLE }`（FINALIZE_PENDING は戦績の作業で足す）、`enum StartupResult { NONE, RESUMABLE, DISCARDED, CORRUPTED }`
  （DISCARDED は FINISHED と、最終ターンまで終えた IN_PROGRESS。戦績の作業で FINALIZED・FINALIZE_FAILED に分ける）
- `inspect_suspended()`: 起動時に1回。CORRUPTED → 削除して `storage_failed(SUSPEND_LOAD)`。FINISHED・最終ターンまで終えた → 削除。
  それ以外 → タイトル用の写しを持って RESUMABLE
- `suspended_status()`・`suspended_snapshot()`（タイトルの再開カード用。試合中でない間に、中断データの盤面を返す）
- `resume() -> bool`: store から読み直し、状態を置いて、進行段階の画面を要求。読めなければ削除・通知・S-01 を要求して false
- `suspend_to_title() -> bool`: 未保存なら保存をやり直し、メモリ上の試合を閉じて（再開カード用の写しを残す）S-01 を要求。保存の成否を返す
- `leave_result()`: 中断データを消してから S-01（戦績の作業で、終了処理が済んでいる場合だけ消す形に変える）
- 再開した試合の `last_goal_by` は、ターン記録の最後の GOAL から出す（方式の選び直し画面の「〜が得点しました」）

### 5. UI
- `ToastView`（`ui/common/toast_view.gd`）: 画面の下に短い文を数秒出す。`MainShell` が1つ持ち、`App.storage_error` を受ける。
  タイトルを開く前に出たものは保持し、タイトルを開いたら出す
- `ConfirmDialog`（`ui/common/confirm_dialog.gd`）: `ask(message, ok_label, cancel_label)`・`answered(ok)`・`is_open()`・`cancel()`
- `MatchMenu`（`ui/common/match_menu.gd`）: `open(has_unsaved_progress)`・`suspend_requested`・`closed`。項目は「設定（準備中）」「中断してタイトルへ」「閉じる」。
  未保存のときは「中断してタイトルへ」で警告つきの確認を出す
- `NewMatchGate`（`ui/common/new_match_gate.gd`）: `begin(host, dialog)`・`finished(started)`
- `TitleScreen`: 再開カード・状態 `IDLE`／`BUSY`／`CONFIRMING`・NewMatchGate
- S-03〜S-05: 上部バーに「≡」。メニューを開いている間は戻る操作で閉じ、それ以外は開く
- `MainShell`: 起動時に `inspect_suspended()` を呼んでからタイトルを開く

## データフロー

### 強制終了から再開
```
1. submit_turn → resolve_turn → store.save（開示より前）
2. （強制終了）
3. 起動 → MainShell → inspect_suspended → RESUMABLE
4. タイトル → 再開カード → resume → store.load → S-03/S-04/S-05
```

## エラーハンドリング戦略

- 保存の失敗: `storage_failed(SUSPEND_SAVE)` を出し、`_has_unsaved` を真。試合は続ける。同じ失敗が続くたびに通知を重ねない
  （失敗の連続中は最初の1回だけ通知し、成功したら戻す）
- 読み込みの失敗・破損: 中断データを削除し `storage_failed(SUSPEND_LOAD)`
- デコーダの誤りは `push_error` しない（改変された保存データは利用者の誤りではない。テストは `errors()` を読む）

## テスト戦略

### ユニットテスト
- `SaveFileIO`: 書き込みの手順の各状態（`.tmp` だけ・`.bak` だけ・本体が壊れて `.bak`）・削除・大きさの上限
- エンコーダ／デコーダ: 固定シードの試合の全ターンの状態で往復が一致し、続きの1ターンが同じ結果になる。範囲外の値を1つずつ入れて null になる
- `SuspendedMatchStore`: NONE・OK・CORRUPTED（JSON でない・版が新しい・版が無い）
- `MatchController`: 保存の時点ごとに保存されること・保存の失敗（書けない場所の store）・inspect の4通り・resume の3つの画面・suspend_to_title・leave_result での削除

### 画面テスト
- タイトル: 再開カードの有無と文・押して再開・CPU 対戦の確認（始める／やめる）・BUSY 中の二度押し
- S-03〜S-05: メニューの開閉・戻る操作・中断してタイトルへ・未保存の警告
- MainShell: タイトルを開く前の通知を、開いた後に出す

## ディレクトリ構造

```
game/data/save_file_io.gd・suspended_match_encoder.gd・suspended_match_decoder.gd・suspended_match_store.gd・suspended_load.gd   新規
game/application/match_controller.gd・app.gd                                変更
game/ui/common/toast_view.gd・confirm_dialog.gd・match_menu.gd・new_match_gate.gd   新規
game/ui/screens/s01_title・s03_match・s04_style_change・s05_halftime、ui/main_shell.gd、ui/common/match_screen_layout.gd   変更
game/tests/data/・tests/application/・tests/ui/                              追加
```

## 実装の順序

1. SaveFileIO → エンコーダ／デコーダ → ストア（往復のテストを先に）
2. MatchController の保存の時点・起動時・再開・中断
3. App の storage_error・MainShell の起動時と通知
4. ConfirmDialog・MatchMenu・NewMatchGate → タイトル → S-03〜S-05
5. 全テスト・変異・スクリーンショット・仕様書の更新

## セキュリティ考慮事項

- 保存データは利用者が改変しうる入力として扱う。型・範囲を検査し、外れたら使わない（NFR-09）。大きさの上限で全量読み込みを防ぐ
- 外部通信なし。保存先は `user://` だけ

## パフォーマンス考慮事項

- 1試合の中断データは数百 KB 以内（ターン記録が最大 40 件前後）。保存はターンの確定ごとに1回で、開示の動きより前に終わる

## 将来の拡張性

- 戦績の作業で、終了処理（`FINALIZE_PENDING`）と `UserDataService` を足す。`SaveFileIO` は戦績・設定でも使う

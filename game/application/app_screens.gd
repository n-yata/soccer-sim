## アプリケーション層の区分値（component-design.md §3.1）: 画面 ID・保存エラーの種類・中断データの状態。
## 画面 ID は画面一覧（functional-overview.md「画面設計」）の S-01〜S-12 と1対1。
## 中断データの状態は MatchController・SuspendKeeper と UI（タイトル・NewMatchGate）が読むので、特定のクラスの内側に置かず
## ここに集める（coding-gdscript.md「enum はクラスに属させる」。2026-10-29）。
class_name AppScreens
extends RefCounted

## NONE: なし／RESUMABLE: 再開できる（再開カードを出す）／FINALIZE_PENDING: 終了処理（戦績の記録）が済んでいない試合が残っている
enum SuspendedStatus { NONE, RESUMABLE, FINALIZE_PENDING }
## 起動時の後始末の結果（MatchController.inspect_suspended）。FINALIZED は終了処理が済んだ試合を消した（FINISHED を見つけた、
## または最終ターンまで終えた IN_PROGRESS の終了処理をやり直して済んだ）。FINALIZE_FAILED はやり直しにも失敗して残した
enum StartupResult { NONE, RESUMABLE, FINALIZED, FINALIZE_FAILED, CORRUPTED }

enum Id {
	S01_TITLE,
	S02_MATCH_SETUP,
	S03_MATCH,
	S04_STYLE_CHANGE,
	S05_HALFTIME,
	S06_RESULT,
	S07_REVIEW,
	S08_TUTORIAL,
	S09_QUIZ,
	S10_SCOPE,
	S11_RECORDS,
	S12_SETTINGS,
}

## 文言の対応は functional-overview.md「エラーハンドリング」
enum StorageErrorKind { SUSPEND_SAVE, USER_DATA_SAVE, SUSPEND_LOAD, USER_DATA_LOAD, USER_DATA_NEWER }

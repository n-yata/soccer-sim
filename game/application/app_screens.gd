## 画面 ID と保存エラーの種類（component-design.md §3.1）。
## 画面 ID は画面一覧（functional-overview.md「画面設計」）の S-01〜S-12 と1対1。
class_name AppScreens
extends RefCounted

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

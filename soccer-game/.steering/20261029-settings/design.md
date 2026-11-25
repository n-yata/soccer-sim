# 設計

## 層ごとの構成

| 層 | ファイル | 役割 |
|---|---|---|
| ドメイン | `domain/user_settings.gd`（`UserSettings`） | 設定の値（`bgm_volume`・`se_volume`・`show_hints`・`tutorial_completed`）。初期値は定数 |
| データ | `data/settings_store.gd`（`SettingsStore`） | `load()`・`load_state()`・`save()`。`LoadState` は `RecordStore` と同じ名前の値 |
| データ | `data/save_file_io.gd` | 退避（`move_aside(source, path)`。日時と連番の名前）を足し、`RecordStore` と共用する |
| アプリ | `application/user_data_service.gd` | `settings()`（写し）・`save_settings()`・`mark_tutorial_completed()`。`_init(record_store, settings_store)` |
| UI | `ui/common/audio_buses.gd`（`AudioBuses`） | 設定をバス `BGM`・`SE` へ反映する |
| UI | `ui/common/settings_panel.gd`（`SettingsPanel`） | 設定の中身（スライダー・トグル・ライセンス）。`show_settings`・`changed`・`committed`・`license_requested` |
| UI | `ui/common/license_view.gd`（`LicenseView`） | ライセンスの表示（`ModalOverlay`。スクロールする本文と閉じる） |
| UI | `ui/common/settings_overlay.gd`（`SettingsOverlay`） | 試合中のメニューから重ねて開く設定（`ModalOverlay` に `SettingsPanel` と閉じる） |
| UI | `s12_settings/settings_screen.gd`（`SettingsScreen`） | S-12 |
| UI | `MatchMenu`・`MatchMenuHost`・`MatchScreen`・`MatchBoardPanel`・`MainShell` | 設定のボタン・重ねた設定・ヒントの描き直し・起動時のバス |

`SettingsPanel` は、詳細設計の `.tscn` ではなくスクリプトで部品を組み立てる（振り返り・戦績の画面と同じ形。`.new()` で作れる）。

## SettingsStore

- ConfigFile の文字列（`encode_to_text`）を `SaveFileIO.write` で書く。読み込みは `SaveFileIO.read` の検証で
  「この設定の書式で読めて `[meta] format_version` が 1 以上の整数」なら使う
- **読み込みは `ConfigFile.parse` を使わない**（コミット前レビュー H-1 で変えた）。`ConfigFile.parse` は値の `Object(...)`・`Resource(...)` から
  オブジェクトを作り、リソースを読み込む。限定の読み方（`SettingsStore.parse`）は「[節]」「キー=値」「注釈」「空行」と、値の整数・小数・
  true・false だけを受け付ける（単純な文字列と英字だけの語は型違いとしてキーごとに初期値、組み立てる書き方は破損）
- 本体が壊れていて `.bak` が読めるときは、壊れた本体を退避してから `.bak` を使う（戦績と同じ。コミット前レビュー M-1）
- 新しい版（`format_version` > 1）: 初期値、`NEWER_VERSION`、`save` は `false`
- 読めない（`format_version` が無い・整数でない・1 未満・書式に合わない）: `SaveFileIO.move_aside` で退避して初期値、`CORRUPTED`。
  退避できなければ `save` は `false`（壊れたファイルを上書きしない）
- キーごと: 音量は数（整数か小数）で有限、0.0〜1.0。真偽値は bool。外れたら、そのキーだけ初期値（`OK` のまま。通知しない）

## UserDataService

- 設定の読み込みの通知: 破損 `USER_DATA_LOAD`・新しい版 `USER_DATA_NEWER`（1回）
- 保存の失敗の通知は、戦績とは別に「続く間1回」（新しい版は読んだときに知らせ済み）
- 保存に失敗しても持っている値は更新する（画面上の値を保つ。screen-12「保存に失敗しても画面上の値は保持する」）
- `settings()` は写しを返す（画面が書き換えても、保存するまで持っている値は変わらない）

## 音量

- `default_bus_layout.tres` に `BGM`・`SE`（送り先 `Master`）。`AudioBuses.apply(settings)`: `volume_db = linear_to_db(値)`、0 なら `mute`
- バスが無ければ（レイアウトが読めない）`push_error` して何もしない
- 起動時: `MainShell._ready` で `AudioBuses.apply(App.user_data.settings())`

## 画面

- **SettingsPanel**: `show_settings(settings)` で値を入れる（このときは `changed`・`committed` を出さない）。
  スライダーの値が変わったら `changed(settings)` を出し、バスへ反映する。`drag_started`〜`drag_ended` の間は保存しない。
  ドラッグでない変更（キー操作・押した位置へ飛ぶ）と `drag_ended`・トグルで `committed(settings)`
- **SettingsScreen**: `committed` → `App.user_data.save_settings()`。戻る: ライセンスが開いていれば閉じる、それ以外はタイトル
- **SettingsOverlay**: メニューの「設定」で開く（メニューの上に重ねる）。`committed` で保存し、ヒント表示が変わったら
  `hints_changed` を出す。閉じるとメニューに戻る
- **MatchMenuHost**: `_init(screen, top_bar, can_open, on_hints_changed: Callable = Callable())`。戻る操作は
  ライセンス → 設定 → 確認 → メニューの順に、いちばん上を閉じる
- **MatchBoardPanel**: `start_turn` で、ヒント表示が OFF なら `user_hints()` を呼ばず空にする。`set_show_hints(is_on)` は
  ヒントを取り直し（または空にし）、`SELECT_TARGET`・`READY` なら選んだ手（と運ぶ先）を選び直して描き直す
- **ライセンス**: `res://assets/fonts/barlow-condensed/OFL.txt`（著作権表示を含む）を読む。書き出しの `include_filter` に
  `assets/fonts/*/OFL.txt` を足す（`.json` 以外の同梱しないファイルは書き出しに入らないため）

## テスト

- `tests/data/settings_store_test.gd`: 往復・キーごとの初期値・破損の退避・新しい版・保存の失敗
- `tests/application/user_data_service_test.gd`: 設定の写し・保存・通知・`mark_tutorial_completed`
- `tests/ui/settings_screen_test.gd`: パネルの値・保存の時点・バス・戻る・ライセンス
- `tests/ui/match_menu_test.gd`: メニューの設定・戻る操作の順・ヒントの切り替え

# 設計書

## アーキテクチャ概要

```
App（オートロード。application/app.gd）
  └─ screen_requested(id, params) ─────────────┐
                                                ▼
MainShell（ui/main_shell.tscn。メインシーン。Control）
  ├─ ScreenRoot（MarginContainer。左右の余白 = セーフエリアの分）
  │    └─ 表示中の画面（AppScreen を継承した各画面のシーン）
  └─ _switcher: ScreenSwitcher（RefCounted。画面の入れ替えと戻る操作の振り分け）
```

- 画面どうしは直接遷移せず、`App.request_screen()` を経由する（`component-design.md` §5.1）。
- `MainShell` は、入力（Android の戻る操作・Esc）とセーフエリアを受け持つ。画面の入れ替えの手順は `ScreenSwitcher` に任せる。

## コンポーネント設計

### 1. `AppScreens`（`game/application/app_screens.gd`）

- `class_name AppScreens extends RefCounted`。`enum Id { S01_TITLE, ..., S12_SETTINGS }`、`enum StorageErrorKind { SUSPEND_SAVE, USER_DATA_SAVE, SUSPEND_LOAD, USER_DATA_LOAD, USER_DATA_NEWER }`（`component-design.md` §3.1）。

### 2. `App`（`game/application/app.gd`。オートロード名 `App`）

- `extends Node`。`class_name` は付けない（オートロード名と衝突するため。`component-design.md` §3.1）。
- `signal screen_requested(screen: AppScreens.Id, params: Dictionary)` と `func request_screen(screen, params = {})`。
- サービスの変数・`storage_error`・`new_tutorial_controller()` は、それぞれのサービスを作る作業で足す。

### 3. `AppScreen`（`game/ui/common/app_screen.gd`。新しいクラス）

**責務**: 画面の共通の約束（`screen-common.md` §4）を型で表す。

- `class_name AppScreen extends Control`。`enter(params: Dictionary) -> void`・`exit() -> void`・`handle_back() -> bool` を持つ。
  既定の動きは、何もしない・何もしない・`false`。
- 各画面のルートはこれを継承する（`Control` の継承のまま。`screen-common.md` §4 の「ルートは `Control`」を満たす）。
- 理由: 型の警告をエラーにしている。画面の型が `Node` のままだと、`enter()` などを呼べない（`unsafe_method_access`）。

### 4. `ScreenSwitcher`（`game/ui/screen_switcher.gd`。新しいクラス）

**責務**: 画面のシーンの入れ替えと、戻る操作の振り分け。

- `_init(container: Node, scene_paths: Dictionary)`: `scene_paths` は `AppScreens.Id` → シーンのパス。
- `open(screen: AppScreens.Id, params: Dictionary) -> bool`
  - 対応が無い、またはシーンを読めない、またはルートが `AppScreen` でない場合は、`push_error` して `false` を返す。今の画面はそのまま。
  - 開けるときは、古い画面の `exit()` を呼び、`container` から外して `queue_free()` する。新しい画面を `container` に足し、`enter(params)` を呼ぶ。
- `current() -> AppScreen`（無ければ null）、`current_id() -> int`（無ければ -1）。
- `route_back() -> bool`: 表示中の画面の `handle_back()` を1回呼んで、その値を返す。画面が無ければ `false`。
- 本番は `MainShell.SCREEN_SCENES`、テストはテスト用の対応を渡す（テスト専用の入口を本番のコードに置かない）。
- `MainShell` は `screen_requested` を受けたら、`open()` を遅らせて呼ぶ（`call_deferred`）。画面のボタンの `pressed` の中で要求が来るため、その場で入れ替えると、押されたボタンを持つ画面ごと処理の途中で外すことになる（実装レビューの提案）。
- 戻る操作で閉じるかの判断は `should_quit_after_back()` に分け、`get_tree().quit()` を呼ばずにテストできるようにした。

### 5. `MainShell`（`game/ui/main_shell.gd`・`main_shell.tscn`）

- `class_name MainShell extends Control`。
- `const SCREEN_SCENES: Dictionary`: 画面 ID → シーンのパス。今は S-01 だけ。画面を作ったら1行足す。
- `static func has_screen(screen: AppScreens.Id) -> bool`: タイトルが、カードを押せるかの判断に使う。
- `_ready()`:
  - `ScreenSwitcher` を作る。
  - `App.screen_requested` に接続する。
  - セーフエリアの余白を当てる。
  - タイトルを開く（`App.request_screen(S01_TITLE)`）。
  - 起動時に呼ぶ予定の `MatchController.inspect_suspended()` などは、サービスを作る作業で足す。
- 戻る操作（`screen-common.md` §4.1）:
  - `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` と、`_unhandled_input` の `event.is_action_pressed("ui_cancel")` を受ける。
    Esc を受けたら `get_viewport().set_input_as_handled()` を呼ぶ。
  - どちらも `_on_back_requested()` に集める。そこで `_switcher.route_back()` を呼び、`false` なら `get_tree().quit()`。
  - デバッグビルドでだけ、「戻る操作 → 画面 ID と結果」をログに出す。エミュレーターで、1回だけ呼ばれたことを確かめるため。
- セーフエリア:
  - `static func side_margins(window_size: Vector2i, safe_area: Rect2i, viewport_height: float) -> Vector2`。左右の余白（基準解像度の px）を返す純粋な関数。
    `keep_height` なので、倍率は `viewport_height / window_size.y`。
  - 余白を当てるのは、モバイル（`OS.has_feature("mobile")`）のときだけ。PC の `get_display_safe_area()` は画面全体の範囲で、ウィンドウとは関係ないため。
  - 画面の大きさが変わったとき（`get_viewport().size_changed`）も当て直す。
  - 外周の余白 24px は、各画面が自分の配置で持つ（`screen-common.md` §1.1 の表）。`MainShell` が足すのはセーフエリアの分だけ。

### 6. `TitleScreen`（`game/ui/screens/s01_title/title_screen.tscn`・`.gd`）

- `screen-01-title.md` のノード構成のうち、`Hero`（`StadiumArt` を除く）と `Cards`（`ResumeCard` は置くが隠す）を作る。
- `enter(params)`:
  - 再開カードを隠す（`MatchController` ができるまで）。
  - チュートリアルを、未完了の位置に置く（設定の読み込みに失敗したときと同じ扱い。`screen-01-title.md`「例外・エラー表示」）。
  - `apply_availability(MainShell.SCREEN_SCENES)` を呼ぶ。
  - 状態（`IDLE`・`BUSY`・`CONFIRMING`）は持たない。骨格の段階では `IDLE` しか起きないため。`BUSY`・`CONFIRMING` は `NewMatchGate` を作る作業で足す（実装レビューの指摘で設計を実装に合わせた）。
- `apply_availability(scene_paths: Dictionary)`: 各カードの行き先が `scene_paths` に無ければ、`disabled = true` にして「準備中」のラベルを出す。
  - 画面ができれば自動的に押せるようになる。テストでは対応を渡して両方の場合を確かめる。
- カードを押したら、`App.request_screen(行き先)`。
- `handle_back()`: 常に `false`（`IDLE` の動き。`screen-01-title.md`）。
- 押せないカードの中の文字は、テーマの選択不可の文字色（`Button` の `font_disabled_color`）にそろえる（PC での確認で、黄色の地向けの暗い文字が読めないと分かったため）。

### 7. テーマ（`game/ui/common/theme/app_theme.tres`）

- プロジェクト設定 `gui/theme/custom` に指定し、すべての `Control` に効かせる。各画面は色を書かない（`screen-common.md` §3）。
- 既定のスタイルと、型の変化形（theme type variation）を定義する。
  - `Button`: 地 `surface`、文字 `text`、押した見た目は縁（4px の `accent`。`AccentCard` は `text` の縁）、選択不可は `disabled_bg`・`disabled_text`。`hover`・`hover_pressed` は通常・押したときと同じ、フォーカスの枠は出さない（§4.1）。
  - `Label`: 文字 `text`。
  - 変化形: `AccentCard`（地 `accent`・文字 `bg`）、`DisplayHeading`（Barlow Condensed Bold）、`TagLabel`（地 `accent` の帯・文字 `bg`・Barlow Condensed SemiBold）、`YouTagLabel`（地 `you`・文字 `bg`。「はじめての方へ」）、`SubLabel`（文字 `text_sub`）、`MutedLabel`（文字 `muted`。「準備中」など）、`CardTitleLabel`・`KickOffLabel`・`KickOffSubLabel`（カードの中の文字）。
- 画面の地は、`rendering/environment/defaults/default_clear_color` を `bg`（`#070D18`）にして塗る。
- `.tres` は手で書く（StyleBoxFlat のサブリソースとフォントの参照）。色の値は `screen-common.md` §3 の写しなので、ファイルの先頭のコメントに正本を書く。

## データフロー

### 起動からタイトル
1. Godot がメインシーン `MainShell` を開く（オートロード `App` は先に用意される）。
2. `MainShell._ready()` が `App.request_screen(S01_TITLE)` を呼ぶ → `screen_requested` → `_switcher.open()` → `TitleScreen.enter({})`。

### 戻る操作
1. Android の戻る操作 または Esc → `MainShell._on_back_requested()` → `_switcher.route_back()` → `TitleScreen.handle_back()`（`IDLE` は `false`）→ `get_tree().quit()`。

## エラーハンドリング戦略

- 対応の無い画面を求められた: `ScreenSwitcher.open()` が `push_error` して今の画面のままにする。画面のボタンは対応の有無で押せなくしているので、通常は起きない（起きたら開発時の誤り）。
- 設定の取り違えで、アプリが Android の戻る操作で勝手に閉じる: `application/config/quit_on_go_back=false` は前の作業で入れた。今回、エミュレーターで実際の動きを確かめる。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/application/app_test.gd`: `request_screen()` が `screen_requested` を同じ値で1回出す。
- `tests/ui/screen_switcher_test.gd`: テスト用の画面のシーン（`tests/fixtures/screens/`。呼ばれた回数を記録する `AppScreen`）を使う。
  - 開く・入れ替える（古い画面の `exit()` が先、新しい画面の `enter()` に引数が渡る、古い画面が外れる）。
  - 対応が無い／ルートが `AppScreen` でない場合は、今の画面のまま `false` を返す。
  - `route_back()` は1回だけ `handle_back()` を呼び、その値を返す。画面が無ければ `false`。
- `tests/ui/main_shell_test.gd`:
  - `side_margins()`: 切り欠きなし、左だけ、左右、倍率（窓の高さが基準と違う）。
  - `has_screen()`: S-01 はある、S-02 は無い（今の状態）。
- `tests/ui/title_screen_test.gd`:
  - シーンを開いて `apply_availability()` に対応ありと対応なしを渡し、`disabled` と「準備中」の表示を確かめる。
  - `IDLE` の `handle_back()` が `false` を返す。
  - カードを押すと、`App.request_screen` が行き先の ID で呼ばれる（`screen_requested` の受信で確かめる）。

### 実際の画面での確認（手で行い、結果を記録する）
- PC: 使い捨ての撮影スクリプトで、ウィンドウを 1280×720 と 1600×720 にして画面を撮る。Esc でアプリが閉じることも確かめる。
- Android エミュレーター: 書き出した APK を入れて起動し、タイトルが出ることを確かめる。
  - 戻る操作（`adb shell input keyevent 4`）で、ログの「戻る操作 → S01: false」が1回だけ出てアプリが閉じることを確かめる。
  - 試合画面などで閉じないことは、`handle_back()` が `true` を返す仮の画面で確かめる。仮の画面は、`SCREEN_SCENES` に一時的に足し、確認後に消す。

## 依存ライブラリ

追加なし。

## ディレクトリ構造

```
game/
├── application/{app.gd, app_screens.gd}
├── ui/
│   ├── main_shell.tscn / main_shell.gd
│   ├── screen_switcher.gd
│   ├── common/{app_screen.gd, theme/app_theme.tres}
│   └── screens/s01_title/{title_screen.tscn, title_screen.gd}
└── tests/
    ├── application/app_test.gd
    ├── ui/{screen_switcher_test.gd, main_shell_test.gd, title_screen_test.gd}
    └── fixtures/screens/{recording_screen.gd, recording_screen.tscn, not_a_screen.tscn}
```

## 実装の順序

1. `AppScreens`・`App`（テスト先行）
2. `AppScreen`・`ScreenSwitcher`（テスト先行）
3. `MainShell`（`side_margins` のテスト先行）と `project.godot`（メインシーン・オートロード・テーマ・地の色）
4. テーマ
5. `TitleScreen`（テスト先行）
6. PC での確認 → APK とエミュレーターでの確認
7. 文書の更新（`component-design.md` の `AppScreen`・`ScreenSwitcher`・名前の一覧、`repository-structure.md` の構造と確認の手順）

## セキュリティ考慮事項

- 外部通信・保存・秘匿値は扱わない。デバッグのログには画面 ID と真偽値だけを出す。

## パフォーマンス考慮事項

- 画面のシーンは開くたびに読み込む（`load()`）。画面の数は12で、切り替えは操作のたびに1回なので問題にならない。

## 将来の拡張性

- 画面の追加は、シーンを作り、`MainShell.SCREEN_SCENES` に1行足すだけでよい。タイトルのカードも自動で押せるようになる。
- サービスを作る作業で、`App` にサービスの変数、`MainShell._ready()` に起動時の確認、`TitleScreen.enter()` に再開カードなどを足す。

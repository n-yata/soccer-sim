# 画面詳細設計書: S-12 設定

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-12」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-10」。設定の項目は
> [`data-definition.md`](../data/data-definition.md)。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-12 設定 |
| シーン | `game/ui/screens/s12_settings/settings_screen.tscn` |
| ルートの `class_name` | `SettingsScreen`（`Control`） |
| 使うアプリケーション層 | `App.user_data`（`settings()`・`save_settings()`）、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-15 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s12-settings`） |

## ノード構成

```
SettingsScreen (Control)
├── Header                                  # ScreenHeader（「← 戻る」と「設定」）
└── SettingsPanel                           # common/settings_panel.tscn（試合中のメニューから重ねて開く設定と共用）。画面の中央、幅 720px
    ├── BgmRow (VBoxContainer)              # 「BGM 音量」＋ HSlider（0〜100、刻み 5）＋数値
    ├── SeRow (VBoxContainer)               # 「効果音音量」＋ HSlider ＋数値
    ├── HintRow (HBoxContainer)             # 「ヒント表示」＋ CheckButton ＋説明「手を選ぶときに、各エリアの人数差とカバーの有無を表示します」
    └── LicenseButton (Button)              # 「ライセンス」（フォントなどのライセンス本文。architecture-overview.md のフォントの注記）
```

- スライダーのつまみと押せる範囲は高さ 96px 以上（NFR-19）
- 「ライセンス」はアプリ内のライセンス表示（OFL 1.1 の本文と著作権表示）を開く。表示はスクロールできる全画面のパネルで、
  閉じると設定に戻る

## 音量の反映

- 保存する値は 0.0〜1.0（スライダーの 0〜100 を 100 で割る）
- オーディオバス（`BGM`・`SE`）の音量は `linear_to_db(値)` で設定する。値が 0 のときはバスをミュートにする
  （`linear_to_db(0)` は負の無限大になるため）
- 起動時は `MainShell` が `settings()` を読んでバスに反映する

## 画面の状態

状態を持たない。スライダー・トグルの値が、そのまま保存する値になる。

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `SettingsPanel.show_settings(user_data.settings())`

### スライダー・トグルを変える（`SettingsPanel.changed`・`committed`）

1. 音量は `SettingsPanel` が `changed` のたびにオーディオバスに反映する（試合中に重ねて開いた設定でも同じ）
2. 保存は、`committed`（`SettingsPanel` がスライダーの `drag_ended` とトグルの切り替えで出す）を受けたときに `user_data.save_settings()` を呼ぶ
   （スライダーを動かしている間は保存しない。書き込みを減らすため）
3. 保存に失敗しても画面上の値は保持する（通知は `MainShell`）

### 戻る・Android の戻る操作

- ライセンスの表示が開いていれば閉じる
- それ以外は `App.request_screen(S01_TITLE)`。`true` を返す
- 試合中のメニューから開いた設定（`SettingsOverlay`）では、戻る操作で重ねた表示を閉じて試合画面に戻る（遷移しない）

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 戻る | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 設定の読み込みに失敗した | 初期値（BGM 70・効果音 70・ヒント ON）で表示する。通知は `MainShell` |
| 設定が新しい版のアプリで保存されている | 初期値で表示し、保存しない（`save_settings` が `false`）。通知は `MainShell` |

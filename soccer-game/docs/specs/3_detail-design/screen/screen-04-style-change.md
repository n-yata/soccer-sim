# 画面詳細設計書: S-04 方式の選び直し

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-04」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-02」。画面共通の決めごとは
> [`screen-common.md`](./screen-common.md)。本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-04 方式の選び直し |
| シーン | `game/ui/screens/s04_style_change/style_change_screen.tscn` |
| ルートの `class_name` | `StyleChangeScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`、`App.library`、`App.user_data`（メニューの設定） |
| `enter` の `params` | なし |
| 関連機能 | FR-17, FR-21 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s04-style-change`） |

## ノード構成

```
StyleChangeScreen (Control)
├── TopBar (HBoxContainer)                  # S-03 と同じ（MenuButton・ScoreBug）
├── Columns (HBoxContainer)                 # screen-common.md §1.1 の本体と操作の列
│   ├── InfoPane (ScrollContainer)          # 本体。縦にスクロール
│   │   └── Body (VBoxContainer)            # 間隔 24px
│   │       ├── GoalBanner (Label)          # 「GOAL」タグ＋「CPU が得点しました」。地 accent のタグ
│   │       ├── OpponentSetupLabel (Label)  # 「◆ CPU 4-4-2／マンツーマン／カウンター型」
│   │       ├── MatchupTitle (Label)        # 「直前の噛み合わせ」
│   │       ├── MatchupNotes                # NotesView（直前の方式区間の両者の方式の解説）
│   │       └── PickedNotes                 # NotesView（選んだ方式の単独の解説。変えたときだけ）
│   └── SideColumn (VBoxContainer)          # 操作の列
│       ├── DefenseTitle (Label) / DefenseToggle (HBoxContainer)
│       ├── AttackTitle (Label) / AttackToggle (HBoxContainer)
│       ├── Spacer (Control)
│       └── KickOffButton (Button)          # 「KICK OFF キックオフ」。列の下端、高さ 112px
├── MatchMenu
├── SettingsOverlay (PanelContainer) └── SettingsPanel
└── ConfirmDialog
```

## 画面の状態

| 状態 | 押せるもの |
|---|---|
| `EDITING` | 方式の2択・キックオフ・メニュー（方式は初期値で選ばれているので、いつでも確定できる） |
| `SUBMITTING` | なし |

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_current` | `TeamStyles` | 直前の方式区間の自分の方式（初期値） |
| `_picked` | `TeamStyles` | 選んでいる方式 |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `snapshot()` でスコアと、どちらが得点したかを出す（直前のターン記録の結果が `GOAL` の側。`snapshot()` の
   `last_goal_by`）
2. `opponent_setup()` で相手の陣形・方式を出す
3. `library.style_notes(自分の現在の方式, 相手の現在の方式)` で「直前の噛み合わせ」を出す
4. `_current`・`_picked` を自分の現在の方式にし、2択のボタンに反映する。`PickedNotes` は隠す

### 方式を選ぶ

1. `_picked` を更新する
2. `_picked` が `_current` と違う項目があれば、その項目の単独の解説（`library.defense_style_notes()`／
   `attack_style_notes()`）を `PickedNotes` に出す。同じに戻したら隠す

### 「キックオフ」を押す

1. `_state = SUBMITTING`
2. `match_controller.submit_style_change(_picked)`。S-03 への切り替えは `MatchController` が要求する（キックオフ時に
   両者の方式を開示する。FR-21）

### メニュー・Android の戻る操作

- メニューの動き（設定・中断してタイトルへ）は S-03 と同じ（[`screen-03-match.md`](./screen-03-match.md)「メニュー」）
- Android の戻る操作: メニュー・設定・確認ダイアログが開いていればいちばん上を閉じる。`EDITING` ならメニューを開く。
  `SUBMITTING` なら何もしない。いずれも `true` を返す

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| キックオフ | S-03 試合 |
| メニュー →「中断してタイトルへ」 | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 保存に失敗した（`submit_style_change` の中） | 本画面では出さない。通知は `MainShell`。試合は続ける |

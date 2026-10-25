# 画面詳細設計書: S-05 ハーフタイム

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-05」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-03」。画面共通の決めごとは
> [`screen-common.md`](./screen-common.md)。本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-05 ハーフタイム |
| シーン | `game/ui/screens/s05_halftime/halftime_screen.tscn` |
| ルートの `class_name` | `HalftimeScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`、`App.library`、`App.user_data`（メニューの設定） |
| `enter` の `params` | なし |
| 関連機能 | FR-08, FR-16, FR-17 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s05-halftime`） |

## ノード構成

```
HalftimeScreen (Control)
├── TopBar (HBoxContainer)                  # S-03 と同じ（MenuButton・ScoreBug。時計は「HT」）
├── Columns (HBoxContainer)                 # screen-common.md §1.1 の本体と操作の列
│   ├── InfoPane (ScrollContainer)          # 本体。縦にスクロール
│   │   └── Body (VBoxContainer)            # 間隔 24px
│   │       ├── HalftimeBanner (Label)      # 「HALF TIME」タグ＋「前半終了」
│   │       ├── OpponentSetupLabel (Label)  # 「◆ CPU 4-4-2／マンツーマン／カウンター型」（前半）
│   │       ├── MatchupTitle (Label)        # 「前半の噛み合わせ（基本配置）」／選び直し中は「後半の噛み合わせ（予測）」
│   │       └── MatchupRow (HBoxContainer)
│   │           ├── MatchupPitch            # MiniPitch（両チームの人数 `自分−相手` と優劣記号。横5レーン×縦6列、上が敵陣）
│   │           └── MatchupNotes            # NotesView（陣形と方式の噛み合わせの解説）
│   └── SideColumn (VBoxContainer)          # 操作の列（screen-common.md §1.1 の3段）
│       ├── SideScroll (ScrollContainer)    # 入りきらないときだけ縦にスクロール
│       │   └── SideBody (VBoxContainer)    # 間隔 12px。見出しは 24px の小さい文字
│       │       ├── FormationTitle (Label)
│       │       ├── FormationGrid (GridContainer) # FormationCard × 4（小さい版。陣形名と ✓。4列、各 約 108×96px）
│       │       ├── DefenseTitle (Label) / DefenseToggle (HBoxContainer)
│       │       └── AttackTitle (Label) / AttackToggle (HBoxContainer)
│       └── SecondHalfButton (Button)       # 「SECOND HALF 後半開始」。列の下端に固定、高さ 112px
├── MatchMenu
├── SettingsOverlay (PanelContainer) └── SettingsPanel
└── ConfirmDialog
```

## 画面の状態

| 状態 | 押せるもの |
|---|---|
| `EDITING` | 陣形・方式・後半開始・メニュー（初期値が選ばれているので、いつでも確定できる） |
| `SUBMITTING` | なし |

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_first_half` | `TeamSetup` | 前半の自分の陣形・方式（初期値） |
| `_picked` | `TeamSetup` | 選んでいる陣形・方式 |
| `_opponent` | `TeamSetup` | 相手の前半の陣形・方式 |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `snapshot()` で前半のスコア、`opponent_setup()` で相手の前半の陣形・方式を取る
2. `_first_half`・`_picked` を自分の前半の陣形・方式にする
3. 噛み合わせを描く（次節）

### 噛み合わせを描く

1. `library.matchup_counts(_picked.formation_id, _opponent.formation_id)` を `MatchupPitch` に渡す（利用者の視点に
   揃えた両チームの基本配置の人数。方式による動きは含めない）
2. `library.formation_notes(_picked.formation_id, _opponent.formation_id)` と
   `library.style_notes(_picked.styles, _opponent.styles)` を `MatchupNotes` に出す
3. `_picked` が `_first_half` と同じなら見出しを「前半の噛み合わせ（基本配置）」、違えば「後半の噛み合わせ（予測）」にする

### 陣形・方式を選ぶ

1. `_picked` を更新し、カードの ✓ と2択のボタンを更新する
2. 「噛み合わせを描く」をやり直す

### 「後半開始」を押す

1. `_state = SUBMITTING`
2. `match_controller.submit_halftime(_picked)`。S-03 への切り替えは `MatchController` が要求する（後半開始時に両者の
   陣形・方式を開示する。FR-08）

### メニュー・Android の戻る操作

S-04 と同じ（[`screen-04-style-change.md`](./screen-04-style-change.md)「メニュー・Android の戻る操作」）。

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 後半開始 | S-03 試合 |
| メニュー →「中断してタイトルへ」 | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 保存に失敗した（`submit_halftime` の中） | 本画面では出さない。通知は `MainShell`。試合は続ける |

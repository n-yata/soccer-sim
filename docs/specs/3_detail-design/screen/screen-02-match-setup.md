# 画面詳細設計書: S-02 試合準備

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-02」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-01 ①」。画面共通の決めごとは
> [`screen-common.md`](./screen-common.md)。本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-02 試合準備 |
| シーン | `game/ui/screens/s02_match_setup/match_setup_screen.tscn` |
| ルートの `class_name` | `MatchSetupScreen`（`Control`） |
| 使うアプリケーション層 | `App.library`（`LibraryService`）、`App.match_controller`、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-01, FR-02, FR-17, FR-20 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s02-match-setup`） |

## ノード構成

```
MatchSetupScreen (Control)
├── Header                                  # common/screen_header.tscn。「← 戻る」と画面名「試合準備」
└── Columns (HBoxContainer)                 # screen-common.md §1.1 の本体と操作の列
    ├── FormationPane (VBoxContainer)       # 本体
    │   ├── FormationTitle (Label)          # 「① 陣形」
    │   └── FormationGrid (GridContainer)   # 2列。カード 4枚
    │       └── FormationCard × 4           # common/formation_card.tscn（陣形名・MiniPitch・選択中の印）。約 352×244px
    └── SideColumn (VBoxContainer)          # 操作の列。間隔 16px
        ├── DefenseTitle (Label)            # 「② 守備方式」
        ├── DefenseToggle (HBoxContainer)   # 2択のボタン（ゾーン／マンツーマン）。高さ 96px
        ├── AttackTitle (Label)             # 「③ 攻撃方式」
        ├── AttackToggle (HBoxContainer)    # 2択のボタン（保持型／カウンター型）
        ├── NotesScroll (ScrollContainer)   # 残りの高さいっぱい。長い解説は中でスクロール
        │   └── NotesView                   # common/notes_view.tscn（見出し「④ 解説」）
        └── StartButton (Button)            # 「この布陣で試合開始」。列の下端、高さ 112px
```

- `FormationCard` は S-05 でも使う（陣形名・`MiniPitch`・選択中の枠と ✓）。押せる範囲はカード全体

## 画面の状態

| 状態 | 意味 | 押せるもの |
|---|---|---|
| `EDITING` | 選んでいる途中（3項目のどれかが未選択） | 陣形カード・方式・戻る。開始ボタンは押せない |
| `READY` | 3項目すべてを選んだ | 上に加えて開始ボタン |
| `STARTING` | 開始ボタンを押し、画面の切り替えを待つ | なし（二重に試合を作るのを防ぐ） |

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_formation_id` | `String` | 選んだ陣形。未選択は空文字 |
| `_defense` | `int` | 選んだ守備方式（`GameEnums.DefenseStyle`）。未選択は -1 |
| `_attack` | `int` | 選んだ攻撃方式（`GameEnums.AttackStyle`）。未選択は -1 |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `library.formations()` で4枚の陣形カードを作る。各カードのミニピッチは `library.base_counts(id)`
2. 3項目を未選択にし、解説欄は「陣形と方式を選ぶと、ここに解説が出ます」とする（未選択から始める理由は
   `screen-design.md` S-02）
3. `_state = EDITING`

### 陣形・方式を選ぶ

1. 選んだ項目を記録し、カードの枠・✓、2択のボタンの選択中の表示を更新する
2. 解説欄を作り直す。選んだ項目の解説だけを、次の順に並べる
   - 陣形: `library.formation_notes(_formation_id, "")`
   - 守備方式: `library.defense_style_notes(_defense)`
   - 攻撃方式: `library.attack_style_notes(_attack)`
3. 3項目すべてが選ばれていれば `_state = READY`（開始ボタンを押せるようにする）

### 「この布陣で試合開始」を押す

1. `_state = STARTING`
2. `TeamSetup` を作り、`match_controller.start_match(setup)`。画面の切り替え（S-03）は `MatchController` が要求する
3. 既存の中断データは、この試合の保存で上書きされる（削除の時点①。確認はタイトルで済んでいる）

### 戻る・Android の戻る操作（`handle_back`）

- `STARTING` 以外なら `App.request_screen(S01_TITLE)`。何も保存しない（中断中の試合はそのまま残る）
- `STARTING` なら何もしない。どちらも `true` を返す

### 画面遷移

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「この布陣で試合開始」 | S-03 試合 | `start_match` の後に `MatchController` が要求する |
| 戻る | S-01 タイトル | — |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 試合の保存に失敗した（`start_match` の中） | 本画面では何も出さず、S-03 へ進む。通知は `MainShell` |
| 解説が0件（静的データに該当の解説が無い） | その項目の見出しだけを出し、本文は出さない（静的データの誤りは開発時の検証で見つける。NFR-17） |

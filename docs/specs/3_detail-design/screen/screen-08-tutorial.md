# 画面詳細設計書: S-08 チュートリアル

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-08」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-06」。段階の定義（`tutorial.json`）の項目は
> [`data-definition.md`](../data/data-definition.md)。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-08 チュートリアル |
| シーン | `game/ui/screens/s08_tutorial/tutorial_screen.tscn` |
| ルートの `class_name` | `TutorialScreen`（`Control`） |
| 使うアプリケーション層 | `App.new_tutorial_controller()`（チュートリアル用の `MatchController`）、`App.library`、`App.user_data`、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-12, FR-23 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s08-tutorial`） |

## ノード構成

```
TutorialScreen (Control)
├── Layout (VBoxContainer)                  # 外周の余白 24px（screen-common.md §1.1）
│   ├── Header                              # ScreenHeader（左は「やめる」、その右に「チュートリアル 3／10」）
│   │   ├── StepProgress (ProgressBar)      # 段階の進み具合。ヘッダーの右側
│   │   ├── PhaseTag (Label)                # 局面のタグ（S-03 と同じ表示）。盤面を出す段階だけ。陣形・方式はパネルの SetupCard に出る
│   │   └── RevealBanner (VBoxContainer)    # 両者の選択の帯（S-03 と同じ2段。FR-09）。開示から次の段階まで PhaseTag の代わりに出す
│   └── Stage (Control)                     # 高さ 576px。段階の種類で中身を切り替える
│       ├── MatchView                       # 盤面を出す段階: MatchBoardPanel（S-03 の BoardPanel と同じ部品）
│       │   ├── （SideTopSlot に）Coach (PanelContainer)    # 説明文の吹き出し。地 surface、左に accent の縦線
│       │   │   └── CoachText (RichTextLabel)              # 段階の説明文。強調は accent。長いときは吹き出しの中でスクロール
│       │   └── （SideBottomSlot に）NextButton (Button)    # 「次へ」。高さ 112px、列の幅いっぱい
│       └── ScopeView (HBoxContainer)       # 最後の段階
│           ├── ScopeList (ScrollContainer) # 本体: 単純化の一覧（SimplificationList。S-10 と同じカード、2列）
│           └── ScopeSide (VBoxContainer)   # 操作の列: 説明文と、下端の「完了」（高さ 112px）
```

- `MatchView` は S-03 の `BoardPanel` と同じ `MatchBoardPanel` を使い、S-03 と同じ状態（`SELECT_ACTION` 〜 `SHOW_RESULT`）で動かす
  （[`screen-03-match.md`](./screen-03-match.md)「画面の状態」）。違いは、`MatchController` がチュートリアル用であることと、
  `LEAVING` の代わりに次の段階へ進むことだけ
- 説明文の吹き出し（`Coach`）と「次へ」は、`MatchBoardPanel` の操作の列の `SideTopSlot`・`SideBottomSlot` に置く
  （試合画面と同じ配置のまま、説明を読みながら盤面を操作できる）。`EXPLAIN` の段階では `ChoicePanel` と「決定」を隠す
- パネルは `enter` で1回だけ `bind(_controller, show_next = false)` でつなぐ（段階ごとにつなぎ直さない）。判定理由を出すとパネルの主ボタンは隠れ、`turn_ready_to_leave` が届く。画面の「次へ」はこの1つだけになる

## 段階の種類と画面

段階の定義の正本は `tutorial.json`（項目は `data-definition.md`）。種類ごとの画面の動きは次のとおり。

| 種類（`kind`） | 画面 | 「次へ」を押せる条件 |
|---|---|---|
| `EXPLAIN` | 説明文と、段階の盤面（操作できない） | すぐ |
| `OPERATE` | 説明文と、操作できる盤面。選べる手は段階の定義で絞る | 手を決定し、判定理由が出た後 |
| `SCOPE` | 単純化の一覧（最後の段階） | すぐ（ボタンは「完了」） |

## 画面の状態と値

| 変数 | 型 | 内容 |
|---|---|---|
| `_controller` | `MatchController` | `App.new_tutorial_controller()` で受け取ったもの。画面を閉じたら捨てる |
| `_steps` | `Array[TutorialStepDef]` | `library.tutorial_steps()` |
| `_index` | `int` | 今の段階（0 始まり） |
| `_can_next` | `bool` | 「次へ」を押せるか |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `_controller = App.new_tutorial_controller()`、`_steps = library.tutorial_steps()`、`_index = 0`。`MatchView.bind(_controller, false)`。パネルの `turn_started`・`reveal_started` を受けて `PhaseTag`・`RevealBanner` を描き直し、`turn_ready_to_leave` を受けて `_can_next = true` にする
2. 段階を始める（次節）

### 段階を始める

1. 見出しの「N／M」と進み具合を更新する
2. `EXPLAIN`・`OPERATE` なら、次の順で段階の盤面を出す。`Coach` に説明文を出す
   1. `_controller.start_tutorial_step(step)` で段階の盤面を作る
   2. `MatchView.set_options_filter(step.allowed_actions)`（試合と同じ規則の範囲内で絞るだけ。手を足すことはない）
   3. `MatchView.set_interactive(step.kind == OPERATE)`（`EXPLAIN` では手のボタンと「決定」を隠す）
   4. `MatchView.start_turn()`
3. `SCOPE` なら `ScopeView` に `library.simplifications()` を出し、「次へ」の代わりに `ScopeSide` の「完了」を使う
4. `_can_next` を「段階の種類と画面」の表のとおりにする。`_can_next` が偽の間は「次へ」を隠す（説明文と手のボタンを一度に見せるため）

### 手を決定する（`OPERATE`）

S-03 の「決定」〜「演出の終了」と同じ（`MatchBoardPanel` が `_controller.submit_turn()`、演出、判定理由を受け持つ）。パネルから `turn_ready_to_leave` が届いたら `_can_next = true`。チュートリアルでは `continue_after_reveal()` を呼ばない（次の段階は `start_tutorial_step()` で作り直す）。

### 「次へ」・「完了」を押す

1. 最後の段階でなければ `_index += 1` して「段階を始める」
2. 最後の段階（「完了」）なら `App.user_data.mark_tutorial_completed()` を呼び、`_controller` を捨てて
   `App.request_screen(S01_TITLE)`。保存に失敗しても完了の表示は行う（通知は `MainShell`）

### 「やめる」・Android の戻る操作

1. `ConfirmDialog.ask("チュートリアルをやめますか？（最初からやり直せます）", "やめる", "続ける")`
2. 了承なら `_controller` を捨てて `App.request_screen(S01_TITLE)`。完了フラグは変えない
3. 演出中の Android の戻る操作は「スキップ」と同じ。確認ダイアログが開いていれば閉じる。いずれも `true` を返す

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 完了・やめる | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 段階の定義の誤り（存在しない手・盤面の人数の誤り） | 起きない（静的データの検証で見つける。`data-definition.md`） |
| 完了フラグの保存に失敗した | 通知は `MainShell`。次回もチュートリアルが「はじめての方へ」として出るだけ |

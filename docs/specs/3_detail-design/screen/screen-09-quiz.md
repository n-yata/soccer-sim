# 画面詳細設計書: S-09 理解度チェック

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-09」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-07」。場面問題（`quiz.json`）と回答結果の項目は
> [`data-definition.md`](../data/data-definition.md)。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-09 理解度チェック |
| シーン | `game/ui/screens/s09_quiz/quiz_screen.tscn` |
| ルートの `class_name` | `QuizScreen`（`Control`） |
| 使うアプリケーション層 | `App.library`（`quiz_questions()`・`principle()`）、`App.user_data`（`quiz_progress()`・`save_quiz_answer()`）、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-22 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s09-quiz`） |

## ノード構成

```
QuizScreen (Control)
├── Header                                  # ScreenHeader（「← 戻る」と、一覧では「理解度チェック」、問題では「LG-2　1／2」）
├── ListView (GridContainer)                # 学習目標の一覧。2列×2行で画面の幅いっぱい
│   └── GoalCard × 4                        # Button。「LG-1 位置的・数的優位を見つける」＋「2問中 2問正解」／「未回答」
└── QuestionView (HBoxContainer)            # 問題の表示（screen-common.md §1.1 の本体と操作の列）
    ├── ScenePane (VBoxContainer)           # 本体
    │   ├── ScenePitch                      # MiniPitch（両チームの人数・ボール。3列×5行、1マス 横 144px・縦 88px）
    │   └── SceneInfo (Label)               # 「自分: ゾーン　相手: 保持型　ボール: 中盤・左HS」
    └── SideColumn (VBoxContainer)          # 操作の列。入りきらないときは ActionButton を下端に固定したまま、その上を縦にスクロール
        ├── QuestionText (Label)            # 問題文。32px Bold
        ├── Choices (VBoxContainer)
        │   └── ChoiceButton × 選択肢の数    # Button。高さ 96px 以上。選んだものに accent の枠
        ├── Feedback (PanelContainer)       # 回答後だけ。正誤（「正解」「不正解」の文字＋記号 ○／×）・解説・根拠の原則
        └── ActionButton (Button)           # 「回答する」→ 回答後は「次の問題」／最後は「一覧へ」。列の下端
```

## 画面の状態

| 状態 | 見えるもの | 押せるもの |
|---|---|---|
| `LIST` | 学習目標の一覧 | 学習目標のカード・戻る |
| `ASKING` | 問題・選択肢 | 選択肢・回答する（選択肢を選ぶまで押せない）・戻る |
| `ANSWERED` | ＋正誤・解説 | 次の問題・戻る（選択肢は押せない） |

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_questions` | `Array[QuizQuestionDef]` | 選んだ学習目標の問題（`quiz.json` の並び順） |
| `_index` | `int` | 今の問題 |
| `_picked` | `String` | 選んだ選択肢の `id`（未選択は空文字） |

## 正答状況の数え方

`UserDataService.quiz_progress()` は、学習目標ごとに次を返す（回答結果の正本は `data-definition.md`）。

- `answered`: 1回以上回答した問題の数
- `correct`: **最新の回答**が正解だった問題の数（同じ問題に何度も答えた場合は、最後の回答だけで数える。直近の理解を
  表すため）
- `total`: その学習目標の問題の数

一覧のカードは「`total` 問中 `correct` 問正解」、`answered` が0なら「未回答」と出す。

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `quiz_progress()` で一覧を描く。`_state = LIST`

### 学習目標のカードを押す

1. `_questions = library.quiz_questions()` のうち、その学習目標の問題。`_index = 0`
2. 問題を出す（`ScenePitch` に場面の人数とボール、`SceneInfo`・問題文・選択肢）。`_picked = ""`、`_state = ASKING`

### 選択肢を選ぶ・「回答する」を押す

1. 選択肢を押すと `_picked` を記録し、枠を付ける（選び直せる）。「回答する」を押せるようにする
2. 「回答する」を押すと、正誤を判定する（選択肢の ID が問題の正解と一致するか。ルールの計算は伴わない）
3. `save_quiz_answer(QuizAnswer(問題 ID, 正誤, 今の日時))`。保存に失敗しても次へ進む（通知は `MainShell`）
4. `Feedback` に正誤（○ 正解／× 不正解）、解説、根拠の原則（`library.principle(id)` の名前）を出す。正解の選択肢に印を付ける
5. `_state = ANSWERED`

### 「次の問題」・「一覧へ」を押す

- 次の問題があれば `_index += 1` して問題を出す
- 最後の問題なら一覧へ戻り、`quiz_progress()` で描き直す

### 戻る・Android の戻る操作

- `ASKING`・`ANSWERED` なら一覧へ戻る（回答前の問題は記録しない）
- `LIST` なら `App.request_screen(S01_TITLE)`。いずれも `true` を返す

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 一覧で戻る | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 回答結果の読み込みに失敗した | 一覧はすべて「未回答」として出す。通知は `MainShell`（1回だけ） |
| 回答結果が新しい版のアプリで保存されている | 一覧は「未回答」として出し、回答は保存しない（`save_quiz_answer` が `false`）。通知は `MainShell` |

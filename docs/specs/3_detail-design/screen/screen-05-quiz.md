# 画面詳細設計書: クイズ画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | クイズ画面 |
| ルート(FE) | `/quiz` |
| 対応コンポーネント | `QuizPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-12 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面5: クイズ画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
QuizPage
└── QuizQuestionCard（1問ずつ表示）
    ├── FormationMiniPitch（kind === "formation" のときのみ、labelを付けて描画）
    └── TermAnnotatedText（設問文・解説文の用語をインライン表示）
```

### props / state 設計

| コンポーネント | props | 内部 state / emits |
|---|---|---|
| `QuizPage` | — | `questions: QuizQuestion[]`（マウント時とrestart時に`buildQuiz`で生成）、`currentIndex: number`、`answers: Record<設問id, 選んだ選択肢id>` |
| `QuizQuestionCard` | `question: QuizQuestion`, `answeredChoiceId: string \| null` | emits: `answer: [choiceId: string]` |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、`data/quiz.ts`の`buildQuiz`が
`data/formations.ts`/`data/matchups.ts`から画面表示のたびに設問を動的に生成する。
生成結果は永続化しない。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時）

1. `restart()` を呼ぶ。`buildQuiz(formations, matchups)`（既定の並べ替え・既定の出題数
   `DEFAULT_QUIZ_LENGTH`）で設問一覧を生成し、`questions`/`currentIndex`（0）/`answers`
   （空オブジェクト）を初期化する。
2. `questions` が空配列の場合（出題できる設問が無い）、設問カードの代わりに固定文言の
   メッセージを表示する。
3. `questions[currentIndex]` を `currentQuestion` として算出し、`QuizQuestionCard` へ渡す。

### 回答

1. ユーザーが選択肢をクリックする。`QuizQuestionCard` が `answer` イベントで
   選択した `choiceId` をemitする。
2. `QuizPage` の `onAnswer(choiceId)` が呼ばれる。**現在の設問idに対して既に回答が
   記録されている場合は何もしない**（1問につき最初の回答のみ確定する。`disabled`属性だけに
   頼らず、ロジック側でも二重回答を防ぐ）。
3. `answers` に `{ [question.id]: choiceId }` を追加した新しいオブジェクトで置き換える
   （直接のプロパティ代入ではなくオブジェクトごと作り直すことで、Vueのリアクティビティ更新を
   確実にする）。
4. `QuizQuestionCard` は `answeredChoiceId` が非nullになったことを検知し、全選択肢を
   `disabled` にしたうえで正誤・正解の選択肢・解説を表示する。

### 次の設問へ

1. ユーザーが「次の問題へ」（最終問題では「結果を見る」）をクリックする。
2. `goNext()` が `currentIndex` をインクリメントする。
3. `currentIndex` が `questions.length` に達すると `currentQuestion` が `undefined` になり、
   テンプレートが結果表示に切り替わる。

### 再挑戦

1. ユーザーが結果画面で「もう一度挑戦する」をクリックする。
2. `restart()` を再度呼び、`questions`/`currentIndex`/`answers` の**すべて**を作り直す
   （個別フィールドをクリアするのではなく、状態オブジェクトごと再生成する。消し忘れによる
   前回状態の持ち越しを防ぐための実装方針）。
3. `buildQuiz` の既定実装は乱数（`Math.random`）ベースの並べ替えのため、再挑戦のたびに
   出題順・選択肢順が変わりうる。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 用語集ボタンをクリック | `/glossary`（`GlossaryPage`） | `router-link` による静的遷移 |
| 「戻る」（アイコン: ArrowLeft）をクリック | 履歴があれば遷移元、無ければ `/`（`FormationListPage`） | `window.history.state.back` の有無で分岐 |
| 結果画面の「一覧画面へ戻る」をクリック | `/`（`FormationListPage`） | `router-link` による静的遷移 |

## 例外・エラー表示

- **出題できる設問が1件も無い場合**: `buildQuiz` が空配列を返す（例: フォーメーションが
  1件しかなく、陣形識別の誤答を作れない）。この場合、設問カード・進捗表示のいずれも表示せず、
  固定文言のメッセージのみを表示する。**例外を投げてクラッシュさせない**（`data/quiz.ts`の
  責務として空配列を返す設計にしている）。
- **設問の参照先フォーメーション/マッチアップが存在しない場合**: `buildQuiz`が生成時点で
  除外するため（`data/quiz.ts`の責務）、`QuizPage`/`QuizQuestionCard`側で
  `undefined`チェックを重複させる必要はない。

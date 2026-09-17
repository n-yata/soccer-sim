# 実装アプローチ — 学習体験の強化（FR-11 / FR-12 / FR-13）

## 全体方針

- 既存の2層構成（UIレイヤー → 静的データ）を崩さない。
  **FR-13 だけが「永続化」という新しい関心事を持ち込む**ため、
  `localStorage` へのアクセスは専用モジュールに閉じ、画面から直接触らせない
- 新規の外部依存はゼロ。ポップオーバー・クイズとも Vue の標準機能で実装する
- **ロジックは `.vue` の外へ出す。** 用語の切り出し・出題生成・進捗の読み書きは
  純粋関数としてテスト可能にし、コンポーネントは描画に徹する

## 追加・変更するファイル

```
src/
  types/
    formation.ts              変更: QuizQuestion / LearningProgress 等の型を追加
  data/
    soccerTerms.ts            変更なし（収録語はそのまま使う）
    termAnnotation.ts         新規: 解説文を「平文」と「用語」のセグメントへ切り出す純粋関数
    quiz.ts                   新規: 静的データから設問を生成する純粋関数
    learningProgress.ts       新規: localStorage の読み書き（検証つき）
  components/
    TermAnnotatedText.vue     新規: 解説文を用語ポップオーバーつきで描画する
    TermPopover.vue           新規: 用語1件の説明を表示する吹き出し
    QuizQuestionCard.vue      新規: 設問1問の表示と回答受付
  pages/
    QuizPage.vue              新規: クイズ画面（/quiz）
    ComparisonPage.vue        変更: 優位ポイント・総合判定理由を TermAnnotatedText へ置換、閲覧記録
    MatrixPage.vue            変更: 確認済み／未確認の可視化、進捗表示、消去ボタン
    FormationListPage.vue     変更: クイズ画面への導線を追加
  router/
    index.ts                  変更: /quiz を追加
```

---

## FR-11 解説文の用語インライン表示

### 用語の切り出し（`data/termAnnotation.ts`）

```typescript
export type TextSegment =
  | { kind: "plain"; text: string }
  | { kind: "term"; text: string; term: SoccerTerm };

export function annotateText(text: string, terms: SoccerTerm[]): TextSegment[];
```

**アルゴリズム**: 先頭から走査し、各位置で「その位置から始まる用語」のうち
**最長のもの**を採用する。一致しなければ1文字進める。

- **最長一致にする理由**: 「最終ライン」と「ライン間」、「中盤」と「守備的MF」のように
  用語同士が部分的に重なる。短い方を先に採ると「最終ラ|イン間|」のような
  誤った切り出しが起き、**本文が静かに別の意味の用語へ化ける**
- 用語リストは**呼び出しのたびに長さ降順へ並べ替えない**。
  モジュール読み込み時に一度だけ長さ降順のインデックスを作る
  （解説文の数 × 用語数の走査が毎描画で走るのを避ける）
- **`v-html` は使わない。** セグメント配列を返し、テンプレート側で `v-for` + `{{ }}` で
  描画する。これにより用語データに HTML が混入しても描画されない（XSS 経路を作らない）

### 描画（`components/TermAnnotatedText.vue`）

```
props: { text: string }
```

- `plain` セグメントは `<span>{{ segment.text }}</span>`
- `term` セグメントは `<button type="button">` として描画し、
  押下で `TermPopover` を開く

**アクセシビリティ**:
- `<button>` を使うことでキーボード操作（Tab / Enter / Space）が標準で効く
- `aria-expanded` で開閉状態を、`aria-describedby` で説明との関連を伝える
- `Escape` で閉じる。本文外のクリックで閉じる（`document` へのリスナは
  `onMounted` / `onUnmounted` で対に登録・解除する）
- 同時に開くポップオーバーは1つ。開いている用語の id を親が持つ

**適用箇所**: 比較画面の優位ポイント（`advantagesForA` / `advantagesForB`）と
総合判定理由（`overallReason`）。
一覧カードの説明文へは適用しない（要求書の「スコープ外」参照。
`role="button"` の内部に操作要素を入れ子にしないため）。

---

## FR-12 理解度チェック（クイズモード）

### 設問の生成（`data/quiz.ts`）

```typescript
export type QuizQuestion =
  | { kind: "edge";      id: string; prompt: string; choices: QuizChoice[]; explanation: string }
  | { kind: "formation"; id: string; prompt: string; choices: QuizChoice[]; explanation: string;
      formation: Formation }
  | { kind: "advantage"; id: string; prompt: string; choices: QuizChoice[]; explanation: string };

export interface QuizChoice { id: string; label: string; correct: boolean }

// shuffle を注入可能にする（テストでは恒等関数や決定的な並べ替えを渡す）
export type Shuffle = <T>(items: T[]) => T[];

export function buildQuiz(
  formations: Formation[],
  matchups: Matchup[],
  options?: { shuffle?: Shuffle; limit?: number },
): QuizQuestion[];
```

**乱数を注入する理由**: `Math.random` を生成ロジックへ直接書くと、
テストがランダムな結果に依存して**フレーキーになるか、意味のないアサーションになる**。
既定は `Math.random` ベースのシャッフル、テストでは決定的な関数を渡す。
**本番コードに `if (testMode)` の類は入れない。**

**設問ごとの生成元と正解**:

| 種別 | 生成元 | 正解 | 解説文 |
|---|---|---|---|
| `edge` | `matchups` の各レコード | `overallEdge`（`A` / `B` / `even`） | `overallReason` |
| `formation` | `formations` の各レコード | その `id` | `description` |
| `advantage` | `matchups` の `advantagesForA` / `advantagesForB` の各要素 | 由来した側のフォーメーション | `overallReason` |

**データ不足時の扱い**:
- `formation` 設問は**誤答の選択肢を3件用意できる（＝フォーメーションが4件以上ある）ときだけ**生成する。
  4件未満なら選べる分だけで作り、それも不可能なら当該種別を生成しない
- `matchups` が空なら `edge` / `advantage` は生成されない
- `buildQuiz` が空配列を返した場合、画面は「出題できる問題がありません」と表示する
  （クラッシュさせない）

**NFR-03 との整合**: 設問は `formations` / `matchups` を走査して生成するため、
データを追加すれば設問も自動的に増える。**問題数をコードに書かない。**

### 画面（`pages/QuizPage.vue`）

状態は「出題中（未回答）」→「回答済み（正誤と解説を表示）」→「次へ」→…→「結果」。
- 回答は1問につき1回だけ確定できる（確定後は選択肢を `disabled` にする）
- 結果画面で正答数 / 全問数と「もう一度挑戦する」を表示
- 「もう一度挑戦する」は `buildQuiz` を再実行し、**前回の回答状態を完全に破棄する**
  （状態のリセット漏れは静かに誤る欠陥になりやすいので、
  個別フィールドを消すのではなく状態オブジェクトごと作り直す）

---

## FR-13 学習進捗トラッキング

### 永続化層（`data/learningProgress.ts`）

```typescript
export interface LearningProgress { viewedPairs: string[] }

export function buildPairKey(idA: string, idB: string): string; // 順序非依存
export function loadProgress(): LearningProgress;
export function markPairViewed(idA: string, idB: string): LearningProgress;
export function clearProgress(): LearningProgress;
export function countAllPairs(formations: Formation[]): number;
```

**順序非依存キー**: `[idA, idB].sort().join("__")`。
`A vs B` と `B vs A` が別レコードになると進捗が二重計上され、
**分母と分子がずれて「1周した」の判定が静かに誤る**。

**localStorage を信用しない**:
- 読み込みは必ず `try/catch` で囲む（プライベートモード等で `localStorage` へのアクセス
  自体が例外を投げる環境がある）
- `JSON.parse` の結果を**形式検証する**。`viewedPairs` が配列であること、
  要素がすべて文字列であることを確認し、1つでも満たさなければ空の進捗として扱う
- 書き込みも `try/catch` で囲む（容量超過で例外になる）。
  **失敗しても呼び出し側の処理は続行する**（記録できないだけで画面は壊さない）
- 保存するのはフォーメーション ID の組み合わせのみ。個人情報・秘匿値は保存しない

> localStorage の内容は利用者が自由に書き換えられる。信用せずに検証するのは
> セキュリティというより**「壊れたデータで静かに誤らない」**ための措置である。

### 可視化（`pages/MatrixPage.vue`）

- 確認済みセルに視覚的な印を付ける。**色だけで区別しない**
  （既に「行有利 / 列有利 / 互角」を色で表現しており、
  そこへ色を重ねると判別できなくなる。チェック印などの記号を重ねる）
- `aria-label` に確認済みか否かを含め、支援技術でも区別できるようにする
- 進捗は「確認済み N / 全 M 組み合わせ」の形で表示。M は `countAllPairs` で算出する
- 「進捗を消去」ボタンを置く。**確認ダイアログは `window.confirm` を使わない**
  （ブラウザモーダルは自動テストとブラウザ自動操作を止める）。
  ボタン押下で「本当に消去しますか」のインライン確認を出す2段階にする

### 記録のタイミング（`pages/ComparisonPage.vue`）

比較画面で `formationA` / `formationB` / `matchup` がすべて解決できたときにのみ記録する。
`watch` + `immediate: true` で、A/B 切替（`router.replace`）による
**同一コンポーネント内でのパラメータ変更も拾う**（`onMounted` だけでは初回しか記録されない）。

---

## テスト方針

`AGENTS.md` および kit のテスト戦略に従い、**実際の機能を検証する**テストを書く。

| 対象 | 検証内容 |
|---|---|
| `termAnnotation.ts` | 最長一致（「最終ライン」が「ライン間」に割られない）、用語なしの平文、用語のみ、連続する用語、空文字 |
| `quiz.ts` | 各種別が生成されること、正解が1つだけであること、`shuffle` を注入した決定的な出力、フォーメーション4件未満でのフォールバック、空データで空配列 |
| `learningProgress.ts` | 順序非依存キー、`localStorage` 例外時に空進捗を返す、壊れた JSON・型不一致の拒否、消去、全組み合わせ件数 |
| `TermAnnotatedText.vue` | 用語がボタンとして描画される、押下で説明が出る、`Escape` で閉じる、用語なしなら平文のみ |
| `QuizPage.vue` | 回答で正誤と解説が出る、確定後は再回答できない、結果の正答数、再挑戦で状態が完全に戻る |
| `MatrixPage.vue` | 確認済みセルに印が付く、進捗の分母分子、消去で0に戻る |
| `ComparisonPage.vue` | 表示で記録される、A/B切替でも記録される、順序違いで二重計上されない |

**`localStorage` のテスト**: jsdom の `localStorage` を直接使い、
例外パターンのみ `vi.spyOn` で `getItem` / `setItem` を throw させる。
本番コードにテスト用の分岐は入れない。

## 検討したが採らなかった案

- **用語のツールチップを `title` 属性で出す**: 実装は最小だが、
  キーボード操作で開けず、モバイルで表示されず、表示までの遅延も制御できない。
  NFR-01（初心者でも迷わず操作できる）を満たさないため採らない
- **クイズの成績を localStorage に保存する**: FR-12 のスコープ外とした。
  FR-13 の進捗と保存形式が絡むと、どちらの不具合か切り分けにくくなる。
  必要になった時点で `learningProgress.ts` を拡張する
- **進捗を URL に持たせる（共有可能にする）**: 学習記録は個人のものであり
  共有の需要が確認できていない。YAGNI

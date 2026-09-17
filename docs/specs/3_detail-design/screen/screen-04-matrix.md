# 画面詳細設計書: 相性マトリクス画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。レイアウト・画面項目・
> 画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 相性マトリクス画面 |
| ルート(FE) | `/matrix` |
| 対応コンポーネント | `MatrixPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-07, FR-13 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面3: 相性マトリクス画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
MatrixPage（単独。子コンポーネントは持たない）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `MatrixPage` | — | `progress: LearningProgress`（マウント時に`loadProgress()`で1回読む）、`isConfirmingClear: boolean`（進捗消去の2段階確認） |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばず、静的データモジュール（`data/formations.ts`,
`data/matchups.ts`）と`localStorage`（`data/learningProgress.ts`）を直接参照する。

## 画面遷移・イベント処理の詳細フロー

### 画面表示（マウント時）

1. `data/formations.ts` の `formations` を行・列に並べたN×N表を組み立てる。
2. 各セルについて `getMatchup(rowId, colId)` を呼び、`overallEdge` を取得する
   （行列とも同一IDの対角線は判定前にスキップし、装飾セルとして扱う）。
3. `overallEdge` が `undefined`（マッチアップ未定義）・`"A"`・`"B"`・`"even"` のいずれかに
   応じてセルの見た目を出し分ける。
4. `data/learningProgress.ts` の `loadProgress()` を1回呼び、`progress` state に保持する。
   以降の描画では `isPairViewed(progress, rowId, colId)` でセルごとの確認済み判定を行う
   （消去操作以外では再読み込みしない）。
5. `countAllPairs(formations)`（分母）と、`formations` の行を走査して数えた確認済み件数
   （分子）から進捗表示を組み立てる。

### セルクリック（マッチアップが存在する場合）

1. ユーザーが行有利/列有利/互角のいずれかのセルをクリックする。
2. `router-link` の静的遷移により `/compare/:rowId/:colId`（`ComparisonPage`）へ遷移する。
3. 遷移先の `ComparisonPage` が学習進捗の記録（FR-13）を行うため、本画面自身は記録処理を
   持たない（読み取り・消去のみを担当する）。

### 進捗の消去

1. ユーザーが「進捗を消去」をクリックする（確認済みが0件のときは`disabled`のため押せない）。
2. `isConfirmingClear` を `true` にし、インラインの確認UI（「消去しますか？」+「消去する」
   「やめる」）に切り替える。**この時点ではまだ何も消去しない**
   （`window.confirm`はブラウザのネイティブモーダルで自動テスト・ブラウザ自動操作を止めるため
   使わない）。
3. 「消去する」をクリックすると `clearProgress()` を呼び、戻り値（空の進捗）で `progress`
   state を更新し、`isConfirmingClear` を `false` に戻す。
4. 「やめる」をクリックすると `isConfirmingClear` を `false` に戻すのみで、`progress` は
   変更しない。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| マッチアップが存在するセルをクリック | `/compare/:rowId/:colId`（`ComparisonPage`） | `router-link` による静的遷移 |
| 「← 戻る」をクリック | 履歴があれば遷移元、無ければ `/`（`FormationListPage`） | `window.history.state.back` の有無で分岐 |

## 例外・エラー表示

- **マッチアップ未定義（データ追加漏れ）**: セルを「データ未定義」を示す独立した見た目
  （黄色の斜線模様、`role="img"` + `aria-label`）にする。互角（`overallEdge === "even"`）と
  混同しないよう、`resolveEdge` の戻り値が `undefined` であることを別状態として扱う
  （`functional-overview.md`「エラーハンドリング」参照。通常運用では発生しない前提だが、
  発生時に「互角の判定に見えるが遷移先が無い」という無言の不整合を防ぐ）。
- **`localStorage` が読めない環境**: `loadProgress()` 内部で例外を握り、空の進捗
  （`{ viewedPairs: [] }`）を返すため、本画面は分岐を持たない（`data/learningProgress.ts`の
  責務）。進捗は「確認済み0件」として表示され、消去ボタンは`disabled`になる。
- **`localStorage` に壊れた値が保存されている場合**: `loadProgress()` が形式検証済みの値
  （または空の進捗）を返すため、本画面は常に有効な `LearningProgress` を受け取る前提で
  実装してよい（バリデーションを画面側で重複させない）。

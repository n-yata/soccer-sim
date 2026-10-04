# 画面詳細設計書: 自由配置ボード画面

> 画面一覧・ルート・対応コンポーネント・画面遷移の正本は
> [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。保存・復元・リセットの
> 確定事項の正本は同書の「自由配置ボード（FR-21）の確定事項」。レイアウト・画面項目・画面イベントの
> 外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)。本書は本画面の
> コンポーネント構成（props/state）・状態管理・詳細な画面遷移/イベント処理フロー・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面名 | 自由配置ボード画面 |
| ルート(FE) | `/board` |
| 対応コンポーネント | `FreeLayoutBoardPage` |
| 関連API | 該当なし（本プロダクトはバックエンドAPIを持たない） |
| 関連機能 | FR-21 |

外部設計（レイアウト・画面項目定義・画面イベント一覧）は
[`screen-design.md`](../../2_basic-design/screen-design.md)「画面8: 自由配置ボード画面」を参照。
本書は以下の実装レベル詳細に限定する。

## コンポーネント構成

```
FreeLayoutBoardPage
├── PageHeader（タイトル・サブタイトル。戻るボタンなし）
├── チーム操作欄 × 2（青チーム・赤チーム。陣形セレクト＋リセットボタン）
├── 「ボールを中央に戻す」ボタン
├── 操作説明（ピッチの aria-describedby の参照先）
└── ピッチ領域
    ├── FreeLayoutPitchDiagram（key = 青の陣形ID:赤の陣形ID:pitchRevision）
    └── BoardBall（key = ballRevision。ピッチと同じ寸法の SVG を重ねる）
```

### props / state 設計

| コンポーネント | props | 内部 state |
|---|---|---|
| `FreeLayoutBoardPage` | — | `board: Record<"A" \| "B", Formation>`（各チームの陣形と、保存配置を適用した選手座標）、`pitchRevision: number`（リセット時にピッチを作り直すための番号）、`ballPosition: BoardBallPosition`、`ballRevision: number`（ボールを中央へ戻すときにボールを作り直すための番号） |
| `FreeLayoutPitchDiagram` | `formationA: Formation`（青。左から右へ攻撃）、`formationB: Formation`（赤。右から左へ攻撃） | `draggingTeam` / `draggingPositionId`（ドラッグ中の選手）。ドラッグ・キー操作の直近座標は非リアクティブな変数で持つ |
| `BoardBall` | `position: BoardBallPosition`（左上基準の 0〜100） | `hitRadius`（画面幅に応じた操作領域の半径）。ドラッグ中のポインタ ID と未確定の位置は非リアクティブな変数で持つ |

初期値:

| state | 初期値 |
|---|---|
| `board.A` | `formations[0]` に、保存キー `A:{陣形ID}` の配置を `applyOverrides` で適用したもの |
| `board.B` | `formations[1]`（無ければ `formations[0]`）に、保存キー `B:{陣形ID}` の配置を適用したもの |
| `ballPosition` | `loadBoardBallPosition()`（保存が無い・不正なら中央 `{ x: 50, y: 50 }`） |
| `pitchRevision` / `ballRevision` | 0 |

## 状態管理（クエリキー設計）

**該当なし**: 本画面はバックエンドAPIを呼ばない。端末内の保存は次の2か所で、いずれもボード専用である。

| 保存対象 | モジュール | 保存先キー | 保存単位 |
|---|---|---|---|
| 選手配置 | `data/freeLayoutStorage.ts` | `formation-lab.board-layout-overrides.v1`（ページから渡す。モジュール既定の比較画面用キーとは別） | `{チーム}:{陣形ID}` ごとに、ポジション ID → `{ x, y }` |
| ボール位置 | `data/boardBallStorage.ts` | モジュール内の固定キー | ボール1個の `{ x, y }` |

再訪時の選択陣形は常に初期値（青 `formations[0]`・赤 `formations[1]`）へ戻り、その陣形の保存配置だけを
復元する（選択中の陣形そのものは保存しない）。

## 画面遷移・イベント処理の詳細フロー

### 画面表示

1. `board` と `ballPosition` を上記の初期値で組み立てる。
2. `FreeLayoutPitchDiagram` は各選手の座標（`x`: 幅方向、`y`: 深さ方向。0〜100）を
   `freeLayoutCoordinates.ts` で SVG 座標へ変換して描画する。青は左から右、赤は右から左へ攻める向き。
3. `BoardBall` は `cx = 5 + x × 2.5`、`cy = 5 + y × 1.5` で描画する（ボール本体が端で切れないよう半径分内側へ寄せる）。

### 陣形の選択

1. セレクトを変更すると `selectFormation(team, formationId)` を呼ぶ。
2. 選んだ陣形に、保存キー `{team}:{formationId}` の保存配置を適用して `board[team]` を置き換える。
   同じ陣形を青・赤の両方で選んでも、保存キーが別なので互いに影響しない。
3. ピッチの `key` に陣形 ID を含むため、ピッチは作り直される（操作途中の状態は破棄）。ボールは変わらない。

### チームのリセット

1. 「{チーム}をリセット」をクリックすると `resetTeam(team)` を呼ぶ。
2. `clearFormationOverride` で、選択中の陣形の保存配置（`{team}:{陣形ID}`）だけを消す。
   他の陣形・相手チームの保存配置は残す。
3. `board[team]` を陣形の初期配置で置き換え、`pitchRevision` を 1 増やしてピッチを作り直す。
   リセット前に始まっていたドラッグ・キー操作の確定イベントが、リセット後に保存されるのを防ぐため。
4. ボールは変わらない。

### 選手の移動（ドラッグ・矢印キー）

1. ドラッグ: `pointerdown` で対象選手を記録してポインタキャプチャを取る。`pointermove` のたびに
   画面座標を SVG 座標、さらに実座標（0〜100 に制限）へ変換し、`update-position` を発火する。
2. ページは `update-position` を受けて `board[team].positions` の該当選手だけを更新する（表示のみ。
   有限値でない座標は無視し、0〜100 に制限する）。
3. `pointerup` / `pointercancel` で `update-position-end` を1回だけ発火し、ページが `savePositionOverride` で保存する。
   一度も動かさずに離した場合（クリックのみ）は発火しない。ボタンが離されているのに `pointermove` を
   受けた場合は、取りこぼした `pointerup` として扱いドラッグを終える。
4. 矢印キー: フォーカス中の選手を 1 回あたり SVG 上 6 単位動かし、`update-position` を発火する。
   キーを離した時（`keyup`）に `update-position-end` を1回だけ発火して保存する（長押しの連打で毎回
   保存しないため）。

### ボールの移動（ドラッグ・矢印キー）

1. ドラッグ: 主ボタンの `pointerdown` でポインタ ID を記録する。`pointermove` で座標を変換し、
   0〜100 に制限して `update-position` を発火する。逆変換できない瞬間は最後の正常位置を保つ。
2. `pointerup` / `pointercancel` / ポインタキャプチャの喪失（`lostpointercapture`）で `update-position-end` を発火し、ページが
   `saveBoardBallPosition` で保存する。
3. 矢印キー: 左右 2.4、上下 4（0〜100 の座標上）ずつ動かす。キーを離した時と、フォーカスが外れた時に
   `update-position-end` を発火して保存する。ドラッグ中はキー操作を受け付けない。
4. 画面幅が狭いときも操作領域を 44px 以上に保つよう、`ResizeObserver` で操作半径を調整する。

### ボールを中央に戻す

1. 「ボールを中央に戻す」をクリックすると `resetBall()` を呼ぶ。
2. `ballRevision` を 1 増やしてボールを作り直し、`ballPosition` を中央にして保存する。
   リセット前の操作の確定イベントが後から保存されるのを防ぐため。選手配置には影響しない。

### 画面遷移イベント

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 主ナビの各項目をクリック | 各画面 | `AppHeader` の責務。本画面の配置は保存済みの分だけ次回復元される |

## 例外・エラー表示

- **`localStorage` が使えない・保存に失敗する**: 読み込みは空（選手は陣形の初期配置、ボールは中央）として
  扱い、保存の失敗は握りつぶす。画面にエラーは出さず、表示中の配置のまま操作を続けられる
  （`freeLayoutStorage.ts` / `boardBallStorage.ts` の責務）。
- **保存データが壊れている・書き換えられている**: 形式が正しい部分だけを使い、不正な部分は保存無しとして
  扱う。`__proto__` などの危険なキーは読み込み時に除外し、座標は有限値だけを 0〜100 に制限して使う。
- **座標変換が NaN になる瞬間**（非表示・幅 0 など）: 変換結果が有限値でなければ移動を反映しない。
- 本画面では戦術判定・試合再生を行わないため、判定に関するエラー表示は持たない。

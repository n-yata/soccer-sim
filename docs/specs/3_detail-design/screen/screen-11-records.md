# 画面詳細設計書: S-11 戦績

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-11」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-09」。戦績の項目は
> [`data-definition.md`](../data/data-definition.md)。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-11 戦績 |
| シーン | `game/ui/screens/s11_records/records_screen.tscn` |
| ルートの `class_name` | `RecordsScreen`（`Control`） |
| 使うアプリケーション層 | `App.user_data`（`records()`・`totals()`）、`App.match_controller`（`NewMatchGate` 経由）、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-13 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s11-records`） |

## ノード構成

```
RecordsScreen (Control)
├── Header                                  # ScreenHeader（「← 戻る」と「戦績」）
├── Columns (HBoxContainer)                 # 1件以上のとき
│   ├── TotalsCard (VBoxContainer)          # 左（幅 440px）: 通算。「勝ち 5」「引き分け 2」「負け 3」を縦に並べる（数字は Barlow Condensed 52px）
│   └── RecordList (ScrollContainer)        # 右（残りの幅）: 新しい順
│       └── RecordRows (VBoxContainer)
│           └── RecordRow × 件数            # 勝敗のタグ（「勝ち」などの文字）・スコア・日時・自分と相手の陣形・方式（前半）
├── EmptyState (VBoxContainer)              # 0件のときだけ。画面の中央
│   ├── EmptyText (Label)                   # 「まだ試合の記録がありません」
│   └── KickOffButton (Button)              # 「KICK OFF CPU 対戦」
├── NewMatchGate                            # ノードを持たない部品（S-01 と共通の手順）
└── ConfirmDialog
```

- 件数が多い（数千件）場合に備え、最初は新しい順に 50 件だけ描き、下端までスクロールしたら次の 50 件を足す
  （`architecture-overview.md`「データ増加への対応」）。通算は保持している戦績（上限までの直近の試合。`data-definition.md`）から求める

## 画面の状態

| 状態 | 押せるもの |
|---|---|
| `IDLE` | 戻る・（0件なら）CPU 対戦 |
| `BUSY` | なし（`NewMatchGate` の処理中） |
| `CONFIRMING` | 確認ダイアログだけ |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `totals()` で通算を描く
2. `records()`（新しい順）が0件なら `EmptyState` を出し、`Columns` を隠す。1件以上なら最初の 50 件を描く
3. 各行の日時は「10/17 19:42」の形（端末のローカル時刻。`functional-overview.md`「確定事項」の日時の基準）

### 空の表示から「CPU 対戦」を押す

`NewMatchGate.begin()`。手順は S-01 の「CPU 対戦」と同じ（[`screen-01-title.md`](./screen-01-title.md)）。

### 戻る・Android の戻る操作

`CONFIRMING` なら確認ダイアログを閉じる。それ以外は `App.request_screen(S01_TITLE)`。`true` を返す。

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| CPU 対戦（0件のとき） | S-02 試合準備（確認を経る） |
| 戻る | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 戦績の読み込みに失敗した | 0件の表示にする（破損したファイルは退避済み）。通知は `MainShell`（1回だけ） |
| 戦績が新しい版のアプリで保存されている | 0件の表示にする（元のファイルは上書きしない）。通知は `MainShell` |

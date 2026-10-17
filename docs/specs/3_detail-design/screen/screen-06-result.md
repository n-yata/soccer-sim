# 画面詳細設計書: S-06 試合結果

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-06」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-01 ③」「UC-04」。画面共通の決めごとは
> [`screen-common.md`](./screen-common.md)。本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-06 試合結果 |
| シーン | `game/ui/screens/s06_result/result_screen.tscn` |
| ルートの `class_name` | `ResultScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-10, FR-13 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s06-result`） |

## ノード構成

```
ResultScreen (Control)
├── Hero (VBoxContainer)                    # 本体（左）。中央寄せ。地はスタジアムの絵を暗くしたもの
│   ├── FullTimeTag (Label)                 # 「FULL TIME」。地 accent
│   ├── OutcomeLabel (Label)                # 「勝ち」「引き分け」「負け」。96px Bold（色だけでなく文字で示す）
│   └── FinalScore (HBoxContainer)          # ScoreBug の大きい版（「● YOU 2 – 1 CPU ◆」）
└── SideColumn (VBoxContainer)              # 操作の列（右）
    ├── HistoryCard (PanelContainer)        # 陣形・方式の推移。地 surface。残りの高さいっぱい
    │   └── HistoryList (VBoxContainer)     # 「前半: ● 4-3-3 ゾーン・保持 対 ◆ 4-4-2 マンツーマン・カウンター」など
    ├── ReviewButton (Button)               # 「振り返り」。高さ 112px。地 accent
    └── TitleButton (Button)                # 「タイトルへ」。高さ 112px。縁取りだけ。列の下端
```

## 画面の状態

| 状態 | 押せるもの |
|---|---|
| `IDLE` | 振り返り・タイトルへ |
| `LEAVING` | なし（`leave_result` の処理中） |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `record = match_controller.final_record()`（開くたびに呼ぶ。振り返りから戻ったときも同じ）
2. 勝敗・最終スコア・陣形と方式の推移を描く
   - 推移は、前半と後半の両チームの陣形・方式に加え、方式が変わったときに「後半 4ターン目: CPU が守備方式をゾーンに変更」の
     形の行を足す（`MatchRecord` の陣形と方式の推移）

### 「振り返り」を押す

`App.request_screen(S07_REVIEW)`。

### 「タイトルへ」を押す・Android の戻る操作

1. `_state = LEAVING`
2. `match_controller.leave_result()`。終了処理が済んでいれば中断データを削除し、済んでいなければやり直す
   （なお失敗したら残して通知。UC-04）。タイトルへの切り替えは `MatchController` が要求する
3. Android の戻る操作は「タイトルへ」と同じ（`LEAVING` 中は何もしない）。`true` を返す

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 振り返り | S-07 振り返り |
| タイトルへ・戻る | S-01 タイトル |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 戦績の記録に失敗していた（終了処理が未完了） | 本画面では出さない（記録の失敗の通知は試合の終了時に出ている）。「タイトルへ」でやり直し、なお失敗した場合の通知は `MainShell` |

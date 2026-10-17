# 画面詳細設計書: S-07 振り返り

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」、
> 集計の規則はアルゴリズム10。レイアウト・画面項目・画面イベントの外部設計は
> [`screen-design.md`](../../2_basic-design/screen-design.md)「S-07」、呼び出しの順序は
> [`usecase.md`](../../2_basic-design/usecase.md)「UC-04」。画面共通の決めごとは [`screen-common.md`](./screen-common.md)。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-07 振り返り |
| シーン | `game/ui/screens/s07_review/review_screen.tscn` |
| ルートの `class_name` | `ReviewScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`（`review()`）、`App.library`（`simplifications()`）、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-18, FR-23 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s07-review`） |

## ノード構成

```
ReviewScreen (Control)
├── Header                                  # ScreenHeader（「← 戻る」と「振り返り」）
│   └── Tabs (TabBar)                       # ヘッダーの右側。エリア別・局面別・得失点・時間帯。各タブの高さ 96px
└── Pages (Control)                         # 選んだタブのページだけを表示する
    ├── AreaPage (HBoxContainer)
    │   ├── AreaPitch                       # 本体: TacticsBoard を「集計の表示」に使う（駒は出さず、各エリアに「勝3 負1 膠1」の札）
    │   └── AreaLegend (Label)              # 操作の列: 「勝＝こちらの判断が通った回数（アルゴリズム10）」などの説明
    ├── PhasePage (VBoxContainer)
    │   └── PhaseRows (GridContainer)       # 4局面 × 勝・負・膠着 の表。各行に横棒グラフ。画面の幅いっぱい
    ├── GoalsPage (HBoxContainer)
    │   ├── GoalList (ScrollContainer)      # 左（幅 560px）: 得点ごとのカード
    │   │   └── GoalCard × 得点数            # 見出し「▼ 失点 前半 6ターン目（0 − 1）」。押すと右に直前のターンを出す
    │   └── TurnList (ScrollContainer)      # 右（残りの幅）: 選んだ得点の直前のターン
    │       └── TurnRow × 遡るターン数       # 両者の手・ミニピッチ（動きの矢印つき）・判定理由・「実戦では」
    └── TimelinePage (ScrollContainer)
        └── SegmentList (VBoxContainer)     # 「前半 1〜6ターン: ● 4-3-3 ゾーン・保持 対 ◆ 4-4-2 マンツーマン・カウンター」
```

- `AreaPitch` は `TacticsBoard` に、駒の代わりに集計の札を描く表示（`show_tally(tally: Dictionary)`）を足して使う。
  判定の無かったエリアは札を出さない
- 得点のカードの見出しは、利用者の得点を「▲ 得点」、失点を「▼ 失点」とし、記号と文字で区別する（色は補助）
- 得失点のタブを開いたときは、最初の得点のカードを選んだ状態にする（右が空にならないように）

## 画面の状態

| 状態 | 内容 |
|---|---|
| `_tab` | 選んでいるタブ（初期値はエリア別。画面を開くたびにエリア別に戻す） |
| `_selected_goal` | 選んでいる得点のカード（得点の順番。0 始まり。得点が無ければ -1）。右の一覧にその得点の直前のターンを出す |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `view = match_controller.review()`（`ReviewView`）
2. 4つのページを `view` から描く。得失点の流れの各ターンは `RevealView` で、ミニピッチに動きの矢印を描き、
   判定理由は `JudgeReasonFormatter` で作る
3. 各ターンの `simplification_ids` が空でなければ、`library.simplifications()` から「実戦では」の文を引いて添える
4. 得点が0件なら、得失点のページに「この試合は 0 − 0 でした。エリア別・局面別で、どこで判断が通ったかを確かめよう」と出す

### タブを切り替える・得点のカードを押す

画面の中の表示を切り替えるだけ（アプリケーション層は呼ばない）。

### 戻る・Android の戻る操作

`App.request_screen(S06_RESULT)`。`true` を返す。

### 画面遷移

| 操作 | 遷移先 |
|---|---|
| 戻る | S-06 試合結果 |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 判定が1回も無かった局面（例: トランジションが起きなかった） | その局面の行に「この試合では起きなかった」と出す |
| ターン記録が無い（通常は起きない） | 「振り返りのデータがありません」と出し、戻るだけを押せるようにする |

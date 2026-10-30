# 画面詳細設計書: S-01 タイトル

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-01」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-01 ①」「UC-05」「UC-06」。画面共通の決めごとは
> [`screen-common.md`](./screen-common.md)。本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-01 タイトル |
| シーン | `game/ui/screens/s01_title/title_screen.tscn` |
| ルートの `class_name` | `TitleScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`、`App.user_data`、`App.request_screen()` |
| `enter` の `params` | なし |
| 関連機能 | FR-01, FR-12, FR-13, FR-14, FR-15, FR-22, FR-23 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s01-title`） |

## ノード構成

```
TitleScreen (Control)
├── Hero (Control)                         # 左半分（16:9 で幅 600px）・高さいっぱい。スタジアムの絵（夜の照明・芝・白線・選手の駒）
│   ├── StadiumArt (TextureRect)           # assets の画像。右端は bg の色へ溶け込む
│   ├── TagLabel (Label)                   # 「MATCHDAY TACTICS」。地 accent
│   ├── ProductNameLabel (Label)           # プロダクト名（仮称）。Barlow Condensed／Noto Sans JP Bold 88px
│   └── TaglineLabel (Label)               # 「読み合いで戦術を学ぶボードゲーム」
└── Cards (VBoxContainer)                  # 右の列（16:9 で幅 632px）。外周の余白 24px、間隔 16px
    ├── ResumeCard (Button)                # 再開カード。RESUMABLE のときだけ。高さ 140px（2026-10-29 に 112px から変えた）。縁 accent
    │   ├── ResumeTag (Label)              # 「RESUME」
    │   ├── ResumeTitle (Label)            # 「中断した試合を再開」
    │   ├── ResumeSummary (Label)          # 「前半 7／15・4-3-3 対 4-4-2」
    │   └── ResumeScore (Label)            # 「1 – 0」（自分の数字は you、相手は opponent の色）
    ├── TutorialCard (Button)              # 未完了のときだけここに置く。高さ 104px
    │   ├── TutorialTitle (Label)          # 「チュートリアル」
    │   ├── TutorialSub (Label)            # 「ピッチ・局面・読み合いを、操作して覚える」
    │   └── FirstTimeBadge (Label)         # 「はじめての方へ」。地 you、文字 bg
    ├── KickOffCard (Button)               # 「KICK OFF／CPU 対戦」。地 accent、高さ 136px
    └── SmallCards (GridContainer)         # 4列（チュートリアル完了後は5列）。残りの高さいっぱい
        ├── QuizCard (Button)              # 「理解度チェック」＋一言「3／8 正解」
        ├── RecordsCard (Button)           # 「戦績」＋一言「5勝 2分 3敗」
        ├── ScopeCard (Button)             # 「表現範囲」＋一言「実戦との違い」
        ├── SettingsCard (Button)          # 「設定」＋一言「音量・ヒント」
        └── (TutorialCard)                 # 完了後はここ（最後）へ移し、小さなカードの形で表示する
```

- チュートリアルの位置は `enter` のたびに決める。未完了なら `Cards` の `KickOffCard` の直前、完了後は `SmallCards` の最後へ
  `reparent()` し（`SmallCards` を5列にする）、大きさと「はじめての方へ」の表示を切り替える
- 再開カードもチュートリアルも無いとき（完了済みで中断中の試合が無い）は、`KickOffCard` を高さ 200px に広げる
- `NewMatchGate`（`common/new_match_gate.gd`）はノードを持たない部品で、`TitleScreen` のスクリプトが持つ（`screen-common.md` §5）
- 確認ダイアログは `ConfirmDialog`（`common/confirm_dialog.tscn`）を `TitleScreen` の最後の子として置く
- カードはすべて `Button`（中に `Label` を並べる）で、押せる範囲はカード全体（NFR-19）

## 画面の状態

| 状態 | 見えるもの | 押せるもの |
|---|---|---|
| `IDLE` | 上のすべて（再開カードは条件付き） | すべてのボタン |
| `BUSY` | そのまま | なし（再開・CPU 対戦の処理中。二重に押されて2回遷移するのを防ぐ） |
| `CONFIRMING` | ＋確認ダイアログ | 確認ダイアログだけ |

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_state` | `State` | 上の状態 |
| `_status` | `AppScreens.SuspendedStatus` | `enter` で取った中断データの状態 |

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `_status = match_controller.suspended_status()`
2. `_status == RESUMABLE` なら `ResumeCard` を出し、`suspended_snapshot()` から「前半／後半 N／M・自分の陣形 対 相手の陣形」と
   スコアを作る。それ以外は隠す
3. `App.user_data.settings().tutorial_completed` でチュートリアルのカードの位置と「はじめての方へ」を決める
4. 小さなカードの一言を作る: 理解度チェックは `quiz_progress()` の全学習目標の正答数／問題数（「3／8 正解」。0件なら
   「未回答」）、戦績は `totals()`（「5勝 2分 3敗」。0件なら「まだ記録がありません」）
5. `_state = IDLE`

### 再開カードを押す

1. `_state = BUSY`
2. `match_controller.resume()`。画面の切り替えは `MatchController` が要求する（S-03／S-04／S-05）
3. 読み直した中断データが消えていた・破損していた場合（起動後に外部から消されたなど）は、`MatchController` が
   `storage_error(SUSPEND_LOAD)` を出してタイトルを要求し直す（`resume()` は `false` を返す。`component-design.md` §3.2）。本画面は `enter` からやり直す
4. `resume()` が `false` を返したのにタイトルの `enter` が呼ばれなかった場合に備え、`false` なら `_state = IDLE` に戻す

### 「CPU 対戦」を押す

`NewMatchGate.begin()` に任せる（S-11 の空の表示と共通。`screen-common.md` §5）。`NewMatchGate` は次の手順で動く。

1. `_state = BUSY`。`suspended_status()` を取り直す（画面を開いた後に変わっている可能性があるため）
2. `NONE` なら `App.request_screen(S02_MATCH_SETUP)`
3. `RESUMABLE` なら `ConfirmDialog.ask("新しい試合を始めると、中断している試合は破棄されます", "始める", "やめる")`。
   了承なら `request_screen(S02_MATCH_SETUP)`、やめるなら `_state = IDLE`
4. `FINALIZE_PENDING` なら `retry_pending_finalize()`
   - `true` なら `request_screen(S02_MATCH_SETUP)`
   - `false` なら `ConfirmDialog.ask("前の試合の戦績を記録できていません。新しい試合を始めると、その戦績は記録されません", "始める", "やめる")`。
     了承なら `request_screen(S02_MATCH_SETUP)`、やめるなら `_state = IDLE`
5. どの経路でも、中断データはここでは消さない（試合を作ったときに上書きされる。削除の時点①）

### その他のボタン

| カード | アクション |
|---|---|
| チュートリアル | `App.request_screen(S08_TUTORIAL)` |
| 理解度チェック | `App.request_screen(S09_QUIZ)` |
| ゲームの表現範囲 | `App.request_screen(S10_SCOPE)` |
| 戦績 | `App.request_screen(S11_RECORDS)` |
| 設定 | `App.request_screen(S12_SETTINGS)` |

### Android の戻る操作（`handle_back`）

| 状態 | 動き |
|---|---|
| `CONFIRMING` | 確認ダイアログを閉じる（「やめる」と同じ）。`true` を返す |
| `IDLE` | `false` を返す（`MainShell` がアプリを閉じる） |
| `BUSY` | 何もしない。`true` を返す |

### 画面遷移

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 再開カード | S-03／S-04／S-05 | 進行段階で決まる（確定事項「再開先」） |
| CPU 対戦 | S-02 試合準備 | 上の手順の確認を経る |
| 各ボタン | S-08〜S-12 | — |

## 作る順序（2026-10-18 時点）

動く骨格の作業（`.steering/20261018-walking-skeleton/`）では、サービスに頼らない部分だけを作った。
- **作ったもの**: `Hero`（`StadiumArt` を除く。地の色のまま）、チュートリアルのカード（未完了の位置で固定）、`KickOffCard`、小さなカード4枚、
  `IDLE` の戻る操作（`false`）
- **行き先の画面が無いカード**: 押せなくして「準備中」を出す。カードの中の文字は、テーマの選択不可の文字色にそろえる。
  行き先は `MainShell.SCREEN_SCENES` の対応で決まり、画面を作って対応を足せば押せるようになる
- **中断・再開の作業（2026-10-29）で足したもの**: 再開カード（`suspended_snapshot()` から一言とスコア。地は通常のカード、
  縁 `accent`（テーマの型 `ResumeCard`）。4行が入るよう高さを 112px から 140px にした）、「CPU 対戦」の確認の手順
  （`NewMatchGate`・`ConfirmDialog`）、状態 `BUSY`・`CONFIRMING`
- **戦績の作業（2026-10-29）で足したもの**: 戦績のカードの一言（`RecordsCard` の中の `RecordsSub`。押せない間は隠し「準備中」だけ。
  小さなカードの幅では1行に収まらず数の途中で折り返すので、「3勝」「3分」「2敗」の3行に分ける）、
  戦績を記録できていない試合（`FINALIZE_PENDING`）の確認
- **設定の作業（2026-10-29）で足したもの**: 「設定」のカードが押せる（S-12 を作った）。`tutorial_completed` は保存できるが、
  完了にする手段（チュートリアル）がまだ無いので、位置の切り替えはチュートリアルの作業で足す
- **チュートリアルの作業（2026-10-29）で足したもの**: チュートリアルのカードが押せる（S-08 を作った）。位置の切り替え
  （`place_tutorial_card`）。小さなカードへ移すときは、名前を折り返し（ほかの小さなカードと同じ）、「はじめての方へ」と説明の行を隠す
- **ゲームの表現範囲の作業（2026-10-30）で足したもの**: 「表現範囲」のカードが押せる（S-10 を作った）。「表現範囲」の一言
  「実戦との違い」と「設定」の一言「音量・ヒント」（どちらも固定の文。シーンに置いた）
- **理解度チェックの作業で足すもの**: 理解度チェックのカードの一言
- プロダクト名は仮称の「SOCCER GAME」（正式名は要件定義書 §7.1 #4）。日本語は Noto Sans JP を置くまで、端末のフォントで表示される

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 起動時に中断データが破損していた | `MainShell` が保持していた通知を、本画面を開いた後に出す（文言は `functional-overview.md`「エラーハンドリング」） |
| 設定の読み込みに失敗した | 初期値（チュートリアル未完了）として扱い、チュートリアルを「CPU 対戦」の直前に出す。通知は `MainShell` |
| 戦績・回答結果の読み込みに失敗した | 一言は「まだ記録がありません」「未回答」と同じ表示にする。通知は `MainShell`（`UserDataService` が1回だけ出す） |
| 戦績の記録のやり直し（`retry_pending_finalize`）に失敗した | 上の確認ダイアログで伝える。加えて `UserDataService` の保存失敗の通知が出る |

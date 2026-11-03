# 画面詳細設計書: S-03 試合

> 画面一覧・画面遷移の正本は [`functional-overview.md`](../../1_requirements/functional-overview.md)「画面設計」。
> レイアウト・画面項目・画面イベントの外部設計は [`screen-design.md`](../../2_basic-design/screen-design.md)「S-03」、
> 呼び出しの順序は [`usecase.md`](../../2_basic-design/usecase.md)「UC-01 ②」。画面共通の決めごと（寸法の単位・
> 配色・画面の出入りの約束・共通部品の形）は [`screen-common.md`](./screen-common.md)。
> 本書は、本画面のノード構成・状態・イベント処理の手順・例外表示を記載する。

## 基本情報

| 項目 | 内容 |
|---|---|
| 画面 ID・画面名 | S-03 試合 |
| シーン | `game/ui/screens/s03_match/match_screen.tscn` |
| ルートの `class_name` | `MatchScreen`（`Control`） |
| 使うアプリケーション層 | `App.match_controller`（`MatchController`）、`App.user_data`（`UserDataService`。ヒント表示の設定） |
| `enter` の `params` | なし（試合の状態はすべて `MatchController` から取る） |
| 関連機能 | FR-03〜FR-07, FR-09, FR-11, FR-16, FR-19, FR-21, FR-24 |
| ワイヤーフレーム | [`wireframes.drawio`](../../2_basic-design/wireframes.drawio)（ページ: `wireframe-s03-match`） |

## ノード構成

```
MatchScreen (Control)
├── Layout (VBoxContainer)                    # 外周の余白 左右 24px・上下 12px（screen-common.md §1.1。2026-10-25）
│   ├── TopBar (HBoxContainer)                # 高さ 96px
│   │   ├── MenuButton (Button)               # 「≡」。96×96px
│   │   ├── ScoreBug (HBoxContainer)          # 中継風のスコア表示（common/score_bug.tscn）
│   │   │   ├── UserChip (Label)              # 「● YOU」。地 #0E3A55
│   │   │   ├── ScoreLabel (Label)            # 「1 – 0」。白地に暗い文字、52px
│   │   │   ├── OpponentChip (Label)          # 「CPU ◆」。地 #4A2611
│   │   │   └── ClockLabel (Label)            # 「前半 5／15」。アディショナルタイムは「前半 15＋2」
│   │   ├── PossessionLabel (Label)           # 「● 自分のボール」／「◆ CPU のボール」。地は保持側のチームの色。開示中も隠さず、判定後の保持に替える（2026-10-24）
│   │   ├── PhaseTag (Label)                  # 「ATTACK」と「攻撃」の2行（1行だとトランジションの「NEG.TRANSITION ネガティブトランジション」で上部バーが画面の幅を超えた。2026-10-29）。地 accent、文字 bg。開示中は隠し、RevealBanner に替える
│   │   └── RevealBanner (VBoxContainer)      # 両者の選択の帯（2段）。開示から次のターンまで表示（それ以外は非表示）。各段 24px、ELLIPSIS
│   │       ├── UserChoiceLabel (Label)       # 「YOU ショートパス → 中盤（敵陣）・中央」。地 #0E3A55
│   │       └── OpponentChoiceLabel (Label)   # 「CPU プレス → 中盤（自陣）・左HS」。地 #4A2611
│   └── BoardPanel                            # MatchBoardPanel（board2d/match_board_panel.tscn）。高さ 600px（2026-10-25 に6列で 576px から変更）。S-08 と共用
│       ├── Columns (HBoxContainer)           # 間隔 24px
│       │   ├── BoardArea (Control)           # 本体。残りの幅いっぱい（16:9 で 728×600px。5レーン×6列で、平面図の1エリア 約 145×100px）
│       │   │   └── TacticsBoard              # board2d/tactics_board.tscn。ピッチ・駒・札・矢印
│       │   └── SideColumn (VBoxContainer)    # 操作の列。幅 480〜640px（screen-common.md §1.1）、間隔 16px
│       │       ├── SetupCard (VBoxContainer)      # 上端に固定。両チームの陣形・方式を常に表示（FR-16・21）。2段、各 24px、ELLIPSIS
│       │       │   ├── UserSetupLabel (Label)     # 「● 自分 4-3-3 ゾーン・カウンター」
│       │       │   └── OpponentSetupLabel (Label) # 「◆ CPU 4-4-2 ゾーン・保持」
│       │       ├── SideScroll (ScrollContainer)   # 中身が入りきらないときだけ縦にスクロールする（screen-common.md §1.1）
│       │       │   └── SideBody (VBoxContainer)   # 間隔 16px
│       │       │       ├── SideTopSlot (VBoxContainer) # 画面ごとに足す表示の置き場。S-03 では空、S-08 は説明文の吹き出し
│       │       │       ├── ChoicePanel           # board2d/choice_panel.tscn。手のボタン（高さ 96px、2列。攻撃の手は6つで2列×3段。奇数個の局面は最後の1つを列の幅いっぱい）
│       │       │       ├── TargetInfo (Label)    # 選んだ運ぶ先の名前と、ヒントの札の文（ヒントが ON のとき）。地 surface
│       │       │       └── JudgeTelop (VBoxContainer) # 判定理由の表示中だけ（ChoicePanel・TargetInfo の代わりに出す）
│       │       │           ├── OutcomeTag (Label)     # 「● ADVANCE 前進」。地は成功した側の色（自分 水色・相手 オレンジ。判定なしは accent）
│       │       │           ├── ReasonLabel (Label)    # JudgeReasonFormatter の文。地 telop_bg
│       │       │           ├── JudgeDetail (Label)    # 判定の内訳「比較エリア 中盤（敵陣）・中央／● 自分 1 対 0 相手 ◆／カバー なし」。NO_CONTEST では隠す
│       │       │           └── RealWorldNote (Label)  # 「実戦では: …」。該当するときだけ。文字 caution
│       │       ├── PrimaryButton (Button)    # 列の下端に固定。高さ 112px、列の幅いっぱい。show_next が偽なら判定理由の表示中は隠す
│       │       │   ├── ButtonSummary (Label) # 「ショートパス → 中盤（敵陣）・中央」／「次のターンへ」
│       │       │   └── ButtonAction (Label)  # 「LOCK IN」／「NEXT」
│       │       └── SideBottomSlot (VBoxContainer) # 画面ごとに足すボタンの置き場。S-03 では空、S-08 は「次へ」
│       （3D 演出の ReplayLayer は 2026-10-23 にやめた。開示は TacticsBoard の上で駒とボールを動かす）
├── MatchMenu                                 # common/match_menu.tscn。閉じているときは非表示
├── SettingsOverlay (PanelContainer)          # メニューの「設定」で重ねて開く
│   └── SettingsPanel                         # common/settings_panel.tscn
└── ConfirmDialog                             # common/confirm_dialog.tscn
```

- **画面の向き**: 横向きだけ（要件定義書 §6.1）。端末の横の長さの違い（16:9〜21:9）は、操作の列の幅（上限 640px）と
  `BoardArea` の幅で吸収する（横に長い端末ほどピッチが横に伸びる。高さは 600px で一定。screen-common.md §1.1）
- **開示の表示場所**: 開示は `TacticsBoard` の上で、判定前の位置から判定時の位置へ（プレー）、続けて次のターン開始時の位置へ
  （詰め直し）、駒とボールを2拍で動かして見せる（2026-11-03 に2拍にした）。
  盤面は縦向きのピッチを斜めから見せ、利用者の攻撃方向は上（2026-10-23 に、3D 演出の表示場所 `ReplayLayer` から置き換えた）
- **盤面と操作の列の部品**: `BoardPanel`（`MatchBoardPanel`）の中身は S-08 と共用する。画面ごとの違いは
  `SideTopSlot`・`SideBottomSlot` に置く（[`screen-08-tutorial.md`](./screen-08-tutorial.md)）
- **処理の持ち主**: 下の「画面の状態」と、「ターンを始める」〜「開示」・「次へ」の 1. は `MatchBoardPanel` のスクリプトが持つ（`turn_resolved` をつなぐのもパネル）。`MatchScreen` は上部バー・メニュー・画面遷移を持ち、`state_changed` を受けて進行段階が `TURN` のままなら `BoardPanel.start_turn()` を呼び、`turn_ready_to_leave` を受けて `continue_after_reveal()` を呼ぶ（「次へ」の 2.）。上部バー（`PossessionLabel`・`PhaseTag`・`RevealBanner`・スコア）は `MatchScreen` の部品なので、パネルが出す `turn_started(snapshot)`（「ターンを始める」の 3.）・`reveal_started(reveal)`（「開示」の 1.）・`result_shown(snapshot)`（「開示」の 4.）を受けて `MatchScreen` が描き直す。下の手順の中の上部バーの操作は、この受け渡しのことを指す
- **見た目**: 色・書体は `screen-common.md` §2・§3、方向性は `screen-design.md`「ビジュアルの方向性」。
  `TacticsBoard` の描き方（駒の並べ方・札・矢印の線種）は `screen-common.md` §5 の `TacticsBoard` の項

## 画面の状態

画面は次の状態のどれか1つにある。状態ごとに、押せるもの・見えるものを決める。

| 状態 | 意味 | 見えるもの | 押せるもの |
|---|---|---|---|
| `SELECT_ACTION` | 手を選んでいない | ボード・手のボタン | 手のボタン、メニュー |
| `SELECT_TARGET` | 運ぶ先を持つ手を選び、エリアを選んでいない | ＋選べるエリアの点線の枠・ヒントの札（ON のとき）・プレス／カバー／スルーパスの選べる条件の一言（スルーパスは手のボタンの下にはみ出すので、見える所までスクロールする。2026-10-25） | 手のボタン（選び直し）、選べるエリア、メニュー |
| `READY` | 手（と必要なエリア）を選び終えた | ＋選んだエリアの塗り・ボールから運ぶ先への矢印（ボールを運ぶ手だけ）・決定前のプレビュー・決定ボタンの要約 | 手のボタン、選べるエリア、「決定」、メニュー |
| `SUBMITTING` | 「決定」を押し、結果を待っている | そのまま | なし（二重送信を防ぐ） |
| `SHOW_RESULT` | 判定理由を表示している | 両者の選択の帯・ボード（駒とボールの動き・動きの矢印・比較エリアの人数の札）・判定理由のテロップ | 「次へ」、メニュー |
| `LEAVING` | 「次へ」の後、画面の切り替えを待っている | そのまま | なし |

**状態遷移図**: [`screen-03-match-states.drawio`](./screen-03-match-states.drawio)。上の表の状態の間の遷移と、
そのきっかけ（手の選択・「決定」・`turn_resolved`・「次へ」・`state_changed`）を示す。3D 演出の状態 `REPLAYING` は 2026-10-23 にやめた（`turn_resolved` で `SUBMITTING` から `SHOW_RESULT` へ進む）。
`submit_turn` が `false` のときだけ、`SUBMITTING` から `SELECT_ACTION` へ戻る（例外の経路。破線）。

- 「運ぶ先を持つ手」は、`MoveOptions` でその手の運ぶ先の一覧が1件以上あり、かつ手の種類が運ぶ先を伴うもの
  （`SHORT_PASS`・`DRIBBLE`・`LONG_BEHIND`・`SWITCH`・`PRESS`・`COVER`・`COUNTER`）。`SHOT`・`COUNTER_PRESS`・
  `RETREAT`・`SECURE` は運ぶ先を持たない
- メニュー・設定・確認ダイアログを開いている間は、上の状態を変えずに、下の画面の入力を止める
  （重ねたパネルの外側を押しても閉じない。閉じるのはパネルの「閉じる」とメニューの選択肢だけ）

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_state` | `State`（上の enum。スクリプト内に置く） | 現在の状態 |
| `_options` | `MoveOptions` | このターンの選べる手（`user_options()` の結果） |
| `_hints` | `Array[ChoiceHint]` | ヒント。設定が OFF なら空 |
| `_selected_family` / `_selected_action` | `GameEnums.ChoiceFamily` / `int` | 選んだ手 |
| `_selected_target` | `String` | 選んだエリアのキー（`"M2-C"` など）。未選択・不要なら空文字 |
| `_reveal` | `RevealView` | 直前の開示の値（`SHOW_RESULT` で使う） |
| `_snapshot` | `BoardSnapshot` | `turn_resolved` で受けた判定後の盤面（次のターン開始時の配置） |

ターンが始まるたび（`SELECT_ACTION` に入るたび）に、`_selected_*` と `_hints` を空に戻す（前のターンの選択を
持ち越さない）。

## イベント処理の詳細フロー

### 画面を開く（`enter`）

1. `App.match_controller` の `state_changed` をつなぎ、`BoardPanel.bind(App.match_controller)`（`turn_resolved` はパネルがつなぐ）
2. `snapshot()` を取り、上部バー（スコアと、局面・陣形と方式の表示）とボードを描く
3. `BoardPanel.start_turn()`（次節）

### ターンを始める

1. `_options = user_options()`。`ChoicePanel.show_options(_options, snapshot.turn_kind, snapshot.user_has_ball)`
2. `App.user_data.settings().show_hints` が真なら `_hints = user_hints()`、偽なら空
3. `TacticsBoard.clear_overlays()`、`RevealBanner`・`JudgeTelop` を隠し、`PhaseTag`・`ChoicePanel` を出す。`PossessionLabel` をそのターンの保持で描き直す。`SetupCard` を描き直す。`TargetInfo` は空にして隠す
4. `PrimaryButton` の要約を空、操作を「LOCK IN」にして押せなくする。`_state = SELECT_ACTION`
5. `snapshot.turn_number` が 1（前半・後半のキックオフ）なら、笛を鳴らす（`Sfx.play(WHISTLE)`。再開した試合の1ターン目でも鳴らす。
   得点後の再開では鳴らさない。2026-10-30 の効果音の作業。鳴らすのは `MatchScreen` で、チュートリアルでは鳴らさない）

### 手のボタンを押す（`ChoicePanel.action_selected`）

1. `_selected_family`・`_selected_action` を記録し、`_selected_target` を空にする。選んだエリアの塗り・意図の矢印・
   決定前のプレビューを消す（`show_preview([])`）
2. 運ぶ先を持つ手なら
   1. `_options` からその手の運ぶ先の一覧を取り、`TacticsBoard.set_selectable(一覧)`
   2. `_hints` からその手の分を取り出し、`TacticsBoard.set_hints({エリアのキー: 表示文})`。表示文は
      人数差（`+1`・`±0`・`−1`）とカバーの有無を並べたもの（`CoverKind` が `DEFENDER` なら `カバーあり`、`NONE` なら空。例: `+1`、`±0 カバーあり`。スルーパスは `読み次第`（相手が何もしなくてもマンツーマンの付け直しで守備が入ってくる運ぶ先は `マーク注意`。確定ではない。2026-10-28）。今の配置のままオフサイドになる運ぶ先は、ほかより先に `オフサイド`（2026-10-25）。`functional-overview.md`「表示仕様」のヒントの札）
   3. プレス・カバー・スルーパスなら、選べる条件の一言（`MatchTexts.target_rule`。誰が動くか・どのエリアを選べるか）を `TargetInfo` に出し、
      2フレーム待ってから `TargetInfo` が見える所まで `SideScroll` をスクロールする（攻撃の手は6つで、説明が手のボタンの下にはみ出すため。2026-10-25）
   4. `_state = SELECT_TARGET`。「決定」は押せない
3. 運ぶ先を持たない手なら、ボードの枠とヒントを消し、その手のヒントを `TargetInfo` に出す
   （例: 即時奪回 `周辺 2対4`）。決定前のプレビュー（`user_preview` → `show_preview`）を出す。
   `_state = READY`、「決定」を押せるようにする
4. `PrimaryButton` の要約（`ButtonSummary`）を更新する

### エリアを押す（`TacticsBoard.area_pressed`）

1. `_state` が `SELECT_TARGET`・`READY` で、押したエリアが選べるエリアのときだけ受け付ける（それ以外は何もしない）
2. `_selected_target` を記録し、そのエリアを塗る。ボールを運ぶ手（攻撃・カウンター）なら、`TacticsBoard.show_intent(ボールのエリア, 運ぶ先)` で
   ボールから運ぶ先への矢印を描く。守備の手では描かない（選ぶのは相手が来ると読んだエリアで、ボールはそこへ動かない）。
   `MatchController.user_preview(手)` の動きを `TacticsBoard.show_preview` で重ねる（決定前のプレビュー。自分の選手だけ。
   相手の駒は動かさない）。
   決定ボタンの要約を「ショートパス → 中盤（敵陣）・中央」の形にする。`TargetInfo` に運ぶ先の名前と、そのエリアのヒントの札の文（ヒントが ON のとき。例「中盤（敵陣）・中央　+1　1対0」）を出す
3. `_state = READY`、「決定」を押せるようにする

### 「決定」を押す

1. `_state = SUBMITTING`。手のボタン・ボード・「決定」・メニューを押せなくする。決定前のプレビューを消す
2. `TurnChoice` を作る（`family`・`action`・`target`。`target` は利用者の視点のエリア。運ぶ先を持たない手は `null`）
3. `submit_turn(choice)` を呼ぶ
   - `false` なら「ターンを始める」をやり直す（選択を捨てて手のボタンを描き直す）。通知は出さない
     （通常は起きない。`component-design.md` §3.2「選択不可の手」）
   - `true` なら、同じ呼び出しの中で `turn_resolved` が届く（次節）

### 開示（`turn_resolved(reveal, snapshot)`）

1. `_reveal = reveal`、`_snapshot = snapshot`。`PhaseTag` を隠し、`RevealBanner` に「あなた: …／CPU: …」を出す（手とエリアの名前は `screen-design.md` の
   要約と同じ形）
2. `ChoicePanel`・`TargetInfo` を隠す
3. `TacticsBoard.show_snapshot(_snapshot)`（次のターン開始時の盤面）の後に、`start_shift` で駒とボールを2拍で動かす（2026-11-03）。
   1拍目（プレー）は判定前（`reveal.*_players_before`・`reveal.ball_before`）→ 判定時（`reveal.*_players_at_judgement`・
   `reveal.ball_after`）を `match_controller.board_play_sec()` 秒、2拍目（詰め直し）は判定時 → 次のターン開始時を
   `match_controller.board_settle_sec()` 秒。どちらの拍も、位置が変わった全選手を動かす（方式でずれた選手も動き、
   手で動いた後にチーム全体がボールに合わせて組み直ることが見える）。
   `show_movements(reveal.movements)` で矢印を描き、`show_compare(reveal.compare_area, reveal.user_count, reveal.opponent_count)` で
   比較エリアを光らせて人数の札（`1対0`）を出す
4. 上部バーのスコアと `PossessionLabel`（判定後の保持）を `_snapshot` で描き直す（`result_shown`）。`JudgeTelop` に結果（`OutcomeTag`。例 `● ADVANCE 前進`。成功した側を色と記号で示す: 保持側（攻撃側・奪った側）の成功は前進・得点・奪回失敗、相手側の成功は膠着・ロスト・シュート阻止・奪回成功・オフサイド（2026-10-25）、判定なしはどちらでもない。`MatchTexts.turn_winner`。2026-10-24）と判定理由（`JudgeReasonFormatter`）、判定の内訳（`JudgeDetail`。`reveal.compare_area`・`user_count`・`opponent_count`・`cover`。`NO_CONTEST` では隠す）を出す。`reveal.simplification_ids` が
   空でなければ、該当する単純化の「実戦では」を `RealWorldNote` に出す（複数なら先頭の1件）。
   効果音（2026-10-30）: 得点なら、`turn_winner` が自分なら `GOAL_FOR`、相手なら `GOAL_AGAINST`。`_snapshot.is_half_over`（前半の終わり・
   試合の終わり）なら笛（`WHISTLE`）。両方に当たれば両方を鳴らす
5. `PrimaryButton` を「次のターンへ／NEXT」にする。`_state = SHOW_RESULT`

> 動いている間も、テロップ・矢印はすぐ出し、「次へ」も押せる（待たせない）。方式の選び直し・ハーフタイムの後と試合の最初は
> 「ターンを始める」だけを通るので動かさない。2026-10-23 に、3D 演出（`REPLAYING`・`ReplayStage`・「スキップ」・演出の終了）から置き換えた。

### 「次へ」を押す

1. `_state = LEAVING`。`PrimaryButton` を押せなくする
2. `continue_after_reveal()` を呼ぶ
   - 進行段階が `TURN` のままなら `state_changed` が届く → 「ターンを始める」
   - それ以外は `App.screen_requested` で `MainShell` が画面を入れ替え、`exit` が呼ばれる

### メニュー

1. 「≡」を押す（`SELECT_ACTION`・`SELECT_TARGET`・`READY`・`SHOW_RESULT` のときだけ押せる。ただし試合を終えた後の
   `SHOW_RESULT`（`is_match_over()` が真。最終ターンの判定理由）は押せない。中断で結果画面と終了処理を飛ばさないため。2026-10-29）と、
   `MatchMenu.open(match_controller.has_unsaved_progress())`
2. 「設定」: `SettingsOverlay` を出し、`SettingsPanel.show_settings(App.user_data.settings())`。音量は `SettingsPanel` がその場で反映する。`committed` を受けたら
   `App.user_data.save_settings()`。ヒント表示を変えた場合は `BoardPanel.set_show_hints(値)` を呼ぶ（画面を開いたときも同じ関数で設定の値を渡す）（`SELECT_*`・`READY` なら、パネルが「ターンを始める」の 2. を
   やり直して、選んだ手のヒントを描き直す。選択は保つ）
3. 「中断してタイトルへ」: `MatchMenu` が警告を添えた確認を出し（`has_unsaved_progress()` が真のとき）、了承されたら
   `suspend_requested` → `match_controller.suspend_to_title()`。戻り値が `false` でも画面はタイトルへ進む（通知は
   `MainShell` が出す）

### Android の戻る操作（`handle_back`）

| 状態 | 動き |
|---|---|
| メニュー・設定・確認ダイアログを開いている | いちばん上のものを閉じる |
| `SELECT_ACTION`・`SELECT_TARGET`・`READY`・`SHOW_RESULT` | メニューを開く（試合を終えた後の `SHOW_RESULT` は開かない） |
| `SUBMITTING`・`LEAVING` | 何もしない |

いずれも `true` を返す（試合画面からアプリを閉じない）。

### 画面遷移

| 操作 | 遷移先 | 備考 |
|---|---|---|
| 「次へ」（得点。ハーフの最終ターンを除く） | S-04 方式の選び直し | `continue_after_reveal()` が要求する |
| 「次へ」（前半終了） | S-05 ハーフタイム | 同上 |
| 「次へ」（後半終了） | S-06 試合結果 | 同上 |
| メニュー →「中断してタイトルへ」 | S-01 タイトル | `suspend_to_title()` の後に `App` が要求する |

## 例外・エラー表示

| ケース | 表示 |
|---|---|
| 中断データの保存に失敗（ターンの確定時など） | 本画面では何も出さない。`MainShell` の通知で出る（文言は `functional-overview.md`「エラーハンドリング」）。試合は続ける |
| `submit_turn` が `false` | 通知は出さず、手の選択からやり直す |
| 選べる手が1つもない | 起きない（トランジションの手・守備の手は常に1つ以上選べる。`functional-overview.md` アルゴリズム3）。起きた場合は開発時の誤りとして `assert` で止める |

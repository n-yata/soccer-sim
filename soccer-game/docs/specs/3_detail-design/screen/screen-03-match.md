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
│   ├── TopBar (HBoxContainer)                # 高さ 96px。縦では PossessionLabel・PhaseTag・RevealBanner を TopSecondRow へ移す（2026-11-27）
│   │   ├── MenuButton (Button)               # 「≡」。96×96px
│   │   ├── ScoreBug (HBoxContainer)          # 中継風のスコア表示（common/score_bug.tscn）
│   │   │   ├── UserChip (Label)              # 「● YOU」。地 #0E3A55
│   │   │   ├── ScoreLabel (Label)            # 「1 – 0」。白地に暗い文字、52px
│   │   │   ├── OpponentChip (Label)          # 「CPU ◆」。地 #4A2611
│   │   │   └── ClockLabel (Label)            # 「前半 5／15」。アディショナルタイムは「前半 15＋2」
│   │   ├── PossessionLabel (Label)           # 「● 自分のボール」／「◆ CPU のボール」。地は保持側のチームの色。開示中も隠さず、判定後の保持に替える（2026-10-24）
│   │   ├── PhaseTag (Label)                  # 「ATTACK」と「攻撃」の2行（1行だとトランジションの「NEG.TRANSITION ネガティブトランジション」で上部バーが画面の幅を超えた。2026-10-29）。地 accent、文字 bg。開示中は隠し、RevealBanner に替える
│   │   └── RevealBanner (VBoxContainer)      # 両者の選択の帯（2段）。開示から次のターンまで表示（それ以外は非表示）。各段 24px、ELLIPSIS（どの手でも入る。2026-11-06）
│   │       ├── UserChoiceLabel (Label)       # 「● ショートパス」。手の名前だけ（行き先は盤面の矢印と判定理由で読む。「あなた:」と行き先まで書くと入らなかった。2026-11-06）。地 #0E3A55
│   │       └── OpponentChoiceLabel (Label)   # 「◆ パスコースを切る」。地 #4A2611
│   └── BoardPanel                            # MatchBoardPanel（board2d/match_board_panel.tscn）。高さ 600px（2026-10-25 に6列で 576px から変更）。S-08 と共用
│       ├── Columns (BoxContainer)            # 間隔 24px。縦では上下に積み、間隔 16px（2026-11-27。MatchBoardPanel.set_portrait）
│       │   ├── BoardArea (Control)           # 本体。残りの幅いっぱい（16:9 で 728×600px。5レーン×6列で、平面図の1エリア 約 145×100px）
│       │   │   └── TacticsBoard              # board2d/tactics_board.tscn。ピッチ・駒・札・矢印
│       │   └── SideColumn (VBoxContainer)    # 操作の列。幅 480〜640px（screen-common.md §1.1）、間隔 16px
│       │       ├── SetupCard (VBoxContainer)      # 上端に固定。両チームの陣形・方式を常に表示（FR-16・21）。2段、各 24px、ELLIPSIS（どの組み合わせでも入る。2026-11-06）
│       │       │   ├── UserSetupLabel (Label)     # 「● 4-3-3 ゾーン・カウンター型」。チームは印だけ（スコア表示の「● YOU」「CPU ◆」と同じ印。「自分」「CPU」まで書くと「4-2-3-1 マンツーマン・カウンター型」が入らなかった。2026-11-06）
│       │       │   └── OpponentSetupLabel (Label) # 「◆ 4-4-2 ゾーン・保持型」
│       │       ├── SideScroll (ScrollContainer)   # 中身が入りきらないときだけ縦にスクロールする（screen-common.md §1.1）
│       │       │   └── SideBody (VBoxContainer)   # 間隔 16px
│       │       │       ├── SideTopSlot (VBoxContainer) # 画面ごとに足す表示の置き場。S-03 では空、S-08 は説明文の吹き出し
│       │       │       ├── ChoicePanel           # board2d/choice_panel.gd。手のボタン（高さ 96px、2列。手は4つまでで、スクロールせずに選べる。文字は番号と行動の名前だけ。2026-11-05）
│       │       │       └── JudgeTelop (VBoxContainer) # 判定理由の表示中だけ（ChoicePanel の代わりに出す）
│       │       │           ├── OutcomeTag (Label)     # 「● ADVANCE 前進」。地は成功した側の色（自分 水色・相手 オレンジ。判定なしは accent）
│       │       │           ├── ReasonLabel (Label)    # JudgeReasonFormatter の文。地 telop_bg
│       │       │           ├── JudgeDetail (Label)    # 判定の内訳「比較エリア 中盤（敵陣）・中央／● 自分 1 対 0 相手 ◆／カバー なし」。NO_CONTEST では隠す
│       │       │           └── RealWorldNote (Label)  # 「実戦では: …」。該当するときだけ。文字 caution
│       │       ├── PrimaryRow (HBoxContainer) # 列の下端に固定。間隔 12px（2026-11-05）
│       │       │   ├── DetailButton (Button)  # 「詳細」。幅 128px・高さ 112px。手を選ぶと押せる。判定理由の表示中は隠す
│       │       │   └── PrimaryButton (Button) # 高さ 112px、残りの幅いっぱい。show_next が偽なら判定理由の表示中は隠す
│       │       │       ├── ButtonSummary (Label) # 「→ 中盤（敵陣）・中央」（行き先だけ。手の名前は選んだボタンに出ている。両方では幅に入らなかった。運ぶ先の無い手は手の名前。2026-11-06）／「次のターンへ」
│       │       │       └── ButtonAction (Label)  # 「LOCK IN」／「NEXT」
│       │       └── SideBottomSlot (VBoxContainer) # 画面ごとに足すボタンの置き場。S-03 では空、S-08 は「次へ」
│       ├── MoveDetailView（ModalOverlay）  # 盤面と操作の列の上に重ねる。選んだ手の詳細のポップアップ（見出し・本文・「閉じる」。2026-11-05）
│       （3D 演出の ReplayLayer は 2026-10-23 にやめた。開示は TacticsBoard の上で駒とボールを動かす。
│        得点・トランジションの3Dのカットイン GoalCutIn も 2026-11-27 に外した）
├── PhaseBanner (PanelContainer)              # 局面の帯（common/phase_banner.gd。2026-11-07。S-08 と共用）。局面が変わったターンの始めに、画面の真ん中を横切る高さ 160px の帯。英字の大見出し 64px（Barlow Condensed）と日本語の一言 28px。地 bg（不透明度 0.92）、縁と見出しは新しい局面でボールを持つ側の色（you／opponent）。1.2 秒で消え、タップを受けない（mouse_filter IGNORE）
├── MatchMenu                                 # common/match_menu.tscn。閉じているときは非表示
├── SettingsOverlay (PanelContainer)          # メニューの「設定」で重ねて開く
│   └── SettingsPanel                         # common/settings_panel.tscn
└── ConfirmDialog                             # common/confirm_dialog.tscn
```

- **画面の向き**: 横向きと縦向き（2026-11-27。縦の配置は `screen-common.md` §1.2。上部バーを2段にし、`BoardPanel` の `Columns`（`BoxContainer`）を上下に積む）。横向きでは、端末の横の長さの違い（16:9〜21:9）は、操作の列の幅（上限 640px）と
  `BoardArea` の幅で吸収する（横に長い端末ほどピッチが横に伸びる。高さは 600px で一定。screen-common.md §1.1）
- **開示の表示場所**: 開示は `TacticsBoard` の上で、判定前の位置から次のターン開始時の位置へ、駒とボールを1拍で動かして見せる
  （2026-11-03 にプレーと詰め直しの2拍にし、2026-11-06 に1拍に戻した）。
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
| `SELECT_ACTION` | 手を選んでいない | ボード・手のボタン・自分の手の行き先の点線の枠と番号の札（ヒントが ON なら人数差も） | 手のボタン、行き先のエリア、メニュー |
| `READY` | 手を選び終えた（行き先はゲームが決めたもの） | ＋選んだ行き先の塗り・ボールから行き先への矢印（ボールを運ぶ手だけ）・決定前のプレビュー・決定ボタンの要約 | 手のボタン（選び直し）、行き先のエリア、「詳細」、「決定」、メニュー |
| `SUBMITTING` | 「決定」を押し、結果を待っている | そのまま | なし（二重送信を防ぐ） |
| `SHOW_RESULT` | 判定理由を表示している | 両者の選択の帯・ボード（駒とボールの動き・動きの矢印・比較エリアの人数の札）・判定理由のテロップ | 「次へ」、メニュー |
| `LEAVING` | 「次へ」の後、画面の切り替えを待っている | そのまま | なし |

**状態遷移図**: [`screen-03-match-states.drawio`](./screen-03-match-states.drawio)。上の表の状態の間の遷移と、
そのきっかけ（手の選択・「決定」・`turn_resolved`・「次へ」・`state_changed`）を示す。3D 演出の状態 `REPLAYING` は 2026-10-23 にやめた（`turn_resolved` で `SUBMITTING` から `SHOW_RESULT` へ進む）。
運ぶ先を選ぶ状態 `SELECT_TARGET` は 2026-11-03 にやめた（行き先はゲームが決め、手を押すとすぐ `READY` になる）。
`submit_turn` が `false` のときだけ、`SUBMITTING` から `SELECT_ACTION` へ戻る（例外の経路。破線）。

- `user_options()` は画面に出す手（`functional-overview.md` アルゴリズム3「画面に出す手」）で、運ぶ先を持つ手の行き先は1件だけ。
  `SHOT`・`COUNTER_PRESS`・`RETREAT`・`SECURE` は運ぶ先を持たない
- メニュー・設定・確認ダイアログを開いている間は、上の状態を変えずに、下の画面の入力を止める
  （重ねたパネルの外側を押しても閉じない。閉じるのはパネルの「閉じる」とメニューの選択肢だけ）

### 画面の中だけで持つ値

| 変数 | 型 | 内容 |
|---|---|---|
| `_state` | `State`（上の enum。スクリプト内に置く） | 現在の状態 |
| `_options` | `MoveOptions` | このターンの画面に出す手（`user_options()` の結果。手ごとに行き先は1件） |
| `_hints` | `Array[ChoiceHint]` | ヒント。設定が OFF なら空 |
| `_selected_family` / `_selected_action` | `GameEnums.ChoiceFamily` / `int` | 選んだ手 |
| `_selected_target` | `String` | 選んだ手の行き先のキー（`"M2-C"` など）。未選択・行き先の無い手なら空文字 |
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

1. `_options = user_options()`。`App.user_data.settings().show_hints` が真なら `_hints = user_hints()`、偽なら空
2. `ChoicePanel.show_options(_options, snapshot.turn_kind, snapshot.user_has_ball)`。選べる手だけを枠の並びで並べ、
   各ボタンは「番号と行動の名前」だけ（例「① ショートパス」。2026-11-05）で、2列に並べてスクロールせずに選べる（`screen-common.md` §5 の `ChoicePanel`）。
   自分の手の行き先を `TacticsBoard.set_selectable(行き先の一覧)` で枠にし、`set_hints({行き先: 札})` で手の番号の札を出す
   （ヒントが ON なら `① +1` のように人数差を添える。同じ行き先の手が複数あれば番号を並べる。相手の手の行き先は出さない）
3. `TacticsBoard.clear_overlays()`、`RevealBanner`・`JudgeTelop` を隠し、`PhaseTag`・`ChoicePanel` を出す。`PossessionLabel` をそのターンの保持で描き直す。`SetupCard` を描き直す。「詳細」（`DetailButton`）を押せなくし、詳細のポップアップを閉じる
4. `PrimaryButton` の要約を空、操作を「LOCK IN」にして押せなくする。`_state = SELECT_ACTION`
5. `snapshot.turn_number` が 1（前半・後半のキックオフ）なら、笛を鳴らす（`Sfx.play(WHISTLE)`。再開した試合の1ターン目でも鳴らす。
   得点後の再開では鳴らさない。2026-10-30 の効果音の作業。鳴らすのは `MatchScreen` で、チュートリアルでは鳴らさない）
6. `PhaseBanner.follow(局面)`（局面は `MatchTexts.user_phase`。攻撃・守備・ネガトラ・ポジトラ）。前のターンと変わっていれば局面の帯を出し、
   変わらなければ消す（見出し「NEG. TRANSITION」・一言「ネガティブトランジション ― ボールを失った」など。`MatchTexts.phase_banner_title`・`phase_banner_line`）。
   前の局面は帯が覚え、`enter` で忘れる（`forget()`）。試合画面を開いた最初のターン（前半・後半・得点後のキックオフ、中断からの再開）は
   比べる前のターンが無いので出さない。帯は 1.2 秒で消え、その間も手は選べる（読み合いの手の選択を待たせない）。
   2026-11-07 にシャビの依頼で足した（案を3つ見せて、中継のテロップの帯に決めた）。2026-11-08 にチュートリアル（S-08）にも出した

### 手のボタンを押す（`ChoicePanel.action_selected`）

1. `_state` が `SELECT_ACTION`・`READY` のときだけ受け付ける
2. `_selected_family`・`_selected_action` を記録し、`_selected_target` をその手の行き先（`_options` の1件。行き先の無い手は空）にする
3. 行き先を塗り（`TacticsBoard.set_selected`）、ボールを運ぶ手（攻撃・カウンター）なら `TacticsBoard.show_intent(ボールのエリア, 行き先)` で
   ボールから行き先への矢印を描く。守備の手では描かない（行き先は守る位置で、ボールはそこへ動かない）。
   `MatchController.user_preview_frames(手)` の配置の並び（ターン開始時・次のターン開始時。2026-11-06 に判定時を外して1拍にした）を `TacticsBoard.show_preview_motion` に
   渡し、自分の選手全員の手の動きと詰め直しを半透明の駒でくり返し見せる（決定前のプレビュー。自分の選手だけ。相手の駒は動かさない。
   2026-11-05。時間は bind で `set_preview_style(match_controller.preview_style())`）。決定で `show_preview_motion([])` にする（結果の盤面を出すときも消える）
4. 詳細のポップアップの中身を作り、「詳細」を押せるようにする（ボタンの下には説明を出さない。2026-11-05）
5. `_state = READY`、「決定」を押せるようにする。決定ボタンの要約を「→ 中盤（敵陣）・中央」の形にする（`MatchTexts.button_summary`。2026-11-06）

### 「詳細」を押す（`DetailButton`。2026-11-05）

1. `_state` が `READY` のときだけ受け付ける
2. 詳細のポップアップ（`MoveDetailView`。`ModalOverlay` の上に、見出しと説明と「閉じる」）を開く。見出しは押したボタンと同じ番号と名前で、
   中身の手が違えば添える（例「① ショートパス（スルーパス）」）。説明は次の行（空の行は出さない）:
   1. 行き先（例「行き先: 敵陣・中央」。守備は「守る位置: 中盤（自陣）・中央」）
   2. 判断材料（ヒントが ON のとき。例「判断材料: +1　1対0」。札も人数も無い手（バックパス）は出さない。行き先の無い手は「比べる人数 2対4」）
   3. 手の説明（`MatchTexts.target_rule`。スルーパス・バックパス・守備の手。誰が動くか・何を読む手か）
3. 「閉じる」か戻る操作で閉じ、フォーカスを「詳細」に戻す。選んだ手はそのまま。戻る操作は、メニューが開いていなければメニューより先に詳細を閉じる
4. 開いたままメニューの設定でヒントを切り替えたら、判断材料の行を新しい設定で出し直す

### 行き先のエリアを押す（`TacticsBoard.area_pressed`）

1. `_state` が `SELECT_ACTION`・`READY` で、押したエリアが自分の手の行き先のときだけ受け付ける（それ以外は何もしない）
2. そのエリアを行き先にする手（同じ行き先の手が複数あれば、ボタンの並びで先の手）を選ぶ（「手のボタンを押す」と同じ）

### 「決定」を押す

1. `_state = SUBMITTING`。手のボタン・ボード・「決定」・メニューを押せなくする。決定前のプレビューを消す
2. `TurnChoice` を作る（`family`・`action`・`target`。`target` は利用者の視点のエリア。運ぶ先を持たない手は `null`）
3. `submit_turn(choice)` を呼ぶ
   - `false` なら「ターンを始める」をやり直す（選択を捨てて手のボタンを描き直す）。通知は出さない
     （通常は起きない。`component-design.md` §3.2「選択不可の手」）
   - `true` なら、同じ呼び出しの中で `turn_resolved` が届く（次節）

### 開示（`turn_resolved(reveal, snapshot)`）

1. `_reveal = reveal`、`_snapshot = snapshot`。`PhaseTag` を隠し、`RevealBanner` に「● …／◆ …」（両者の手の名前。`MatchScreen.reveal_line`。2026-11-06）を出す。局面の帯が残っていれば消す（`PhaseBanner.dismiss()`。2026-11-07）
2. `ChoicePanel`・「詳細」を隠し、詳細のポップアップを閉じる
3. `TacticsBoard.show_snapshot(_snapshot)`（次のターン開始時の盤面）の後に、`start_shift` で駒とボールを1拍で動かす（2026-11-03 に2拍にし、2026-11-06 に1拍に戻した）。
   判定前（`reveal.*_players_before`・`reveal.ball_before`）→ 次のターン開始時（いまの盤面）を
   `match_controller.board_play_sec()` 秒。位置が変わった全選手を動かす（手で動いた選手も、方式でずれた選手も）。
   得点だけは判定時（`reveal.*_players_at_judgement`・`reveal.ball_after`）も渡して2拍にし、シュートの後に、判定時 → キックオフの
   配置を `match_controller.board_settle_sec()` 秒で動かす（拍の組み立ては `MatchBoardPanel.reveal_keyframes`。2026-11-06）。
   2拍目は止めずに続けて動かす（2026-11-07〜11-26 は、得点のカットインが終わるまで2拍目を待たせていた）。ボールは、ボールを持つ側の手
   （`BallFlight.holder_choice(reveal)`）の軌道 `BallFlight.kind_for(...)` で動かす（2026-11-03）。軌道の高さの値は、
   `bind` で `TacticsBoard.set_ball_style(match_controller.ball_style())` として入れる。駒の動き（ずらし・弾み）と拍の間の
   小休止も、`bind` で `set_piece_style(match_controller.piece_style())`・`set_beat_gap_sec(match_controller.board_beat_gap_sec())`
   として入れる（2026-11-05。小休止は 2026-11-06 から、2拍になる得点のときだけ効く）。
   `show_movements(reveal.movements)` で矢印を描き、`show_compare(reveal.compare_area, reveal.user_count, reveal.opponent_count)` で
   比較エリアを光らせて人数の札（`1対0`）を出す
4. 上部バーのスコアと `PossessionLabel`（判定後の保持）を `_snapshot` で描き直す（`result_shown`）。`JudgeTelop` に結果（`OutcomeTag`。例 `● ADVANCE 前進`。成功した側を色と記号で示す: 保持側（攻撃側・奪った側）の成功は前進・得点・奪回失敗、相手側の成功は膠着・ロスト・シュート阻止・奪回成功・オフサイド（2026-10-25）、判定なしはどちらでもない。`MatchTexts.turn_winner`。2026-10-24）と判定理由（`JudgeReasonFormatter`）、判定の内訳（`JudgeDetail`。`reveal.compare_area`・`user_count`・`opponent_count`・`cover`。`NO_CONTEST` では隠す）を出す。`reveal.simplification_ids` が
   空でなければ、該当する単純化の「実戦では」を `RealWorldNote` に出す（複数なら先頭の1件）。
   効果音（2026-10-30）: 得点なら、`turn_winner` が自分なら `GOAL_FOR`、相手なら `GOAL_AGAINST`。`_snapshot.is_half_over`（前半の終わり・
   試合の終わり）なら笛（`WHISTLE`）。両方に当たれば両方を鳴らす
5. `PrimaryButton` を「次のターンへ／NEXT」にする。`_state = SHOW_RESULT`

> 矢印はすぐ出し、「次へ」もすぐ押せる（待たせない）。**`JudgeTelop` は、拍の着地（`TacticsBoard.play_landed`）で出す**
> （2026-11-03。手順 4 の中身は開示の瞬間に作っておき、隠しておく。動きが無ければすぐ出る。動きを途中で止めても出し忘れない。
> 「ターンを始める」で待つのをやめるので、次のターンの後に前のテロップは出ない）。着地のときに、盤面に結果の演出
> （`ResultEffect.for_reveal(reveal)` を `start_shift` の2つ目の引数で渡す。時間は bind で `set_result_sec(match_controller.board_result_sec())`）を出す。
> **カットインは出さない**（2026-11-27）: 2026-11-07 に得点の、2026-11-08 にボールを奪った・キーパーが止めたときの3Dのカットインを
> 拍の着地で盤面の上に重ねていたが、Android の端末で動かなかったため外した（シャビ判断）。着地で出すのはテロップと結果の演出だけ。
> カットインを出した次のターンで局面の帯を出さない扱いも外し、局面が変われば毎回帯を出す（「ターンを始める」6.）。
> 方式の選び直し・ハーフタイムの後と試合の最初は
> 「ターンを始める」だけを通るので動かさない。2026-10-23 に、3D 演出（`REPLAYING`・`ReplayStage`・「スキップ」・演出の終了）から置き換えた。

### 「次へ」を押す

1. `_state = LEAVING`。`PrimaryButton` を押せなくする
2. `continue_after_reveal()` を呼ぶ
   - 進行段階が `TURN` のままなら `state_changed` が届く → 「ターンを始める」
   - それ以外は `App.screen_requested` で `MainShell` が画面を入れ替え、`exit` が呼ばれる

### メニュー

1. 「≡」を押す（`SELECT_ACTION`・`READY`・`SHOW_RESULT` のときだけ押せる。ただし試合を終えた後の
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
| `SELECT_ACTION`・`READY`・`SHOW_RESULT` | メニューを開く（試合を終えた後の `SHOW_RESULT` は開かない） |
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
| 選べる手が1つもない | 起きない（トランジションの手は常に選べ、守備の手も、守備側に選手がいればパスコースを切るが残る。`functional-overview.md` アルゴリズム3）。起きた場合は開発時の誤りとして `assert` で止める |

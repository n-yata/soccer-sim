# 設計

要求は [requirements.md](./requirements.md)。画面ごとの正本は `docs/specs/3_detail-design/screen/screen-03-match.md`〜
`screen-06-result.md`・`screen-common.md`。本書は、今回の範囲（3D 演出・メニュー・保存・解説を除く）での作り方と、
正本から外す点を書く。

## 全体の流れ

```
S-01 ──CPU 対戦──▶ S-02 ──start_match()──▶ (MatchController が S-03 を要求)
S-03: start_turn → 手・エリア → 決定(submit_turn) → turn_resolved → SHOW_RESULT → 次へ(continue_after_reveal)
      ├─ TURN のまま: state_changed → start_turn
      ├─ 得点: S-04 ──submit_style_change()──▶ (S-03 を要求)
      ├─ 前半終了: S-05 ──submit_halftime()──▶ (S-03 を要求)
      └─ 後半終了: S-06 ──leave_result()──▶ (S-01 を要求)
```

画面の切り替えは、試合の中ではすべて `MatchController` が要求する（各画面の詳細設計のとおり）。画面は
`App.request_screen` を直接呼ばない（S-02 の「戻る」・S-01 のカードなど、試合の外の遷移は今までどおり）。

## 1. `MatchController` の追加（application）

- `start_match`・`submit_style_change`・`submit_halftime` が成功したら、`state_changed` の後に
  `_request_screen.call(S03_MATCH, {})`。失敗（`false`）のときは要求しない。
- `leave_result() -> bool`: 試合が終わっていなければ `push_error` して `false`。終わっていれば S-01 を要求して `true`。
  終了処理（戦績・中断データの削除）は、保存・戦績の作業で足す。
- 既存のテストの、画面の要求の並びの期待値を直す（S-03 の要求が加わる）。

## 2. 表示の文言（ui/common）

### `MatchTexts`（`ui/common/match_texts.gd`。static）
画面の文言を1か所に集める。エリアは利用者の視点のキー（`BoardSnapshot`・`RevealView` の値）を受ける。

| 関数 | 例 |
|---|---|
| `area_name(key)` | `"M-L1"` → `中盤・左HS`。ゾーン: 自陣・中盤・敵陣（`D`・`M`・`A`）。レーン: 左大外・左HS・中央・右HS・右大外（HS = ハーフスペース。glossary の略語） |
| `lane_name(lane)` | ボードのレーン名（左大外 など） |
| `action_name(family, action)` | ショートパス・ドリブル・背後へのロングボール・サイドチェンジ・シュート／プレス・カバー／即時奪回・リトリート／カウンター・保持 |
| `choice_summary(choice)` | `ショートパス → 中盤・中央`。運ぶ先が無ければ手の名前だけ |
| `phase_tag(turn_kind, user_has_ball)` | `ATTACK 攻撃`・`DEFENSE 守備`・`POS.TRANSITION ポジティブトランジション`・`NEG.TRANSITION ネガティブトランジション` |
| `outcome_label(outcome)` | `ADVANCE 前進`・`STALL 膠着`・`LOSS ロスト`・`GOAL 得点`・`SAVE シュート阻止`・`REGAIN 奪回成功`・`REGAIN_FAILED 奪回失敗`・`NO_CONTEST 判定なし`（`functional-overview.md` の区分値の日本語） |
| `setup_text(setup)` | `4-3-3 ゾーン・カウンター型` |
| `hint_tag(hint)` | `+1`・`±0 GK外`・`−1`（人数差 = `own_count − opponent_count`。カバーは同数のときだけ添える（同数のときだけ判定に効くため）。`CoverKind`: DEFENDER → `カバーあり`、GOALKEEPER → `GK`、OUT_OF_GK_REACH → `GK外`、NONE → なし。人数を比べない手は空） |
| `clock_text(snapshot)` | `前半 5／12`・`後半 12／12` |

### `JudgeReasonFormatter`（`ui/common/judge_reason_formatter.gd`。static）
- `format(reveal) -> String`: `{エリア名}で {自分}対{相手}。{原因}{結果}`
  - 人数は `user_count`・`opponent_count`（利用者から見た順。表示仕様「`自分 対 相手`」）。
  - 原因は、利用者から見た人数の大小で決める: 多ければ `こちらが数的優位で`、少なければ `相手が数的優位で`、
    同数なら `cover` による（DEFENDER: `同数で背後にカバーがいて`、GOALKEEPER: `同数でGKがカバーして`、
    OUT_OF_GK_REACH: `同数でGKのカバーが届かず`、NONE: `同数でカバーがいなくて`）。
    - 当初は「判定した側から見た数的優位／数的不利」としたが、即時奪回（比べるのは喪失側）などで、主語が無いと
      どちらの優位か読めないため、利用者から見た主語つきにした（実装時に変更）。
    - 人数が違うときにカバーを文に入れないのは、カバーが判定に効くのは同数のときだけだから（アルゴリズム5）。
      カバーの有無は、判定の内訳（`detail`）で常に示す。
  - 結果は `MatchTexts.outcome_label` の日本語（例: `前進`）。
  - 例: `中盤・中央で 1対0。こちらが数的優位で前進`、`敵陣・中央で 1対1。同数でGKがカバーして膠着`。
- `NO_CONTEST`（`has_detail` が偽）: `user_role` が POS_TRANSITION（奪取側）なら `判定なし（相手は撤退、こちらは保持）`、
  NEG_TRANSITION なら `判定なし（こちらは撤退、相手は保持）`。
- `detail(reveal) -> String`: `比較エリア 中盤・中央／● 自分 1 対 0 相手 ◆／カバー なし`（`has_detail` が偽なら空）。
- 文の言い回しはアルゴリズム9（解説）の作業で差し替える前提の、基本の文。

## 3. 部品（ui/board2d・ui/common）

### `TacticsBoard`（`ui/board2d/tactics_board.gd`。`Control`、`_draw` で描く）
- 外から: `show_snapshot(snapshot)`・`set_selectable(keys)`・`set_selected(key)`・`set_hints(dict)`・
  `show_intent(from_key, to_key)`・`show_movements(movements)`・`show_compare(key, user_count, opponent_count)`・
  `clear_overlays()`。シグナル `area_pressed(area_key)`。
- エリアの位置: ゾーンを列（左から D・M・A）、レーンを行（上から L2〜R2）。各エリアは `size / (3, 5)`。
  `area_at(position) -> String` と `area_rect(key) -> Rect2` を公開する（描画・入力・テストで同じ計算を使う）。
- 押す操作: `gui_input` の左ボタンを押した位置のエリアを覚え、離した位置が同じエリアのときだけ、そのエリアが
  選べるエリアなら `area_pressed` を出す（`screen-common.md` §4.1。選べないエリアは反応しない）。
- 描く内容（`screen-common.md` §5）: ピッチと芝目・ハーフスペースのレーン・白線・ペナルティエリア・ゴール、
  15エリアの点線とレーン名、駒（自分 ● を左半分、相手 ◆ を右半分。背番号。上端 32px は記号と札の帯。2列×2段、
  5人以上は3つと `+N`）、角の優劣記号、選べるエリアの点線の枠、選んだエリアの塗り、ヒントの札、意図の矢印、
  動きの矢印（DRIBBLE = `accent` の太線、PRESS・COVER = チームの色の実線、それ以外 = 白の点線）と凡例、
  比較エリアの光と人数の札（描く順は ⑥矢印 → ⑦比較。凡例の「寄せ・カバー」は両チームの色を並べる）。
- テストのための読み出し: `pieces_in(key) -> Dictionary`（`{"user": [背番号], "opponent": [背番号]}`）、
  `mark_of(key) -> String`（`▲`・`＝`・`▼`）、`selectable_areas()`・`selected_area()`・`hint_of(key)`・
  `compare_tag() -> String`・`movement_count()`・`has_intent()`。描画もこの値から行う。
- 色はテーマの型 `TacticsBoard` に置く（`app_theme.tres` に足す。`screen-common.md` §3 の写し）。

### `ChoicePanel`（`ui/board2d/choice_panel.gd`。`GridContainer` 2列）
- `show_options(options, turn_kind, user_has_ball)`: 局面の手を enum の順に2列のボタンで並べる（高さ 96px）。
  選べない手は `disabled` にし、手の名前の次の行に `選択不可` を添える（色だけで示さない）。
  - 2列の幅（約 220px）に「背後へのロングボール（選択不可）」が1行で入らないため、改行して添え、長い名前はボタンの
    中で折り返す（左右の余白を詰めたテーマの型 `ChoiceButton`、24px）。
  - 詳細設計の「5つ目（シュート）は列の幅いっぱい」は、`GridContainer` で1マスを広げられないため、今は2列の1マスにする
    （押せる大きさは 96px 以上を保つ）。
- 運ぶ先を持たない手を選んだときの説明（`TargetInfo`）は `比べる人数 2対4`（人数を比べない手は出さない）。
- `has_available()`: 選べる手が1つ以上あるか。`MatchBoardPanel.start_turn` が、無ければ `assert` で止める
  （`screen-03-match.md`「例外・エラー表示」）。
- `select_action(family, action)`: 選んだ印（押した状態）を付ける。`set_enabled(bool)`。
- シグナル `action_selected(family, action)`。

### `ScoreBug`（`ui/common/score_bug.gd`。子のラベルはコードで組む）
- `show_snapshot(snapshot, clock_override: String = "")`: `● YOU`・`1 – 0`・`CPU ◆`・時計（`MatchTexts.clock_text`）。

### `MatchBoardPanel`（`ui/board2d/match_board_panel.gd`。子のノードはコードで組む）
- 詳細設計は `.tscn` を置く構成だが、今回の部品（`TacticsBoard`・`ChoicePanel`・`ScoreBug`・`MatchBoardPanel`・
  `StylePicker`・`MatchScreenLayout`）はすべてコードで組み、画面（S-03〜S-06）の `.tscn` はルートとスクリプトだけにした。
  ノード名は詳細設計に合わせ、テストは名前で引く。3D 演出（`ReplayLayer`）を足すときに `.tscn` へ移すかを見直す。
- 左に `TacticsBoard`、右に操作の列（`SetupCard`・`ChoicePanel`・`TargetInfo`・`JudgeTelop`・`PrimaryButton`）。
- `bind(controller)`（1回だけ。`turn_resolved` をつなぐ）・`unbind()`（`exit` で切る）・`start_turn()`。
- シグナル: `turn_ready_to_leave`・`turn_started(snapshot)`・`reveal_started(reveal)`・`result_shown(snapshot)`。
- 状態: `SELECT_ACTION`・`SELECT_TARGET`・`READY`・`SUBMITTING`・`SHOW_RESULT`・`LEAVING`（`REPLAYING` は 3D 演出の作業で足す。
  今は `turn_resolved` を受けたら、`reveal_started` を出してから、すぐ「演出の終了」の手順に進む）。
- ヒントは常に ON（`user_hints()` を呼ぶ）。設定の作業で `App.user_data.settings().show_hints` に替える。
- 手の選択・エリア・決定・開示・次へは `screen-03-match.md` の手順どおり。`state()` で状態を読める（テスト用）。

## 4. 画面

| 画面 | シーン | 作るもの |
|---|---|---|
| S-03 | `ui/screens/s03_match/match_screen.tscn`（`MatchScreen`） | 上部バー（`ScoreBug`・`PhaseTag`・`RevealBanner`）＋`MatchBoardPanel`。`enter` で `state_changed` をつなぎ、`bind`→描画→`start_turn`。`state_changed` を受けて段階が `TURN` なら `start_turn`。`turn_ready_to_leave` で `continue_after_reveal()`。`handle_back` は `true` を返すだけ |
| S-04 | `ui/screens/s04_style_change/style_change_screen.tscn`（`StyleChangeScreen`） | `ScoreBug`、`GoalBanner`（`GOAL` タグと「あなたが得点しました」/「CPU が得点しました」）、`OpponentSetupLabel`、方式の2択（初期値は現在の方式）、`KickOffButton`。状態 `EDITING`・`SUBMITTING` |
| S-05 | `ui/screens/s05_halftime/halftime_screen.tscn`（`HalftimeScreen`） | `ScoreBug`（時計 `HT`）、`HalftimeBanner`、`OpponentSetupLabel`、陣形の4カード（`FormationCard` の compact 版）、方式の2択、`SecondHalfButton`。初期値は前半の陣形・方式。状態 `EDITING`・`SUBMITTING` |
| S-06 | `ui/screens/s06_result/result_screen.tscn`（`ResultScreen`） | `FullTimeTag`、`OutcomeLabel`（勝ち／引き分け／負け）、`ScoreBug`（時計 `FT`）、`TitleButton` → `leave_result()`。状態 `IDLE`・`LEAVING`。戻る操作は「タイトルへ」と同じ |

- 試合中の画面（S-03〜S-05）の戻る操作は、メニューが無い間は何もせず `true`（アプリを閉じない）。
- メニューの「≡」の置き場は空けておく（上部バーの左端に置かない。メニューの作業で足す）。
- S-04・S-05 の解説（`NotesView`）・噛み合わせのミニピッチ、S-06 の推移・「振り返り」は今回は置かない。

### S-02 の試合開始
- 状態 `STARTING` を足す。開始ボタン → `STARTING`、`TeamSetup` を作って `App.match_controller.start_match(setup)`。
  `false`（陣形が無い。開発時の誤り）なら `READY` に戻す。`STARTING` 中の戻る操作は何もしない（`true`）。

### `FormationCard` の compact 版
- `compact` が真なら、ミニピッチを隠し、陣形名と ✓ だけにする（S-05。`screen-common.md` §5）。

### `MainShell.SCREEN_SCENES`
- S-03〜S-06 を足す。タイトルの「CPU 対戦」と S-02 の開始ボタンは、既存の仕組み（`has_screen`）でそのまま押せるようになる。

## テスト戦略

- **単体**: `MatchTexts`（15エリアの名前が一意・各手・各結果）、`JudgeReasonFormatter`（結果ごとの文と NO_CONTEST の2通り）。
- **部品**: `TacticsBoard`（駒の数と背番号が snapshot と一致、記号、エリアの位置の計算、選べないエリアを押しても出ない、
  押して外で離すと出ない）、`ChoicePanel`（選べない手、シグナル）、`ScoreBug`。
- **画面**: `MatchBoardPanel`・`MatchScreen`（状態ごとの押せるもの、二度押し、開示の後のスコア、比較の札、ターンごとのリセット、
  利用者が守備のときの向き）、S-04・S-05（初期値・確定で S-03・二度押し）、S-06（勝敗3通り・タイトルへ）、
  S-02（開始で `start_match` と S-03 の要求・二度押し）。
  - `App.match_controller` を、固定シードの乱数で作った `MatchController` に差し替える（テスト後に戻す）。
- **通しの試合**: `MainShell` を作り、S-01 から画面のボタンの `pressed` とボードの `area_pressed`（または入力イベント）で
  S-06 → S-01 まで進める。画面の入れ替えは次のフレームで行われるので、操作ごとにフレームを待つ。得点と S-04 を必ず
  通るシードを使う（テストの中で、S-04 を通ったことを確かめる）。
- 変異: 状態のガード（SUBMITTING・LEAVING）、選べないエリア、S-03 の要求、スコアの更新の時期、勝敗の判定。

## 設計書の更新
- `component-design.md` §3.2: `leave_result` と、S-03 の要求を足した注記。§5: `MatchTexts` を足す。
- `screen-03-match.md` などには、今回外した部分（3D 演出・メニュー）を書き換えない（正本は完成形のまま）。
  外した点は、各スクリプトの冒頭の注記とこの設計に書く。
- `repository-structure.md`: `ui/board2d/` の行が無ければ足す。

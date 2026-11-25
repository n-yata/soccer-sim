# 設計書

## アーキテクチャ概要

既存の3層（ドメイン → アプリケーション → UI）に沿う。ドメインは利用者を知らず viewer（`TeamSide`）から集計し、
アプリケーション層が利用者 = HOME として呼び、各ターンを `RevealView` に変換して UI に渡す。

```
TurnRecord[] ──ReviewAggregator.aggregate(records, HOME, N)──▶ ReviewSummary（ドメイン）
                                     MatchController.review() ─▶ ReviewView（goals の各ターン = RevealView）
                                                                    └▶ ReviewScreen（4タブ）
```

## コンポーネント設計

### 1. ドメイン `domain/review/review_aggregator.gd`（`ReviewAggregator`）

- `aggregate(records, viewer, lookback_turns) -> ReviewSummary`
- `tally_of(outcome, viewer_is_attacker) -> JudgeTally`・`phase_of(record, viewer) -> Phase` も公開（表のテストを直接書くため）
- エリア: `judge.compare_area`（攻撃側の視点）を、viewer が攻撃側でなければ `mirrored()`。`EXCLUDED` はエリアにも局面にも数えない
- 得失点: 記録の順に GOAL の累計スコアを数え、そのハーフの直前の得点（なければハーフの初め）より後で、最大 N ターン前まで
- 時間帯: `half` と両者の `TeamSetup`（陣形・守備・攻撃の方式）が直前の記録と同じなら同じ時間帯

### 2. ドメインの値 `ReviewSummary`・`ReviewGoal`・`ReviewSegment`

- `ReviewSummary`（`domain/review_summary.gd`）: `area_tallies`（エリアのキー → `[勝, 負, 膠着]`）、
  `phase_tallies`（`Phase` → `[勝, 負, 膠着]`。4局面とも必ず入る）、`goals: Array[ReviewGoal]`、
  `segments: Array[ReviewSegment]`、`turn_count`。数の配列は `JudgeTally` の WIN・LOSE・STALL の位置
- `ReviewGoal`（`domain/review_goal.gd`）: `seq`・`half`・`turn_number`・`scorer`・`home_score`・`away_score`（得点後）・
  `lead_up_seqs`（直前のターンの通し番号。古い順）
- `ReviewSegment`（`domain/review_segment.gd`）: `half`・`from_turn`・`to_turn`・`home_setup`・`away_setup`
- 内部クラスは使わない（既存の値オブジェクトと同じく1ファイル1クラス）

### 3. アプリケーション `ReviewView`・`MatchController.review()`

- `ReviewView`（`application/review_view.gd`）: `area_tallies`・`phase_tallies`（写し）、`goals`（各要素
  `{"is_user", "half", "turn_number", "score_user", "score_opponent", "turns": Array[RevealView]}`。turns は直前のターン → 得点のターンの順）、
  `segments`（各要素 `{"half", "from_turn", "to_turn", "user_setup", "opponent_setup"}`）、`turn_count`
- `RevealView` に `half`・`turn_number` を足す（振り返りの各ターンの見出し。開示では使わない）。`ViewConverter.reveal` が入れる
- `review()` は試合前なら push_error して null。遡るターン数は `_config.presentation().review_lookback_turns`

### 4. 設定値 `PresentationConfig.review_lookback_turns`

- 初期値 3（functional-overview.md の表）。範囲は 0 以上（component-design.md §4.2）。範囲外は初期値の Resource に戻す（既存の `board_shift_sec` と同じ扱い）

### 5. UI

- `TacticsBoard.show_tally(tally: Dictionary)`（エリアのキー → 札の文）。駒・ボールを出さない集計表示として、
  エリアの中央に札を描く。`drawn_tally_keys()` で描くキーを問い合わせられる（テスト・描画が同じ問い合わせを通る）。
  札の描き方はヒントの札（`_draw_hint`）と共通化する
- `MiniPitch`: 2チーム表示（`show_counts(counts, true)` を、利用者 ● と相手 ◆ の人数に拡張）と動きの矢印を足す。
  振り返りでは `show_turn(user_counts, opponent_counts, movements)` を使い、マスを大きくする（`cell_size` を引数で変えられるようにする）。
  矢印は作戦ボードと同じ理由（`TacticsBoard.DRAWN_REASONS`）のものだけ
- `ReviewScreen`（`ui/screens/s07_review/`）: ヘッダー（ScreenHeader）＋ TabBar ＋ 4ページ。ノードはコードで組む（S-06 と同じ流儀）が、
  ヘッダーは `screen_header.tscn` を tscn でインスタンス化する（S-02 と同じ）
- 札の文: `ReviewTexts`（`ui/common/review_texts.gd`）に「勝3 負1 膠1」・時間帯の文・得点の見出しを置く（テストしやすい純関数）
- `ResultScreen`: 「振り返り」ボタンを主ボタン（タイトルへ）の上に足す。`LEAVING` では押せない
- `MainShell.SCREEN_SCENES` に S-07 を足す

## データフロー

### 振り返りを開く
```
1. S-06 で「振り返り」→ App.request_screen(S07_REVIEW)
2. ReviewScreen.enter → App.match_controller.review()
3. ReviewView から 4ページを描く（得失点は最初の得点を選んだ状態）
4. 戻る → App.request_screen(S06_RESULT)
```

## エラーハンドリング戦略

- 試合前の `review()` は UI の誤り: push_error して null。画面は null・`turn_count == 0` を「振り返りのデータがありません」として出す
- 設定値の範囲外: 初期値に戻して push_error（既存と同じ）

## テスト戦略

### ユニットテスト
- `ReviewAggregator`: 数え方の表の全行・局面・エリアの鏡像・得失点の遡り（上限・ハーフの境・続けての得点・1ターン目）・時間帯（同じ設定の連続・ハーフの境・途中の方式変更）・NO_CONTEST だけ・0件
- `ConfigRepository`: 遡るターン数の範囲外 → 初期値、同梱の値が範囲内
- `MatchController.review()`: 試合前 null、終わった試合で集計と `ViewConverter.reveal` が一致
- `ReviewTexts`: 文の形
- `TacticsBoard.show_tally`・`MiniPitch` の2チーム表示

### 画面テスト
- `ReviewScreen`: 固定シードの終わった試合で開く（タブ・札・局面の行・得点のカード・戻る）。得点の無い試合の文・データ無しの文
- `ResultScreen`: 振り返りボタンで S-07 を頼む、LEAVING では押せない

## ディレクトリ構造

```
game/domain/review/review_aggregator.gd        新規
game/domain/review_summary.gd                  新規
game/domain/review_goal.gd                     新規
game/domain/review_segment.gd                  新規
game/domain/config/presentation_config.gd      変更（review_lookback_turns）
game/config/presentation_config.tres           変更
game/data/config_repository.gd                 変更（範囲の確認）
game/application/review_view.gd                新規
game/application/reveal_view.gd                変更（half・turn_number）
game/application/view_converter.gd             変更（reveal に half・turn_number、review の変換）
game/application/match_controller.gd           変更（review()）
game/ui/board2d/tactics_board.gd・board_painter.gd  変更（show_tally）
game/ui/common/mini_pitch.gd                   変更（2チーム・矢印・cell_size）
game/ui/common/review_texts.gd                 新規
game/ui/screens/s07_review/review_screen.gd/.tscn  新規
game/ui/screens/s06_result/result_screen.gd    変更（振り返りボタン）
game/ui/main_shell.gd                          変更（S-07 の登録）
game/tests/...                                 各テスト
```

## 実装の順序

1. ドメイン（値 → 集計 → テスト）
2. 設定値
3. アプリケーション（RevealView・ReviewView・review()）
4. UI 部品（ReviewTexts・show_tally・MiniPitch）
5. 画面（ReviewScreen・ResultScreen・MainShell）
6. 全テスト・変異の確認・仕様書の更新

## セキュリティ考慮事項

- 外部通信・保存・入力の追加は無い。表示する文字列はすべてアプリ内の値から作る

## パフォーマンス考慮事項

- 集計はターン記録（1試合 30〜40件）を1回走査するだけ。画面を開くたびに集計してよい

## 将来の拡張性

- 「実戦では」は `RevealView.simplification_ids` が入れば、画面が `LibraryService.simplifications()` から引いて添える（単純化の作業）

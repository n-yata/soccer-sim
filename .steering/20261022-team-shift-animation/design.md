# 設計

## 方針

- ルールは変えない。開示のとき、駒を瞬間的に入れ替える代わりに、ターン前の位置から次のターン開始時の位置まで補間して見せる。
- 動きの元と先は、開示と一緒に届く値をそのまま使う。
  - 元: `RevealView.user_players_before` / `opponent_players_before`（ターン開始時の配置）。
  - 先: `BoardSnapshot.user_players` / `opponent_players`（次のターン開始時の配置）。
  - 選手は `player_id` で対応づける。新しいドメインの計算は無い。
- 動くのは盤面の駒だけ。判定理由のテロップ・動きの矢印・比較の札は、いまどおり開示と同時に出す。
  - 画面の状態は増やさない（SHOW_RESULT のまま）。「次へ」も押せる。
  - 理由: 動きは0.6秒ほどで、待たせる理由が無い。状態を増やすと、二度押しの防止などの確かめる経路が増える。

## 設定値: `PresentationConfig`（今回作る）

- `game/domain/config/presentation_config.gd` を作る。同梱の値は `game/config/presentation_config.tres`。
- 持つ値は `board_shift_sec: float = 0.6`（開示で駒を動かす時間。0 より大きく 2 以下。有限の値）。
  - 上限 2 秒: 毎ターン見る動きなので、長いとテンポが落ちる。初期値は上限から離しておく。
- 設計書にある3D演出の上限と、振り返りで遡るターン数は、それぞれの作業で足す。いま使わない値を先に置かない。
- 読み込みは `ConfigRepository.presentation()`。既存の値と同じく、読めない・型が違う・範囲外なら初期値に戻して push_error する。
- `MatchController.board_shift_sec() -> float` で UI に渡す。コントローラーは使うときに初めて `config.presentation()` を読む（実装で変更。試合を進めるだけの呼び出し側・テストに、表示の設定ファイルを求めないため）。

## UI

### TacticsBoard
- `start_shift(user_before: Array[Dictionary], opponent_before: Array[Dictionary], duration_sec: float)` を足す。
  - `show_snapshot` の後に呼ぶ。動きの先は、いま持っている盤面。
- `shift_paths() -> Array[Dictionary]` を足す。中身は `{"player_id", "is_user", "from": Vector2, "to": Vector2}`。
  - 駒の位置が変わった選手だけを入れる（元と先の駒の中心で比べる。エリアが同じでも、ほかの選手の出入りで列の位置が変われば入れる。実装レビューを受けて、エリアのキーで比べる形から変えた）。描画とテストで共有する。
  - 元に居ない選手（`player_id` が見つからない）は入れない。
- 駒の位置
  - 元は、元のエリアの自分の側の駒の列で、元の配置の選手の順の位置（`piece_center`。`MAX_PIECES - 1` で止める）。
  - 先も同じく、先のエリアで、今の盤面の選手の順の位置。
- 進み具合 `_shift_progress`（0〜1）は `Tween` で進め、`queue_redraw` する。
  - `duration_sec` が 0 以下なら、動かさずにすぐ終わる。
- 描画
  - 動いている間（`is_shifting()`）は、駒を選手ごとに `from.lerp(to, t)` の位置に描く。
    - 動かない選手は、先の位置。
    - 「+N」の札は、動いている間は出さない。
  - 動き終えたら、いまの描き方（エリアごとの列と「+N」）に戻る。
  - 動き終わりの位置は、いまの描き方の位置と一致する（どちらも `piece_center` の同じ添字）。
- 次の操作では止める。対象は `show_snapshot`・`clear_overlays`（`finish_shift()` は作らなかった。止める経路はこの2つで足り、外から止める呼び出し側が無いため）。
- 道筋は `start_shift` の時点の座標で持つ。動いている最大2秒の間に画面の大きさが変わると、その間だけずれた位置を通る（動き終えると通常の描き方に戻るので、直さない）。
  - 前のターンの動きが次のターンへ残らない。

### MatchBoardPanel
- `_on_turn_resolved` で、`show_snapshot(snapshot)` の後に `start_shift(reveal.user_players_before, reveal.opponent_players_before, _controller.board_shift_sec())` を呼ぶ。
- `start_turn` は `clear_overlays` と `show_snapshot` で動きを止める（既存の呼び出しのまま）。
  - 方式の選び直し・ハーフタイムの後と、試合の最初は、`start_turn` だけを通るので動かない。

### 得点のターン
- 得点では、次のターン開始時の配置はキックオフの配置になる。そのため、全員がキックオフの位置へ戻る動きになる。
- ターンの流れの中の動きなので、そのまま動かす（要求の「動かさない場面」は、方式の選び直し・ハーフタイムの画面を経た後のこと）。

## テスト
- `config_repository_test`
  - 同梱の値（0.6）。
  - 範囲外（0・負・2超・NaN・INF）は初期値に戻り、エラーを出す。
  - 境界（2.0）は受け付ける。
  - ファイルが無いときは初期値。
- `tactics_board_test`
  - 位置が変わった選手だけが動く。数が元と先の差と一致し、両チームを含む。
  - 元と先の位置が、駒の列の位置（元の配置の順・先の配置の順）と一致する。
  - 元に居ない選手は動かさない。
  - `show_snapshot`・`clear_overlays` で止まる。
  - 時間 0 なら動かない。
- `match_board_panel_test`
  - 開示で動きが始まる。動く選手の数が、`RevealView` の判定前と `BoardSnapshot` の差と一致する。
  - 次のターンで止まっている。
- `match_controller_test`: `board_shift_sec()` が設定の値を返す。

## 変更するドキュメント
- functional-overview.md（設定値の表に1行。表示仕様の「選手の動き」）
- component-design.md（§4.2 の PresentationConfig の今回の範囲、MatchController.board_shift_sec、§5.3）
- screen-03-match.md（開示）、screen-common.md（TacticsBoard）
- data-definition.md・repository-structure.md（該当があれば）

# 設計

## 拍を持つ `BoardShift`

いまの `BoardShift` は、駒の道筋・ボールの道筋・進み具合を1組だけ持つ。これを**拍の並び**にする。

- `beats: Array[Dictionary]`。各要素は `{"piece_paths": Array[Dictionary], "ball_path": Dictionary}`（道筋の形はいまと同じ）。
- `beat_index: int`（いま動かしている拍）と `progress: float`（その拍の中の進み具合 0〜1）。
- `start(beats)`: 駒もボールも動かない拍を取り除いてから入れる。残りが空なら動かない。
- `piece_position(player_id, rest)`:
  1. いまの拍に道筋があれば、その途中。
  2. 無ければ、**後の拍**で最初に出てくる道筋の `from`（まだ動いていない選手は、その拍の始まりの位置にいる）。
  3. それも無ければ `rest`（もう動き終えたか、動かない選手）。
  - 前の拍の `to` を見ないのは、前の拍の `to` と後の拍の `from` は同じ位置（判定時の配置）であり、後の拍にも出てこない選手は動き終わりの位置 = `rest` だから。
- `ball_position(rest)` も同じ考え方。
- `piece_paths` の問い合わせは、すべての拍の駒の道筋を合わせたもの（描画が「駒を選手ごとに描くか」を決めるのに使う）と、拍ごとのものを分ける。

## `TacticsBoard.start_shift`

```gdscript
func start_shift(user_before, opponent_before, ball_before: String,
		user_at_judgement, opponent_at_judgement, ball_at_judgement: String,
		play_sec: float, settle_sec: float) -> void
```

- 1拍目: before → at_judgement、2拍目: at_judgement → いまの盤面（`_user_players` 等）。
- 道筋は `BoardShift.paths` をそのまま使う（エリアの中の列の位置で比べる）。
- Tween は、残った拍ごとに `tween_callback(拍の番号を進める)` → `tween_method(進み具合, 0→1, その拍の長さ)` を順につなぐ。最後に `_stop_shift`。
- 長さが 0 以下の拍は動かさない（その拍を取り除く）。両方 0 以下なら動かさない。

## 調整値

- `PresentationConfig.board_shift_sec`（いまの値）は意味が「全体」から **2拍目（詰め直し）の長さ**に変わるので、`board_settle_sec` に改名する。`board_play_sec`（1拍目）を足す。初期値はどちらも 0.6 秒。範囲は既存と同じ（0 より大きく 2 以下。範囲外はデータ層が初期値に戻す）。範囲の上限の定数も `MAX_BOARD_BEAT_SEC` に改名する。
  - 当初は名前を残す計画だったが、実装レビューで「同じ型のまま意味だけ変わると、古い値が黙って使われる」（coding-common）と指摘され、改名に変えた。保存データではなく同梱の設定なので移行は要らない。同梱の .tres が新しいキーを持つことは、文字列でテストする（Godot は知らないキーを黙って無視するため）。
- `MatchController.board_play_sec()` を足し、`board_shift_sec()` を `board_settle_sec()` に改名する。

## `MatchBoardPanel`

`_on_turn_resolved` で、`reveal` の判定時の選手・`ball_after` と、2つの長さを渡す。

## テスト

- `tactics_board_test`
  - 1拍目の駒の道筋が before と at_judgement の差、2拍目が at_judgement といまの盤面の差。
  - 1拍目の途中で、2拍目だけで動く選手が判定時の位置に描かれる。
  - ボールの各拍の道筋。同じなら空。
  - 動きの無い拍が飛ばされる（拍の数）。
  - 時間の経過で止まり、いまの位置に描かれる。
  - 既存の `start_shift` の呼び出しを新しい引数に合わせる。
- `board_shift` の単体テストがあれば拍の位置の決め方を足す（無ければ `tactics_board_test` で足りる）。
- `config_repository_test`: `board_play_sec` の範囲外で初期値に戻る。
- `match_board_panel_test`: 開示で、拍の道筋が `RevealView` と `BoardSnapshot` に対応する。

## 変更するドキュメント

- functional-overview.md「設定値として外部化する値」（`board_play_sec`）
- component-design.md（`board_settle_sec` への改名・`board_play_sec()`・§5.3 の注記）
- screen-design.md（開示の動き）
- screen-common.md（`start_shift`）・screen-03-match.md（開示の呼び出し）
- usecase.md・usecase-sequences.drawio に記述があれば

# 設計

## 1. `MatchPositions` への分割
- 置き場: `game/domain/match/match_positions.gd`（`class_name MatchPositions`）。
- `MatchRules` から呼ぶ内部のクラス。アプリケーション層は呼ばない（入口は `MatchRules` のまま）。
- 移す処理（名前の先頭の `_` を外して公開する）:

| 移す前（MatchRules） | 移した後（MatchPositions） |
|---|---|
| `_kickoff` の中の、全員を基本エリアに置く処理 | `reset_to_base(state)` |
| `_release_fixes` | `release_fixes(state)` |
| `_store_players`・`_players_at` | `store_players(next, pair)`・`_players_at` |
| `_mark_moved` | `mark_moved(next, start)` |
| `_stop_dribble`・`_player_of` | `stop_dribble(next, state, output)`・`_player_of` |
| `_place_holder` | `place_holder(next, start)` |

- `MatchRules._kickoff` は、ボール・保持・局面の設定と `reset_to_base` の呼び出しを持つ。
- 結果: `match_rules.gd` 211行、`match_positions.gd` 121行。
- `component-design.md` §2.5 の決めごとに、分けたことを1行足す。

## 2. 一様な手の性質のテスト
- `one_step_movement_test.gd` の試合の回し方を `_check_matches(rng, choose)` にまとめ、手の選び方だけを Callable で差し替える。
  - CPU: `CpuPlanner.choose_turn`（既存）。
  - 一様: `MoveHints.evaluate(state, side, MoveRules.options_for(state, side))` の並び（運ぶ先ごとに1つ）から `randi_range` で選ぶ。
- 方式・陣形の選び直しは、どちらも CPU の選び方（確かめたいのはターン中の動き）。
- 一様の回し方では、選んだ手の種類（family と action の組）を数え、enum の大きさの和（11種類）と一致することを確かめる。
- `resolve_turn` が手を拒否したら、どのターンかを示して落とす。

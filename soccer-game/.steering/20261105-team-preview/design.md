# 設計

## ドメイン
- `MatchRules.preview_next(state: MatchState, output: JudgeOutput, holder_choice: TurnChoice) -> MatchState`（新規・公開）:
  `resolve_turn` の、判定の結果から次のターンの状態を作る部分（`_ball_after`・`_apply_outcome`・`mark_moved`・`place_holder`）
  だけを通す。ハーフの終わり・記録は扱わない（プレビューには要らない）。`resolve_turn` もこれを使う形にして、二重に持たない。
- `MovePreview.team_steps(state, side, choice) -> Array[LayoutPair]`（新規）: `[ターン開始時, 判定時, 次のターン開始時]`。
  次のターン開始時は `StyleLayoutCalculator.turn_start(preview_next(...))`。シュートとオフサイドになる手は判定時までの2つ。
  - 攻撃: `apply_attack` の後の配置に、結果を `ADVANCE` と仮定した `JudgeOutput`。
  - 守備: `apply_defense` の後の配置に、結果を `STALL` と仮定（ボールは動かない）。
  - トランジション: いまと同じ、相手を動かない手にした `TransitionJudge.judge` の結果。
- `own_movements` はいまの呼び出し（CPU のヒントなど）に残す。

## アプリケーション
- `MatchController.user_preview_frames(choice) -> Array`（新規）: 自分の選手の並び（`BoardSnapshot.user_players` と同じ形・利用者の視点）を、
  `team_steps` の配置の数だけ。選べない手・試合中でなければ空。`ViewConverter.user_players_of(pair, catalog, setup)` を足して使う。
- `MatchController.preview_style() -> Dictionary`（`{"move_sec", "hold_sec"}`。PresentationConfig）。

## UI
- `BoardPreviewLoop`（新規、ボードの子ノード。`board_preview_loop.gd`）: フレーム（選手の並び）の並びを受け取り、各区間を `move_sec`、
  最後に `hold_sec` 止めて、最初へ戻すのを Tween の loops でくり返す。区間の道筋は `BoardShift.paths`（駒の列の位置）で、
  駒の進み方は `PieceMotion.smooth`。問い合わせ: `ghost_centers() -> Array[Dictionary]`（`{"player_id", "plan"}`。動く駒だけ）。
- `TacticsBoard.show_preview_motion(frames: Array)`・`set_preview_style(style)`。`standing_order` は、動かしている半透明の駒を
  `is_preview` で並べる。`show_preview`（矢印と静止した半透明の駒）は使わなくなるので消す（関連の問い合わせ・描画・テストも）。
- `MatchBoardPanel`: 手を選んだら `show_preview_motion(_controller.user_preview_frames(choice))`、取り消し・決定で空にする。bind で
  `set_preview_style`。

## 調整値（`PresentationConfig`）
| 値 | 初期値 | 範囲 |
|---|---|---|
| `preview_move_sec`（プレビューの1区間を動く時間） | 0.6 秒 | 0 より大きく 2 以下 |
| `preview_hold_sec`（動き終えて止める時間） | 0.6 秒 | 0 以上 2 以下 |

## テスト（単体を細かく・結合は最低限）
- `move_preview_test`: `team_steps` の数と配置（攻撃・シュート・オフサイド・守備・トランジション）。
- `match_rules_test`: `preview_next` が `resolve_turn` と同じ次の状態を作る（同じ結果のとき）。
- `match_controller_test`: `user_preview_frames` の形と、選べない手で空。`preview_style`。
- `board_preview_loop_test`（新規）: 動く駒だけが道筋を持つ、区間の途中・止める間・くり返しの位置。
- `tactics_board_test`・`match_board_panel_test`: 半透明の駒の並べ方、選び直し・決定で替わる・消える。矢印を描かない。
- `config_repository_test`: 2つの値。

## 変更するドキュメント
- functional-overview.md（表示仕様「決定前のプレビュー」・設定値）、component-design.md、screen-common.md（TacticsBoard）、
  screen-03-match.md（プレビュー）、screen-design.md、repository-structure.md。docs/specs 全体を検索し .drawio も見る。

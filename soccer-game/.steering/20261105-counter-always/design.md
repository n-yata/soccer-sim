# 設計

- `MoveRules.pos_transition_options`: 味方のいる運ぶ先が無ければ、`zone + 1`・レーン差1以内のエリアを足す
- `TransitionJudge.carry_if_empty(pair, ball, target)`（新規）: 運ぶ先に奪取側がいなければ、`OpenPlayJudge.carry_ball`（`_dribble` と同じ）でボールを持つ選手を運ぶ。いれば何もしない。判定（カウンターの分岐）とヒント（`MoveHints._add_winner_hints`）で共有する
- 奪った後のボールの保持者は、運んだ選手が運ぶ先に固定されるので、前進ならそのまま。膠着・ロストのときは試合進行の保持者の配置（1マス以内）に任せる
- テスト: move_rules（運ぶ先の足し方）、transition_judge（運ぶ動きと判定、味方がいるときは動かない）、move_hints（運んだ後の人数）

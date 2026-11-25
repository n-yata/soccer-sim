# 設計

## 1. アディショナルタイム（ドメイン）
- `MatchRuleConfig.max_additional_turns`（初期値 5）を足す。`turns_per_half` の初期値を 15 にする。同梱の `.tres` も同じ値。
- `ConfigRepository` は `max_additional_turns >= 0` も確かめ、外れたら初期値に戻す（エラーの文に両方の値を出す）。
- ハーフを終えたかを `MatchRules._is_half_over(turn_number, last_record, rules)` で決める。状態に印は足さない（保存の形式を変えないため）。
  - `turn_number <= turns_per_half`: 続く。
  - `turn_number > turns_per_half + max_additional_turns`: 終える。
  - その間: 直前のターンの結果が `GOAL`・`SAVE`・`LOSS`・`REGAIN` なら終える。記録が無ければ終える（続いている攻撃が無い）。
- `resolve_turn` は、ターン番号を進めた後にこの判断で、ハーフタイム（前半）・試合終了（後半）に切り替える。保持者を置くのも、この判断で続くときだけ。
- `is_play_complete` は「後半で、ハーフを終えている」。`is_additional_time` を足す（時計の表示用）。

## 2. 時計（アプリケーション・UI）
- `BoardSnapshot.is_half_over`（ハーフタイム・試合終了の後の盤面か）を足す。`MatchController.snapshot` が段階と `is_match_over` から渡す。
- `MatchTexts.clock_text`: 表示するターン = ハーフを終えた後なら turn_number − 1、そうでなければ turn_number。規定を超えていれば「前半 15＋n」。

## 3. 結果の色分け（UI）
- `MatchTexts.TurnWinner { USER, OPPONENT, NONE }` と `turn_winner(reveal)`。
  - NO_CONTEST は NONE。
  - 保持側（`Phase.ATTACK`・`POS_TRANSITION`）の成功は ADVANCE・GOAL・REGAIN_FAILED。それ以外は相手側の成功。
- `MatchTexts.outcome_tag(reveal)`: 「● ADVANCE 前進」「◆ LOSS ロスト」。NONE は記号なし。
- テーマに `YouOutcomeTagLabel`・`OpponentOutcomeTagLabel`（`OutcomeTagLabel` を基に、地を `you`・`opponent` の色）を足す。文字は `bg` の色のまま（コントラスト 9.8・8.3）。
- `MatchBoardPanel` は開示で、札の文と `theme_type_variation`（`outcome_variation_for(winner)`）を替える。

## 4. 仕様書
- functional-overview（設定値の表・アルゴリズム7）、glossary（アディショナルタイム。「ハーフの最終ターン」はアディショナルタイムの最後のターンを指す）、requirements-definition（FR-07・FR-10・§7.1 #1）、component-design（§2.5・BoardSnapshot・MatchRuleConfig・値の範囲・件数の上限）、screen-design・screen-03・screen-01・screen-common（時計・札の色）、data-definition（turn_number・turn_records・timeline の範囲）、repository-structure、wireframes.drawio（時計の例）。

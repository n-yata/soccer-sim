# 設計

## 方針
- オフサイドの規則（ライン・受け手・判定）を新しいクラス `OffsideRule`（`game/domain/judge/offside_rule.gd`）に置き、判定（`OpenPlayJudge`）・ヒント（`MoveHints`）・盤面の表示（`ViewConverter`）が同じ規則を使う（規則を1か所に置き、表示と判定を食い違わせないため）。
- ターン結果 `OFFSIDE` を `TurnOutcome` の末尾に足す（既存の値の番号を変えない）。

## 規則（すべて攻撃側の視点の列番号 0〜5）
- `OffsideRule.line_row(defender: TeamLayout, ball: PitchArea) -> int`: 守備側の選手の今いるエリアを攻撃側の視点に写し、いちばん大きい列（守備側のゴールにいちばん近い列）。ボールの列がそれより前ならボールの列（実装レビューで、ボールと並んだスルーパスの受け手がオフサイドになる抜けを見つけ、実際のサッカーに合わせた）。ただし自陣の境（`OWN_HALF_ZONES - 1` = 2）より小さければ 2（自陣の受け手はオフサイドにならないため、実効のラインはハーフウェーライン）。守備側が0人なら 5（誰もオフサイドにならない）。
- `OffsideRule.receiver_area(pair, ball, attack) -> PitchArea`: 対象の手の受け手のエリア。スルーパスは `OpenPlayJudge.through_pass_runner` の今いるエリア（走り込む前）、ショートパス（運ぶ先がボールより前の列のときだけ）・ロングボールは運ぶ先。それ以外の手・横や後ろへのショートパスは null。
- `OffsideRule.is_offside(pair, ball, attack) -> bool`: 受け手のエリアがあり、その列が `line_row(pair.defender)` より大きい。
- 判定（`OpenPlayJudge.judge`）: 守備の手（と付け直し）を適用した後の配置で `is_offside` を見る。オフサイドなら攻撃の手を適用せず（プレーが止まる。スルーパスの受け手も走り込まない）、結果 `OFFSIDE`。内訳の比較エリアは受け手のエリア（人数はそこで数える。読み・カバーは無し）。
- 試合進行（`MatchRules`）:
  - `_ball_after`: `OFFSIDE` は内訳の比較エリア（受け手のいたエリア。攻撃側の視点）。
  - `_apply_outcome`: `OFFSIDE` は保持が入れ替わり（ボールは守備側の視点へ写す）、トランジションに入らず攻守ターン。固定を解く（プレーが止まり、配置区間が始まる）。
  - `_ends_attack`: `OFFSIDE` を足す（アディショナルタイムならハーフを終える）。

## ヒントと CPU
- `ChoiceHint.is_offside: bool`（既定 false）。`MoveHints._add_attack_hints` がターン開始の配置（守備の手の前）で `OffsideRule.is_offside` を入れる。
- `MatchTexts.hint_tag`: `is_offside` なら `オフサイド`（スルーパスの「読み次第」より先）。作戦ボードの札の幅に収まる5文字。
- `MatchBoardPanel`: オフサイドの札は控えめな色にしない。
- `CpuConfig.offside_penalty`（新しい調整値。初期値 3.0。0 以上）: `CpuPlanner.turn_probabilities` で、`is_offside` の手の値から引く。調整値なので .tres に置き、`ConfigRepository` で範囲を確かめる。

## 画面
- `BoardSnapshot.offside_line_zone: int`（利用者の視点の列。-1 なら描かない）。`ViewConverter.snapshot` が、攻守ターンで利用者が保持しているときだけ、ターン開始の相手の配置から `OffsideRule.line_row` を入れる。
- `TacticsBoard` が受け取り、`BoardPainter` がその列の上端（相手ゴール側の境界）に、相手チームの色の線を描く。テスト用に `offside_line_zone()` を出す。
- 結果: `MatchTexts.OUTCOME_WORDS` に「オフサイド」。`turn_winner` は守備側の成功（既存の分岐のまま）。
- 判定理由（`JudgeReasonFormatter`）: `OFFSIDE` は「{受け手のエリア}でオフサイド。受け手がラインより前にいた」。

## 測定
- `MatchBalanceProbe`: `OFFSIDE` をプレー中の入れ替わりに数え、オフサイドの回数を要約に出す。

## 仕様書
- functional-overview: 区分値 `TurnOutcome`、アルゴリズム5（手順にオフサイドを足す）、7（結果の反映・アディショナルタイム）、8（offside_penalty）、10（勝ち負けの表）、判定例 JE-10、表示仕様（ライン・札・判定理由）、設定値の表。
- glossary（オフサイド・オフサイドライン、`OFFSIDE`）、requirements-definition（FR-03・FR-05）、component-design（`OffsideRule`・`ChoiceHint`・`BoardSnapshot`・`CpuConfig`）、screen-design・screen-03。

## テスト
- offside_rule_test（新規）: ライン（最深の守備者・自陣の境・0人）、受け手（スルーパスは走り込む前・前へのショートパス・ロングボール・横や後ろは対象外）、境界（1列前・同じ列・自陣）。
- open_play_judge_test: 守備の手でラインが上がる・下がる、人数・読みより先、スルーパスの受け手が走らない、JE-10。
- match_rules_test: 守備側の攻守ターンで再開・固定が解ける・アディショナルタイムで終わる。
- move_hints_test・cpu_planner_test・config_repository_test・match_texts_test・judge_reason_formatter_test・view_converter_test・tactics_board_test。
- 変異: ラインの最深・自陣の境・境界（> と >=）・受け手の起点・前へのパスの判定・トランジションしない・固定を解く・アディショナルタイム・札・CPU。

# 設計

## 方針
- 規則は既存の場所に足す（新しいクラスは作らない）。運ぶ先の条件は `MoveRules`、受け手の選び方と判定は `OpenPlayJudge`。
- 受け手の選び方は1か所（`OpenPlayJudge.through_pass_runner`）に置き、`MoveRules`（選べるか）と `OpenPlayJudge.apply_attack`（動かす）が共有する。選べるかの判定と実際に動く選手がずれないため。

## 変更点

### ドメイン
- `GameEnums.PlayType`: `SHORT_PASS, DRIBBLE, THROUGH_PASS, LONG_BEHIND, SWITCH, SHOT`（手のボタンの並び順になる。保存データは enum の名前で持つので、位置がずれても読み方は変わらない。保存はまだ無い）。
- `GameEnums.MovementReason`: 末尾に `THROUGH_RUN`（受け手の走り込み）を足す。
- `MoveRules.attack_options`:
  - `SHOT`: `ball.zone == A2` かつ `ball.lane in [L1, C, R1]`（ペナルティエリア）。`_FINAL_ROWS_FIRST` は LONG_BEHIND 専用になる。
  - `THROUGH_PASS`: `1 <= target.zone - ball.zone <= 2` かつ `lane_gap <= 1` かつ `OpenPlayJudge.through_pass_runner(pair.attacker, ball, target) != null`。
- `OpenPlayJudge`:
  - `static func through_pass_runner(attacker: TeamLayout, ball: PitchArea, target: PitchArea) -> PlayerState`: `target` から `steps_to` が1以内で、今いるエリアが `ball` でない攻撃側の選手のうち、`steps_to` が最小（同じなら配置の順で先）。いなければ null。
  - `apply_attack`: `THROUGH_PASS` なら受け手を `target` へ動かして固定し、`THROUGH_RUN` の動きを返す（受け手が `target` にいれば動きは無いが、固定はする）。守備側がマンツーマンなら付け直す（ドリブルと同じ）。
  - `judge`: `THROUGH_PASS` なら結果を `through_pass_outcome(detail)`（read が EXACT なら LOSS、それ以外は ADVANCE）で決める。比較エリア・人数・読みは他の手と同じく記録する。
  - `outcome_of` は変えない（トランジションと共有しているため）。
- `MatchRules`・`MatchPositions`: 変更なし（ADVANCE でボールが運ぶ先へ進み、受け手がそこにいる。LOSS では守備側が運ぶ先で奪う。膠着は起きないので、ドリブルの戻しは関係しない）。
- `CpuPlanner._is_preferred`: `THROUGH_PASS` はカウンター型が好む手。`score` はヒントが比べない手（`is_compared = false`）なので 0。`situation_bonus` は運ぶ先の列 − ボールの列の前へ運ぶ加点（変更なしでそのまま効く）。
- `MoveHints._add_attack_hints`: `THROUGH_PASS` は `is_compared = false`（人数を比べない）。人数は、受け手が走り込んだ後の運ぶ先の値を入れておく（画面の内訳には使わない）。

### UI
- `MatchTexts.ACTION_NAMES`: 「スルーパス」を3番目に。
- `MatchTexts.target_rule`: 攻撃の `THROUGH_PASS` に「スルーパス: 1〜2列前の、味方が走り込めるエリアへ出す。読まれていれば人数に関係なく奪われる」。
- `MatchTexts.hint_tag`: `THROUGH_PASS` の札は「読み次第」（人数を比べない手で、通るかは読み次第であることを示す。作戦ボードの札の幅に収まる4文字）。
- `JudgeReasonFormatter._cause`: 攻撃側の手が `THROUGH_PASS` なら、ロストは「読まれて／読み切って」、前進は「読まれず／読めず」（人数の句を原因にしない）。
- `TacticsBoard.DRAWN_REASONS` に `THROUGH_RUN` を足し、`BoardPainter` は受け手の走り込みをチームの色の実線で描く（ボールの矢印は選んだ手の矢印が担う）。
- `BoardPainter` のペナルティエリア: 幅をレーン L1〜R1（ボードの幅の 20%〜80%）、奥行きを1列分（高さの 1/6）にする。

### 仕様書
- functional-overview: アルゴリズム3（表に THROUGH_PASS、SHOT の条件）、アルゴリズム5（スルーパスの判定・受け手）、アルゴリズム8（好む手の表）、判定例 JE-09、表示仕様（判定理由・ヒントの札）、区分値 `PlayType`・`MovementReason`。
- glossary（スルーパス・シュート・ペナルティエリア）、requirements-definition（FR-03・FR-06）、component-design（`through_pass_runner`・`THROUGH_RUN`）、screen-design・screen-03（ボタン6つ・補足文・札）。

## テスト
- move_rules_test: シュートの3マスと境界、スルーパスの運ぶ先（1・2列前、3列前・同じ列・後ろ・レーン差2は不可、受け手なし・ボールのエリアにしかいないは不可）。
- open_play_judge_test: 判定（ぴったり→攻撃側が多くても LOSS、隣・外れ→守備側が多くても ADVANCE）、受け手（いちばん近い・同じなら配置の順・運ぶ先にいれば動かず固定）、マンツーマンの付け直し。JE-09。
- move_hints_test・cpu_planner_test（好む手・評価値0）・match_texts_test（名前・補足文・札）・judge_reason_formatter_test・choice_panel_test（6つ）・tactics_board_test（走り込みの矢印）。
- 既存の手の並び順に依存するテスト（enum の値・先頭の手）を直す。
- 変異: SHOT の条件、運ぶ先の列・レーン差、受け手の除外（ボールのエリア）・距離、判定（EXACT のみ LOSS）。

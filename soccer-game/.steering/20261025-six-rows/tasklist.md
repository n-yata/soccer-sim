# タスクリスト

## 盤面の土台
- [x] `pitch_area_test` を6列で書き直し、落ちることを確かめる → `GameEnums.Zone`・`PitchArea` を6列にする
- [x] `team_layout_test`・`layout_values_test`・`match_values_test` など値の型のテストを6列にする

## 基本配置とキックオフ
- [x] `base_layout_deriver_test`・`formations_base_layout_test` を6列で書き直す → `_zone_of` を6列に
- [x] キックオフの位置（`kickoff_areas`）のテストを書く → 実装し、`MatchPositions.place_for_kickoff`（実装で reset_to_base から改名） で使う

## 規則
- [x] `move_rules_test` を6列で書き直す（ショートパス2マス・ロングボール・シュート・カバー・カウンターの境界）→ `MoveRules` を直す
- [x] `defense_mover_test`・`style_layout_calculator_test` を6列で書き直す → マンツーマンの列・余りのマーカーを直す
- [x] `open_play_judge_test`・`transition_judge_test`（判定例 JE-01〜08 を含む）を6列で書き直す
- [x] `move_hints_test`・`move_preview_test`・`cpu_planner_test` を6列で書き直す → CPU の加点を1列あたりに
- [x] `match_rules_test`（キックオフ・シュート阻止の後・アディショナルタイムほか）を6列で書き直す → `MatchRules` を直す
- [x] 性質のテスト（1ターン1マス・保持者・対称性・通しの試合）を通す

## アプリケーション・画面
- [x] `view_converter_test`・`match_controller_test`・`library_service_test` を6列にする
- [x] `match_texts_test`・`judge_reason_formatter_test`・`tactics_board_test`・`mini_pitch_test` ほか画面のテストを6列にする → エリア名・ピッチの線を直す
- [x] 画面を描いて、6列の盤面と押せる範囲（NFR-19）を確かめる

## 仕上げ
- [x] 仕様書を6列に書き直す（.drawio も検索する）
- [x] 全体のテスト・バランスの目安（593件・失敗0。目安を6列の値（2.7点・入れ替わり5.0回・保持4.6ターン）が入る幅へ広げた）
- [x] 変異で確かめる（狙ったスイートだけ）（6列の変異20個すべて KILLED。52秒）
- [x] review-implementation・review-pre-commit
- [x] 振り返り

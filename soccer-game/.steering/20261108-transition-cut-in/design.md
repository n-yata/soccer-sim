# 設計（20261108-transition-cut-in）

## 部品
| 部品 | 層 | 役割 |
| --- | --- | --- |
| `GoalCutIn`（変更） | UI | 場面 `Kind { GOAL, SAVE, STEAL }` を持つ。`play(kind, is_user, score_user, score_opponent, sec)`。is_user は主役の側（得点した側・奪った側）が利用者か。文は場面ごと（GOAL は `GoalCutInArt.texts`、SAVE は `SaveCutInArt.texts`、STEAL は `StealCutInArt.texts`）、重ねの値は `scene_frame(kind, p, is_user)`。SAVE の題は上の3分の1（ゴールの裏から低く見るキーパーを隠さない） |
| `GoalStage3D`（変更） | UI | `build(kind, is_user, colors, font)`。2人の選手を、ボールを持つ側 `holder()`（点を決める選手・ドリブルする選手・シュートを止められる選手）と止める側 `stopper()`（キーパー・奪う選手）にした。色は colors の `you`・`opponent`・`keeper_you`・`keeper_opponent` から、場面と側で選ぶ。SAVE はつかんだ後、ボールをキーパーの両手の間に置く |
| `StealCutInArt`（新規） | UI | ボールを奪う場面の時刻 p → 重ねの値・ドリブルする選手（Sprint → つまずいて Roll）・奪う選手（Sprint → Slide_Start → Slide_Exit）・ボール・カメラ・文。純粋な関数 |
| `SaveCutInArt`（新規） | UI | シュートを止める場面。得点の時間割の一部（`goal_p = SAVE_FROM + p * SAVE_SPAN`）を使い、ボールは CATCH_POINT（つかむ瞬間のキーパーの両手の間）へ飛ぶ。蹴った選手は喜ばずにうなだれる（`DEJECTED_POSE`） |
| `GoalCutInArt`（変更） | UI | `striker_pose(p, finish)`（蹴った後に移る姿勢を選べる）、`pose_frame`・`blend_frames` を公開 |
| `MatchBoardPanel`（変更） | UI | 1拍目の着地で、LOSS なら STEAL、SAVE なら SAVE のカットインを `transition_cut_in_sec()` 秒出す。出したかを次の開示まで覚える（`showed_transition_cut_in()`） |
| `PhaseBanner.follow(phase, quiet)`（変更） | UI | quiet なら局面は覚えるが帯は出さない。試合画面・チュートリアルは、直前の開示でトランジションのカットインを出したら quiet で渡す |
| `PresentationConfig.transition_cut_in_sec` | ドメイン（設定） | 既定 1.8 秒、0 以上 4 以下。0 なら出さない |
| `animations.res` | 素材 | UAL2 の Slide_Start・Slide_Exit を足した。使っていない Jump・Jump_Start を外した |

## 場面の時間割（p。既定 1.8 秒）
- STEAL: 帯 0〜0.08 → 滑り込み 0.24 → ボールに触れる 0.42（閃光・揺れ）→ つまずく 0.45 → 題 0.46〜0.56 → 文 0.56〜0.66 → 起き上がる 0.74 → 暗転 0.9〜1.0。
- SAVE: 得点の時間割の 0.31〜0.81 を写す。蹴る 0.18 → つかむ 0.38（閃光・揺れ）→ 題 0.40〜0.50 → 文 0.50〜0.60 → 暗転 0.9〜1.0。

## テスト
- `steal_cut_in_art_test`（新規）: 時間割の順・閃光と揺れは奪った側が利用者のとき・文・ドリブルとボール・奪う選手の動きと向き・ボールが跳ねて地面に止まる・カメラ。
- `save_cut_in_art_test`（新規）: 得点の時間割の写し方・題と閃光・文・ボールがつかむ点へ飛んで手に残る・蹴った選手がうなだれて跳ばない・キーパーは得点と同じ動き。
- `goal_cut_in_test`: 奪う選手の足がボールに届く（描く体の骨で）・奪った側のユニフォーム・キーパーがつかんで手に持ち続ける。
- `match_board_panel_test`: LOSS で STEAL（奪われた・奪った）・SAVE で SAVE・トランジションにならない結果（前進・奪い返し・オフサイド）では出さない・次の開示で忘れる。
- `phase_banner_test`・`match_screens_test`: quiet で帯を出さずに局面を覚える・カットインの後のターンで帯を出さない。
- `config_repository_test`: 同梱値・範囲の内（0 と上限）・範囲外は初期値とエラー。

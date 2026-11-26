# 設計書

## 方針

3つのカットイン（得点 GOAL・ボールを奪った STEAL・シュートを止めた SAVE）は、1つのクラス `GoalCutIn` が 3D の舞台
（`GoalStage3D`）を使って出している。どれか1つを残しても同じ仕組みが Android で動かないため、仕組みごと外す。
カットインのためだけにある仕組みも一緒に外す（使い手のいない分岐を残さない）。

## 外すもの

| 場所 | 外すもの |
|---|---|
| `ui/board2d/` | `goal_cut_in.gd`・`goal_cut_in_art.gd`・`steal_cut_in_art.gd`・`save_cut_in_art.gd`・`goal_player_model.gd`・`goal_stage_3d.gd`（と `.uid`） |
| `MatchBoardPanel` | カットインの子ノードと `play`・`stop` の呼び出し、`goal_cut_in()`・`showed_transition_cut_in()`・`forget_transition_cut_in()`、`reveal_keyframes` の `wait_for_cut_in` |
| 盤面の「待ち」 | keyframe・拍の `"wait"`（`BoardShift.build_beats`）、`BoardReveal.resume`・`_wait`、`TacticsBoard.resume_shift` |
| 局面の帯 | `PhaseBanner.follow` の `quiet`（試合画面・チュートリアルから渡していた「カットインを出したか」） |
| 設定 | `PresentationConfig.goal_cut_in_sec`・`transition_cut_in_sec`、同梱の `.tres` の値、`ConfigRepository` の範囲の検査、`MatchController` の読み出し |
| テーマ | `GoalCutIn` の色（キーパー・髪・グローブ） |
| 素材 | `assets/models/goal_cut_in/`、`LICENSES.md` の「3Dモデル・動き」（外した経緯だけ残す）、書き出しの `include_filter` の `assets/models/*/*.json` |

## 振る舞いの変化

- 得点の開示: シュートの着地でテロップと結果の演出を出し、キックオフへの組み直し（2拍目）を止めずに続けて動かす
- ロスト・セーブの開示: 着地でテロップと結果の演出だけを出す
- 次のターン: 局面が変われば毎回、局面の帯を出す（カットインを出したターンの後に帯を止める扱いが無くなる）

## テスト戦略

- 先に直す（Red）: 盤面パネル（得点で待たない・カットインのノードが無い・keyframe に "wait" が無い）、同梱の設定に
  カットインの時間が無い、ボールの持ち主が変わった次のターンで局面の帯が出る
- 消す: カットインの5つのスイート、盤面の「待ち」のテスト、帯の `quiet` のテスト、カットインの時間の範囲のテスト
- ブラウザ版を書き出して試合を進め、得点の開示にカットインが重ならないことを確かめる

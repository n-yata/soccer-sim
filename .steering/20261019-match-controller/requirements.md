# 要求内容

## 概要

試合を動かすアプリケーション層を作る（`component-design.md` §3.1〜3.3・§3.5・§4.2）。ドメイン層の部品（アルゴリズム1〜8）をつなぎ、試合画面から呼べる入口を用意する。
- `MatchController`: 試合の開始、選べる手とヒント、1ターンの確定と開示、方式の選び直し、ハーフタイム。座標は利用者の視点に変換して渡す。
- `OpponentPolicy`・`CpuOpponent`: CPU の手と陣形・方式（`CpuPlanner` を呼ぶ）。
- `BoardSnapshot`・`RevealView`: 画面に渡す値（利用者の視点）。
- `ConfigRepository`（データ層）: 調整値の `.tres` を読み、範囲を検査する（範囲外なら初期値）。
- `App` への組み込み: 乱数生成器を1つ作って注入し、`App.match_controller` を持つ。

## 背景

- ドメイン層で、CPU と試合を通しで進められる部品がそろった（`../20261018-cpu-planner/`）。
- 次の試合画面（S-03）は、このアプリケーション層を通して試合を進める。PC で CPU と対戦できるようにするための手前の作業。
- 前の作業からの申し送り:
  - `ConfigRepository` で範囲を検査する。`is_finite`、NaN でも拒否する比較。
  - 範囲外の値をどう扱うか（エラーにするか、ログに残すか）を決める。
  - CPU の手が選択不可なら `assert`（開発時）／先頭の手に置き換え（書き出し版）。
  - 判定の前に `is_allowed` で利用者の手を確かめる。
- シャビの指示（2026-10-19「1→2で進めて。」。1 = 試合を動かすアプリケーション層、2 = 試合画面）。

## 実装対象の機能

### 1. `ConfigRepository`（`game/data/config_repository.gd`）と調整値ファイル
- `game/config/match_rule_config.tres`・`cpu_config.tres` を作る（初期値は `functional-overview.md`「設定値として外部化する値」）。
- `match_rules() -> MatchRuleConfig`・`cpu() -> CpuConfig`。
  - ファイルが無い・型が違う・値が範囲外のときは、初期値の Resource を返して `push_error` する。
  - 範囲: ターン数 1 以上、τ > 0（有限）、0 ≤ floor < 1（有限）。
- 読み込み先のディレクトリは引数で変えられる（テストで壊れた `.tres` を読ませるため）。

### 2. `OpponentPolicy`・`CpuOpponent`（`game/application/`）
- `OpponentPolicy`: `choose_turn(state, side)`・`choose_setup()`・`choose_styles()`。利用者の手は受け取らない（FR-11）。
- `CpuOpponent`: `CpuPlanner` に、注入された `CpuConfig`・`RandomNumberGenerator`・`ContentCatalog` を渡す。

### 3. `BoardSnapshot`・`RevealView`（`game/application/`）
- `component-design.md` §3.5 の表のフィールドを、利用者の視点で持つ。
  - 選手は `player_id`・`number`（背番号）・`area`（エリアのキー）。
  - `BoardSnapshot.movements` は、直前のターンの動き。
  - `RevealView.simplification_ids` は、単純化カタログを扱う作業まで空にする。

### 4. `MatchController`（`game/application/match_controller.gd`）
- 作り方: `_init(catalog, config, rng, opponent, request_screen)`。`request_screen` は画面の切り替えを頼む関数（`App.request_screen`。テストでは記録用の関数）。
- 利用者 = `HOME`、CPU = `AWAY`（§1.3）。
- `start_match(user_setup)`
  - CPU の陣形・方式を `opponent.choose_setup()` で選ぶ。
  - 前半のキックオフ側を `rng` で決め、`MatchRules.create_match` で試合を作る。
  - 試合 ID・開始日時はアプリケーション層で作る。
- `user_options()`・`user_hints()`: 利用者の視点に変換した、選べる手とヒント。
- `submit_turn(user_choice) -> bool`
  - 利用者の手（利用者の視点）を、判定時の攻撃側の視点へ変換し、`MoveRules.is_allowed` で確かめる。選択不可なら `false` を返し、状態を変えない。
  - CPU の手を `opponent.choose_turn` で得る。選択不可なら、開発時は `assert`、書き出し版は `push_error` して選べる手の先頭に置き換える。
  - `MatchRules.resolve_turn` で解決し、`turn_resolved(reveal, snapshot)` を出す。
- `continue_after_reveal()`: 進行段階に応じて次へ進む。
  - `TURN`: `state_changed(snapshot)` を出す。
  - `STYLE_CHANGE`・`HALFTIME`: `stage_changed(stage)` を出し、方式の選び直し（S-04）・ハーフタイム（S-05）の画面を頼む。
  - 後半の最終ターンを終えた: 試合結果（S-06）の画面を頼む。
- `submit_style_change(user_styles)`・`submit_halftime(user_setup)`: CPU の方式・陣形を選び、`MatchRules` で再開して、`state_changed` を出す。
- `opponent_setup()`・`snapshot()`・`is_match_over()`。

### 5. `App`
- 起動時に `RandomNumberGenerator` を1つ作って `randomize()` し、`ConfigRepository`・`CpuOpponent` とともに `MatchController` を作って `App.match_controller` に持つ。
- カタログは、`library` と同じものを使う（1回だけ読む）。

## 受け入れ条件

- テストは先に失敗する状態から書く（Red→Green）。`bash tools/run-tests.sh` が成功する（件数が増え、失敗0）。
- `ConfigRepository`
  - 同梱の `.tres` を読み、値が初期値と一致する。
  - ファイルが無い・範囲外（ターン数 0、τ 0・負、floor 1 以上・負）のときは、初期値を返して `push_error` する。
- `MatchController`（固定シードの乱数と、決まった手を返すテスト用の相手で確かめる）
  - `start_match`: 前半・ターン1・利用者と CPU の陣形と方式・キックオフ側（シードで決まる）。
  - 視点の変換: 利用者が守備のとき、選べる守備の手と運ぶ先が利用者の視点（攻撃側の視点の鏡像）になる。利用者の視点で選んだ手を送ると、判定時の攻撃側の視点で解決される。
  - `submit_turn`
    - 選択不可の手で `false`。状態とシグナルは変わらない。
    - 選べる手で `turn_resolved` を1回出し、`RevealView` が利用者の視点（役割・選択・内訳・ボール位置・配置）になる。
  - `continue_after_reveal`: 進行段階に応じて、`state_changed`・`stage_changed`、画面の要求（S-04・S-05・S-06）が出る。
  - `submit_style_change`・`submit_halftime`: CPU の方式・陣形が選び直され、試合が続く。
  - CPU の手が選択不可のとき、置き換えて解決する（書き出し版の経路）。開発時の `assert` は、テストを止めるため試さない。
  - 通し: CPU 相手に、利用者の手を毎回選べる手の先頭にして、試合が最後（S-06 の要求）まで進む。
- `BoardSnapshot`: 両チームの選手（背番号つき）と人数が、利用者の視点で一致する。ボール位置・保持・スコア・陣形と方式・ターンが入る。
- `App`: `App.match_controller` が作られている。
- 禁止依存の検査で 0 件（ドメイン層は変えない）、型の警告 0 件。

## 成功指標

- `component-design.md` §3.2 のうち今回作る関数と、§3.5 の `BoardSnapshot`・`RevealView` のフィールドのすべてに、対応するテストがある。

## スコープ外

- 中断データの保存・再開・起動時の後始末（`SuspendedMatchStore`・`inspect_suspended`・`resume`・`suspend_to_title`・`has_unsaved_progress`）
  - 保存形式の見直し（前の作業の申し送り）と一緒に、保存の作業で作る。
- 戦績・終了処理（`UserDataService`・`final_record`・`leave_result`・`retry_pending_finalize`）、振り返り（`review`）
- チュートリアル（`ScriptedOpponent`・`new_tutorial_controller`・`start_tutorial_step`）
- 3D 演出の長さ（`PresentationConfig`・`replay_max_sec`）
- 試合画面などの UI（次の作業）

## 参照ドキュメント

- `docs/specs/2_basic-design/component-design.md`（§1.2・§1.3・§3.1〜3.3・§3.5・§4.2）
- `docs/specs/1_requirements/functional-overview.md`（設定値として外部化する値・エラーハンドリング・アルゴリズム7・8）
- `docs/specs/1_requirements/repository-structure.md`（game/config/）

## 未決事項（設計で既定を決めた）

- **`MatchController` の作り方を、今回の範囲に合わせる**
  - 設計書の引数（`content`・`store`・`user_data`・`is_tutorial`）は、保存・戦績・チュートリアルの作業で足す。
  - 今回は `catalog`・`config`・`rng`・`opponent`・`request_screen` にする。
- **画面の要求を関数で受け取る**: `App.request_screen` を直接呼ばずに注入する。テストで画面の要求を記録できるようにするため。
- **範囲外の調整値は `push_error` で知らせる**: エラーハンドリング「表示しない（開発時のテストで検知する）」に従い、利用者には出さない。同梱の `.tres` が範囲内であることを、テストで確かめる。
- **試合 ID**: `YYYYMMDD-HHMMSS-NNNN`（`data-definition.md` §2.1）。日時は端末のローカル時刻、`NNNN` は注入された乱数から作る。

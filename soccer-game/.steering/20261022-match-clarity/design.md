# 設計書

## アーキテクチャ概要

既存の層の構成（ドメイン → アプリケーション → UI）は変えない。変更は3か所に分かれる。

```
domain/match/match_rules.gd      … 2. 保持者を置く・ドリブルの膠着で運んだ選手を戻す
domain/cpu/cpu_planner.gd        … 3. 方式の癖の加点
domain/config/cpu_config.gd      … 3. 加点の設定値（style_bonus）。τ・floor の初期値の変更
data/config_repository.gd        … 3. style_bonus の範囲の検査
domain/game_enums.gd             … 2. MovementReason に DRIBBLE_STOPPED・BALL_HOLDER を足す（末尾に追加）
ui/board2d/tactics_board.gd      … 1. シンプル案の描画
ui/board2d/match_board_panel.gd  … 1. ヒントの札の ±0 の区別を渡す
ui/common/theme/app_theme.tres   … 1. 使わなくなった色・字の大きさの整理と、±0 の札の色
```

## コンポーネント設計

### 1. TacticsBoard（シンプル案）

**責務**:
- 15エリアの盤面と、駒・ボール・選べるエリア・ヒントの札・矢印・比較エリアを描く。描画の変更だけで、入力と位置の計算は変えない。

**実装の要点**:
- **消すもの**
  - 角の優劣記号（`_draw_band` と `mark_of`）。
  - 背番号の文字。
  - 動きの凡例（`_draw_legend`）。
  - テーマの `mark_size`・`number_size`・`legend_size`。
- **白線**: 外枠・ハーフウェイライン・センターサークル・ペナルティエリア・ゴールは、いまのまま残す。
- **駒**
  - エリアの縦の中央に1列で並べる。自分の ● は中央から左へ、相手の ◆ は中央から右へ置く。
  - 1チームの上限は `MAX_PIECES`（4）のまま。超えたら、駒を3つと「+N」の札にする（いまの規則を保つ）。
  - 4つは、セル幅の半分（基準解像度で約120px）に、直径26px・間隔28pxで入る。
- **ボール**
  - エリアの上側の中央に描く。
  - ボールのあるエリアを、白の薄い塗り（テーマ `ball_area_fill`）で明るくする。
- **ヒントの札**
  - 選べるエリアにだけ描く。エリアの下端の中央に置く。
  - `set_hints(tags, even_keys)` で、±0 の札のキーを受け取る。±0 の札は控えめな色（`tag_muted_bg`・`text`）、それ以外は `accent` で描く。
  - 読み出しは `is_hint_even(key)`。
  - ±0 の判定は、パネルが `ChoiceHint.diff() == 0` で行う。札の文字列から推し量らない。
- **レーン名**: エリアの左上に小さく出す（`lane_size` を 16 に下げる。実装時に、色を薄くすると NFR-21 のコントラスト比 4.5:1 に届かないと分かったため、色は薄くしない）。
- **動きの矢印**
  - 描くのは `DRIBBLE`・`PRESS`・`COVER` の動きだけ。
  - 描く動きは `drawn_movements()` で返し、描画とテストで共有する。`movement_count()` は、受け取った数として残す。
- **ファイルの大きさ**: `_draw_band` と `_draw_legend` を消すので、行数は減る見込み。

### 2. MatchBoardPanel

**責務**:
- 運ぶ先を持つ手を選んだとき、ヒントの札の文と、±0 のエリアのキーを盤面に渡す。

**実装の要点**:
- `_on_action_selected` の中で、`hint.diff() == 0` のキーを `even_keys` に集める。

### 3. MatchRules（ボールのあるエリアに必ず保持者を置く）

**責務**:
- ターンの解決とキックオフの後、次のターンの開始時の配置で、ボールのエリアに保持側の選手がいることを保証する。

**実装の要点**:
- **ドリブルの膠着**（`_stop_dribble`）
  - 次の条件をすべて満たすときに戻す。
    - 判定前のターンが攻守ターン。
    - 保持側の手が `DRIBBLE`。
    - 結果が `STALL`。
  - `output.movements` の `DRIBBLE` の動きから、運んだ選手を特定する。その選手の `fixed_area` を、判定前の状態（`state.players_of(holder)`）に戻す。
  - ターン記録に `Movement(holder, id, T, B, DRIBBLE_STOPPED)` を足す。`pair_at_judgement`（判定時の配置）は変えない。判定と 3D 演出は、運んだ後の位置を使う。
- **保持者を置く**（`_place_holder(next) -> Array[Movement]`）
  - `StyleLayoutCalculator.turn_start(next)` で、次のターンの開始時の配置を出す。その攻撃側（保持側）の、ボールのエリアの人数が0のときだけ置く。
    - 攻守ターンは方式の動きの後の配置。
    - トランジションは起点の写し。
  - 置く選手は、開始時の配置の現在エリアからボールまでの距離（ゾーン差＋レーン差）がいちばん小さい選手にする。同じ距離なら、配置の選手の順で先の選手にする。アルゴリズム2の `_distance`・`_nearest_marker` と同じ測り方。
  - 置いた選手は、`next.players_of(holder)` の `fixed_area` をボールのエリアにして固定する。
  - トランジションターンなら、`next.transition_origin.attacker` の、その選手の現在エリアと固定も同じく変える。`TeamLayout` に `with_fixed(player_id, area) -> TeamLayout` を足す。
  - `Movement(holder, id, 開始時のエリア, ボール, BALL_HOLDER)` を返す。
  - 呼び出し場所は次の3つ。
    - `resolve_turn`: ハーフの最終ターンの切り替えの後。返した動きはターン記録に足す。
    - `create_match`・`apply_halftime`: キックオフの後。記録は無い。
  - 試合を終えた後（`is_play_complete`）と、`HALFTIME`・`STYLE_CHANGE` でも、ボールの位置と配置は決まっている。そのため一律に呼んでよい。
    - `STYLE_CHANGE`: キックオフ済み。
    - `HALFTIME`: 後半のキックオフで置き直す。
- **固定の扱い**
  - 置いた選手は、配置区間が終わるまで固定する。方式の動き（保持型の前進）で、ボールから離れないようにするため。
  - 配置区間のリセットで固定が外れても、次のターンの開始前に `_place_holder` がまた置く。
- **MovementReason**
  - `DRIBBLE_STOPPED`・`BALL_HOLDER` を enum の末尾に足す（既存の値の番号を変えない）。
  - 盤面はこの2つを描かない。

### 4. CpuPlanner（方式の癖）

**責務**:
- 評価値に、CPU の方式に応じた加点を足して、選択確率を出す。

**実装の要点**:
- `choose_turn` の中で、`score(hint) + style_bonus(hint, styles, ball, cpu)` を評価値にする。`score` は FR-19 のヒントと共有する値なので、変えない。
- `style_bonus` は、好む手なら `cpu.style_bonus`、そうでなければ 0 を返す。
- 好む手の表は、ルールの定義なので定数で持つ（StyleLayoutCalculator と同じ扱い）。

  | 方式 | 好む手 |
  |---|---|
  | 攻撃 カウンター型 | `LONG_BEHIND`、前（ボールよりゾーンが前）への `DRIBBLE`、`PosTransAction.COUNTER` |
  | 攻撃 保持型 | `SHORT_PASS`、`SWITCH`、`PosTransAction.SECURE` |
  | 守備 マンツーマン | `PRESS`、`NegTransAction.COUNTER_PRESS` |
  | 守備 ゾーン | `COVER`、`NegTransAction.RETREAT` |

- 「前へのドリブル」の判定には、ボールの位置（保持側の視点。CPU が保持側のときだけ攻撃の手を持つ）を使う。
- **CpuConfig**
  - `style_bonus`（0 以上の有限の値）を足す。
  - `temperature`・`floor_probability` の初期値は、自動の試合で測って決める。目標値は事前に決めず、実測（評価値が最高の手 55%→70%、方式ごとの差）を見て、読み合いの余地（floor・τ を下げすぎない）とのバランスで判断した（functional-overview.md アルゴリズム8に根拠を記録）。
  - `ConfigRepository` は `style_bonus` も検査する。範囲外なら、ほかの値と同じく初期値に戻す。

## データフロー

### ターンの解決（変更後）
```
1. resolve_turn: 判定（変更なし） → _apply_outcome（変更なし）
2. ドリブルの膠着なら、運んだ選手の固定を判定前に戻す（記録に DRIBBLE_STOPPED）
3. ハーフの最終ターンの切り替え（変更なし）
4. _place_holder(next): 次のターンの開始時の配置で、ボールに保持側がいなければ1人置いて固定（記録に BALL_HOLDER）
5. TurnResolution を返す → MatchController が BoardSnapshot・RevealView を作る（変更なし）
```

## エラーハンドリング戦略

### カスタムエラークラス
なし。

### エラーハンドリングパターン
- `_place_holder` は、保持側の選手がいない配置（10人いるので通常は起きない）では何もしない。
- 設定値の範囲外は、いまと同じく `push_error` して初期値を使う。

## テスト戦略

### ユニットテスト
- **MatchRules**
  - ドリブルの膠着: 運んだ選手が判定前のエリアに戻る。判定の人数は変わらない。記録に `DRIBBLE_STOPPED` が残る。
  - ドリブルの前進: 運んだ選手は運ぶ先で固定されたまま（戻らない）。
  - 保持者を置く（トランジション後のリセット）: いちばん近い選手が置かれて固定される。記録に `BALL_HOLDER` が残る。
  - 同じ距離のときの順（配置の選手の順）。
  - 既に保持側がいるときは何もしない。
- **不変条件**: 固定シードの CPU 同士の試合を複数回し、すべてのターンの開始時に、ボールのエリアに保持側が1人以上いる。キックオフ・方式の選び直し・ハーフタイムを含む。
- **CpuPlanner**
  - 方式ごとの好む手に加点が入る（4方式。前へのドリブルだけが対象で、横へのドリブルは対象外）。
  - 加点 0 なら、いまと同じ確率になる。
  - 加点を大きくすると、好む手の確率が上がる（NFR-16）。
  - floor の下限は保たれる。
- **ConfigRepository**: `style_bonus` が負・NaN なら初期値に戻る。
- **TacticsBoard**
  - 描く動きが `DRIBBLE`・`PRESS`・`COVER` だけになる。
  - ±0 の札の区別がある。
  - ヒントは選べるエリアだけ。
  - 駒の数は人数と一致する（既存）。
- **MatchBoardPanel**: ±0 のヒントのキーが盤面に渡る。

### 統合テスト
- 既存の通しの試合のテスト（`match_flow_test`）が通ったまま。
- スクリーンショットで、攻撃・守備（プレス）・結果の3場面を確かめる（一時的なシーン。コミットしない）。

## 依存ライブラリ

追加なし。

## ディレクトリ構造

```
game/domain/game_enums.gd                   (変更)
game/domain/team_layout.gd                  (変更: with_fixed)
game/domain/match/match_rules.gd            (変更)
game/domain/cpu/cpu_planner.gd              (変更)
game/domain/config/cpu_config.gd            (変更)
game/config/cpu_config.tres                 (変更)
game/data/config_repository.gd              (変更)
game/ui/board2d/tactics_board.gd            (変更)
game/ui/board2d/match_board_panel.gd        (変更)
game/ui/common/theme/app_theme.tres         (変更)
game/tests/domain/match/match_rules_test.gd (変更)
game/tests/domain/match/ball_holder_invariant_test.gd (新規)
game/tests/domain/cpu/cpu_planner_test.gd   (変更)
game/tests/data/config_repository_test.gd   (変更)
game/tests/ui/tactics_board_test.gd         (変更)
game/tests/ui/match_board_panel_test.gd     (変更)
docs/specs/...                              (変更: 表示仕様・アルゴリズム・画面設計・詳細設計)
```

## 実装の順序

1. 保持者を置く（ドメイン。ほかの2つの前提となる盤面の値が変わるため最初）
2. CPU の方式の癖と設定値（ドメイン・データ。自動の試合で値を測る）
3. 盤面のシンプル案（UI）
4. 仕様書の更新

## セキュリティ考慮事項

- 通信・永続化・外部入力の変更は無い。設定値ファイルの読み込みは既存の検査に `style_bonus` を足すだけ。

## パフォーマンス考慮事項

- `_place_holder` は、1ターンに1回の配置の計算（`turn_start`）を足す。15エリア・10人の固定の計算で、無視できる。
- 不変条件のテストは試合を何回も回すので、件数を絞る（20試合ほど）。

## 将来の拡張性

- `DRIBBLE_STOPPED`・`BALL_HOLDER` の動きは記録に残る。3D 演出と振り返りで、ボールのところへ寄った選手として描ける。
- 好む手の表は、方式を足すときに行を足すだけでよい。

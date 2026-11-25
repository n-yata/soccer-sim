# 要求内容

## 概要

アルゴリズム8「CPU の選択」と、FR-19 のヒントの計算を、ドメイン層に作る（`functional-overview.md`・`component-design.md` §2.4・§2.6・§4.2）。

- `MoveHints.evaluate`: 選べる各手について、「相手が何もしない」と仮定して手を適用した後の、比較エリアの人数とカバーの有無を出す。利用者へのヒントと、CPU の評価値の両方で使う。
- `CpuPlanner`: 評価値から選択確率を出し、注入された乱数で手を選ぶ。試合開始時・ハーフタイムの陣形と方式、得失点後の方式も選ぶ（一様ランダム）。

## 背景

- アルゴリズム1〜7がそろい、ドメイン層で試合を通しで進められるようになった（`../20261018-match-rules/`）。
- CPU 対戦（FR-11）には、相手の手を決める仕組みが要る。ヒント（FR-19）は、CPU の評価値と同じ材料を利用者に見せる（`component-design.md` §2.4 の注記）。
- シャビの指示（2026-10-18「アルゴリズム8をお願い。」）。

## 実装対象の機能

### 1. `ChoiceHint`（`game/domain/choice_hint.gd`）
- 手（`family`・`action`）と運ぶ先（`target`。攻撃側の視点、運ぶ先を持たない手は `null`）。
- 比較の人数（`own_count`・`opponent_count`。その手を選ぶ側から見た値）と、カバー（`cover: CoverKind`）。
- 人数を比べない手（リトリート・保持）は `is_compared = false`。
- 推奨の印は持たない（FR-19「最善の選択を指示しない」）。

### 2. `MoveHints.evaluate(state, side, options)`（`game/domain/judge/move_hints.gd`）
- 選べる手（`options`）ごと、運ぶ先ごとに `ChoiceHint` を返す。相手は何もしないと仮定する。
  - **攻撃の手**: ターン開始時の配置に攻撃の手だけを適用する（ドリブルは選手を動かし、守備側がマンツーマンならマークを付け直す）。比較エリアは運ぶ先（シュートはボール位置）。人数とカバーは、アルゴリズム5の手順5〜6と同じ計算。
  - **守備の手**: 制限するエリア `T_d` の、ターン開始時の人数とカバー（脅威度の材料）。
  - **カウンター**: カウンターの配置（飛び出しの後）で、運ぶ先の人数とカバー。喪失側は直前の配置のまま。
  - **即時奪回**: ボール位置 `X` と上下左右の隣接エリアの人数の合計。奪取側は直前の配置のまま（保持）。
  - **リトリート・保持**: 比べない（`is_compared = false`）。
- `OpenPlayJudge` の攻撃の手の適用（ドリブルと付け直し）を公開し、判定と共有する。判定とヒントで計算をずらさないため。

### 3. `CpuPlanner`（`game/domain/cpu/cpu_planner.gd`）と `CpuConfig`（`game/domain/config/cpu_config.gd`）
- `CpuConfig`（`Resource`）: 温度 `temperature`（初期値 1.0）・下限確率 `floor_probability`（初期値 0.1）。
- `probabilities(scores, cpu)`: `p_i = floor / N + (1 − floor) × softmax(s_i / τ)`。
- `choose_turn(state, side, cpu, rng)`
  - `MoveRules.options_for` の選べる手だけを候補にする。
  - 評価値を付け、確率に従って `rng` で1つ選ぶ。
  - 評価値: 攻撃の手・カウンター・即時奪回は 自分 − 相手、守備の手は脅威度（攻撃側 − 守備側）、リトリート・保持は 0。
  - 引数に、相手のそのターンの手を含めない（同時手番の公平性）。
- `choose_setup(catalog, rng)`: 陣形と方式を一様ランダムに選ぶ（試合開始時・ハーフタイム）。
- `choose_styles(rng)`: 方式を一様ランダムに選ぶ（得失点後）。
- 乱数生成器はドメインで作らず、引数で受け取る（`architecture-overview.md`「ドメイン層」）。

## 受け入れ条件

- テストは先に失敗する状態から書く（Red→Green）。`bash tools/run-tests.sh` が成功する（件数が増え、失敗0）。
- ヒント
  - 攻撃・守備・カウンター・即時奪回の人数とカバーを、具体的な局面で手計算の値と照らす。
  - ドリブルは選手を動かした後の人数になる。マンツーマンならマーカーがついていく。
  - 判定（`OpenPlayJudge`・`TransitionJudge`）で相手の手が影響しない場面では、ヒントの人数とカバーが判定の内訳と一致する。
  - 選べない手のヒントは出さない。リトリート・保持は比べない。
- CPU（アルゴリズム8のエッジケースすべて）
  - 選択不可の手を選ばない（多くの乱数のシードで、選んだ手が `MoveRules.is_allowed` を通る）。
  - どの選択可能な手にも `floor / N` 以上の確率が残る。確率の合計は1。
  - 利用者の選択を参照しない（引数に含まれないことを API で保証する）。
- 選択確率: 評価値が同じなら等確率、評価値の大きい手ほど確率が高い。極端な評価値でも数値が壊れない（NaN・無限大にならない）。
- 固定シードで選択が再現する。
- 陣形と方式: 4陣形 × 2 × 2 の組み合わせだけを返す。多くのシードで、すべての組み合わせが出る。
- 禁止依存の検査で 0 件（乱数は注入されたものだけを使う）、型の警告 0 件。

## 成功指標

- アルゴリズム8のエッジケース（3項目）と FR-19 のヒントの各手に、対応するテストがある。

## スコープ外

- 調整値ファイル（`cpu_config.tres`）と `ConfigRepository`（データ層）
- `CpuOpponent`・`OpponentPolicy`・`MatchController`（アプリケーション層）、試合画面のヒントの札
- 自己対戦による陣形・方式の偏りの検証（FR-02。テスト基盤の作業）

## 参照ドキュメント

- `docs/specs/1_requirements/functional-overview.md`（アルゴリズム3〜8・表示仕様のヒントの札）
- `docs/specs/1_requirements/requirements-definition.md`（FR-11・FR-19）
- `docs/specs/2_basic-design/component-design.md`（§2.4・§2.6・§4.2・§7）
- `docs/specs/3_detail-design/screen/screen-03-match.md`（ヒントの扱い）

## 未決事項（設計で既定を決めた）

- **使わない `catalog` 引数を外す**: `MoveHints.evaluate`・`CpuPlanner.choose_turn` は陣形データを使わない（`MatchRules` と同じ理由）。
- **守備の手の脅威度は、ターン開始時の配置で数える**: 仕様の「制限するエリアの脅威度 `攻撃側人数(T_d) − 守備側人数(T_d)`」を、守備の手を適用する前の人数として読む。適用後の人数で数えると、プレスで寄せた選手の分だけ一律に下がり、脅威の比較にならないため。
- **ヒントの人数は、その手を選ぶ側から見た値で持つ**: 評価値の向き（守備は脅威度）は `CpuPlanner` が手の種類から決める。ヒントに評価値（推奨の材料）を持たせない。

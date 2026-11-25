# 設計書

## アーキテクチャ概要

```
OpenPlayJudge.judge(pair, attacker_styles, defender_styles, ball, attack, defense) -> JudgeOutput（選べない手なら null）
  1. 手の種類を確かめる（attack は ATTACK、defense は DEFENSE）
  2. DefenseMover.apply(pair, defense.action, defense.target)  → null なら null
  3. MAN なら StyleLayoutCalculator.remark
  4. DRIBBLE なら _dribble（ボールを持つ選手を運ぶ先へ固定） → MAN なら remark
  5. 比較エリア・人数差・カバー判定 → JudgeOutput
```

すべて `static` の純粋関数。ドメイン層の禁止依存を使わない。

## コンポーネント設計

### 1. `JudgeDetail`（`domain/judge_detail.gd`）
- `_init(compare_area, attacker_count, defender_count, cover)`・`duplicate_deep()`。
- `compare_area` は攻撃側の視点（§1.2「ターン記録の比較エリア・運ぶ先は判定時の攻撃側」）。

### 2. `JudgeOutput`（`domain/judge_output.gd`）
- `_init(outcome, detail, pair, movements)`。配列はコピーして持つ。`duplicate_deep()`。
- `detail` は `NO_CONTEST`（アルゴリズム6）のときだけ `null`。

### 3. `OpenPlayJudge`（`domain/judge/open_play_judge.gd`）
- 人数: 攻撃側は `pair.attacker.count_at(area)`、守備側は `pair.defender.count_at(area.mirrored())`。
- `_dribble(pair, from, to)`: `from`（ボール位置）の攻撃側の選手を1人選ぶ（固定された選手 = 直前にボールを運んできた選手を優先、配置の順。実装レビューで「固定されていない選手を優先」から変えた）。`fixed_area` と現在エリアを `to` にした配置と、`Movement(attacker_side, id, from, to, DRIBBLE)`。誰もいなければ配置のコピーと空の動き。
- 比較とカバー:
  - `diff = attacker - defender`。
  - `SHOT`: `GOAL`／`SAVE`、カバー `NONE`。
  - それ以外で `diff != 0`: `ADVANCE`／`LOSS`、カバー `NONE`。
  - `diff == 0`: `behind = compare.forward()`（攻撃側から見て1ゾーン前 = 守備側ゴール方向）。
    - `behind == null`（攻撃側の `A`）: レーンが `L2`・`R2` → `ADVANCE`・`OUT_OF_GK_REACH`、それ以外 → `STALL`・`GOALKEEPER`。
    - それ以外: 守備側人数(behind) > 攻撃側人数(behind) → `STALL`・`DEFENDER`、そうでなければ `ADVANCE`・`NONE`。
- 動きは各段の `LayoutStep.movements` をつなげる。
- 入力を書き換えない（`DefenseMover`・`remark` はコピーを返す。`_dribble` も写す）。

## テスト戦略

### ユニットテスト（gdUnit4）
- `tests/domain/judge_values_test.gd`: `JudgeDetail`・`JudgeOutput` の `duplicate_deep` と配列のコピー。
- `tests/domain/judge/open_play_judge_test.gd`:
  - JE-01〜06（JE-02 の `LOSS` を含む）を `formations.json` → `BaseLayoutDeriver` → `StyleLayoutCalculator.compute` → `OpenPlayJudge.judge` で再現する。途中の守備側の配置（攻撃側の視点の行）と寄せた選手のエリアを確かめる。
  - エッジケース: 敵陣の大外・中央・ハーフスペースの同数、シュートの同数、背後が同数でカバーなし、`LOSS` のカバー `NONE`。
  - `DRIBBLE`: 選手の移動と固定、マンツーマンのマーカーの追従、ボール位置に攻撃側がいない場合。
  - 対称性: 攻撃側のチームを入れ替えた入力で、結果・内訳・配置が同じ、動きのチームだけが入れ替わる。
  - 選べない手で `null`、入力を書き換えない。
- 期待値は仕様の判定例と規則から手で書く。

## ディレクトリ構造

```
game/domain/{judge_detail.gd, judge_output.gd}
game/domain/judge/open_play_judge.gd
game/tests/domain/{judge_values_test.gd, judge/open_play_judge_test.gd}
```

## 実装の順序

1. 値オブジェクト（テスト先行）
2. `OpenPlayJudge`（テスト先行。JE を先に書く）
3. 変異で、重要なテストが落ちることを確かめる
4. 文書の更新（`component-design.md` §2.4 の決めごと）

## セキュリティ・パフォーマンス
- 外部通信・保存・秘匿値は扱わない。1回の判定は配置計算の数回分で、問題にならない。

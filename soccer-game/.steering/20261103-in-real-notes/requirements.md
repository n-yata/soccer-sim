# 要求: 解説の「実戦では」（FR-23）

## 概要
FR-17 で作った解説（S-02・S-04・S-05 の解説欄）に、単純化に関わる項目では単純化カタログの「実戦では」を添える。

## 背景
FR-23 は、解説・振り返り・ヒントで単純化に関わる場面が出たら「実戦ではこう」を添えることを求めている（requirements-definition.md）。FR-17 の作業で、解説の項目（`MatchupNote`）に `simplification_ids` を持たせた。方式の ZONE・MAN には SIM-07 を付けたが、表示する仕組みが無く、ルールの `simplification_ids` は空のままだった。

## 実装対象の機能
- 方式（`styles.json`）と噛み合わせのルール（`matchup_rules.json`）に、関わる単純化の ID を付ける
- `NotesView.show_notes` に単純化カタログを渡し、項目の下に「実戦では: …」を `CautionLabel` で出す
- 同じ単純化は、その欄の中で最初に出てくる項目の下にだけ出す（方式の単独の解説は3件とも同じ ID を持つため）
- S-02・S-04・S-05 の呼び出しで、`App.library.simplifications()` を渡す

## 受け入れ条件
- 単純化 ID を持つ項目の下に、カタログの `in_real` が「実戦では: 」付きで出る
- 同じ ID は欄の中で1回だけ出る
- ID を持たない項目の下には何も出ない
- S-02 で保持型を選ぶと、SIM-02 の「実戦では」が出る（画面のつなぎ込み）
- `tools/run-tests.sh` が 180 秒以内で通る

## 成功指標
- 解説を読んだ利用者が、ゲームの単純化と実戦の違いに、その場で気づける

## スコープ外
- S-03 の判定テロップの「実戦では」（`RevealView.simplification_ids`）と、S-07 振り返りの各ターンの「実戦では」。ターンの判定にどの単純化を結びつけるかの決まりが仕様書に無く、その設計から始める別の作業にする
- ヒント（`ChoiceHint`）の「実戦では」
- 理解度チェックの解説

## 参照ドキュメント
- docs/specs/1_requirements/requirements-definition.md（FR-23）
- docs/specs/1_requirements/functional-overview.md（単純化カタログ・アルゴリズム9）
- docs/specs/3_detail-design/screen/screen-common.md（NotesView・caution の色）
- docs/specs/2_basic-design/component-design.md（MatchupNote・NotesView）

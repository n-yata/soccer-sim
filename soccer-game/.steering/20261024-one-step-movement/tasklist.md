# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 土台（位置・1マス）

- [x] テストを書き、失敗することを確かめる（PitchArea.step_toward、PlayerState の current_area・moved_in_turn、TeamLayout.from_players）
- [x] 実装してテストを通す

## フェーズ2: 方式の動き（アルゴリズム2）

- [x] テストを書き、失敗することを確かめる（スライドの反転が2ターン、1マスずつ戻る、マーカーが1マスずつ近づく、moved_in_turn の選手は動かない、リトリートが1マス）
- [x] StyleLayoutCalculator（turn_start・remark・retreat）を実装してテストを通す

## フェーズ3: カバーと試合進行（アルゴリズム4・7）

- [x] テストを書き、失敗することを確かめる（カバーの前方の選手を使わない、MoveRules の条件、キックオフ、トランジション後に戻らない、保持者の規則、膠着したドリブル）
- [x] DefenseMover・MoveRules・MatchTexts・MatchRules を実装してテストを通す

## フェーズ4: 性質のテストと既存のテスト

- [x] 性質のテスト（CPU 同士の全ターンで1マス以内）を書いて通す
- [x] 既存のテストの期待値を新しい規則に合わせ、全件を通す

## フェーズ5: バランスの測り直し

- [x] 計測のテストで測り、目標から外れたら CPU の加点を調整する。保持者がいないターンの頻度も測る

## フェーズ6: 仕様書の更新

- [x] requirements-definition.md・functional-overview.md・glossary.md・component-design.md・data-definition.md ほか（.drawio を含めて検索する）

## フェーズ7: 品質チェックとコミット

- [x] `bash tools/run-tests.sh` が成功する（実行件数・失敗0・終了コード0を確かめる）
- [x] 変異で、重要なテストが落ちることを確かめる（狙ったスイートだけ回し、全体で3分以内）
- [x] 実装レビュー（review-implementation。規約は全文を渡す）を行い、指摘を直す
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] シャビに報告し、main へコミットする（ファイルを名指しでステージする）

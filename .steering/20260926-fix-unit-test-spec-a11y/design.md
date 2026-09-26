# 設計書

## アーキテクチャ概要

本作業はコード変更を伴わないドキュメント復旧作業（例外: `MatchSimulationPanel.vue`の
FR番号誤記1箇所のみ修正）。設計そのものは`specs-detail-design`・`specs-unit-test`スキルが
規定するプロセスに従う（`docs/specs/1_requirements/functional-overview.md` →
`2_basic-design` → `3_detail-design` → `4_unit-test`の順に一方向で反映する）。

## 実施方針

1. `functional-overview.md`（既に最新）を正本として、`2_basic-design/screen-design.md`・
   `component-design.md`に、実装済みだが未反映だったFR-14〜19の内容を追記する。
2. `2_basic-design`を入力に、`3_detail-design/screen/screen-02-comparison.md`を更新し、
   `screen-06-league.md`・`screen-07-cup.md`を新設する。
3. `3_detail-design`と実際の`.test.ts`ファイル（grepでテストケース名を抽出）を突き合わせ、
   `4_unit-test/test-screen-02-comparison.md`を更新し、`test-screen-06-league.md`・
   `test-screen-07-cup.md`を新設する。
4. 記載内容は実装コード（`.vue`/`.ts`ファイル）を直接読み込んで裏取りし、推測で書かない。

## 発見事項

- `LeaguePage.vue`にはテストファイルが存在しない（`CupPage.vue`・`HalftimeTacticsModal.vue`は
  今回のa11y監査対応で新規作成済み）。単体テスト仕様書には意図した テストケースを記載しつつ、
  実装（テストコード）が未着手であることを明記した。
- `MatchSimulationPanel.vue`のコメントに「ハーフタイム(FR-17)」という誤記があった
  （実際はFR-19。ハーフタイム采配実装当初はFR-17だったが、後続のマージでカップ戦がFR-17を
  取得しFR-19へ改番された際に取り残されたコメント）。ドキュメント記述との整合のため修正した。

## テスト戦略

ドキュメントのみの変更のため、自動テストの追加は無い。既存のテストスイートに影響が
無いこと（`MatchSimulationPanel.test.ts`が変更後も成功すること）を確認する。

## 実装の順序

1. `2_basic-design/screen-design.md`更新
2. `2_basic-design/component-design.md`更新
3. `3_detail-design/screen/screen-02-comparison.md`更新
4. `3_detail-design/screen/screen-06-league.md`・`screen-07-cup.md`新規作成
5. `4_unit-test/test-screen-02-comparison.md`更新
6. `4_unit-test/test-screen-06-league.md`・`test-screen-07-cup.md`新規作成
7. `MatchSimulationPanel.vue`のFR番号誤記を修正
8. 既存テストスイートへの影響が無いことを確認

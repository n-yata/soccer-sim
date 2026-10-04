# 要求内容

## 概要

画面6〜8（戦術学習一覧・陣形学習・自由配置ボード）の画面詳細設計書と単体テスト仕様書を作成し、
既存の画面1〜5と同じ粒度で詳細設計・単体テスト仕様をそろえる。

## 背景

- 2026-10-04 の整合作業（`.steering/20261004-screen-docs-alignment/`）で基本設計（screen-design.md・
  component-design.md）は8画面にそろえたが、`3_detail-design/screen/` と `4_unit-test/` は画面1〜5のみで、
  画面6〜8は申し送りになっていた。

## 実装対象の機能

### 1. 画面詳細設計書（`docs/specs/3_detail-design/screen/`）
- `screen-06-learning-list.md` / `screen-07-formation-learning.md` / `screen-08-free-layout-board.md`
- 既存 screen-01〜05 の章立て（基本情報・コンポーネント構成・props/state・状態管理・詳細フロー・例外表示）に合わせる

### 2. 単体テスト仕様書（`docs/specs/4_unit-test/`）
- `test-screen-06-learning-list.md` / `test-screen-07-formation-learning.md` / `test-screen-08-free-layout-board.md`
- 既存 test-screen-01〜05 の形式（テスト対象表・テストケース一覧・完了欄・備考）に合わせる
- 完了欄は既存テストと対応づけ、実在するテストがあるケースのみ `[x]` にする

## 受け入れ条件

- [ ] 6ファイルがそれぞれシャビの承認を得ている（AGENTS.md「ドキュメント作成時」）
- [ ] 詳細設計書の記述が実装（`src/pages`・`src/components`・`src/data`）と一致している
- [ ] テスト仕様書の各ケースに具体的な前提・操作・期待結果があり、境界値・異常系を含む
- [ ] `[x]` のケースは実在するテストに対応し、対応しないケースは `[ ]` のまま残す（未実装を実装済みに見せない）
- [ ] screen-design.md「詳細設計への申し送り」の「画面6〜8は未作成」の記述を更新する
- [ ] 既存の検証コマンド（test・lint・typecheck・build）がパスする

## 成功指標

- 8画面すべてに詳細設計書と単体テスト仕様書がそろう

## スコープ外

- テストコードの追加（仕様書で `[ ]` となったケースの実装は後続作業）
- アプリの機能変更

## 参照ドキュメント

- `docs/specs/1_requirements/functional-overview.md` - 画面一覧の正本
- `docs/specs/2_basic-design/screen-design.md` / `component-design.md`
- `<kit>/reference/rules/testing.md`

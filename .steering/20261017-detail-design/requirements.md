# 要求: 詳細設計（docs/specs/3_detail-design/）

- `specs-detail-design` スキルに従い、基本設計を画面単位・保存データ単位に詳細化する
- 作るもの（2026-10-17 シャビ決定）
  - `screen/`: 画面ごとに1ファイル（S-01〜S-12）と、画面共通の決めごと（`screen-common.md`）
  - `data/`: 保存データ（中断データ・戦績・回答結果・設定）と静的データの項目ごとの定義
  - `db/`・`api/` は作らない（RDB・API を持たない。functional-overview.md）
- 進め方: S-03 と screen-common.md を見本として承認を得てから、残りを一括で作り、まとめてレビューを受ける
- 作業は main で行う（AGENTS.md「プロジェクト固有の設定」）

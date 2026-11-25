# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 検査と実行の仕組み

- [x] `tools/check_domain_deps.gd` を作る（4カテゴリのパターン、コメントの除外、終了コード）
- [x] `game/tests/fixtures/forbidden_deps/` にカテゴリごとの fixture を置く（Godot として正しい構文。誤検出しないことを見る `clean/` も足した）
- [x] `tools/run-tests.sh` を作る（自己確認 → domain の検査 → gdUnit4。0件は失敗扱い）
- [x] fixture ごとに検出されること（終了コード 1）と、空の `game/domain/` で 0 件になることを確かめる

## フェーズ2: 区分値とエリア

- [x] `GameEnums` を作る（component-design §2.1 のとおり）
- [x] `tests/domain/pitch_area_test.gd` を書き、失敗すること（Red）を確かめる
- [x] `PitchArea` を実装し、テストを通す（Green。13件）
  - 新しい `class_name` はエディタで取り込むまでテストから見えないため、`run-tests.sh` の最初に取り込み（`--editor --quit`）を足した

## フェーズ3: 陣形と配置の値オブジェクト

- [x] `tests/domain/team_layout_test.gd` を書き、失敗することを確かめる
- [x] `PlayerSlotDef`・`FormationDef`・`PlayerState`・`TeamLayout`・`ContentCatalog` を実装し、テストを通す

## フェーズ4: 基本配置の導出

- [x] `tests/domain/layout/base_layout_deriver_test.gd` を書き、失敗することを確かめる（アルゴリズム1のエッジケースすべて）
- [x] `BaseLayoutDeriver` を実装し、テストを通す（Red は `BaseLayoutDeriver` が無い状態で終了コード 105 を確認。Green は8件。境界の比較を `<=`→`<` に変える変異で落ちることも確認）

## フェーズ5: 陣形の静的データと読み込み

- [x] 移植元から `game/content/formations.json` を機械的に起こし、背番号を要求書の表で付ける（表との照合を含む）
- [x] `tests/data/content_repository_test.gd` を書き、失敗することを確かめる（本物の正常系・誤りの種類ごとの検出・空のカタログ）
- [x] `ContentRepository` を実装し、テストを通す（25件。壊れたデータは本物を1か所だけ変えてテスト内で作る。design.md「テスト戦略」）
- [x] `tests/data/formations_base_layout_test.gd`（4陣形 × 15エリアの表）を書き、通ることを確かめる。期待値を1か所変えると失敗することも確かめる

## フェーズ6: 書き出しと文書

- [x] デバッグ版の APK を書き出し、`content/formations.json` が含まれ、`tests/` が含まれないことを確かめる
- [x] `component-design.md` を実装に合わせる（`TeamLayout` の関数、`PlayerSlotDef.position_type`、`ContentRepository` の引数、`ContentCatalog.formation()`）
- [x] `repository-structure.md` を更新する（tools/ の実ファイル、テストの実行は `tools/run-tests.sh`、`game/` の未作成の表示）
- [x] `non-functional-requirements.md` の NFR-13 から検査スクリプトの名前を参照する

## フェーズ7: 品質チェックとコミット

- [x] `tools/run-tests.sh` が成功する（実行件数・失敗 0 を確認。56件）
- [x] `godot --headless --editor --quit`（`game/` で実行）がエラー 0 件で終わる
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（総合 4.4/5。[必須] 1件・[推奨] 6件・[提案] 5件。対応は retrospective.md）
  - [x] 禁止依存の検査: extends を許可リスト方式に、`RandomNumberGenerator.new()`・ノード操作・フレーム数・`load_from_file` を追加、当たった語を出力、`--self-check` で全ルールの空振りを確認、検査できない対象（終了コード 2）も自動で確認
  - [x] `ContentRepository`: 制約値を定数にして正本を注記、陣形 ID の集合の確認、有限値の確認、構造の異常系のテスト
  - [x] 値オブジェクト: 受け取った配列をコピーして持つ、`count_at(null)`、`ContentCatalog.duplicate_deep()`、bool の改名
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す（第2回で完了。review-report.md）
- [x] 振り返りを `retrospective.md` に記録する
- [x] main へコミットする（ファイルを名指しでステージする）

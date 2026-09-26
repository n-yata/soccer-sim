# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: 型定義と永続化レイヤー

- [x] `types/formation.ts` に `FreeLayoutOverrides` 型を追加
- [x] `data/freeLayoutStorage.ts` を実装
  - [x] `applyOverrides(positions, formationId)`
  - [x] `savePositionOverride(formationId, positionId, x, y)`
  - [x] `clearFormationOverride(formationId)`
  - [x] 不正データ・localStorage例外に対する防御（learningProgress.tsと同じ方針）
- [x] `data/freeLayoutStorage.test.ts` を実装しパスすることを確認（16 tests passed）
  - [x] applyOverridesの上書き適用・未保存分のcanonical維持・クランプ
  - [x] save→applyの往復一致（決定性）
  - [x] フォーメームID間の独立性
  - [x] clearFormationOverrideの効果範囲
  - [x] 不正JSON・型不一致・localStorage例外時のフォールバック

## フェーズ2: FreeLayoutPitchDiagram.vueのBチーム対応

- [x] Bチームの`<circle>`にdraggableクラス・`@pointerdown`ハンドラを追加
- [x] `update-position`のemitシグネチャに`team`を追加
- [x] ドラッグ状態の追跡にdraggingTeamを追加し、`cxToDepth`にドラッグ中のチームを渡す
- [x] `FreeLayoutPitchDiagram.test.ts` を変更後の仕様に更新（10 tests passed）
  - [x] Bチームにもdraggableクラスが付与されることの検証に更新（既存の「付与されない」検証を置き換え）
  - [x] Bチームドラッグでteam:"B"付きemitを検証
  - [x] Aチームドラッグでteam:"A"付きemitを検証（既存テストのシグネチャ更新）
  - [x] 全テストがパスすることを確認

## フェーズ3: ComparisonPage.vueへの統合

- [x] `freePositionsB` refを追加
- [x] `toggleFreeLayoutMode`: A・B両方の初期値にapplyOverridesを適用
- [x] `resetFreeLayout`: A・B両方でclearFormationOverride→canonical positionsで上書き
- [x] `onUpdatePosition(team, positionId, x, y)`: teamに応じてfreePositionsA/Bを更新し、savePositionOverrideで永続化
- [x] `effectiveFormationB` を追加
- [x] `effectiveStatsB` を追加
- [x] `matchup`の分岐条件・generateMatchupの引数をB対応に変更
- [x] `radarSeries`のB側をeffectiveStatsBに変更
- [x] 組み合わせ変更時のwatchに`freePositionsB.value = null`を追加
- [x] `ComparisonPage.test.ts` にテストを追加（41→48件。既存分含め全通過）
  - [x] Bチーム配置変更でレーダーチャートが再計算される
  - [x] A/Bの独立性、リセットでA・B両方が元に戻る
  - [x] OFF→ONで保存済み配置が復元される
  - [x] 再マウント（リロード相当）後も復元される
  - [x] 同じフォーメーションを別組み合わせで表示しても復元される
  - [x] リセット後はlocalStorageのエントリが削除され、再ONでcanonicalに戻る
  - [x] 既存テスト（Aチーム自由配置）がそのまま通ることを確認

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（501 tests passed / 32 test files）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラー無し）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（エラー無し）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）（501 passed, 0 skipped, 0 failed）
- [x] `npm run dev` でBチームのドラッグ・リロード後の復元・リセットを目視確認（ブラウザでLM選手をドラッグ→移動を確認、リロード後に位置が復元されることを確認、リセットで元の位置に戻ることを確認）

## フェーズ5: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` のFR-15を更新（Bチーム対応・永続化仕様）、§6.2の積み残し2項目を解消して§6.1へ移動
- [x] `docs/specs/1_requirements/functional-overview.md` の「自由配置モードのピッチ図」表示仕様を更新
- [x] `docs/specs/1_requirements/architecture-overview.md` の「データ永続化戦略」を実態（FR-13学習進捗・今回のFR-15座標がlocalStorageを使用）に合わせて修正
- [x] 更新した永続ドキュメントの差分に対して、必要なら再度コミット前レビューを回す（第1回レビューで実施。ドキュメント差分自体への指摘なし）
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

## フェーズ6: コミット前レビュー対応（第1回レビューのMedium指摘）

- [x] `FreeLayoutPitchDiagram.vue`: `update-position`（表示用）と`update-position-end`（ドラッグ確定時の永続化用）にイベントを分離
- [x] `ComparisonPage.vue`: `savePositionOverride`の呼び出しを`onUpdatePositionEnd`へ移動
- [x] `freeLayoutStorage.ts`: `__proto__`/`constructor`/`prototype`キーを弾くガードを追加
- [x] `freeLayoutStorage.ts`: `EMPTY`を`Object.freeze`する
- [x] テスト追加（イベント分離3件・プロトタイプ汚染ガード1件）、空振りテストの修正1件
- [x] 誤字「フォーメーム」を今回の差分内で修正
- [x] 全チェック再実行（505 tests passed / lint・typecheck・build 成功）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

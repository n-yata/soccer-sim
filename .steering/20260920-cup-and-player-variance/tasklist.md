# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: 型定義とユーティリティのexport

- [x] `types/formation.ts` に `CupMatch` / `CupSimulationResult` 型を追加
- [x] `composables/matchSimulation.ts` の `mulberry32` / `fnv1aHash` / `clamp` を `export` に変更

## フェーズ2: カップ戦シミュレーション

- [x] `composables/cupSimulation.ts` を実装
  - [x] 準々決勝（4試合）の対戦カード生成（formations配列の並び順）
  - [x] 準決勝（2試合）・決勝（1試合）の勝ち上がりロジック
  - [x] 同点時のPK戦（`fnv1aHash`+`mulberry32`で決定的に、必ず勝者を1人決める）
  - [x] `formations.length !== 8` / マッチアップ欠落時の `Error`
- [x] `composables/cupSimulation.test.ts` を実装しパスすることを確認（11 tests passed）
  - [x] 実データでの構造検証（4/2/1試合、対戦カードの並び、勝ち上がりの整合性）
  - [x] 決定性検証（2回実行して結果が完全一致）
  - [x] スタブによるPK戦の決定性・必ず決着する検証
  - [x] 異常系（8件以外、マッチアップ欠落）のError検証

## フェーズ3: 選手個体差（スカッドコンディション）

- [x] `composables/squadCondition.ts` を実装（`applySquadVariance`）
- [x] `composables/squadCondition.test.ts` を実装しパスすることを確認（5 tests passed）
  - [x] 変動範囲（90-110%、0-100クランプ）の検証
  - [x] 同一seedでの決定性検証
  - [x] 異なるseedで結果が変わりうることの検証
  - [x] 元のstatsオブジェクトを変更しない（イミュータブル）ことの検証

## フェーズ4: カップ戦画面

- [x] `pages/CupPage.vue` を実装（準々決勝・準決勝・決勝のブラケット表示、優勝表示、比較画面への導線）
- [x] `router/index.ts` に `/cup` ルートを追加
- [x] `FormationListPage.vue` に「🥇 カップ戦」導線を追加

## フェーズ5: 比較画面への選手個体差UI統合

- [x] `components/SquadConditionControls.vue` を実装
- [x] `pages/ComparisonPage.vue` に統合
  - [x] `squadConditionSeed` の状態管理（トグルON/OFF・reroll）
  - [x] `runSimulation` で有効時のみ実効statsを算出してsimulateMatchへ渡す
  - [x] 組み合わせ変更時のリセット処理に `squadConditionSeed` を追加
- [x] 既存 `ComparisonPage.test.ts` がそのまま通ることを確認（デフォルト無効時の非破壊性。464 tests passed）

## フェーズ6: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（464 tests passed / 30 test files）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラー無し）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（エラー無し）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功）
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）（464 passed, 0 skipped, 0 failed）
- [x] `npm run dev` でカップ戦画面・選手個体差UIを目視確認（/cup でブラケット・PK戦表示、比較画面で選手個体差トグル→シミュレーション実行を確認）

## フェーズ7: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` にFR-17（カップ戦）・FR-18（選手個体差）を追加し、機能詳細・受け入れ基準・画面表・スコープ節を更新
- [x] `docs/specs/1_requirements/functional-overview.md` の画面一覧・画面遷移図・表示項目を更新
  - [x] ~~データモデル（CupMatch/CupSimulationResult）の追加~~（実装方針の確認により不要と判断: 既存の`LeagueStanding`/`LeagueMatchResult`/`LeagueSimulationResult`も同ドキュメントの「データモデル」節にエンティティとして追加されていない前例があり、`composables/`が返す非永続の導出データはこの節の対象外という既存の扱いに揃えた。画面設計側の反映で十分）
- [x] 更新した永続ドキュメントの差分に対して、必要なら再度コミット前レビューを回す（第1回レビューで実施。指摘はコード側のみでドキュメント差分自体への指摘なし）
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

## フェーズ8: コミット前レビュー対応（第1回レビューのMedium指摘）

- [x] `cupSimulation.ts`: PK戦の勝者が呼び出し順（a/b）に依存するバグを修正（正準順で解決してから呼び出し順へマッピング）
- [x] `cupSimulation.test.ts`: PK戦の勝者が配列内の並び順に依存しないことを検証するテストを追加
- [x] `CupPage.vue`: 例外の握りつぶしに`console.error`を追加
- [x] `FormationListPage.vue`: `formations.length !== 8`のとき「カップ戦」導線を非表示にする
- [x] `SquadConditionControls.test.ts` を新規作成（他の全コンポーネントがテストを持つ既存規約に揃える）
- [x] `ComparisonPage.test.ts` に選手個体差の状態管理（トグルON/OFF・リロール・組み合わせ変更時のリセット・レーダーチャートへの非影響）のテストを追加
- [x] 誤字「フォーメーム」→「フォーメーション」を今回の差分内（`requirements-definition.md`・`cupSimulation.test.ts`・本ディレクトリの`requirements.md`）で修正
- [x] 全チェック再実行（477 tests passed / lint・typecheck・build 成功）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

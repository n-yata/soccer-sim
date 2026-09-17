# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: データモデル変更

- [x] `src/types/formation.ts`の`Matchup`型を`commentary: string`から
      `advantagesForA: string[]` / `advantagesForB: string[]`に変更する
- [x] `src/data/matchups.ts`の`getMatchup`に正規化ロジック（呼び出し順序とレコード順序が
      逆の場合、advantagesForA/Bを入れ替えて返す）を実装する
- [x] 全6組み合わせ（4-4-2×4-3-3, 4-4-2×4-2-3-1, 4-4-2×3-5-2, 4-3-3×4-2-3-1,
      4-3-3×3-5-2, 4-2-3-1×3-5-2）のコンテンツを、具体的な戦術ポイントで書き直す
- [x] `src/data/matchups.test.ts`を新データ構造に合わせて更新する（16件パス確認済み）
  - [x] 既存の正常系・順序非依存テストを新構造に更新
  - [x] 順序が逆のときadvantagesForA/Bが入れ替わって返ることを検証するテストを追加
  - [x] 既存の全組み合わせ存在検証テストは変更不要と確認（データ構造に依存しないため）

## フェーズ2: PitchDiagram変更

- [x] `src/components/PitchDiagram.vue`に`showField`props（既定値true）を追加し、
      `<rect>`（ピッチ背景）の描画を制御する
- [x] `src/components/PitchDiagram.test.ts`にテストを追加する（12件パス確認済み）
  - [x] `showField=false`のとき`<rect>`が描画されないことを検証
  - [x] `showField`省略時は従来どおり`<rect>`が描画されることを検証（後方互換）

## フェーズ3: ComparisonPage変更

- [x] `src/pages/ComparisonPage.vue`のレイアウトを変更する
  - [x] ピッチ図2枚を重ね合わせ表示にする（1枚目showField省略=true、2枚目showField=false
        を絶対配置で重ねる）+ 色の凡例（●アイコン）を追加
  - [x] 解説文を`advantagesForA`/`advantagesForB`の見出し付き箇条書き表示に変更する
- [x] `src/pages/ComparisonPage.test.ts`を更新する（12件パス確認済み）
  - [x] 解説文の検証を箇条書き表示の検証に更新
  - [x] ピッチ図の重ね合わせ（showFieldの値含む）を検証

## フェーズ4: ドキュメント更新

- [x] `docs/specs/1_requirements/functional-overview.md`のデータモデル・ER図・画面設計
      （表示仕様）を新しいMatchup構造・重ね合わせ表示に合わせて更新する
- [x] `docs/specs/2_basic-design/component-design.md`のPitchDiagram・データレイヤーの
      インターフェース記述を更新する
- [x] `docs/specs/2_basic-design/screen-design.md`の比較画面レイアウト・画面項目定義を
      更新する（ワイヤーフレームdrawioが未追随である旨の注記も追加）
- [x] `docs/specs/3_detail-design/screen/screen-02-comparison.md`のコンポーネント構成・
      画面遷移フローを更新する
- [x] `docs/specs/1_requirements/glossary.md`のMatchupエンティティのフィールド説明を更新する
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`のテストケースを実装に合わせて
      更新する（前提データ、ケース4・5・11の内容更新、ケース17・18を新規追加）

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（Vitest） → 6 Test Files, 47 Tests すべてpassed
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（ESLint） → 0 problems
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（vue-tsc） → 0エラー
- [x] ビルドが成功することを確認
  - [x] `npm run build`（Vite） → ビルド成功
- [x] **テストが実際に実行されたことを確認** → `Test Files 6 passed (6)` `Tests 47 passed (47)`、スキップ0件
- [x] `review-implementation`による実装検証を実施し、指摘（[必須]3件・[推奨]5件）に対応する
  - [x] [必須] 重ね合わせ表示で選手座標が完全一致し下層が見えなくなる問題を修正
        （選手を半透明色+白い縁取りで描画）
  - [x] [必須] 重ね合わせの向きが対戦を表現していない問題を修正（`PitchDiagram`に`flip`
        propsを追加し、2枚目を上下反転して向き合う配置にする）+ 回帰テスト追加
  - [x] [必須] `requirements-definition.md`・`repository-structure.md`の
        FR-03/FR-04・配置説明が旧仕様（並列表示）のまま未更新だったのを修正
  - [x] [推奨] `ComparisonPage.test.ts`に、正規化ロジックの入れ替えを直接検証する
        アサーション（青/赤カラムの文言の中身）を追加（恒真テスト回避）
  - [x] [推奨] `matchups.test.ts`に全マッチアップのadvantagesForA/B非空検証・
        配列内重複検証を追加
  - [x] [推奨] `:key="point"`を`:key="index"`に変更（キー衝突リスク回避）
  - [x] [推奨] `matchups.ts`の`getMatchup`に、正規化時の`id`の意味についてコメントを追記
  - [x] [推奨] `npm run format`を実行（Prettier未整形を解消）
  - [x] 対応後、`npm run test`（47件）・`lint`・`typecheck`・`build`を再実行し全て成功を確認

## フェーズ6: ドキュメント更新（テスト仕様書チェック）

- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`の完了チェック欄を更新する
      → 全23ケース（新規追加分含む）すべて`[x]`
- [x] `review-pre-commit`スキルによるコミット前レビューを実施する
      → Critical/High 0件。Medium 2件（誤記再発、`getMatchup`非対称性）は対応済み。
      詳細は`review-report.md`
- [x] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）
      → 完了。`retrospective.md`参照

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

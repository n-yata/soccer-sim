# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール
- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

---

## フェーズ1: ドキュメント更新（要件定義・機能概要）

- [x] `requirements-definition.md` §6.1「対象範囲(MVP)」にレーダーチャート表示・対戦演出を追加
- [x] `requirements-definition.md` §6.2「スコープ外」から「アニメーション演出」の行を削除
- [x] `requirements-definition.md` §4.1に新規FR（FR-05: レーダーチャート表示、
      FR-06: 対戦演出アニメーション）を追加し、§4.2に受け入れ基準を追記
- [x] `functional-overview.md`「データモデル」に`FormationStats`/軸定義を追加し、
      「`Formation`に属する静的スコアであり`Matchup`のA/B入れ替えロジックとは独立」と明記
- [x] `functional-overview.md`「表示仕様」にレーダーチャートの表示仕様（軸一覧・配色ルール）と
      アニメーション仕様（スライドイン→VSバッジ→判定ポップインの順、`prefers-reduced-motion`
      対応）を追記

## フェーズ2: データ層

- [x] `src/types/formation.ts`に`RadarAxisId`/`FormationStats`型を追加し、`Formation`に
      `stats: FormationStats`フィールドを追加
- [x] `src/data/radarAxes.ts`を新規作成（5軸のメタデータ: attack/defense/balance/
      spaceControl/pressIntensity）
- [x] `src/data/formations.ts`に4フォーメーション分のstats値を追加
      （positionsからの算出ルールをコメントで明記し、既存descriptionと矛盾しないよう調整）
- [x] `src/data/formations.test.ts`に不変条件テストを追加
  - [x] 全フォーメーションの全軸スコアが0-100範囲内であること
  - [x] 全フォーメーションのstatsベクトルが互いに完全一致しないこと（52件全てpass確認済み）

## フェーズ3: RadarChartコンポーネント

- [x] `src/components/RadarChart.vue`を新規実装（自前SVG、props: axes/maxValue/series）
- [x] `src/components/RadarChart.test.ts`を新規作成（5件、全てpass）
  - [x] 軸数分のラベル（`<text>`）が描画されること
  - [x] 系列数分の`<polygon>`が描画されること
  - [x] 既知の軸数・スコアに対する頂点座標が近似的に正しいこと

## フェーズ4: ComparisonPageへの組み込み

- [x] `ComparisonPage.vue`にRadarChartを組み込む（既存の優位ポイント表示は維持、併存させる）
- [x] `ComparisonPage.test.ts`にRadarChartへのprops連携（formationA/Bのstatsが正しく渡る
      こと）を検証するテストを追加（58件全てpass確認済み）

## フェーズ5: 対戦演出（アニメーション）

- [x] `MatchupPitchDiagram.vue`のテンプレートでチーム別の2つの`<g>`にグルーピング
      （DOM順序・クラス名は変えない）
- [x] `MatchupPitchDiagram.vue`にチームA左スライドイン・チームB右スライドインの
      CSS `@keyframes`を追加
- [x] `MatchupPitchDiagram.test.ts`にチームグループ`<g>`の存在検証を追加
      （既存アサーションは維持されることを確認、12件全てpass）
- [x] `ComparisonPage.vue`にVSバッジ要素を追加（`<button>`にしない、戻るボタンより後に配置）
- [x] `ComparisonPage.vue`の`.comparison-page__verdict`に`animation-delay`付き
      ポップインkeyframesを追加
- [x] VSバッジに回転ポップインのCSS `@keyframes`を追加
- [x] `MatchupPitchDiagram.vue`/`ComparisonPage.vue`両方に
      `@media (prefers-reduced-motion: reduce)`でアニメーション無効化のCSSガードを追加
- [x] `ComparisonPage.test.ts`で`wrapper.find("button")`のインデックス依存箇所が
      壊れていないことを確認（59件全てpass）

## フェーズ6: 基本設計ドキュメントの最終同期

- [x] `docs/specs/2_basic-design/screen-design.md`「画面2: 比較画面」にレーダーチャートの
      配置とアニメーション順序（スライドイン→VSバッジ→判定ポップイン）を追記
- [x] `docs/specs/2_basic-design/component-design.md`に`RadarChart.vue`の責務・
      インターフェースを追加
- [x] `docs/specs/2_basic-design/wireframes.drawio`に比較画面の新ワイヤーフレームページ
      （`wireframe-comparison-v3(対戦演出+レーダーチャート)`）を追加し、レーダーチャート・
      VSバッジを反映（XML整形式・5ページ構成をPythonで検証済み）

## フェーズ7: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm run test`（59件全てpass、0スキップ）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`（エラーなし）
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`（`FormationCard.test.ts`のモックFormationにstats未設定の
        型エラーを発見・修正済み）
- [x] ビルドが成功することを確認
  - [x] `npm run build`（成功）
- [x] `npm run dev` + Chrome自動操作で比較画面を開き、スライドイン→VSバッジ→判定ポップイン
      の演出とレーダーチャートの重ね描画を目視確認（VSバッジ・判定ポップイン・レーダー
      チャートの重ね描画いずれも意図通り表示されることを確認）
- [x] `prefers-reduced-motion`対応はCSSソースレベルで実装済みであることをコードで確認
      （動的シミュレーションは未実施。`@media (prefers-reduced-motion: reduce)`ブロックが
      両コンポーネントに存在することをレビューで確認する）
- [x] **テストが実際に実行されたことを確認**（59件実行・0スキップ、`npm run test`出力で確認済み）

## フェーズ8: コミット前レビュー・振り返り

- [x] `review-pre-commit`を実施し、新たなCritical/Highが出なくなるまで修正・再レビューを繰り返す
      （3ラウンド実施。第3回でCritical/High/Medium全て指摘なしに収束）
- [x] 実装後の振り返りを記録（別ファイル`retrospective.md`に記録 → モード3）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md`に記録する。全タスクが`[x]`になったことを確認してから作成すること。

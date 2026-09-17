# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

### 必須ルール

- **全てのタスクを`[x]`にすること**
- 「時間の都合により別タスクとして実施予定」は禁止
- 「実装が複雑すぎるため後回し」は禁止
- 未完了タスク（`[ ]`）を残したまま作業を終了しない

### タスクスキップが許可される唯一のケース

以下の技術的理由に該当する場合のみスキップ可能:

- 実装方針の変更により、機能自体が不要になった
- アーキテクチャ変更により、別の実装方法に置き換わった
- 依存関係の変更により、タスクが実行不可能になった

スキップ時は必ず理由を明記:

```markdown
- [x] ~~タスク名~~（実装方針変更により不要: 具体的な技術的理由）
```

---

## フェーズ1: サッカー用語データの追加

- [x] `src/types/formation.ts` に `SoccerTerm` 型を追加する
- [x] 収録する用語を実文言から抽出する
  - [x] `src/data/matchups.ts` の優位ポイント・総合判定理由を走査する
  - [x] `src/data/radarAxes.ts` の軸説明・`src/data/formations.ts` の説明文を走査する
- [x] `src/data/soccerTerms.ts` を作成する（カテゴリ付き・説明は用語を使わず平易に）
- [x] `src/data/soccerTerms.test.ts` を作成する（id の一意性・必須項目の非空）

## フェーズ2: 一覧カードのフォーメーションプレビュー（機能①）

- [x] `src/components/FormationMiniPitch.vue` を作成する
  - [x] `cy = 100 - y` の上下反転で攻撃方向を上にする
  - [x] `role="img"` / `aria-label` を付ける
- [x] `src/components/FormationMiniPitch.test.ts` を作成する
  - [x] 11 ポジション分の円が描画される
  - [x] `y` が大きいポジションほど `cy` が小さい
  - [x] `aria-label` にフォーメーション名が含まれる
- [x] `src/components/FormationCard.vue` にミニピッチ図と説明文を組み込む
  - [x] 既存の選択トグル・キーボード操作・`aria-pressed` を壊さない
  - [x] カードが高くなってもグリッドのレイアウトが崩れないことを確認する
- [x] `src/components/FormationCard.test.ts` に検証を追加する

## フェーズ3: 比較画面の回遊性（機能②）

- [x] `src/pages/ComparisonPage.vue` に「⇄ 入れ替え」ボタンを追加する（`router.replace`）
- [x] A 側・B 側のフォーメーション切替セレクトを追加する
  - [x] 相手側で選択済みのフォーメーションを `disabled` にする
  - [x] 可視ラベル（`<label>`）を付ける
- [x] `MatchupPitchDiagram` に `:key` を与え、切替後も対戦演出が再生されるようにする
- [x] `src/pages/ComparisonPage.test.ts` に検証を追加する
  - [x] 入れ替えボタンで A/B 逆順の URL が `replace` される
  - [x] セレクト変更で正しい組み合わせが `replace` される
  - [x] 相手側で選択済みの `option` が `disabled` である
  - [x] `push` が呼ばれない

## フェーズ4: アプリ内サッカー用語集（機能③）

- [x] `src/pages/GlossaryPage.vue` を作成する（`<dl>` / カテゴリ別グルーピング）
- [x] `src/router/index.ts` に `/glossary` ルートを追加する
- [x] `src/pages/FormationListPage.vue` に用語集への導線を追加する
- [x] `src/pages/ComparisonPage.vue` に用語集への導線を追加する
- [x] `src/pages/GlossaryPage.test.ts` を作成する
  - [x] 全件が描画される
  - [x] 空配列でも落ちない

## フェーズ5: 品質チェックと修正

- [x] すべてのテストが通ることを確認
  - [x] `npm test`（10 files / 76 tests, all passed）
- [x] リントエラーがないことを確認
  - [x] `npm run lint`
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）
- [x] `npm run dev` で実際の画面を確認する（一覧・比較・用語集の3画面）
  - [x] 一覧画面: 全カードにミニピッチ図・説明文・用語集ボタンが表示される
  - [x] 比較画面: 入れ替えボタンでURL・優位ポイント・レーダーが正しく入れ替わる
  - [x] 用語集画面: カテゴリ別に全用語が表示される

## フェーズ6: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` に FR を追加する
      （作業時点ではFR-07〜09として追加。main統合時に相性マトリクス機能のFR-07と
      衝突したため、最終的にFR-08〜10へ採番し直した。詳細は`retrospective.md`参照）
- [x] `docs/specs/1_requirements/functional-overview.md` を更新する
  - [x] 画面一覧に用語集画面を追加
  - [x] 画面遷移図を更新
  - [x] モジュール構成図に `soccerTerms.ts` を追加
- [x] `docs/specs/1_requirements/glossary.md` に利用者向け用語の正本へのポインタを追記する
- [x] `docs/specs/1_requirements/repository-structure.md` の構成図・ファイル一覧を更新する
- [x] `docs/specs/2_basic-design/screen-design.md` を更新する（画面項目・画面イベント・新画面）
- [x] `docs/specs/2_basic-design/component-design.md` に新規コンポーネントを追記する
- [x] `docs/specs/3_detail-design/screen/` の既存2画面の詳細設計を更新し、`screen-03-glossary.md` を新規作成する
- [x] `docs/specs/4_unit-test/` のテスト仕様書を更新し、`test-screen-03-glossary.md` を新規作成する
- [ ] 実装後の振り返りを記録（別ファイル `retrospective.md` に記録 → モード3）

## フェーズ7: review-implementation指摘への対応

- [x] `soccerTerms.ts` にNFR-02未収録語（スペース・最終ライン・中盤・1対1）を追加し、
      説明文中の未収録専門用語（タッチライン・ゴールライン・局面・陣形）を平易な言い回しへ置換
- [x] `soccerTerms.test.ts` に「全件のtermが実文言のいずれかに登場する」不変条件テストを追加
- [x] `ComparisonPage.test.ts` に用語集リンク（`/glossary`）のhref検証を追加し、
      `test-screen-02-comparison.md` にケースNo.41として追記
- [x] `npm run format` を実行し、新規ファイルの整形漏れを解消
      （作業範囲外の `RadarChart.vue`/`RadarChart.test.ts`/`radarAxes.ts` への巻き込みは revert）
- [x] `ComparisonPage.vue`（418行）から A/B 選択UIを `components/ComparisonControls.vue` へ
      切り出し、コンポーネント250行の目安に近づける
  - [x] `ComparisonControls.test.ts` を新規作成
  - [x] `component-design.md` / `repository-structure.md` / `screen-02-comparison.md` /
        `test-screen-02-comparison.md` を切り出しに合わせて更新
- [x] `FormationCard.vue` の `FormationMiniPitch` に `aria-hidden="true"` を付与し、
      カードのアクセシブルネームの冗長性（配置図の説明文が二重に読み上げられる）を解消
- [x] `GlossaryPage.vue` の `categories`/`termsByCategory` の2つのcomputedを
      `groupedTerms` 1本に統合
- [x] 修正後、`npm test` / `npm run lint` / `npm run typecheck` / `npm run build` を再実行し
      全て成功することを確認（82 tests passed）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

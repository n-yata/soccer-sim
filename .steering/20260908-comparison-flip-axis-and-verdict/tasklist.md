# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

---

## フェーズ1: PitchDiagramの重なり対策（左右反転→左右オフセットへ方針転換）

- [x] （試行1・破棄）`playerCy`を常に`100 - y`に固定し`playerCx`で左右反転する実装を試みたが、
      `review-pre-commit`で「全フォーメーションが左右対称なため恒等変換に等しく効果がない」
      とCritical指摘を受け、シャビにも「重ね合わせはしろよ。それで左右に並べろ」と
      指摘された（反転ではなくオフセットを求めていた）
- [x] `offsetX` propsを新設し、選手のx座標に加算して右にずらすようにする（`flip`は廃止）
- [x] テンプレートのcircle/textの`x`/`cx`を`playerCx`（`x + offsetX`）経由に変更する
- [x] `ComparisonPage.vue`の2枚目に`offset-x="6"`を指定する
- [x] `PitchDiagram.test.ts`を更新する
  - [x] offsetX指定時にcxがその分ずれ、cyは変わらないことを検証するテストを追加
  - [x] offsetX省略時の後方互換テストを追加
  - [x] offsetX=6でも全フォーメーションの円がviewBox(0-100)からはみ出さないことを
        全走査で検証するテストを追加

## フェーズ2: Matchupへの総合優劣判定の追加

- [x] `Matchup`型に`overallEdge: "A" | "B" | "even"`と`overallReason: string`を追加する
- [x] `matchups.ts`の全6組み合わせに`overallEdge`/`overallReason`を記載する
- [x] `getMatchup`の入れ替えロジックに`overallEdge`の反転を追加する
- [x] `ComparisonPage.vue`に総合判定の見出し表示を追加する
- [x] `matchups.test.ts`を更新する
  - [x] 全走査でoverallEdge/overallReasonが設定されていることを検証するテストを追加
  - [x] 入れ替え時のoverallEdge反転（A→B, B→A, even→even）を検証するテストを追加
- [x] `ComparisonPage.test.ts`を更新する
  - [x] 入れ替え経由でoverallEdgeが反転した総合判定が表示されることを検証
  - [x] evenの組み合わせで「互角」と表示されることを検証

## フェーズ3: ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md`のFR-03/FR-04を更新する
- [x] `docs/specs/1_requirements/functional-overview.md`のER図・確定事項を更新する
- [x] `docs/specs/1_requirements/glossary.md`のピッチ図・マッチアップの説明を更新する
- [x] `docs/specs/2_basic-design/component-design.md`のPitchDiagram/ComparisonPageの
      責務・インターフェースを更新する
- [x] `docs/specs/2_basic-design/screen-design.md`のレイアウト説明・画面項目定義を更新する
- [x] `docs/specs/3_detail-design/screen/screen-02-comparison.md`の画面表示フローを更新する
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`のテストケースを追加する
      （ケース24-28）

## フェーズ4: 品質チェックと修正

- [x] すべてのテストが通ることを確認（`npm run test`）→ 50件全パス
- [x] リントエラーがないことを確認（`npm run lint`）→ 0 problems
- [x] 型エラーがないことを確認（`npm run typecheck`）→ 0エラー
- [x] ビルドが成功することを確認（`npm run build`）→ ビルド成功
- [x] 「フォーメーム」誤記の再発がないことを`grep`で確認

## フェーズ5: コミット前レビューとコミット

- [x] `review-pre-commit`スキルによるコミット前レビューを実施する（3回実施）
  - [x] 第1回: `flip`（左右反転）実装に対しCritical 1件・High 2件の指摘
        → 全フォーメーションが左右対称なため反転は恒等変換に等しく、重なりが悪化していた
  - [x] 第2回: `offsetX`（片側6）実装に対しHigh 1件の指摘
        → 別のポジションペアが新たに距離1.0まで接近することが判明
  - [x] 第3回: `offsetX`両側分担（-4.5/4.5）実装で再レビュー
        → Critical/Highなし。Medium 3件（ドキュメント記述漏れ2件、テスト恒真化対策1件）指摘
- [x] 指摘（Critical/High）に対応し再レビューする（上記の通り3巡で収束）
- [x] Medium指摘に対応する
  - [x] `test-screen-02-comparison.md` No.11の`offsetX=6`記述を`-4.5`/`4.5`に修正
  - [x] `glossary.md`/`screen-design.md`/`requirements-definition.md`の
        「一方だけ右にずらす」という旧記述を両側分担の表現に修正
  - [x] `ComparisonPage.test.ts`の距離検証テストに`circlesA/B.length > 0`の
        事前チェックを追加（circle 0件時の恒真化を防止）
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md`の完了チェック欄を更新する
- [x] 実装後の振り返りを記録（`retrospective.md`）
- [ ] コミット → mainへマージ → main側で再テスト・ビルド確認
- [ ] worktree撤去・ブランチ削除

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。全タスクが `[x]` になったことを確認してから作成すること。

# タスクリスト — 学習体験の強化（FR-11 / FR-12 / FR-13）

進捗: `[ ]` 未着手 / `[x]` 完了

## 0. 準備

- [x] worktree `../soccer-sim-worktrees/learning-reinforcement` とブランチ `feature/learning-reinforcement` を作成
- [x] `npm install` とベースライン確認（93テスト green）
- [x] ステアリング `requirements.md` / `design.md` を作成

## 1. FR-11 解説文の用語インライン表示

- [x] `src/types/formation.ts` に `TextSegment` 型を追加
- [x] `src/data/termAnnotation.ts` を作成（最長一致の切り出し。長さ降順インデックスはモジュール初期化時に一度だけ構築）
- [x] `src/data/termAnnotation.test.ts` — 最長一致・用語なし・用語のみ・連続用語・空文字・部分重複（最終ライン / ライン間）
- [x] `src/components/TermPopover.vue` を作成（説明の吹き出し）
- [x] `src/components/TermAnnotatedText.vue` を作成（`v-html` を使わずセグメント描画、`aria-expanded` / `aria-describedby`、Escape・外側クリックで閉じる）
- [x] `src/components/TermAnnotatedText.test.ts` — ボタン描画・押下で説明表示・Escape で閉じる・用語なしなら平文・同時に開くのは1つ
- [x] `src/pages/ComparisonPage.vue` の優位ポイントと総合判定理由を `TermAnnotatedText` へ置換
- [x] `src/pages/ComparisonPage.test.ts` に用語が注釈されることの検証を追加

## 2. FR-12 理解度チェック（クイズモード）

- [x] `src/types/formation.ts` に `QuizQuestion` / `QuizChoice` / `Shuffle` 型を追加
- [x] `src/data/quiz.ts` を作成（`buildQuiz`。shuffle 注入可能、問題数をハードコードしない）
- [x] `src/data/quiz.test.ts` — 3種別の生成・正解が1つだけ・決定的shuffleでの出力・フォーメーション4件未満のフォールバック・空データで空配列
- [x] `src/components/QuizQuestionCard.vue` を作成（設問表示・回答受付・確定後 disabled・正誤と解説の表示）
- [x] `src/components/QuizQuestionCard.test.ts` — 選択肢描画・回答emit・確定後の再回答不可・解説表示
- [x] `src/pages/QuizPage.vue` を作成（出題→回答→次へ→結果、再挑戦で状態オブジェクトごと作り直す、出題0件のフォールバック）
- [x] `src/pages/QuizPage.test.ts` — 進行・正答数・再挑戦での完全リセット・出題0件時の表示
- [x] `src/router/index.ts` に `/quiz` を追加
- [x] `src/pages/FormationListPage.vue` にクイズ画面への導線を追加

## 3. FR-13 学習進捗トラッキング

- [x] `src/types/formation.ts` に `LearningProgress` 型を追加
- [x] `src/data/learningProgress.ts` を作成（順序非依存キー・try/catch・形式検証・書き込み失敗でも続行）
- [x] `src/data/learningProgress.test.ts` — 順序非依存・localStorage例外時の空進捗・壊れたJSON・型不一致の拒否・消去・全組み合わせ件数
- [x] `src/pages/ComparisonPage.vue` で閲覧を記録（`watch` + `immediate`。A/B切替でも記録される）
- [x] `src/pages/ComparisonPage.test.ts` に記録の検証を追加（切替時・順序違いで二重計上しない）
- [x] `src/pages/MatrixPage.vue` に確認済みの印（色だけに頼らない）・進捗表示・消去ボタン（`window.confirm` を使わない2段階確認）を追加
- [x] `src/pages/MatrixPage.test.ts` — 確認済みの印・進捗の分母分子・消去で0に戻る・aria-labelに確認済みが含まれる

## 4. 検証

- [x] `npm test` が全件 green（218テスト）
- [x] `npm run typecheck` がエラーなし
- [x] `npm run lint` が指摘なし
- [x] `npm run build` が成功
- [x] 実ブラウザで動作確認 — **未実施**。Chrome拡張機能が本セッションで接続できなかったため、
      コンポーネント単位のDOM操作・キーボード操作・aria属性のテスト（218件）で代替した。
      レイアウト崩れ・視覚的な確認は`review-report.md`「未検証」に明記済み

## 5. ドキュメント更新

- [x] `docs/specs/1_requirements/requirements-definition.md` — FR-11/12/13 を §4 へ追加、§6.1 スコープへ追記、§4.3 画面対応表を更新
- [x] `docs/specs/1_requirements/functional-overview.md` — 画面一覧・画面遷移図・モジュール構成図・ユースケース一覧・データモデル（進捗の永続化）を更新
- [x] `docs/specs/1_requirements/repository-structure.md` — 新規ファイルを反映
- [x] `docs/specs/1_requirements/glossary.md` — 「学習進捗」を追加
- [x] `docs/specs/2_basic-design/component-design.md` — 新規コンポーネントの責務・インターフェース
- [x] `docs/specs/2_basic-design/screen-design.md` — クイズ画面のレイアウト・項目・イベント、画面数の更新（4→5画面）
- [x] `docs/specs/3_detail-design/screen/screen-05-quiz.md` — 新規（当初計画のscreen-04-quizから、相性マトリクス分をscreen-04-matrixとしたため番号を1つ後ろへ）
- [x] `docs/specs/3_detail-design/screen/screen-02-comparison.md` — 用語インライン表示・進捗記録を追記
- [x] `docs/specs/4_unit-test/test-screen-05-quiz.md` — 新規
- [x] `docs/specs/4_unit-test/test-screen-02-comparison.md` に追加テストケースを反映
- [x] 積み残しの対応: 相性マトリクス画面（FR-07）の画面設計・詳細設計・単体テスト仕様書が未作成（`bc78a7f` 由来）。
      `docs/specs/3_detail-design/screen/screen-04-matrix.md`・`docs/specs/4_unit-test/test-screen-04-matrix.md`を新規作成して整備した

## 6. 完了処理

- [x] `review-pre-commit` でコミット前レビュー（Critical 0 / High 0 / Medium 0 / Low 6件。うち2件を対応、詳細は`review-report.md`）
- [x] `retrospective.md` を作成
- [x] コミット
- [ ] PR 作成
- [ ] マージ後に worktree 撤去 → ブランチ削除

## 前作業からの積み残し（本作業で回収するもの）

`.steering/20260912-learning-experience/review-report.md` の第2回申し送りより:

- [x] リンク検証テストの先頭アンカー依存を、クラス指定へ寄せる
      （`FormationListPage.test.ts`・`MatrixPage.test.ts`の双方で対応）
- [x] `matchups` の全ペア網羅を検証する不変条件テストを追加する
      → 確認の結果、`matchups.test.ts`（既存）に既に実装済みだった（追加不要）

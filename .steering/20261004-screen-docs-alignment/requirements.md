# 要求内容

## 概要

実装（8画面・主ナビ6項目）と乖離した画面設計ドキュメント（ワイヤーフレーム drawio・画面設計・
コンポーネント設計・画面遷移図）を現状に整合させ、以後の画面変更で drawio を必ず同時更新する
ルールをプロジェクトに定義し、同種の抜けを防ぐ改善を spec-kit に申告する。

## 背景

- #8〜#10（自由配置ボード、ボール、戦術学習ハブ）で画面は8画面・主ナビ6項目になったが、
  `docs/specs/2_basic-design/wireframes.drawio` は2ページ（`wireframe-formation-list` /
  `wireframe-comparison`）のままで、主ナビも旧3項目（一覧／相性表／理解度チェック）を描いている。
- `screen-design.md` は画面遷移図節が「5画面のみ」、グローバルナビ説明が旧項目、ページヘッダー節が
  「全5画面」、自由配置ボード画面の節が無い。相性マトリクス・用語集・クイズはレイアウトが文章のみで
  drawio が無い。
- `component-design.md` に学習系・ボード系のページ／コンポーネント（`LearningListPage`、
  `FormationLearningPage`、`TacticalReplay*`、`FreeLayoutBoardPage`、`FreeLayoutPitchDiagram`、
  `BoardBall` 等）が記載されていない。
- 正本の `functional-overview.md` も、画面一覧には自由配置ボードがあるのに画面遷移図に
  `FreeLayoutBoardPage` が無い。
- 根本原因: 実装時に wireframe 更新を求める規定がどこにも無い。kit の `flow-add-feature`
  A-ステップ8-2 は「基本設計やアーキテクチャに影響があれば docs 更新」とあるのみで、画面変更が
  その判断から漏れる。`review-implementation` / `review-pre-commit` にも検出観点が無い。

## 実装対象の機能

### 1. wireframes.drawio の最新化
- 1ファイル複数ページ構成を維持し、全8画面（ルート）に1ページずつ対応させる。
  - 既存更新: `wireframe-formation-list`、`wireframe-comparison`（主ナビ6項目化、現行レイアウトへの追随）
  - 新規追加: `wireframe-learning-list`、`wireframe-formation-learning`、`wireframe-matrix`、
    `wireframe-glossary`、`wireframe-quiz`、`wireframe-free-layout-board`
- 既存ページの配色・凡例・要素表現の作法に合わせる（drawio MCP で編集する）。

### 2. screen-design.md の整合
- 画面遷移図節: 8画面であることを反映し、正本（functional-overview.md）参照に徹する。
- グローバルナビ節・ページヘッダー節: 実装（`AppHeader.vue` の6項目、PageHeader 利用画面）に合わせる。
- 全8画面の「レイアウト（ワイヤーフレーム）」節から、対応する drawio ページ名へリンクする。
- 戦術学習一覧画面・陣形学習画面の節を他画面と同じ構成（レイアウト／画面項目定義／画面イベント）に整理する。
- 自由配置ボード画面の節を新設する。

### 3. component-design.md の整合
- `src/pages/` と `src/components/` の全ファイルを、責務・依存関係付きで記載する
  （学習系・ボード系の追記が中心）。

### 4. functional-overview.md 画面遷移図の補修
- 画面遷移図に `FreeLayoutBoardPage`（AppHeader 経由）を追加する。

### 5. drawio 同時更新ルールの定義
- `docs/specs/1_requirements/repository-structure.md` に、プロジェクト固有規約として以下を理由付きで記載する。
  - 画面（`src/pages/`・ルート・主ナビ・画面レイアウト）を追加・変更する PR では、同一 PR で
    `wireframes.drawio` と `screen-design.md` を更新する。
  - ワイヤーフレームは1ファイル複数ページ（`wireframe-[画面slug]`）で管理する
    （kit ガイドの「画面ごとに別ファイル」との意図的な差分）。
- `AGENTS.md` の「プロジェクト固有の設定」欄（マーカー外）には参照リンクのみ置く（正本は1つ）。

### 6. spec-kit への申告
- `retrospective.md` に kit 改善提案として次の3点を記載する（受け渡し場所経由で kit が拾う）。
  1. `flow-add-feature` A-ステップ8-2 に「画面の追加・変更があれば wireframe（drawio）と画面設計を更新する」を明記
  2. `review-implementation`（必要なら `review-pre-commit`）に「画面差分があるのに wireframe 未更新」の検出観点を追加
  3. `flow-steering` の design テンプレートに「影響するワイヤーフレーム／画面設計」欄を追加

## 受け入れ条件

### 1. wireframes.drawio
- [ ] drawio のページ数が `src/router/index.ts` のルート数（8）と一致し、各ページ名が `wireframe-[画面slug]` 形式
- [ ] 全ページの主ナビ表記・順序が `AppHeader.vue`（フォーメーションを選ぶ／戦術を学ぶ／相性表／自由配置ボード／理解度チェック／用語集）と一致
- [ ] 各ページのタイトル・サブタイトルが対応する `*Page.vue` の PageHeader と一致
- [ ] 各ページの主要領域が screen-design.md の画面項目定義と対応している
- [ ] drawio MCP で全ページを開けて表示が崩れていない

### 2. screen-design.md
- [ ] 「5画面のみ」「全5画面」等、画面数・主ナビに関する旧記述が残っていない
- [ ] 全8画面の節が存在し、各レイアウト節が対応する drawio ページ名へリンクしている
- [ ] 戦術学習一覧・陣形学習・自由配置ボードの節にレイアウト／画面項目定義／画面イベントがある

### 3. component-design.md
- [ ] `src/pages/` と `src/components/` の全ファイルが責務付きで登場する

### 4. functional-overview.md
- [ ] 画面遷移図に `FreeLayoutBoardPage` があり、画面一覧の8画面すべてが遷移図に登場する

### 5. ルール定義
- [ ] repository-structure.md に同時更新ルールと1ファイル複数ページ構成が理由付きで記載されている
- [ ] AGENTS.md 固有設定欄に repository-structure.md への参照リンクのみがある（規則本文の重複なし）

### 6. kit 申告
- [ ] retrospective.md に kit 改善提案3点が、根拠（今回の乖離の経緯）付きで記載されている

### 共通
- [ ] アプリのコード（`src/`）を変更していない
- [ ] repository-structure.md 記載の検証コマンド（テスト・lint 等）が引き続きパスする

## 成功指標

- 画面数・主ナビについて、実装と設計ドキュメントの間に差分がゼロになる
- 以後の画面変更 PR で drawio と screen-design.md が同時に更新される運用が定着する

## スコープ外

以下はこのフェーズでは実装しません:

- `docs/specs/3_detail-design/screen/` と `docs/specs/4_unit-test/` への画面6〜8（戦術学習一覧・陣形学習・自由配置ボード）の追加
- アプリの機能・見た目の変更
- kit（spec-kit）側スキルの直接修正（申告のみ）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` - 要件定義書（プロダクトビジョン・KPI・機能一覧の正本）
- `docs/specs/1_requirements/functional-overview.md` - 機能概要（画面一覧・遷移図の正本）
- `docs/specs/1_requirements/architecture-overview.md` - アーキテクチャ概要
- `docs/specs/1_requirements/repository-structure.md` - プロジェクト固有規約の正本
- `docs/specs/2_basic-design/screen-design.md` / `component-design.md` / `wireframes.drawio`

## 未決事項

- 詳細設計（`3_detail-design/screen/`）・単体テスト仕様（`4_unit-test/`）の画面6〜8は別作業として切り出す。
  本作業の retrospective.md に後続作業として記録する。
- 比較画面ワイヤーフレームの現行レイアウトへの追随範囲（#4 の UI/UX 改善以降の差分）は、実装フェーズで
  現行 `ComparisonPage.vue` と突き合わせて判断する。

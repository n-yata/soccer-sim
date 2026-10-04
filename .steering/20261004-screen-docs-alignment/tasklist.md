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

## フェーズ1: 正本（functional-overview.md）の補修

- [x] 画面遷移図に `FreeLayoutBoardPage`（AppHeader経由）を追加
- [x] UC-06 の関連画面を自由配置ボード画面に修正
- [x] モジュール構成図に画面6〜8と参照データを追加

## フェーズ2: wireframes.drawio の最新化

- [x] 既存2ページの更新
  - [x] `wireframe-formation-list`: 主ナビ6項目化、サブタイトル・セクション見出し・選択状況を実装に合わせる
  - [x] `wireframe-comparison`: 主ナビ6項目化（現在地=フォーメーションを選ぶ）、サブタイトル追加
- [x] 新規6ページの追加
  - [x] `wireframe-learning-list`
  - [x] `wireframe-formation-learning`
  - [x] `wireframe-matrix`
  - [x] `wireframe-glossary`
  - [x] `wireframe-quiz`
  - [x] `wireframe-free-layout-board`
- [x] 機械チェック（XML パース・ページ数8・全ページ主ナビ6項目・タイトル/サブタイトル一致）
- [x] 目視確認（drawio MCP またはレンダリングで表示崩れが無いこと）

## フェーズ3: screen-design.md の整合

- [x] 共通事項（遷移図節・グローバルナビ節・ページヘッダー節）を8画面・6項目に修正
- [x] 画面3〜5のレイアウト節に drawio ページへのリンクを追加
- [x] 画面6（戦術学習一覧）・画面7（陣形学習）をレイアウト／項目定義／イベント構成で整理
- [x] 画面8（自由配置ボード）の節を新設
- [x] 「詳細設計への申し送り」を末尾へ移動
- [x] 旧記述 grep（「5画面」「全5画面」等）0件を確認

## フェーズ4: component-design.md の整合

- [x] AppHeader 節・PageHeader 節を現状に修正
- [x] 学習系（LearningListPage, FormationLearningPage, TacticalReplay, TacticalReplayPlayer, TacticalReplayPitch, tacticalReplayFrame）を追記
- [x] ボード系（FreeLayoutBoardPage, FreeLayoutPitchDiagram, freeLayoutCoordinates, BoardBall）を追記
- [x] データ層（formationLessons/lessons/tacticalScenes, freeLayoutStorage, boardBallStorage）を追記
- [x] `src/pages`・`src/components` 全ファイルの登場を grep で確認

## フェーズ5: ルール定義

- [x] repository-structure.md「汎用規約からの差分」に同時更新ルールと1ファイル複数ページ構成を理由付きで追加
- [x] AGENTS.md 固有設定欄に参照リンクのみ追加

## フェーズ6: 品質チェックと修正

- [x] `src/` に差分が無いことを確認（`git diff --stat -- src`）
- [x] すべてのテストが通ることを確認
  - [x] `npm test`
- [x] リントエラーがないことを確認
  - [x] `npm run lint`
- [x] 型エラーがないことを確認
  - [x] `npm run typecheck`
- [x] ビルドが成功することを確認
  - [x] `npm run build`
- [x] **テストが実際に実行されたことを確認**（実行件数・スキップ数）: 35ファイル・508件成功、スキップ0

## フェーズ7: レビューと振り返り

- [x] review-implementation（ドキュメントと実装の整合）を実施し指摘を反映（総合4.6/5。[必須]retrospective未作成は本フェーズで解消、[推奨]4件・[提案]4件を反映）
- [x] review-pre-commit を実施し review-report.md を出力（Critical/High 収束まで）: 第1回で Critical/High 0件
- [x] retrospective.md を作成（レビュー要約・kit 申告3点・後続作業）

---

> **振り返りについて**: 実装後の振り返りはこのファイルではなく、同じディレクトリの
> `retrospective.md` に記録する。

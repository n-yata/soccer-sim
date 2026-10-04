# 設計書

## アーキテクチャ概要

ドキュメントのみの変更。アプリコード（`src/`）は変更しない。正本の依存方向
（`functional-overview.md` → `2_basic-design/`）を守り、正本側の欠落を先に補修してから
基本設計を追随させる。

```
functional-overview.md（画面一覧・遷移図・UC・モジュール構成図の正本）
   ↓ 参照
screen-design.md ──リンク──> wireframes.drawio（8ページ）
component-design.md（src/pages・src/components の責務）
repository-structure.md（同時更新ルールの正本） <── AGENTS.md 固有設定欄（参照リンクのみ）
```

## コンポーネント設計

### 1. wireframes.drawio

**責務**:
- 全8画面の外観（要素の有無・大まかな配置）を示す。ページ名 `wireframe-[画面slug]`。

**実装の要点**:
- drawio デスクトップ／MCP 経由の手作業ではなく、XML（非圧縮 `mxGraphModel`）を直接編集する。
  既存ファイルが非圧縮 XML で、差分レビューが容易なため。
- 共通パーツ（AppHeader 50px バー、PageHeader 白背景＋下境界1px）は既存ページのスタイル値
  （`#FFFFFF`/`#E5E7EB`/`#0F172A`/`#475569`、選択色 `#15803D`、カード `arcSize=14` 等）を踏襲する。
- 主ナビ6項目は `AppHeader.vue` の順序・文言どおり。現在地は緑（`#15803D`）、他はグレー（`#6B7280`）。
  `isActive` に従い、比較画面は「フォーメーションを選ぶ」、陣形学習画面は「戦術を学ぶ」を現在地にする。
- アイコンは既存の絵文字表記（⚽ ✏️ 📖）を記号として踏襲する（ワイヤーフレーム上の表現であり、実装は lucide）。
- ページ幅 827px（既存と同じ）。ブランドの幅を詰めて6項目を収める。
- 各ページ末尾に注記（灰色イタリック）で、ワイヤーフレームが示さない挙動（アニメーション・
  レスポンシブ・状態）を1行で補足する（既存の比較画面ページの作法）。

| ページ | 主要領域 |
|---|---|
| formation-list | hero ヘッダー（⚽タイトル・サブタイトル・Jリーグ外部リンク）、「比較したい2つを選ぶ」＋選択状況、8カード、フッター注記 |
| comparison | 戻る＋タイトル＋サブタイトル、総合判定、A/B凡例、ピッチ見出し、重ね合わせピッチ＋レーダー、優位ポイント2カラム、別の組み合わせ（セレクト・入れ替え） |
| learning-list | ヘッダー、導入文、8枚のリンクカード（ミニピッチ・陣形名・場面名・目的・「この陣形を学ぶ →」） |
| formation-learning | 「← 学習一覧へ」、ヘッダー、陣形切替タブ8個、基本配置ミニピッチ＋「この陣形で学ぶこと」、役割一覧、戦術再生（開いた状態: ピッチ・凡例・解説・進捗・操作4ボタン）、用語の折りたたみ |
| matrix | 戻る＋ヘッダー、凡例、進捗＋消去ボタン、表の説明、8×8表（対角・行優位・列優位・互角・チェック） |
| glossary | 戻る＋📖ヘッダー、検索入力・件数、カテゴリ見出し＋2カラム定義リスト |
| quiz | 戻る＋ヘッダー、進捗文＋バー、設問カード（選択肢・正誤・解説）、次へボタン |
| free-layout-board | ヘッダー、青/赤の陣形セレクト＋リセット、ボールを中央に戻す、操作説明、ピッチ（青11・赤11・ボール）、攻撃方向 |

### 2. screen-design.md

**責務**: 各画面のレイアウト・画面項目定義・画面イベント。

**実装の要点**:
- 遷移図節は「8画面」に直し、正本参照に徹する（遷移の列挙を再掲しない）。
- グローバルナビ節を6項目＋現在地ルール（正本は functional-overview「学習の導線」）に直す。
  「ワイヤーフレームはグローバルナビ追加前のものを維持」の記述は削除する。
- ページヘッダー節を PageHeader 利用画面（陣形学習は戻るボタンの代わりに「学習一覧へ」リンク）に直す。
- 画面番号: 1一覧 / 2比較 / 3マトリクス / 4用語集 / 5クイズ（既存維持）/ 6戦術学習一覧 / 7陣形学習 / 8自由配置ボード。
  現在の「画面6」節を画面6・7へ分割し、「詳細設計への申し送り」は末尾へ移す。
- 項目定義・イベントは実装（各 `*Page.vue`）から起こす。

### 3. component-design.md

**責務**: `src/pages`・`src/components` 全ファイルの責務・インターフェース・依存関係。

**実装の要点**: 既存の節形式（責務／インターフェース／依存関係）で追記する。対象:
`LearningListPage`、`FormationLearningPage`、`FreeLayoutBoardPage`、`TacticalReplay`、
`TacticalReplayPlayer`、`TacticalReplayPitch`、`tacticalReplayFrame.ts`、`FreeLayoutPitchDiagram`、
`freeLayoutCoordinates.ts`、`BoardBall`、データ層 `formationLessons`/`lessons`/`tacticalScenes`/
`freeLayoutStorage`/`boardBallStorage`。AppHeader 節の旧ナビ記述も直す。PageHeader 節の
「グラデーション背景」記述も現状（白背景・hero variant）に直す。

### 4. functional-overview.md

- 画面遷移図に `FreeLayoutBoardPage`（AppHeader経由）を追加。
- UC-06 の関連画面を「自由配置ボード画面」に直す（比較画面からの自由配置は d2f7bd8 で撤去済み）。
- モジュール構成図に画面6〜8と参照データを追加。

### 5. repository-structure.md / AGENTS.md

- 「汎用規約からの差分」に2項目を理由付きで追加:
  (a) 画面変更 PR での wireframe・screen-design 同時更新義務（対象パス・チェック方法を含む）
  (b) wireframe は1ファイル複数ページ（kit ガイドは画面ごとの別ファイル）
- `docs/` 配下の説明に wireframes.drawio のページ構成への言及を追加。
- AGENTS.md「プロジェクト固有の設定」（マーカー外）の「（未記入）」を参照リンク1行に置換。

## データフロー

該当なし（ドキュメント変更のみ）。

## エラーハンドリング戦略

該当なし。drawio の XML 破損を防ぐため、編集後に XML パースとページ数・主ナビ文言の機械チェックを行う。

## テスト戦略

### ユニットテスト
- アプリコード無変更のため追加なし。既存 `npm test` が引き続きパスすることのみ確認。

### ドキュメント検証
- drawio: XML パース成功、`<diagram>` が8個、各ページに主ナビ6項目の文言、ページ名がルートと対応。
- drawio MCP が使える場合は各ページを開いて表示崩れを目視確認。
- screen-design.md: 「5画面」「全5画面」等の旧記述の grep が0件、`wireframe-` リンクが8画面分。
- component-design.md: `src/pages`・`src/components` の全ファイル名が登場することを grep で確認。

## 依存ライブラリ

なし。

## ディレクトリ構造

```
docs/specs/1_requirements/functional-overview.md   （更新）
docs/specs/1_requirements/repository-structure.md  （更新）
docs/specs/2_basic-design/wireframes.drawio        （更新: 2→8ページ）
docs/specs/2_basic-design/screen-design.md         （更新）
docs/specs/2_basic-design/component-design.md      （更新）
AGENTS.md                                          （マーカー外の固有設定欄のみ更新）
.steering/20261004-screen-docs-alignment/          （requirements/design/tasklist/review-report/retrospective）
```

## 実装の順序

1. functional-overview.md（正本）の補修
2. wireframes.drawio（既存2ページ更新 → 6ページ追加 → 機械チェック）
3. screen-design.md
4. component-design.md
5. repository-structure.md / AGENTS.md
6. 検証 → レビュー → 振り返り（kit 申告）

## セキュリティ考慮事項

- ドキュメントに実 URL・キーを書かない（Jリーグリンクは「外部サイト」表記のみ、環境変数名で参照）。

## パフォーマンス考慮事項

該当なし。

## 将来の拡張性

- 画面追加時は drawio にページ `wireframe-[slug]` を1枚足し、screen-design.md に節を足す運用で拡張できる。

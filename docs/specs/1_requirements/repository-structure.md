# リポジトリ構造: フォーメーションラボ

> 汎用規約の正本は `/kit-guidelines`。本ファイルには**このプロジェクト固有の内容だけ**を書く。
> コーディング規約・Git 運用・テスト戦略・命名規則・ロギング・シークレット管理・依存関係管理・
> 図版管理は `/kit-guidelines` を参照すること。

作成日: 2026-09-06
工程: 要件定義 — **技術スタックを反映した具体的なディレクトリ構造**

## このドキュメントの役割

**このプロジェクトに実在するディレクトリ構造**を定義する。物理配置の正本。
あわせて、環境変数一覧・セットアップ手順・CI/CD などこのプロジェクト固有の運用情報と、
汎用規約から意図的に外れる差分をここに集約する。

## プロジェクト構造

Vue + TypeScript + Vite の標準的な構成をベースに、バックエンドを持たない本プロダクトの
実態に合わせた構造とする。

```
soccer-sim/
├── src/
│   ├── main.ts                  # エントリーポイント
│   ├── App.vue                  # ルートコンポーネント
│   ├── router/
│   │   └── index.ts             # Vue Router 定義（一覧・比較・相性マトリクス・用語集・クイズ・リーグ戦画面のルート）
│   ├── pages/
│   │   ├── FormationListPage.vue  # フォーメーション一覧画面
│   │   ├── ComparisonPage.vue     # 比較画面
│   │   ├── MatrixPage.vue         # 相性マトリクス画面
│   │   ├── GlossaryPage.vue       # サッカー用語集画面
│   │   ├── QuizPage.vue           # 理解度チェック（クイズ）画面
│   │   └── LeaguePage.vue         # リーグ戦（総当たり1回戦の勝ち点表・全対戦結果）画面
│   ├── components/
│   │   ├── FormationCard.vue        # フォーメーションカード（一覧画面の選択UI）コンポーネント
│   │   ├── FormationMiniPitch.vue   # フォーメーション単体のミニピッチ図（SVG描画）コンポーネント
│   │   ├── ComparisonControls.vue   # 比較画面のA/B入れ替え・切替UIコンポーネント
│   │   ├── MatchupPitchDiagram.vue  # 2フォーメーション重ね合わせピッチ図（SVG描画）コンポーネント
│   │   ├── FreeLayoutPitchDiagram.vue # 自由配置モードのピッチ図（実座標の線形マッピング描画・Aチームのドラッグ受付）
│   │   ├── freeLayoutCoordinates.ts   # FreeLayoutPitchDiagram用の座標変換純粋関数（DOM非依存）
│   │   ├── FreeLayoutControls.vue     # 自由配置モードのトグル・リセットボタンUIコンポーネント
│   │   ├── TermAnnotatedText.vue    # 解説文中のサッカー用語をボタン化し説明を開閉するコンポーネント
│   │   ├── TermPopover.vue          # サッカー用語1件の説明を表示する吹き出し
│   │   ├── QuizQuestionCard.vue     # クイズの設問1問の表示・回答受付コンポーネント
│   │   └── MatchSimulationPanel.vue # 試合シミュレーション結果（スコア・ポゼッション・タイムライン）表示コンポーネント
│   ├── composables/
│   │   ├── matchSimulation.ts   # 試合シミュレーションの計算ロジック（純粋関数。`simulateMatch`）
│   │   └── leagueSimulation.ts  # 総当たり1回戦の集計・順位算出ロジック（純粋関数。`runLeagueSimulation`）
│   ├── data/
│   │   ├── formations.ts        # フォーメーション定義（静的データ）
│   │   ├── matchups.ts          # マッチアップ解説文（静的データ）
│   │   ├── soccerTerms.ts       # サッカー用語定義（静的データ）
│   │   ├── termAnnotation.ts    # 解説文を「平文/用語」へ切り出す純粋関数（副作用なし）
│   │   ├── quiz.ts              # フォーメーション・マッチアップからクイズ設問を生成する純粋関数（副作用なし）
│   │   ├── radarScoreEstimator.ts # 自由配置モード用: タグ差分からレーダースコアを概算する純粋関数
│   │   └── learningProgress.ts  # 学習進捗の読み書き（`localStorage`。副作用を持つ唯一のdata/モジュール）
│   └── types/
│       └── formation.ts         # Formation・Position・Matchup・SoccerTerm・QuizQuestion・LearningProgress 等の型定義
├── public/                      # 静的アセット（favicon等）
├── docs/                        # プロジェクトドキュメント
├── index.html                   # Vite エントリーHTML
├── vite.config.ts               # Vite設定
├── tsconfig.json                # TypeScript設定
└── package.json
```

## ディレクトリ詳細

### src/ 配下

#### pages/

**役割**: 画面単位のトップレベルコンポーネント。ルーティング対象となる。

**配置ファイル**:
- `FormationListPage.vue`: フォーメーション一覧表示・比較対象の選択（FR-01, FR-02, FR-08）
- `ComparisonPage.vue`: ピッチ図重ね合わせ表示・優位ポイント表示（用語インライン表示付き）・
  A/B入れ替え・切替・学習進捗の記録・自由配置モードの状態管理
  （FR-03, FR-04, FR-09, FR-11, FR-13, FR-15）
- `MatrixPage.vue`: 全フォーメーションの相性をN×Nの表で一覧表示・学習進捗の可視化と消去
  （FR-07, FR-13）
- `GlossaryPage.vue`: サッカー用語一覧表示（FR-10）
- `QuizPage.vue`: クイズの出題進行・結果表示・再挑戦（FR-12）
- `LeaguePage.vue`: 全フォーメーション総当たり1回戦の勝ち点表・全対戦結果一覧の表示、
  比較画面への遷移（FR-16）

**依存関係**:
- 依存可能: `components/`, `composables/`, `data/`, `types/`
- 依存禁止: 他の `pages/` から直接インポートしない（画面間のデータ受け渡しはルートパラメータ経由）

#### components/

**役割**: 複数画面から再利用しうる表示コンポーネント。

**配置ファイル**:
- `FormationCard.vue`: フォーメーション1件のカード表示（ミニピッチ図・説明文含む）・
  選択状態の表示・クリック（キーボード操作含む）イベントのemit
  （`screen-01-formation-list.md`参照）
- `FormationMiniPitch.vue`: 1つのフォーメーション（formation）の選手配置を、攻撃方向を
  上にした縦向きのミニピッチ図としてSVGで描画する表示専用コンポーネント
- `ComparisonControls.vue`: 比較画面のA/B入れ替えボタン・フォーメーション切替セレクトを
  表示する。フォーメーション一覧をpropsで受け取り、`swap`/`select-a`/`select-b`をemitする
  だけの表示専用コンポーネント（ルーティングは呼び出し元の`ComparisonPage`が行う）
- `MatchupPitchDiagram.vue`: 2つのフォーメーション（formationA/formationB）を1つの
  ピッチ図上に重ねてSVGで描画する（`pages/` からフォーメーションデータを受け取って
  描画するだけの表示コンポーネント）
- `FreeLayoutPitchDiagram.vue`: 自由配置モード（FR-15）用のピッチ図。実座標(0-100)を
  `freeLayoutCoordinates.ts`で線形マッピングして描画し、Aチームの選手のみドラッグ操作を
  受け付ける。内部にドラッグ座標のstateを持たず、`update-position`イベントで
  呼び出し元（`ComparisonPage`）へ通知するだけの表示専用コンポーネント
- `freeLayoutCoordinates.ts`: `FreeLayoutPitchDiagram.vue`専用の座標変換（実座標↔SVG座標、
  ピッチ範囲へのクランプ）を行う、DOM非依存の純粋関数群
- `FreeLayoutControls.vue`: 自由配置モードのトグル・リセットボタンを表示する。
  現在の有効状態（isActive）をpropsで受け取り、`toggle`/`reset`をemitするだけの
  表示専用コンポーネント（状態管理は呼び出し元の`ComparisonPage`が行う）
- `TermAnnotatedText.vue`: 表示するテキスト（text）をpropsで受け取り、`data/termAnnotation.ts`
  で「平文/用語」に切り出してボタン化する。用語ボタンの開閉状態は自身で持つ
- `TermPopover.vue`: サッカー用語（term）1件をpropsで受け取り、説明を吹き出し表示する
  表示専用コンポーネント
- `QuizQuestionCard.vue`: クイズの設問（question）と回答状態（answeredChoiceId）をpropsで
  受け取り、選択肢の表示・`answer`イベントのemit・正誤と解説の表示を行う
- `MatchSimulationPanel.vue`: 試合シミュレーション結果（`MatchSimulationResult`）と
  両フォーメーション名をpropsで受け取り、スコアボード・ポゼッションバー・
  シュート/枠内シュートの対比・ハイライトタイムラインを表示する表示専用コンポーネント
  （シミュレーションの計算自体は行わない。呼び出し元の`ComparisonPage`が
  `composables/matchSimulation.ts`を呼んで結果をpropsで渡す）

**依存関係**:
- 依存可能: `types/`
- 依存禁止: `pages/`、`composables/`、`data/`配下の**静的データ定義**（`formations.ts` /
  `matchups.ts` / `soccerTerms.ts`）と**副作用を持つモジュール**（`learningProgress.ts`）
- **例外的に依存可能**: `data/`配下の**副作用を持たない純粋関数**（`termAnnotation.ts`）。
  コンポーネントはpropsで受け取ったテキストを注釈表示するために直接呼び出す。
  データを保持・取得するのではなく、受け取った値を加工するだけであるため、
  「コンポーネントはpropsを経由してデータを受け取る」という原則を破らない
  （`quiz.ts`はpages層で呼び出し、結果をpropsで渡すため、コンポーネントからは呼ばない）

#### composables/

**役割**: UIレイヤーとデータレイヤーの間に置く計算ロジック層（`architecture-overview.md`
「アーキテクチャパターン」の3層構成に対応）。

**配置ファイル**:
- `matchSimulation.ts`: 2つのフォーメーション（Formation）と組み合わせ（Matchup）を
  受け取り、90分・1分刻みのイベント駆動シミュレーションを実行して`MatchSimulationResult`を
  返す純粋関数（`simulateMatch`）。シード付きPRNG（mulberry32）で決定的に乱数を生成する
- `leagueSimulation.ts`: フォーメーション一覧（Formation[]）とマッチアップ取得関数を
  受け取り、総当たり1回戦（n(n-1)/2試合）を`matchSimulation.ts`の`simulateMatch`で実行して
  勝ち点表（`LeagueStanding[]`）・全対戦結果（`LeagueMatchResult[]`）を返す純粋関数
  （`runLeagueSimulation`）。マッチアップ取得は`data/`層への依存を避けるため関数として
  引数注入する（`simulateMatch`は同じ`composables/`層のため既定引数として直接利用）

**依存関係**:
- 依存可能: `types/`、同階層の`composables/`（`leagueSimulation.ts`が`matchSimulation.ts`を利用）
- 依存禁止: `pages/`、`components/`、`data/`（`formations.ts`/`matchups.ts`等の
  静的データモジュールをimportしない。必要なFormation/Matchupの実体は、呼び出し元の
  UIレイヤーが引数として渡す）

#### data/

**役割**: フォーメーション定義・マッチアップ解説文・サッカー用語定義の静的データ
（`functional-overview.md`「データモデル」に対応）。

**配置ファイル**:
- `formations.ts`: フォーメーションIDごとのポジション配置定義
- `matchups.ts`: フォーメーションの組み合わせごとの戦術解説文
- `soccerTerms.ts`: 用語集画面で表示するサッカー用語の定義（他エンティティとは独立）
- `termAnnotation.ts`: 解説文を「平文/用語」の区間へ切り出す純粋関数（`annotateText`）。
  副作用を持たず、`soccerTerms.ts`を加工するだけのロジックのため、`components/`からの
  依存を例外的に許可している（詳細は上記`components/`の依存関係を参照）
- `quiz.ts`: `formations.ts`/`matchups.ts`からクイズ設問を生成する純粋関数（`buildQuiz`）。
  乱数（並べ替え）を注入可能にしており、本番コードとテストで実装を分けずに決定的な
  検証を可能にしている
- `learningProgress.ts`: 学習進捗（確認済みの組み合わせ）を`localStorage`へ読み書きする。
  `data/`配下で唯一副作用を持つモジュール。読み込み時に保存値の形式を検証し、
  壊れたデータは空の進捗として扱う（利用者が`localStorage`を直接書き換えられるため）
- `radarScoreEstimator.ts`: 自由配置モード（FR-15）用。タグ構成の差分（ドラッグ前後で
  新たに立った/消えたタグ）から、元のレーダースコア（`FormationStats`）を基準に概算する
  純粋関数（`estimateStats`）。`formationTags.ts`と同様、positions/Formationは直接見ず
  タグ配列のみを入力にする

**依存関係**:
- 依存可能: `types/`
- 依存禁止: `pages/`, `components/`（データレイヤーはUIレイヤーに依存しない。
  `architecture-overview.md`「アーキテクチャパターン」参照）

#### types/

**役割**: プロジェクト全体で使う型定義（`Formation`, `Position`, `PositionType`, `Matchup` 等）。

### docs/ 配下

**配置ドキュメント**:
- `docs/specs/1_requirements/`: 要件定義工程の成果物（要件定義書・非機能要件定義書（該当なし）・
  機能概要・アーキテクチャ概要・リポジトリ構造（本書）・用語集）
- `docs/specs/2_basic-design/`: 基本設計（コンポーネント設計・画面設計・ワイヤーフレーム）
- `docs/specs/3_detail-design/`: 詳細設計（画面詳細設計書）
- `docs/specs/4_unit-test/`: 単体テスト仕様書
- `docs/specs/5_integration-test/`: 該当なし（本プロダクトは実DBを持たないため結合テストは対象外）
- `docs/ideas/`: 壁打ちで作成した初期要求メモ

## 機能追加時の配置方針

新しい機能を追加する際の配置方針:

1. **小規模機能**（例: フォーメーションの追加）: `data/formations.ts` へのデータ追加のみで対応する
2. **中規模機能**（例: 試合シミュレーション機能。FR-14として2026-09-13実装済み）:
   `src/composables/` を新設し、`pages/` から呼び出すロジック層として分離する
3. **大規模機能**（例: バックエンドAPIの追加）: `architecture-overview.md` のレイヤー構成の
   見直しから着手する

> 各レイヤーへの追加パターンの一般論は `reference/rules/naming-and-placement.md`
> 「機能追加時のスケーリング」を正本とする。

## 開発環境セットアップ

| ツール   | バージョン | インストール方法 |
| -------- | ---------- | ---------------- |
| Node.js  | 20系 LTS   | 公式サイトまたはバージョン管理ツール（nvm等）でインストール |
| npm      | Node.js に同梱 | 追加インストール不要 |

## 環境変数（`.env`）一覧

該当なし。本プロダクトはバックエンド・外部API・シークレットを持たないため、環境変数は
使用しない。

## セットアップ手順

```bash
npm install
npm run dev
```

## CI/CD

未導入。個人開発規模かつ静的サイトのため、当面は手動でのビルド確認で十分と判断する。
チームでの共同開発や公開運用を始める場合に、Lint/型チェック/テストを実行するCIの導入を
検討する。

## 汎用規約からの差分

- **kit専用スキルの配布を受容している**: `.claude/skills/` には kit-mcp の `get_stubs` が
  返す22件のスタブをそのまま配置している。このうち `kit-contribute` と `review-skills` は
  各SKILL.mdのdescription自体に「利用側プロジェクトでは使用しない」「kitリポジトリ専用」と
  明記されたkit専用スキルであり、本来このリポジトリには不要である。
  - **理由**: `get_stubs` が利用側専用スキルとkit専用スキルを区別せず全件返す配布仕様のため。
    利用側だけでこの2件を除外すると、次の `/kit-sync` 実行時に「kitにあるが構築先に無いもの」
    として再配置され、矛盾が生じる。
  - **リスクと受容判断**: descriptionによる発火条件のガードがあるため通常は誤発火しないが、
    「還元」「振り返りをまとめて」等の依頼で誤って発火する経路はゼロではない。開発者と協議の
    上、リスクを認識した上でそのまま受容することとした（2026-09-06）。
  - **申し送り**: kit側の配布仕様の問題として、`kit-contribute` の受け渡し経路を通じて
    フィードバック済み（`.steering/20260906-initial-setup/retrospective.md` 参照）。

## 書かないこと（`/kit-guidelines` が正本）

| 内容                                               | 正本                                                                                                  |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| ファイル配置規則・命名規則・レイヤー間依存のルール | `<kit>/reference/rules/naming-and-placement.md`                                                                  |
| `.steering/` の運用                                | `<kit>/reference/rules/steering.md`                                                                              |
| `.gitignore` の除外設定                            | `<kit>/reference/rules/gitignore.md`                                                                             |
| エージェント設定ディレクトリの扱い                 | `<kit>/reference/host-rules.md`                                                                             |
| ファイルサイズの管理・分割方針                     | 関数単位は `<kit>/reference/rules/coding-common.md`、ファイル/コンポーネント単位は `<kit>/reference/rules/coding-typescript-vue.md` |

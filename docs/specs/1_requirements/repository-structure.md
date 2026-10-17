# リポジトリ構造 — soccer-game（仮称）

**更新日**: 2026-10-17

> **このプロジェクトに実在する（または開発環境の構築時に作る）ディレクトリ構造**を定義する。物理配置の正本。
> あわせて、セットアップ手順・CI/CD などこのプロジェクト固有の運用情報と、汎用規約から意図的に外れる
> 差分をここに集約する。
>
> ファイル配置規則・命名規則・レイヤー間依存の一般論、GDScript のコーディング規約、`.gitignore` の
> 共通エントリ、図版の管理方法は kit の `reference/rules/` が正本である（索引は `/kit-guidelines`）。
> **ここには再掲しない。** 依存方向・レイヤー責務の論理的な正本は `architecture-overview.md`。
> 本書はそれを物理構造に対応させる。

## プロジェクト構造

`（未作成）` は開発環境の構築時に作るもの。それ以外は現時点で実在する。

```
soccer-game/
├── AGENTS.md                      # 進め方・必ず守ることの正本（kit が生成する区間を含む）
├── CLAUDE.md                      # AGENTS.md へのポインタ
├── .mcp.json                      # MCP サーバーの接続設定（kit-mcp の spec-kit と drawio）
├── .gitignore / .gitattributes
├── .claude/                       # kit の配布物（skills はスタブ、hooks は実体）
├── .steering/                     # 作業ごとの計画・レビューレポート・振り返り
├── docs/
│   ├── ideas/                     # 壁打ちメモ（自由形式）
│   ├── specs/
│   │   ├── 1_requirements/        # 要件定義工程の6ドキュメント（本書を含む）
│   │   ├── 2_basic-design/        # 基本設計（screen-design.md・wireframes.drawio などを置く）
│   │   ├── 3_detail-design/       # 詳細設計（DB 設計書は作らない。functional-overview.md「データモデル」）
│   │   ├── 4_unit-test/
│   │   └── 5_integration-test/
├── game/                          # Godot プロジェクト（未作成）
│   ├── project.godot
│   ├── export_presets.cfg.example # 鍵を含まない書き出し設定の共有用（本物の export_presets.cfg は除外）
│   ├── addons/gdUnit4/            # テストフレームワーク（同梱して固定）
│   ├── domain/                    # ドメイン層（純粋ロジック。Node 非依存）
│   ├── application/               # アプリケーション層（試合進行・画面遷移・保存の呼び出し）
│   ├── data/                      # データ層（静的データの読み込み・端末内保存）
│   ├── ui/                        # UI 層（画面・2D 作戦ボード・3D 演出）
│   ├── content/                   # 静的データ（JSON）
│   ├── config/                    # 調整値（Resource .tres）
│   ├── assets/                    # 3D 素材・テクスチャ・音・フォント（ライセンス台帳 LICENSES.md を含む）
│   └── tests/                     # gdUnit4 のテスト
└── tools/                         # 開発補助スクリプト
    └── mcp/drawio-mcp.mjs         # drawio MCP を空きポートで起動するラッパー
```

## ディレクトリ詳細

### game/ 配下

Godot プロジェクトはリポジトリ直下ではなく `game/` に置く。`docs/`・`.steering/`・`.claude/` を
Godot のインポート対象から外し、書き出し（エクスポート）に紛れ込ませないためである。

#### game/domain/

**役割**: `functional-overview.md`「アルゴリズム設計」1〜10 を実装する純粋ロジック
（`architecture-overview.md`「ドメイン層」）。

**配置ファイル**:
- `game_enums.gd`: 区分値（`Lane`・`Zone`・`DefenseStyle` など。`functional-overview.md`「エンティティと区分値」）を集約するクラス
- 直下のその他のファイル: 値オブジェクト（クラスの一覧は `docs/specs/2_basic-design/component-design.md` §2.2）
- `config/`: 調整値の Resource のクラス（`.tres` 本体は `game/config/`。ドメインが引数で受け取るためドメイン層に置く）
- `layout/`: 基本配置の導出・現在配置の算出・守備の手による移動（アルゴリズム1・2・4）
- `judge/`: 選択可能な手・攻守ターン・トランジションの判定（アルゴリズム3・5・6）
- `match/`: キックオフ・ハーフ・試合終了の進行規則（アルゴリズム7）
- `cpu/`: CPU の選択（アルゴリズム8）
- `commentary/`: 解説の導出（アルゴリズム9）
- `review/`: 振り返り集計（アルゴリズム10）

**依存関係**:
- 依存可能: `game/domain/` 内のみ
- 依存禁止: `application/`・`data/`・`ui/`。API の禁止事項は `architecture-overview.md`「ドメイン層」が正本（自動チェックは NFR-13）

#### game/application/

**役割**: 試合の状態遷移、ターンごとのドメイン呼び出し、保存のタイミング制御、乱数生成器の生成と注入。

**依存関係**:
- 依存可能: `domain/`・`data/`
- 依存禁止: `ui/`（UI へはシグナルで通知する）

#### game/data/

**役割**: `content/` の JSON と `config/` の `.tres` の読み込み、`user://` 配下の保存データ（中断データ・戦績・回答結果・設定）の読み書き。読み込んだデータはドメインの値オブジェクトへ変換して渡す。

**依存関係**:
- 依存可能: `domain/`（値オブジェクトの型）
- 依存禁止: `application/`・`ui/`

#### game/ui/

**役割**: 画面（S-01〜S-12）、2D 作戦ボード、3D 演出。

**配置ファイル**:
- `screens/`: 画面ごとのシーンとスクリプト。ディレクトリ名は画面 ID と画面の英語名（例: `s03_match/`）
- `board2d/`: 2D 作戦ボードの部品（エリア・人数・優劣記号・動きの矢印）
- `replay3d/`: 3D 演出のシーン（ターン記録から生成する再生専用の表現）
- `common/`: 画面をまたいで使う部品

**依存関係**:
- 依存可能: `application/`、`domain/` の値オブジェクト（表示のための読み取りのみ）
- 依存禁止: `data/`。ルールの計算（`architecture-overview.md`「UI 層」）

#### game/content/

**役割**: 静的データ（JSON）。

**配置ファイル**:
- `formations.json`: 4陣形の選手座標と特徴タグ（フォーメーションラボから移植）
- `styles.json`: 4方式の名称と解説の固定文（`functional-overview.md` のエンティティ「方式」）
- `matchup_rules.json`: 噛み合わせルール（各ルールに原則 ID を持つ）
- `principles.json`: 戦術原則カタログのアプリ内表示用データ
- `simplifications.json`: 単純化カタログのアプリ内表示用データ
- `quiz.json`: 理解度チェックの場面問題
- `tutorial.json`: チュートリアルの各段階（説明文・盤面の初期状態・相手が出す手）

#### game/config/

**役割**: 調整値の Resource（`.tres`）。対象の一覧と初期値の正本は `functional-overview.md`「確定事項」の
「設定値として外部化する値」。

#### game/assets/

**役割**: 3D モデル・アニメーション・テクスチャ・音・フォント。外部から調達した素材は、追加するたびに
`game/assets/LICENSES.md`（ライセンス台帳）に調達元・ライセンス・バージョンを記録する。台帳を素材と同じ
ディレクトリに置くのは、素材の追加と台帳の更新を同じ変更に含めやすくするため。

#### game/tests/

**役割**: gdUnit4 のテスト。`domain/`・`data/`・`application/` と同じ構成のサブディレクトリに置く
（例: `tests/domain/judge/`）。

- `tests/self_play/`: 自己対戦による決定性・対称性・偏りの検証（NFR-05〜07）
- `tests/fixtures/`: 破損した保存データなどのテスト用データ（NFR-09）

### tools/ 配下

**配置ファイル**:
- `mcp/drawio-mcp.mjs`: drawio MCP の起動ラッパー（後述「drawio MCP の運用」）
- ドメイン層の禁止依存の検出スクリプト（NFR-13。検索する API 名の一覧はこのスクリプトが正本）
- カタログと静的データの突き合わせスクリプト（NFR-17 ②）
- ワイヤーフレームと画面一覧の対応検査スクリプト（後述「ワイヤーフレームの運用」）
- テストの一括実行スクリプト（gdUnit4 の CLI 呼び出し）

### docs/ 配下

- `docs/specs/1_requirements/`: 要件定義工程の6ドキュメント
- `docs/specs/2_basic-design/` 以降: 基本設計・詳細設計・テスト仕様
- `docs/` 直下には実ファイルを置かない（AGENTS.md「ディレクトリ構造」）。セルフレビュー用チェックリストは `functional-overview.md`「妥当性の維持」、素材のライセンス台帳は `game/assets/LICENSES.md` に置く

## 機能追加時の配置方針

- **陣形の追加**: `content/formations.json` に座標を追加する。新しい特徴タグが必要なら `matchup_rules.json` にルールを追加し、原則 ID を付ける
- **方式の追加**: `game_enums.gd` に区分値を、`domain/layout/` に動き方の規則を追加する
- **画面の追加**: `ui/screens/` に画面ディレクトリを追加し、`functional-overview.md` の画面一覧と `wireframes.drawio` のページを同じ変更で追加する
- いずれも、判定例・対称性・偏りの検証（NFR-05〜07・14）が通ることを完了条件とする

> 各レイヤーへの追加パターンの一般論は kit の `reference/rules/naming-and-placement.md`
> 「機能追加時のスケーリング」を正本とする。

## 開発環境セットアップ

バージョンの正本は `architecture-overview.md`「テクノロジースタック」。本表はインストール方法だけを持つ。

| ツール | インストール方法 |
|---|---|
| Godot Engine（標準版。.NET 版ではない） | 公式サイトから取得 |
| gdUnit4 | `game/addons/gdUnit4/` に同梱 |
| Android SDK・JDK | Godot 公式ドキュメント「Exporting for Android」の手順 |
| Git | — |
| Draw.io Integration（VS Code 拡張） | ワイヤーフレームの閲覧・編集用に VS Code の拡張機能として導入 |

### 環境変数（`.env`）一覧

**該当なし**: アプリは実行時に環境変数・外部の接続先を使わない（外部通信なし。要件定義書 §7 #8）。
`.gitignore` の `.env` 除外は、誤配置の事故防止として維持する。

### 機密情報の置き場

| 機密情報 | 置き場 | 備考 |
|---|---|---|
| Android の署名鍵（アップロード鍵）とそのパスワード | リポジトリ外（各自の端末のユーザーディレクトリ配下） | Godot のエディタ設定・書き出し設定から参照する。書き出し設定（`export_presets.cfg`）は鍵を平文で持つため除外する |

### セットアップ手順

開発環境の構築時に、以下を実施して本節に実際のコマンドと結果を記録する。

1. Godot・gdUnit4・Android SDK・JDK のバージョンを決め、`architecture-overview.md`「テクノロジースタック」に記録する
2. `game/project.godot` を作成し、GDScript の警告設定を kit の `coding-gdscript.md`「静的型付けを必須とする」に従って設定する。実際の設定項目名を本節に記録する（警告名は Godot のバージョンで変わりうるため）
3. `.gitignore` に Godot 用の除外（kit の `gitignore.md`「ゲーム（Godot）」）と Android の署名鍵ファイル（`*.keystore`・`*.jks`）を追加し、`git check-ignore` で両方向を実測する
4. クリーンクローンから再インポートして、シーン・リソースの参照が壊れないことを一度確認する（kit の `coding-gdscript.md`「バージョン管理で扱うファイル」）
5. 書き出し設定のうち、鍵を含まない共有すべき項目（リソース以外に含めるファイルのフィルタ `content/*.json`、テストを除外するフィルタ `tests/*`・`addons/gdUnit4/*` など）を、本物をコピーせずに手で書き起こした `game/export_presets.cfg.example` として追跡する（kit の `gitignore.md`「`export_presets.cfg` は鍵を平文で持つ」）。各自の `export_presets.cfg` はこれをもとに作り、書き出した成果物に JSON が含まれ、テストが含まれないことを確認する
6. Android 基準端末の機種を決め、`non-functional-requirements.md` §2 に記録する

### CI/CD

- **CI（導入する）**: 最初の実装作業でリポジトリのリモートを用意した時点で導入する。プルリクエストごとに次を実行する
  - gdUnit4 のテスト（画面なし。`--ignoreHeadlessMode`）
  - 自己対戦検証（NFR-05〜07）
  - ドメイン層の禁止依存の検出（NFR-13）
  - カタログと静的データの突き合わせ（NFR-17 ②）
  - ワイヤーフレームと画面一覧の対応検査
  - シークレットスキャン（流出防止の正本。kit の `gitignore.md`「`.gitignore` に頼りきらない」）
- **CD（導入しない）**: リリース用のビルドは署名鍵を使うため、手元で行う。Google Play への登録は Play Console で手動で行う。導入を検討するトリガーは、リリース頻度が月1回を超えたとき

## プロジェクト固有の運用

### ワイヤーフレームの運用

- ワイヤーフレームは `docs/specs/2_basic-design/wireframes.drawio` の1ファイルに、**画面1つにつき1ページ**で作る
- ページ名は `wireframe-[画面ID小文字]-[画面の英語名 kebab-case]`（例: `wireframe-s03-match`）。画面 ID は `functional-overview.md` の画面一覧が正本
- **画面を変える変更では、`functional-overview.md` の画面一覧・`screen-design.md`・`wireframes.drawio` の該当ページを同じ変更で更新する**
- 対応検査スクリプト（`tools/`）が、ページ名と画面一覧の画面 ID の一対一対応を検査する（フォーメーションラボの `wireframeConsistency.test.ts` の考え方を踏襲）

### drawio MCP の運用

- `.mcp.json` の `drawio` は、`drawio-mcp-server` を直接起動せず、`tools/mcp/drawio-mcp.mjs` を経由して起動する
- **理由**: `drawio-mcp-server` は既定でポート 3333（WebSocket）と 3000（エディタ）を固定で使う。Claude Code の
  セッションを複数開くと（別プロジェクトを含む）、後から起動したセッションが「Port 3333 is already in use」で
  接続に失敗する。ラッパーは起動のたびに空きポートを選んで渡すため、セッションをいくつ開いても衝突しない
- ラッパーは次も行う
  - サーバーの版を固定する（`npx` が起動のたびに最新版を取得しないようにするため。更新はラッパー内の版を変える）
  - 待ち受けを `127.0.0.1` に限定する（既定は全アドレスで待ち受け、同じネットワークの他の端末から届くため）
- **エディタの URL**: 起動のたびに変わる。ラッパーが OS の一時ディレクトリの `drawio-mcp/` に
  `<起動ディレクトリ名>-<pid>.json`（`editorUrl` を含む）を書き出し、終了時に消す（強制終了で残ったものは、
  次の起動時に、動いていない pid のものを消す）。図を編集するときは、このファイルの `editorUrl` をブラウザで
  開いてから drawio MCP の道具を使う
- **起動する場所**: `.mcp.json` はラッパーをリポジトリのルートからの相対パスで指定している。Claude Code は
  リポジトリのルートで起動する。サブディレクトリで起動すると、drawio だけが
  接続に失敗する（`Cannot find module`）
- 接続に失敗したら、まず `/mcp` で再接続する。それでも失敗する場合は、ラッパーを
  `node tools/mcp/drawio-mcp.mjs` で手で起動し、標準エラー出力を確認する

## 汎用規約からの差分

| 差分 | 内容 | 理由 |
|---|---|---|
| worktree・作業ブランチを使わない | kit の `git-workflow.md`「基本フロー」（と、それを要約した `AGENTS.md` のマーカー区間「ブランチ運用」）は、作業ごとに worktree とブランチを切り、`main` では編集しないことを求める。本プロジェクトは `main` の作業ツリーで編集・コミットする。手順・守り続ける規則・`/kit-sync` 後の確認の正本は `AGENTS.md`「プロジェクト固有の設定」 | worktree で作業すると VS Code で差分が見づらい（2026-10-17 決定） |
| 静的データを JSON で持つ | kit の `coding-gdscript.md`「調整対象の数値はコードに埋めない」は Resource（`.tres`）での外部化を求める。本プロジェクトは**調整値**（ターン数・CPU パラメータ等）は規約どおり `.tres`（`game/config/`）にするが、**静的データ**（陣形の座標・噛み合わせルール・カタログ・場面問題）は JSON（`game/content/`）で持つ | 静的データはフォーメーションラボの TypeScript から機械的に移植する。また、`functional-overview.md` のカタログとの ID・件数の突き合わせ（NFR-17）を、Godot を起動せずにスクリプトでも検査できるようにするため |
| テストを対象と別ディレクトリに置く | kit の `naming-and-placement.md` は Go・TS のテストを対象と同じディレクトリに置く。本プロジェクトは `game/tests/` に対象と同じ構成で置く | テストのスクリプトを、1つのディレクトリ指定で書き出し（エクスポート）から除外できるようにするため。除外の漏れは、セットアップ手順5の成果物確認で検出する。対象と同じディレクトリに置くと、ファイルごとのフィルタ指定が必要になり、漏れやすい |
| Godot プロジェクトをサブディレクトリに置く | kit の `gitignore.md` の Godot 向けエントリはリポジトリ直下のプロジェクトを想定している（`/export/` `/build/`）。本プロジェクトは `game/` 配下に置くため、パターンを `game/` に合わせて書き換える | 上記「game/ 配下」のとおり、ドキュメント類を Godot のインポート・書き出しから外すため |

## 書かないこと（kit の `reference/rules/` が正本）

| 内容 | 正本 |
|---|---|
| ファイル配置規則・命名規則・レイヤー間依存の一般論 | `naming-and-placement.md` |
| GDScript のコーディング規約（型付け・命名・`class_name` の一意性・Node 非継承） | `coding-gdscript.md` |
| `.steering/` の運用 | `steering.md` |
| `.gitignore` の共通エントリと Godot 向けエントリ | `gitignore.md` |
| 図版の形式と置き場 | `diagrams.md` |
| エージェント設定ディレクトリの扱い | `host-rules.md` |

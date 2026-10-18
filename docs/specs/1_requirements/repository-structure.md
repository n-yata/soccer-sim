# リポジトリ構造 — soccer-game（仮称）

**更新日**: 2026-10-18

> **このプロジェクトに実在する（または開発環境の構築時に作る）ディレクトリ構造**を定義する。物理配置の正本。
> あわせて、セットアップ手順・CI/CD などこのプロジェクト固有の運用情報と、汎用規約から意図的に外れる
> 差分をここに集約する。
>
> ファイル配置規則・命名規則・レイヤー間依存の一般論、GDScript のコーディング規約、`.gitignore` の
> 共通エントリ、図版の管理方法は kit の `reference/rules/` が正本である（索引は `/kit-guidelines`）。
> **ここには再掲しない。** 依存方向・レイヤー責務の論理的な正本は `architecture-overview.md`。
> 本書はそれを物理構造に対応させる。

## プロジェクト構造

`（未作成）` は、それを使う機能の作業で作るもの。それ以外は現時点で実在する（`game/` は 2026-10-18 の開発環境の構築で、`domain/`・`data/`・`content/` は同日の「ルールの土台」の作業で作成）。

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
│   │   ├── 3_detail-design/       # 詳細設計。screen/（画面ごと・画面共通）と data/（保存データ・静的データの定義）。DB 設計書は作らない
│   │   ├── 4_unit-test/
│   │   └── 5_integration-test/
├── game/                          # Godot プロジェクト
│   ├── project.godot
│   ├── export_presets.cfg.example # 鍵を含まない書き出し設定の共有用（本物の export_presets.cfg は除外）
│   ├── addons/gdUnit4/            # テストフレームワーク（同梱して固定）
│   ├── domain/                    # ドメイン層（純粋ロジック。Node 非依存）
│   ├── application/               # アプリケーション層（試合進行・画面遷移・保存の呼び出し）（未作成）
│   ├── data/                      # データ層（静的データの読み込み・端末内保存）
│   ├── ui/                        # UI 層（画面・2D 作戦ボード・3D 演出）（未作成）
│   ├── content/                   # 静的データ（JSON。今は formations.json だけ）
│   ├── config/                    # 調整値（Resource .tres）（未作成）
│   ├── assets/                    # 3D 素材・テクスチャ・音・フォント（ライセンス台帳 LICENSES.md を含む）
│   │   └── fonts/                 # 書体ごとのディレクトリ（barlow-condensed/。noto-sans-jp/ はサブセットの作業で作る）。フォントと OFL.txt
│   └── tests/                     # gdUnit4 のテスト
└── tools/                         # 開発補助スクリプト
    ├── run-tests.sh               # テストの一括実行（禁止依存の検査と gdUnit4）
    ├── check_domain_deps.gd       # ドメイン層の禁止依存の検出（NFR-13）
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
- `tests/fixtures/`: 破損した保存データなどのテスト用データ（NFR-09）。`fixtures/forbidden_deps/` は、禁止依存の検査が
  空振りしていないことを確かめるためのスクリプト（カテゴリごとに禁止した参照を1つ書いたもの）
- 静的データの異常系のテストは、fixture を置かず、本物の JSON を1か所だけ変えてテストの中で作る
  （本物を直したときに fixture だけが古いまま残らないようにするため）

### tools/ 配下

**配置ファイル**:
- `mcp/drawio-mcp.mjs`: drawio MCP の起動ラッパー（後述「drawio MCP の運用」）
- `check_domain_deps.gd`: ドメイン層の禁止依存の検出（NFR-13。検索する API 名の一覧はこのスクリプトが正本）。
  Godot を画面なしで動かして実行する（`godot --headless --path game --script <このファイルの絶対パス> -- [ディレクトリ]`。
  省くと `res://domain`）。見つかれば終了コード 1、検査できなければ（ディレクトリが無い・スクリプトが0件）2。
  `--self-check <カテゴリ>` は、fixture でそのカテゴリの全ルールが当たることを確かめる（ルールを足したら fixture にも足す）
- フォントのサブセットの生成と、フォントに無い文字の検出（`architecture-overview.md` のフォントの注記）
- カタログと静的データの突き合わせスクリプト（NFR-17 ②）
- ワイヤーフレームと画面一覧の対応検査スクリプト（後述「ワイヤーフレームの運用」）
- `run-tests.sh`: テストの一括実行（後述「セットアップ手順」2 の「テストの実行」）

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
| Godot Engine（標準版。.NET 版ではない） | 公式サイトから取得（winget の `GodotEngine.GodotEngine` でもよい）。`godot` コマンドで起動できるようにする |
| 書き出しのテンプレート（Godot と同じ版） | エディタの「エクスポートテンプレートの管理」から入れる。手で入れる場合は、公式のリリースの `Godot_v<版>-stable_export_templates.tpz` を同じリリースの `SHA512-SUMS.txt` で確かめ、`templates/` の中身をエディタのデータディレクトリの `export_templates/<版>.stable/` に置く（Android には `android_debug.apk`・`android_release.apk`・`android_source.zip` が要る） |
| gdUnit4 | `game/addons/gdUnit4/` に同梱（入れる作業は不要） |
| JDK | OpenJDK 17 |
| Android SDK | Android Studio か cmdline-tools で入れ、`sdkmanager` で後述の部品を足す（Godot 公式ドキュメント「Exporting for Android」） |
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

新しい端末で環境を作るときの手順。2026-10-18 の構築で実施した結果を、各手順の「結果」に記録している。
バージョンは `architecture-overview.md`「テクノロジースタック」に従う。

#### 1. ツールを入れる

- 上の表のツールを入れる。Android SDK には、次の部品を足す（`sdkmanager` は SDK の `cmdline-tools/latest/bin/` にある）

  ```
  sdkmanager --sdk_root=<Android SDK のパス> "platform-tools" "build-tools;36.0.0" "platforms;android-36" "ndk;28.1.13356709" "cmake;3.10.2.4988404"
  ```

- Godot のエディタ設定（端末ごと。リポジトリには入らない）の次の2項目に、各自の端末のパスを入れる
  - `export/android/android_sdk_path`: Android SDK のパス
  - `export/android/java_sdk_path`: JDK 17 のパス
- **結果**: `sdkmanager --list_installed` で上記の部品が入ったことを確かめた。build-tools は、対象 API（36）に合う版が無いと
  書き出しのときに警告が出て別の版で代用されるため、36.0.0 を入れた

#### 2. Godot プロジェクトの設定（`game/project.godot`）

GDScript の警告と画面の設定の、Godot 4.7.2 での実際の設定項目名と値。列挙の値は数値で保存される。

| 設定項目 | 値 | 根拠 |
|---|---|---|
| `debug/gdscript/warnings/untyped_declaration` | `2`（Error） | kit の `coding-gdscript.md`「静的型付けを必須とする」 |
| `debug/gdscript/warnings/unsafe_property_access` | `2`（Error） | 同上 |
| `debug/gdscript/warnings/unsafe_method_access` | `2`（Error） | 同上 |
| `debug/gdscript/warnings/unused_variable` | 既定の `1`（Warn）のまま（ファイルに書かれない） | 同上 |
| `debug/gdscript/warnings/enable` | 既定の `true` のまま | 同上 |
| `display/window/size/viewport_width`・`viewport_height` | `1280`・`720` | `screen-common.md` §1 |
| `display/window/stretch/mode`・`aspect` | `"canvas_items"`・`"keep_height"` | 同上 |
| `display/window/handheld/orientation` | `4`（Sensor Landscape） | 同上・NFR-25 |
| `rendering/renderer/rendering_method`（と `.mobile`） | `"gl_compatibility"` | `architecture-overview.md`（Compatibility レンダラー） |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` | Android の書き出しの必須条件（無いと書き出せない） |
| `application/config/quit_on_go_back` | `false` | 既定の `true` だと、Android の戻る操作で画面の `handle_back()` に関係なくアプリが閉じる（`screen-common.md` §4.1） |
| `editor_plugins/enabled` | `res://addons/gdUnit4/plugin.cfg` | テストランナー |

- 警告の項目名は、Godot を画面なしで起動して `ProjectSettings.get_property_list()` で確かめた（Godot の版を上げるときも同じ方法で確かめる）
- 警告は、Godot 4.7 の既定（`debug/gdscript/warnings/directory_rules` が `{ "res://addons": 0 }`）で `addons/` には効かない。同梱の gdUnit4 は対象外になる
- **プロジェクトを開いてエラーが無いことの確かめ方**: `game/` で `godot --headless --editor --quit` を実行する。
  `godot --headless --path game --quit` は、メインシーンが無いうちは「no main scene defined」で終わる（メインシーンは最初の機能の作業で作る）
- **テストの実行**: リポジトリのどこからでも `tools/run-tests.sh` を実行する（Windows では Git Bash）。Godot は環境変数
  `GODOT_BIN`、無ければ PATH の `godot` を使う。次の順に実行し、1つでも失敗すれば終了コード 1 で終わる
  0. エディタでの取り込み（新しく足した `class_name` は、取り込むまでテストから見えないため）
  1. 禁止依存の検査の自己確認（`tests/fixtures/forbidden_deps/` で各カテゴリの全ルールが当たること、コメント・文字列の中の語は
     検出しないこと、検査できない対象を失敗として扱うこと）
  2. `game/domain/` の禁止依存の検査（NFR-13）
  3. gdUnit4 のテスト。テストが0件で終わった場合も失敗として扱う（空振りの防止）

  中で呼んでいる gdUnit4 の CLI は次のとおり（`game/` で実行）:

  ```
  godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
  ```

  - gdUnit4 同梱の `runtest.cmd`・`runtest.sh` と同じ呼び出し方。`--remote-debug tcp://127.0.0.1:0` は、スクリプトの構文エラーのときに
    対話式のデバッガで止まらないようにするための指定で、接続できない旨のエラーが2行出るのは想定どおり
  - 終了コード: 成功は `0`、失敗があると `100`。レポートは `game/reports/`（XML・HTML。Git の除外対象）に出る
  - テストが0件のときは「No test cases found」で終了コード `0` になり、レポートは出ない
- **結果**: プロジェクトを開いてエラー 0 件。テストランナーは、一時的に置いたテスト（画面の設定の検査）で、成功で `0`・失敗で `100` になり、
  レポートが出ることを確かめた（テストは確認後に消した）

#### 3. Git の除外設定

- `.gitignore` に、Godot 用の除外（kit の `gitignore.md`「ゲーム（Godot）」）、gdUnit4 のレポートの出力先、
  Android の署名鍵ファイル（`*.keystore`・`*.jks`）を足した
- **結果**（2026-10-18。`git check-ignore -v --no-index --non-matching` で1パスずつ確かめた）:

  | パス | 期待 | 実際にマッチしたパターン |
  |---|---|---|
  | `game/.godot/x` | 除外 | `.godot/` |
  | `game/export/a.apk` | 除外 | `/game/export/` |
  | `game/build/x` | 除外 | `/game/build/` |
  | `game/reports/report_1/index.html` | 除外 | `/game/reports/` |
  | `game/export.cfg` | 除外 | `export.cfg` |
  | `game/export_presets.cfg` | 除外 | `export_presets.cfg*` |
  | `game/export_presets.cfg.bak` | 除外 | `export_presets.cfg*` |
  | `a.keystore` | 除外 | `*.keystore` |
  | `game/a.jks` | 除外 | `*.jks` |
  | `game/export_presets.cfg.example` | 追跡 | `!export_presets.cfg.example`（否定パターン） |
  | `game/x.import` | 追跡 | なし |
  | `game/x.gd.uid` | 追跡 | なし |
  | `game/project.godot` | 追跡 | なし |
  | `game/addons/gdUnit4/plugin.cfg` | 追跡 | なし |

  `git ls-files -i -c --exclude-standard` は空（追跡中のファイルを巻き込んでいない）

#### 4. クリーンな状態からの再インポート

- **結果**: Git が追跡する予定のファイル（`git ls-files -co --exclude-standard game`）だけを一時ディレクトリへ写し、
  `godot --headless --editor --quit` で取り込み直して、エラー 0 件を確かめた（`.import`・`.uid` を追跡していれば、`.godot/` が無くても参照が壊れない）

#### 5. 書き出し設定

- `game/export_presets.cfg.example` をコピーして、各自の `game/export_presets.cfg` を作る。`.example` には署名の項目を書いていない。
  デバッグ版は、エディタ設定のデバッグ用の鍵で署名される
- `.example` の要点: プリセット名 `Android (debug)`、書き出し先 `export/`、リソース以外に含めるファイル `content/*.json`、
  除外するファイル `tests/*, addons/gdUnit4/*`、Gradle ビルドなし、`arm64-v8a` と `x86_64`（エミュレーター用）、
  `permissions/internet=false`、パッケージ名は仮の `com.example.soccergame`（正式名は要件定義書 §7.1 #4 の決定後）
- 書き出し（`game/` で実行。書き出し先の `export/` は Godot が作らないので、先に作っておく）:

  ```
  mkdir export
  godot --headless --export-debug "Android (debug)" export/soccer-game-debug.apk
  ```

- APK の中身は `unzip -l`、マニフェストは build-tools の `aapt2 dump badging`・`aapt2 dump permissions` で確かめる
- **エミュレーター**: AVD は x86_64 のシステムイメージを使う。`emulator -avd <AVD 名> -gpu host` のように、ホストの GPU を使って起動する。
  既定のソフトウェア描画（SwiftShader）では、3D 用のシェーダーの uniform の数が上限を超えてリンクに失敗し、文字も描かれなかった
- **結果**（2026-10-18）:
  - 確認用の仮の JSON（`content/` に置き、確認後に消した）が APK の `assets/content/` に含まれた。`tests/` と `addons/gdUnit4/` は 0 件
  - `minSdkVersion` 24・`targetSdkVersion` 36、ネイティブコードは `arm64-v8a`・`x86_64`
  - API 35（x86_64）のエミュレーターで起動した。確認用の仮のメインシーン（確認後に消した）で、APK 内の JSON を読めることと、
    ビューポートが 1280×720 になることを確かめた
  - 書き出しのとき「No project icon specified」と出る。書き出しは成功する。アイコンは公開の準備で作る

#### 6. Android の基準端末

- **結果**: 機種はまだ無い（2026-10-18 時点）。決定は端末の入手後に持ち越し、当面はエミュレーターで確かめる（`non-functional-requirements.md` §2）

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

### 動作確認の方法

開発中の動作確認は PC のウィンドウで行う（2026-10-18 決定）。配布先は MVP では Android のままで、Windows 版は後続マイルストーン
（要件定義書 §6.2）。画面を横向きだけにしたため、PC のウィンドウでもスマホとほぼ同じ配置で確かめられる。

- **起動**: `godot --path game`（またはエディタの実行）。ウィンドウはビューポートと同じ 1280×720 で開き、大きさを変えられる
  （`display/window/size/resizable` が `true`）。スマホの横長の比率は、ウィンドウを横に広げて確かめる（例: 20:9 なら 1600×720）
- **操作**: マウスの左クリックがタップにあたる。Esc キーが Android の戻る操作にあたる（入力の扱いの正本は
  `docs/specs/3_detail-design/screen/screen-common.md` §4.1）
- **PC では確かめられないもの**: 次は、Android エミュレーター（`-gpu host`。「セットアップ手順」5）と基準端末で確かめる
  - セーフエリア（ノッチ・パンチホール）の余白、端末の回転（`sensor_landscape`）、Android の戻る操作そのもの
    （`handle_back()` が1回だけ呼ばれ、試合画面などでアプリが閉じないこと）
  - `non-functional-requirements.md` で「Android 基準端末で」と定めた測定と確認（性能・指での操作など。一覧は同書が正本）
- メインシーンはまだ無い（2026-10-18 時点）。PC で画面を確かめられるのは、メインシーンを作る作業の後になる

## 汎用規約からの差分

| 差分 | 内容 | 理由 |
|---|---|---|
| worktree・作業ブランチを使わない | kit の `git-workflow.md`「基本フロー」（と、それを要約した `AGENTS.md` のマーカー区間「ブランチ運用」）は、作業ごとに worktree とブランチを切り、`main` では編集しないことを求める。本プロジェクトは `main` の作業ツリーで編集・コミットする。手順・守り続ける規則・`/kit-sync` 後の確認の正本は `AGENTS.md`「プロジェクト固有の設定」 | worktree で作業すると VS Code で差分が見づらい（2026-10-17 決定） |
| 静的データを JSON で持つ | kit の `coding-gdscript.md`「調整対象の数値はコードに埋めない」は Resource（`.tres`）での外部化を求める。本プロジェクトは**調整値**（ターン数・CPU パラメータ等）は規約どおり `.tres`（`game/config/`）にするが、**静的データ**（陣形の座標・噛み合わせルール・カタログ・場面問題）は JSON（`game/content/`）で持つ | 静的データはフォーメーションラボの TypeScript から機械的に移植する。また、`functional-overview.md` のカタログとの ID・件数の突き合わせ（NFR-17）を、Godot を起動せずにスクリプトでも検査できるようにするため |
| テストを対象と別ディレクトリに置く | kit の `naming-and-placement.md` は Go・TS のテストを対象と同じディレクトリに置く。本プロジェクトは `game/tests/` に対象と同じ構成で置く | テストのスクリプトを、1つのディレクトリ指定で書き出し（エクスポート）から除外できるようにするため。除外の漏れは、セットアップ手順5の成果物確認で検出する。対象と同じディレクトリに置くと、ファイルごとのフィルタ指定が必要になり、漏れやすい |
| Godot プロジェクトをサブディレクトリに置く | kit の `gitignore.md` の Godot 向けエントリはリポジトリ直下のプロジェクトを想定している（`/export/` `/build/`）。本プロジェクトは `game/` 配下に置くため、パターンを `game/` に合わせて書き換える（`/game/export/`・`/game/build/`。gdUnit4 のレポートの `/game/reports/` も足した） | 上記「game/ 配下」のとおり、ドキュメント類を Godot のインポート・書き出しから外すため |

## 書かないこと（kit の `reference/rules/` が正本）

| 内容 | 正本 |
|---|---|
| ファイル配置規則・命名規則・レイヤー間依存の一般論 | `naming-and-placement.md` |
| GDScript のコーディング規約（型付け・命名・`class_name` の一意性・Node 非継承） | `coding-gdscript.md` |
| `.steering/` の運用 | `steering.md` |
| `.gitignore` の共通エントリと Godot 向けエントリ | `gitignore.md` |
| 図版の形式と置き場 | `diagrams.md` |
| エージェント設定ディレクトリの扱い | `host-rules.md` |

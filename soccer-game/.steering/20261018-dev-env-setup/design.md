# 設計書

## 方針

- 構築の手順と結果の正本は `repository-structure.md`「開発環境セットアップ」、バージョンの正本は
  `architecture-overview.md`「テクノロジースタック」。このファイルは今回の作業の進め方だけを持つ。
- 端末ごとの設定（Godot のエディタ設定の SDK・JDK のパス、署名鍵）はリポジトリに入れない。リポジトリに入れるのは、
  誰の端末でも同じになる設定（`project.godot`・`.gitignore`・`export_presets.cfg.example`・同梱するアドオンとフォント）だけ。

## 1. Android SDK の追加

```
sdkmanager --sdk_root=<Android SDK のパス> "ndk;28.1.13356709" "cmake;3.10.2.4988404" "platforms;android-36"
```

- `sdkmanager` は `cmdline-tools/latest/bin/` にある（PATH には無い）。JDK は `JAVA_HOME`（OpenJDK 17）を使う。
- 既存の部品は消さない（ほかのプロジェクトが使っている可能性がある）。

## 2. Godot のエディタ設定（端末ごと。リポジトリ外）

- `export/android/android_sdk_path`・`export/android/java_sdk_path` を、エディタ設定（ユーザーのアプリデータ配下の
  `editor_settings-4.7.tres`）に設定する。値は端末ごとなので、文書には「どの設定項目に何を入れるか」だけを書き、実際のパスは書かない。

## 3. `game/project.godot`

| 設定 | 値 | 根拠 |
|---|---|---|
| `application/config/name` | `soccer-game`（仮称） | 正式名は要件定義書 §7.1 #4 |
| `config/features` | `4.7`、`GL Compatibility` | Godot 4.7 系、Compatibility レンダラー（architecture-overview） |
| `rendering/renderer/rendering_method`（と `.mobile`） | `gl_compatibility` | 同上 |
| `display/window/size/viewport_width` / `viewport_height` | 1280 / 720 | screen-common §1 |
| `display/window/stretch/mode` / `aspect` | `canvas_items` / `keep_height` | 同上 |
| `display/window/handheld/orientation` | `sensor_landscape`（4.7 の値の表し方は実際の設定画面で確かめる） | 同上・NFR-25 |
| `debug/gdscript/warnings/enable` | `true` | coding-gdscript |
| `debug/gdscript/warnings/untyped_declaration`・`unsafe_property_access`・`unsafe_method_access` | error | 同上 |
| `debug/gdscript/warnings/unused_variable` | warning | 同上 |
| `editor_plugins/enabled` | gdUnit4 | テストランナー |

- 設定は、Godot を画面なしで起動して作った `project.godot` を土台にする。警告の設定項目名と値の表し方（列挙の数値など）は、
  4.7.2 の実物（`ProjectSettings` の一覧）で確かめてから書く。手で推測した項目名は書かない。
- ディレクトリは、今回使うものだけを作る（`addons/`・`assets/fonts/`・`tests/`）。レイヤーのディレクトリは最初の機能の作業で作る
  （空のディレクトリを `.gitkeep` で並べると、構造の正本の `repository-structure.md` と二重になるため）。

## 4. gdUnit4

- 公式リポジトリ（godot-gdunit-labs/gdUnit4）の v6.2.2 のタグのアーカイブから、`addons/gdUnit4/` だけを `game/addons/gdUnit4/` に置く。
- ライセンス（MIT）は `game/assets/LICENSES.md` の台帳に記録する（台帳は素材とアドオンの両方を扱う）。
- 確かめること: CLI（`addons/gdUnit4/runtest.cmd` か、`godot --headless` からの実行）が画面なしで起動し、
  テストが 0件でもレポートを出して正常に終わること。

## 5. `.gitignore`

kit の `gitignore.md`「ゲーム（Godot）」に従って、次を足す。

```gitignore
# Godot
.godot/
/game/export/
/game/build/
export.cfg
export_presets.cfg*
!export_presets.cfg.example
# Android の署名鍵
*.keystore
*.jks
```

- `/game/android/`（Gradle ビルド用のテンプレート）は今回は作らないので、扱いはリリース版の AAB を作る作業で決める。
- 1パスずつ `git check-ignore -v --no-index --non-matching` で確かめる。除外される側: `game/.godot/x`、`game/export_presets.cfg`、
  `game/export_presets.cfg.bak`、`a.keystore`、`a.jks`。除外されない側: `game/export_presets.cfg.example`、`game/x.import`、`game/x.gd.uid`。
- `git ls-files -i -c --exclude-standard` が空であることを確かめる。

## 6. 書き出し設定

- `export_presets.cfg.example` には、鍵を含まない共有すべき項目だけを手で書く。
  - プリセット名: `Android (debug)`
  - 書き出し先: `export/`
  - リソース以外に含めるファイル: `content/*.json`
  - 除外するファイル: `tests/*`、`addons/gdUnit4/*`
  - パッケージ名（仮の値）・アーキテクチャ（`arm64-v8a`・`x86_64`）
  - 権限: `permissions/internet=false` を明記する（ほかの権限は既定で false）
  - 画面の向きは `project.godot` 側で決まり、API レベルは Gradle ビルドなしでは書き出しの既定値（最小 24・対象 36）になるため、`.example` には書かない
- 署名の項目は書かない（各自の `export_presets.cfg` でだけ設定する）。デバッグ用の鍵は Godot がエディタ設定で使うものに任せる。
- 確かめ方: 各自の `export_presets.cfg` を `.example` から作り、`godot --headless --export-debug` で APK を書き出す。
  `aapt2 dump`（build-tools 36.0.0）と APK の中身の一覧で、JSON と除外を確かめる。エミュレーターに入れて起動を確かめる。
  - 中身を確かめる JSON は、確認用の仮のファイルを `content/` に置いて行い、確かめたら消す（本物の静的データは最初の機能の作業で作る）。

## 7. 持ち越していた確認

### 組み込みクラス名との衝突

- `component-design.md` §6 の全クラス名と、Godot 4.7.2 の `ClassDB.get_class_list()` の名前を突き合わせる。
  一覧の取得は、画面なしで実行する使い捨てのスクリプト（リポジトリに入れない）で行う。
- 衝突があれば名前を変える案を出し、シャビに確認する。結果は `component-design.md` §6 に記録する。

### フォント

- 取得元は、各書体の公式リポジトリ（Noto Sans JP は notofonts／Google Fonts、Barlow は jpt/barlow）。OFL の本文（`OFL.txt`）も一緒に取る。
- 予約フォント名（RFN）は、OFL の本文の著作権表示の行に「with Reserved Font Name」があるかで判断する。
- 台帳（`game/assets/LICENSES.md`）に、取得元・バージョン（またはコミット）・ライセンス・RFN の有無を記録する。
- サブセットは作らない（スコープ外）。元のフォントのファイルを置くだけにする。
  - 元の Noto Sans JP は大きい（1つの太さで数MB）。リポジトリが大きくなる問題は、サブセットのスクリプトを作る作業で解消する。
    当面は使う2つの太さ（Regular・Bold）だけを置く。

### INTERNET 権限

- 手順6で書き出した APK の `AndroidManifest.xml` を `aapt2 dump permissions`（または `badging`）で調べる。
- リリース版の確認は、デバッグ用の鍵で `--export-release` した APK で行う（署名鍵を作らずに、マニフェストだけを確かめる）。
- デバッグ版に INTERNET が入る場合（Godot のリモートデバッグのため）は、開発時だけのものとして許容するかどうかを決め、
  NFR-10 の検査の手順（リリース版で確かめる）とあわせて記録する。

## セキュリティ考慮事項

- 署名鍵・パスワードはリポジトリに入れない（`export_presets.cfg` を除外し、`.example` には署名の項目を書かない）。
- 外部から取るもの（gdUnit4・フォント）は公式の配布元からだけ取り、取得元を台帳に残す。
- 文書には端末のパス・ユーザー名を書かない（`<Android SDK のパス>` のようなプレースホルダにする）。

## テスト戦略

- この作業ではテストを書かない（テストは最初の機能の作業で、実際の機能に対して書く）。
- テストランナーが動くことは、CLI の実行結果（0件で正常終了し、レポートが出る）で確かめる。

## 実施中に変えたこと（2026-10-18）

- **Android 用の書き出しのテンプレートを足した**: 入っていたのは Windows 用だけだった。公式のリリースの `.tpz` を `SHA512-SUMS.txt` で確かめ、Android の3ファイルだけを入れた。
- **build-tools 36.0.0 を足した**: 対象 API 36 に合う build-tools が無いと、書き出しのときに警告が出て 34.0.0 で代用された。
- **`project.godot` に `rendering/textures/vram_compression/import_etc2_astc=true` を足した**: Android の書き出しの必須条件。
- **プロジェクトを開く確認は `godot --headless --editor --quit`（`game/` で実行）にした**: `--path game --quit` はメインシーンが無いと失敗するため。
- **`.gitignore` に `/game/reports/` を足した**: gdUnit4 のレポートの出力先。
- **テストランナーの確認に一時的なテストを使った**: 0件ではレポートが出ないため。画面の設定を検査するテストを置き、成功と失敗の終了コードとレポートを確かめてから消した。
- **起動の確認に仮のメインシーンを使った**: メインシーンが無いと、アプリは起動直後に終了するため。JSON を読んで表示するシーンを置き、確認後に消した。
- **エミュレーターは `-gpu host` で起動した**: SwiftShader では 3D 用のシェーダーのリンクに失敗した。
- **パッケージ名は仮の `com.example.soccergame` にした**: `com.example.$genname` は、プロジェクト名の `-` のため置き換えの警告が出た。
- **警告の除外の項目名**: 4.7 では `debug/gdscript/warnings/directory_rules`（既定で `res://addons` を除外）。
- **衝突の確認に gdUnit4 のクラス名も含めた**: gdUnit4 は多数のグローバルなクラス名を登録するため。
- **§6 の `.example` の項目と aapt2 の版を実物に合わせた**（コミット前レビューの指摘）: 向き・API レベルは `.example` に書かない、権限は INTERNET だけを明記、aapt2 は build-tools 36.0.0 のもの。
- **Noto Sans JP は置かないことにした**（コミット前レビューの Medium の指摘、シャビ決定）: 元のファイル（約9.2MB）を一度コミットすると、サブセットに差し替えても履歴に残るため。取得元・版・RFN の有無は台帳に記録し、ファイルはサブセットの作業で置く。Barlow Condensed（約0.3MB）は置いた。

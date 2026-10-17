# 要求内容

## 概要

開発環境を構築する。`repository-structure.md`「セットアップ手順」1〜6 を実施し、結果（実際のコマンド・設定項目名・バージョン）を文書に記録する。
あわせて、設計の工程から持ち越していた3つの確認を行う。

## 背景

詳細設計まで承認され、実装に入る前の最後の準備にあたる。Godot プロジェクト（`game/`）はまだ無い。

この端末には、すでに次が入っていた（2026-10-18 に確認）。

| ツール | 状態 |
|---|---|
| Godot | 4.7.2（winget）。書き出しのテンプレート 4.7.2 は Windows 用だけが入っていた（Android 用は構築中に足した。計画の時点では「導入済み」と誤って記録していた） |
| JDK | OpenJDK 17.0.2（scoop） |
| Android SDK | build-tools 34・35.0.1、platforms 34・35、cmdline-tools、NDK 26・27、CMake 3.22.1 |

## 決定事項（2026-10-18 シャビ）

- **Godot は 4.7 系**（入っている 4.7.2）にする。文書の「4.6 系」を改める。
  理由: gdUnit4 が 6.2 系から 4.7 に対応した。文書で 4.6 の版で確かめる予定にしていた項目（C# の Android 対応・レンダラー）は、すでに 4.7 の公式ドキュメントで確認している。
- **gdUnit4 は 6.2 系**にする（最新は v6.2.2。MIT ライセンス）。
- **足りない Android SDK の部品を sdkmanager で入れる**（モドリッチが実施する）。
  - NDK 28.1.13356709 と CMake 3.10.2.4988404: Godot 4.7 の Android 書き出しの手順が求める版。
  - platforms;android-36: Google Play は 2026-08-31 から、新しいアプリに Android 16（API 36）を対象にすることを求めている。
- **Android の基準端末はまだ無い**。機種の決定は持ち越し、当面はエミュレーターで確かめる。

## 実装対象

### 1. ツールのバージョンの確定（セットアップ手順1）

- 足りない Android SDK の部品を入れる。
- Godot・gdUnit4・Android SDK・JDK・最小と対象の API レベルを、`architecture-overview.md` に記録する。

### 2. Godot プロジェクトの作成（手順2）

- `game/project.godot` を作る。内容は次のとおり。
  - レンダラーは Compatibility。
  - 画面の拡大縮小は詳細設計の screen-common §1 のとおり（基準 1280×720、`keep_height`、`canvas_items`、`sensor_landscape`）。
  - GDScript の警告は kit の `coding-gdscript.md` のとおり。
- gdUnit4 を `game/addons/gdUnit4/` に同梱し、CLI でテストランナーが動くことを確かめる。

### 3. 除外設定（手順3）

- Godot 用の除外と、署名鍵ファイル（`*.keystore`・`*.jks`）の除外を足す。
- 除外されることと、除外されないこと（`.example` など）の両方を `git check-ignore` で確かめる。

### 4. 再インポートの確認（手順4）

- クリーンクローンから再インポートしても、参照が壊れないことを確かめる。

### 5. 書き出し設定（手順5）

- `game/export_presets.cfg.example` を、本物をコピーせずに手で書き起こす。
- 各自の `export_presets.cfg` からエミュレーター用のデバッグ版の APK を書き出し、次を確かめる。
  - JSON が含まれ、テストが含まれない。
  - エミュレーターで起動する。

### 6. 基準端末（手順6）

- 機種はまだ無いので、`non-functional-requirements.md` §2 に「未定（持ち越し）」と記録する。

### 7. 持ち越していた確認

- **組み込みクラス名との衝突**: 設計した `class_name` と、Godot 4.7 の組み込みクラス名（`ClassDB`）を突き合わせる。
- **フォント**: Noto Sans JP と Barlow Condensed を公式の配布元から取得し、`game/assets/fonts/` に置く。OFL の本文を確かめ、予約フォント名（RFN）の有無を `game/assets/LICENSES.md` の台帳に記録する。
- **INTERNET 権限**: 書き出した APK の `AndroidManifest.xml` に INTERNET 権限があるかを確かめる。デバッグ版とリリース版のそれぞれで扱いを決め、記録する（外部通信なし。NFR-10）。

## 受け入れ条件

- `architecture-overview.md` の「構築時に記録する」としていた項目に、実際の値が入っている。
- `godot --headless` でプロジェクトを開いて、エラーが出ない。
- gdUnit4 の CLI を画面なしで実行し、テストランナーの起動と結果のレポート出力まで通る（この作業ではテストを書かない）。
- `git check-ignore` で、除外と追跡の両方向を1パスずつ確かめた結果を、`repository-structure.md` に記録している。
- クリーンクローンからの再インポートで、エラーが 0件である。
- 書き出した APK に `content/` の JSON が含まれ、`tests/`・`addons/gdUnit4/` が含まれない。エミュレーターで起動する。
- 3つの確認の結果が、文書（`component-design.md`・`LICENSES.md`・NFR-10 の検査の記録など、各事項の正本）に記録されている。

## スコープ外

- ドメイン層などの実装と、実装に伴うテスト（最初の機能の作業で行う）
- CI の導入（リモートを用意した時点で行う。`repository-structure.md`「CI/CD」）
- フォントのサブセットを作るスクリプト（静的データの文言がそろってから作る）
- 署名鍵の作成と、リリース版の AAB の書き出し（公開の準備で行う）
- 基準端末の機種の決定（端末の入手後）

## 参照ドキュメント

- `docs/specs/1_requirements/repository-structure.md`: 開発環境セットアップの手順と、機密情報の置き場
- `docs/specs/1_requirements/architecture-overview.md`: テクノロジースタックと、構築時に記録する項目
- `docs/specs/1_requirements/non-functional-requirements.md`: NFR-10・NFR-25、§2 の基準環境
- `docs/specs/3_detail-design/screen/screen-common.md` §1: 画面の拡大縮小の設定
- kit の `coding-gdscript.md`・`gitignore.md`

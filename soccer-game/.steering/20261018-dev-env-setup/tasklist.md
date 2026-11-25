# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: ツールの準備

- [x] Android SDK に足りない部品を入れる
  - [x] `sdkmanager` で `ndk;28.1.13356709`・`cmake;3.10.2.4988404`・`platforms;android-36` を入れる
  - [x] 入ったことを `sdkmanager --list_installed` で確かめる
- [x] Godot のエディタ設定に Android SDK と JDK のパスを設定する（端末ごと。リポジトリ外。設定済みだったことを確かめた）

## フェーズ2: Godot プロジェクト

- [x] `game/project.godot` を作る
  - [x] 画面なしで起動して土台を作り、4.7.2 の実際の設定項目名と値の表し方を確かめる
  - [x] design.md §3 の設定を入れる
  - [x] `godot --headless --editor --quit`（`game/` で実行）でエラーが無いことを確かめる（`--path game --quit` はメインシーンが無いため実行できない。メインシーンは最初の機能で作る）
- [x] gdUnit4 v6.2.2 を `game/addons/gdUnit4/` に置き、プラグインを有効にする
- [x] gdUnit4 の CLI を画面なしで実行し、テストが 0件でも正常に終わってレポートが出ることを確かめる
  - 0件では「テストが無い」で正常終了（終了コード 0）し、レポートは出ない。一時的なテスト（画面設定の検査）を置いて、成功で 0・失敗で 100 になり、XML・HTML のレポートが出ることを確かめてから消した

## フェーズ3: 除外設定と再インポート

- [x] `.gitignore` に Godot と署名鍵の除外を足す（gdUnit4 のレポートの出力先 `/game/reports/` も足した）
- [x] `git check-ignore -v --no-index --non-matching` で、除外される側と除外されない側を1パスずつ確かめる
- [x] `git ls-files -i -c --exclude-standard` が空であることを確かめる
- [x] クリーンクローン（作業用の一時ディレクトリへの `git clone`）から画面なしで再インポートし、エラーが 0件であることを確かめる
  - [x] 一時的に、フェーズ2・3の変更を含むコミット前の状態を再現するため、作業ツリーの内容を一時ディレクトリへ写して確かめる（コミットはしない）

## フェーズ4: 書き出し

- [x] `game/export_presets.cfg.example` を手で書き起こす（署名の項目なし）
- [x] 各自の `game/export_presets.cfg` を `.example` から作る（除外されていることを確かめる）
- [x] 確認用の仮の JSON を `game/content/` に置き、デバッグ版の APK を `godot --headless --export-debug` で書き出す
  - Android 用の書き出しのテンプレートが入っていなかった（入っていたのは Windows 用だけ）。公式の 4.7.2 のテンプレートを取得し、SHA-512 を確かめて Android の分だけを入れた
  - `rendering/textures/vram_compression/import_etc2_astc=true` が必須だったので `project.godot` に足した
  - 対象 API 36 に合う build-tools 36.0.0 を足した
- [x] APK の中身に JSON が含まれ、`tests/`・`addons/gdUnit4/` が含まれないことを確かめる
- [x] エミュレーター（API 35 か 36）に入れて起動することを確かめる
  - 確認用の仮のメインシーン（JSON を読んで表示する）を一時的に置いた
  - 既定の SwiftShader の GPU では 3D 用のシェーダーの uniform が上限を超えて失敗した。`-gpu host` で起動して、表示と JSON の読み込みを確かめた
- [x] 確認用の仮の JSON を消す（仮のメインシーン・`project.godot` の `run/main_scene` も消した）

## フェーズ5: 持ち越していた確認

- [x] 組み込みクラス名との衝突
  - [x] Godot 4.7.2 の `ClassDB.get_class_list()` を、使い捨てのスクリプトで取得する
  - [x] `component-design.md` §6 の全クラス名と突き合わせる（gdUnit4 が登録するグローバルなクラス名とも突き合わせる）
  - [x] 結果を `component-design.md` §6 に記録する（衝突があればシャビに名前の変更を確認する）
- [x] フォント
  - [x] Noto Sans JP（Regular・Bold）と Barlow Condensed（SemiBold・Bold）を公式の配布元から取り、`game/assets/fonts/` に置く
    - コミット前レビューの指摘を受け、Noto Sans JP（約9.2MB）は置かないことにした（シャビ決定）。RFN は確かめたうえで、サブセットの作業で置く
  - [x] 各書体の `OFL.txt` を置き、予約フォント名（RFN）の有無を確かめる
  - [x] `game/assets/LICENSES.md`（台帳）を作り、フォントと gdUnit4 を記録する
- [x] INTERNET 権限
  - [x] デバッグ版の APK のマニフェストの権限を `aapt2` で調べる
  - [x] リリース版（デバッグ用の鍵で署名）の APK のマニフェストの権限を調べる
  - [x] 結果と扱い（デバッグ版で許容するか）を、NFR-10 の検査の手順とあわせて記録する（デバッグ版にも INTERNET は入らなかったので、許容の判断は不要になった）

## フェーズ6: 文書の更新

- [x] `architecture-overview.md`: Godot 4.7.2・gdUnit4 6.2.2・Android SDK と JDK・最小と対象の API レベルを記録する。4.6 の版で確かめる予定だった注記を直す
- [x] `repository-structure.md`: セットアップ手順1〜6 の実際のコマンドと結果、設定項目名、除外の確認結果、プロジェクト構造の「未作成」の更新
- [x] `non-functional-requirements.md` §2: 基準端末は未定（持ち越し）と記録する
- [x] 文書の版数・更新日を更新する（NFR 0.5。ほかは更新日のみ）

## フェーズ7: 品質チェックとコミット

- [x] `godot --headless --editor --quit`（`game/` で実行）がエラー 0件で終わる
- [x] gdUnit4 の CLI が正常に終わる（終了コード 0）
- [x] デバッグ版の APK の書き出しが成功する（書き出し先の `export/` を先に作る必要があった。手順に追記）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] main へコミットする（ファイルを名指しでステージする）

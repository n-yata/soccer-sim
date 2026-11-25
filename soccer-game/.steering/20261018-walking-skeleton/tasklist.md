# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的な理由で不要になった場合だけ。理由を明記する（`- [x] ~~タスク名~~（理由）`）
- タスクが大きすぎる場合は、サブタスクに分割して1つずつ完了させる

---

## フェーズ1: 画面の切り替えの入口

- [x] `tests/application/app_test.gd` を書き、失敗することを確かめる
- [x] `AppScreens`・`App` を作り、オートロードに登録して、テストを通す

## フェーズ2: 画面の入れ替え

- [x] テスト用の画面（`tests/fixtures/screens/`）と `tests/ui/screen_switcher_test.gd` を書き、失敗することを確かめる
- [x] `AppScreen`・`ScreenSwitcher` を作り、テストを通す

## フェーズ3: メインシーン

- [x] `tests/ui/main_shell_test.gd`（`side_margins`・`has_screen`）を書き、失敗することを確かめる
- [x] `MainShell` を作り、テストを通す（登録したシーンが実在するテストのため、タイトルは最小の形で先に置いた）
- [x] `project.godot` にメインシーン・地の色を設定する

## フェーズ4: テーマ

- [x] `app_theme.tres` を作り、`gui/theme/custom` に指定する（hover は通常と同じ）

## フェーズ5: タイトル画面

- [x] `tests/ui/title_screen_test.gd` を書き、失敗することを確かめる
- [x] `TitleScreen` のシーンとスクリプトを作り、テストを通す（6件。押せるかの判定を逆にする変異で落ちることを確認）

## フェーズ6: 実際の画面での確認

- [x] PC で 1280×720 と 1600×720 の画面を撮り、配置を確かめる。Esc でアプリが閉じることを確かめる
  - 撮影は `--write-movie`（`--script` ではオートロードが読み込まれない）。20:9 は一時的な `override.cfg` でビューポートを 1600×720 にして撮った。押せないカードの文字が読めない問題を見つけて直した（テストも追加）
  - Esc は一時的なオートロードで流し込み、`handle_back()` が1回（handled=false）呼ばれてアプリが閉じることを確かめた
- [x] デバッグ版の APK を書き出し、エミュレーターで起動してタイトルが出ることを確かめる（初回は Godot の起動画面のあと約10秒でタイトル。日本語は Android のシステムフォントで表示された）
- [x] エミュレーターで戻る操作をして、タイトルでは `handle_back()` が1回だけ呼ばれてアプリが閉じることを確かめる（ログ1行・プロセスが消えた）
- [x] `handle_back()` が `true` を返す仮の画面で、アプリが閉じないことを確かめ、仮の画面を消す（仮の画面の代わりに、タイトルの `handle_back()` を一時的に `true` にした APK で確認。戻る操作2回でログ2行・プロセスは残った。元に戻し、アプリはアンインストールした）
  - 1回目は差分のインストールで新しい APK が反映されず、元の APK のまま動いた。`adb install --no-incremental` で入れ直して確かめた

## フェーズ7: 文書の更新

- [x] `component-design.md`: §5 に `AppScreen`・`ScreenSwitcher`・`MainShell.SCREEN_SCENES`／`has_screen()`、§6 の名前の一覧と衝突の確認
- [x] `screen-01-title.md`: 骨格の段階で作っていない部分と「準備中」の扱い
- [x] `repository-structure.md`: 構造の「未作成」の更新、「動作確認の方法」の更新、書き出した APK の起動の確認の手順

## フェーズ8: 品質チェックとコミット

- [x] `tools/run-tests.sh` が成功する（100件）
- [x] 申し送り: タイトルの `enter()` が `MainShell.SCREEN_SCENES` を使っていることは、行き先の画面が1つも無いいまはテストで区別できない。S-02 などを足す作業で、押せるカードがあることをテストで確かめる（テストのコメントにも記載）
- [x] 実装レビュー（review-implementation）を行い、指摘を直す（総合 4.4/5、[必須] なし。[推奨] 6件はすべて対応: 組み立てた MainShell のテスト、push_error のテスト、FirstTimeBadge を you の地に、フォーカスの枠を出さない、名前の隠れの改名、`/game/override.cfg` の除外。[提案] は画面の入れ替えを call_deferred に。型付き Dictionary・tscn の uid は申し送り）
- [x] コミット前レビュー（review-pre-commit）を行い、新たな Critical / High が無くなるまで直す
- [x] 振り返りを `retrospective.md` に記録する
- [x] main へコミットする（ファイルを名指しでステージする）

# 要求内容

## 概要

アプリを起動するとタイトル画面が出て、画面の切り替え・戻る操作・終了が、PC のウィンドウと Android の両方で動く骨格を作る。
作るのは次の4つ。
- メインシーン（`MainShell`）
- 画面の切り替えの入口（`App`・`AppScreens`）
- タイトル画面（S-01）の骨格
- 配色のテーマ

## 背景

- メインシーンがまだ無い。そのため、PC で画面を確かめることも、書き出した APK が起動するかを確かめることもできない。
- 開発中の動作確認は PC のウィンドウで行う方針にした（2026-10-18 決定。`repository-structure.md`「動作確認の方法」）。
  まず、PC で画面を開けるようにする。
- 前の作業からの申し送りが3つある。
  - 開発環境の構築・ルールの土台から: 書き出した APK を起動して確かめる手順を固定する。
  - PC で確認する方針の作業から: Android の戻る操作で `handle_back()` が1回だけ呼ばれ、試合画面などでアプリが閉じないことを、エミュレーターで確かめる。

## 決定事項（2026-10-18 シャビの指示「動く骨格に進んで」を受けた範囲）

- サービス（`MatchController`・`UserDataService`・`LibraryService`）は作らない。タイトル画面のうち、サービスに頼る部分は、それを作る作業で足す。
  - 該当するのは、再開カード・小さなカードの一言・チュートリアルのカードの位置の切り替え・「CPU 対戦」の確認の手順。
- 行き先の画面がまだ無いカードは、押せないようにして「準備中」と表示する。
  - 画面が無いのに押せると、何も起きないか、エラーになる。どちらも確認のじゃまになるため。
  - 画面を作れば、自動的に押せるようになる形にする（画面の一覧の1か所を見る）。

## 実装対象の機能

### 1. 画面 ID と画面の切り替えの入口（アプリケーション層）
- `AppScreens`（`game/application/app_screens.gd`）: 画面 ID の enum（`S01_TITLE`〜`S12_SETTINGS`）と、保存エラーの種類の enum を持つ（`component-design.md` §3.1）。
- オートロード `App`（`game/application/app.gd`）: `screen_requested` シグナルと `request_screen()` を持つ。
  - サービスの変数と `storage_error` は、サービスを作る作業で足す。

### 2. メインシーン `MainShell`（`game/ui/main_shell.tscn`）
- `App.screen_requested` を受けて、画面のシーンを入れ替える。入れ替えでは、古い画面の `exit()`、新しい画面の `enter(params)` を呼ぶ（`screen-common.md` §4）。
- 起動したらタイトルを開く。
- 戻る操作は、Android の戻る操作と PC の Esc を、表示中の画面の `handle_back()` に渡す。`false` が返ったらアプリを閉じる（`screen-common.md` §4.1）。
- セーフエリアの分を、左右の余白に足す（`screen-common.md` §1.1）。
- 画面 ID → シーンの対応を1か所に持つ。対応の無い画面を求められたら、エラーを出して今の画面のままにする。

### 3. タイトル画面 `TitleScreen`（S-01 の骨格）
- `screen-01-title.md` の配置のうち、サービスに頼らない部分を作る。
  - 左の `Hero`: タグ・プロダクト名・キャッチコピー。スタジアムの絵は素材ができるまで地の色にする。
  - 右の列: チュートリアルのカード（未完了の位置）・「KICK OFF／CPU 対戦」・小さなカード4枚。
- 各カードは、行き先の画面が `MainShell` にあるときだけ押せる。無いときは押せず「準備中」と出す。
- `handle_back()` は、`IDLE` で `false`（アプリを閉じる）を返す。

### 4. テーマ（`game/ui/common/theme/app_theme.tres`）
- `screen-common.md` §3 の色（`bg`・`surface`・`text`・`accent`・`disabled_*` など）と、ボタン・ラベルのスタイルを定義する。
- ホバーの見た目は、通常と同じにする（`screen-common.md` §4.1）。
- 英字の見出し（`KICK OFF`・`MATCHDAY TACTICS`）には Barlow Condensed を使う。
- 日本語は、Noto Sans JP を置くまで、Godot の既定のフォント（端末のフォントで代わりに表示される）にする。

## 受け入れ条件

### 画面の切り替え
- [ ] `App.request_screen()` が、`screen_requested` を同じ画面 ID と引数で1回出す（gdUnit4）。
- [ ] `MainShell` は、起動するとタイトルを開く。別の画面を求められたら、古い画面の `exit()` を呼んでから外し、新しい画面の `enter()` を呼ぶ（gdUnit4。テスト用の画面のシーンを使う）。
- [ ] 対応の無い画面 ID を求められたら、今の画面のまま、エラーを出す（gdUnit4）。
- [ ] 戻る操作で、表示中の画面の `handle_back()` が1回だけ呼ばれ、その戻り値でアプリを閉じるかが決まる（gdUnit4 で判断の部分を確かめる）。
- [ ] セーフエリアの左右の余白の計算が、切り欠きの無い端末・左右に切り欠きのある端末で正しい（gdUnit4）。

### タイトル画面
- [ ] 行き先の画面が無いカードは押せず、「準備中」が出る。行き先がある場合は押せる（gdUnit4 で、対応の有無から決まることを確かめる）。
- [ ] `IDLE` の `handle_back()` は `false` を返す（gdUnit4）。

### 実際の画面での確認
- [ ] PC で `godot --path game` を実行するとタイトル画面が出る。16:9（1280×720）と 20:9（1600×720）の両方で、配置が崩れない（画面を撮って確かめる）。
- [ ] PC で Esc を押すと、アプリが閉じる。
- [ ] 書き出した APK がエミュレーターで起動して、タイトル画面が出る。
- [ ] エミュレーターで戻る操作をすると、`handle_back()` が1回だけ呼ばれ、タイトルではアプリが閉じる（ログで確かめる）。
  - 試合画面などで閉じないことは、その画面が無いため、`handle_back()` が `true` を返すテスト用の画面で確かめる（確認後に消す）。

### 共通
- [ ] `tools/run-tests.sh` が成功する。禁止依存の検査も、引き続き 0 件。
- [ ] 型の警告（エラー扱い）が 0 件。

## 成功指標

- シャビが PC で `godot --path game` を実行して、タイトル画面を見られる。
- 以降の画面の作業では、画面のシーンを作って `MainShell` の対応に1行足すだけで、タイトルから開ける。

## スコープ外

- サービス（`MatchController`・`UserDataService`・`LibraryService`）と、それに頼るタイトルの機能
  - 再開カード、小さなカードの一言、チュートリアルの位置の切り替え、「CPU 対戦」の確認の手順、`NewMatchGate`・`ConfirmDialog`
- 保存エラーの通知（`storage_error`・`ToastView`）
- S-02 以降の画面
- スタジアムの絵などの素材、Noto Sans JP の同梱（サブセットの作業）
- 書き出した APK の起動の確認の自動化（CI。リモートを用意した時点）。今回は手順を `repository-structure.md` に固定する

## 参照ドキュメント

- `docs/specs/2_basic-design/component-design.md` - §3.1（`App`・`AppScreens`）、§5.1・§5.2（`MainShell`・画面）
- `docs/specs/2_basic-design/screen-design.md` - S-01・ビジュアルの方向性
- `docs/specs/3_detail-design/screen/screen-common.md` - §1（寸法・セーフエリア）、§2（フォント）、§3（配色）、§4・§4.1（画面の出入り・入力）
- `docs/specs/3_detail-design/screen/screen-01-title.md` - タイトルのノード構成・状態・戻る操作
- `docs/specs/1_requirements/repository-structure.md` - 動作確認の方法・書き出し

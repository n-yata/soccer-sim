# 要求内容

## 概要

設定（FR-15）を作る。BGM・効果音の音量とヒント表示（FR-19）の ON/OFF を変え、端末内に保存する。
設定の画面（S-12）と、試合中のメニューから重ねて開く設定の両方から変えられる。

## 背景

タイトルの「設定」と試合中のメニューの「設定」は「準備中」のまま。ヒントは常に出ていて、消せない。
戦績の作業で `UserDataService` と保存の形（`RecordStore`）ができたので、同じ形で設定の保存を足す。
理解度チェック（FR-22）は後回しにする（2026-10-29 シャビ判断）。

## 実装対象の機能

### 1. 設定の保存（`SettingsStore`。data-definition.md §2.4）
- `settings.cfg`（ConfigFile）。`[meta] format_version`、`[audio] bgm_volume`・`se_volume`（0.0〜1.0。初期値 0.7）、
  `[ui] show_hints`（初期値 ON）、`[progress] tutorial_completed`（初期値 OFF）
- 1つのキーだけが範囲外・型違いなら、そのキーだけを初期値にする
- `format_version` が無い・読めない（ConfigFile として読めないを含む）なら破損: 本体を退避して初期値（戦績と同じ退避の規則）
- 新しい版なら初期値で表示し、書き込まない

### 2. 参照（`UserDataService`）
- `settings()`・`save_settings()`・`mark_tutorial_completed()`。最初に使うときに1回だけ読む
- 読み込みの破損・新しい版、保存の失敗を `App.storage_error` で知らせる（保存の失敗は続く間1回）

### 3. 音量
- オーディオバス `BGM`・`SE` を作る（`default_bus_layout.tres`）。音量は `linear_to_db(値)`、0 ならミュート
- 起動時に `MainShell` が設定を読んでバスへ反映する。スライダーを動かす間もその場で反映する
- 音そのもの（BGM・効果音の素材）はまだ無い（音の作業で足す）

### 4. 画面
- S-12 設定: ヘッダーと `SettingsPanel`（BGM・効果音のスライダー 0〜100 刻み 5 と数値、ヒント表示のトグルと説明、ライセンス）
- ライセンス: 同梱フォントの OFL の本文と著作権表示を、スクロールできるパネルで出す
- 試合中のメニューの「設定」: 同じ `SettingsPanel` を重ねて開く。戻る操作で閉じ、試合に戻る
- ヒント表示を OFF にしたら、試合画面はヒントを出さない（`user_hints()` を呼ばない）。手を選んでいる間に切り替えたら、選んだ手のまま描き直す
- 保存は、スライダーを離したとき・トグルを切り替えたときだけ（動かしている間は保存しない）

## 受け入れ条件

- [ ] 設定を変えて保存すると、作り直したサービスで同じ値が読める（再起動後も保持）
- [ ] 範囲外・型違いのキーはそのキーだけ初期値、`format_version` が無いファイルは退避して初期値、新しい版は書かない。破損と新しい版は通知を1回
- [ ] 音量を変えるとバスの音量が変わり、0 ならミュート
- [ ] ヒント表示 OFF で、試合画面の選べるエリアにヒントの札が出ない。試合中に切り替えるとその場で消える／出る
- [ ] S-12 から戻るとタイトル、試合中の設定から戻ると試合のまま
- [ ] タイトルの「設定」、試合中のメニューの「設定」が押せる
- [ ] 全テストが通る

## スコープ外

- BGM・効果音の素材と再生（音の作業）
- タイトルのチュートリアルの位置の切り替え（チュートリアルの作業。`tutorial_completed` の保存と `mark_tutorial_completed()` だけ作る）
- 理解度チェック（後回し）
- Noto Sans JP のライセンス（フォントを置く作業で足す）

## 参照ドキュメント

- `docs/specs/1_requirements/requirements-definition.md` FR-15・FR-19
- `docs/specs/1_requirements/functional-overview.md`「エラーハンドリング」
- `docs/specs/2_basic-design/component-design.md` §3.4・§4.3
- `docs/specs/3_detail-design/data/data-definition.md` §2.4
- `docs/specs/3_detail-design/screen/screen-12-settings.md`・`screen-03-match.md`（メニュー）・`screen-common.md`

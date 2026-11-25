# コミット前レビューレポート

## 第1回（2026-10-18）
- 対象: `docs/specs/3_detail-design/screen/screen-common.md`（§4.1 を追加）、`docs/specs/1_requirements/repository-structure.md`（「動作確認の方法」を追加）、`docs/specs/1_requirements/non-functional-requirements.md`（版数 0.6、§2 の注記）。文書だけで、実装コードの変更なし
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 5件

## コミット前レビュー結果

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
- [バグ] **Android の戻る操作で、Godot の既定設定のままだとアプリが勝手に終了する**: `application/config/quit_on_go_back` は既定で `true` で、`game/project.godot` でも上書きしていない。この設定だと、戻る操作の通知が届いたとき、`handle_back()` の戻り値に関係なく SceneTree が終了する。このため screen-03「いずれも `true` を返す（試合画面からアプリを閉じない）」と screen-01 の `CONFIRMING`（ダイアログを閉じるだけ）が成り立たない。もとの欠落は今回の差分より前の §4 にあるが、§4.1 が「戻る操作は MainShell が handle_back へ渡す」と書き直しているので、ここで直すのがよい。→ §4.1 に「`quit_on_go_back` は `false` にし、アプリを閉じるのは handle_back が false を返したときに MainShell が `get_tree().quit()` を呼ぶ形だけにする」を足し、「セットアップ手順 2」の設定の表にも載せる。
- [バグ] **`AreaCell` を「左ボタンを離したとき」で受けると、指を外へずらして離しても選ばれる**: 押した Control が離すまでマウスを受け続けるため、セルの外で離したイベントも押したセルに届く。`Button` は内部で判定しているが、`AreaCell` が自分で受けるなら同じ判定が要る。→ 離した位置がセルの内側（`Rect2(Vector2.ZERO, size).has_point(event.position)`）のときだけ選んだとみなす、と §4.1 に書く。単体テスト仕様に「外で離したら選ばれない」を入れる。

### Low / 改善提案
- [バグ] ホバーの表示が、作らなくても出る。`Button` はテーマの `hover` スタイルを既定で持ち、Android ではタップした位置にマウスが残ってホバーの見た目のままになる。→ テーマの `hover`（と `hover_pressed`）を `normal`（と `pressed`）と同じスタイルにする、と書く。
- [バグ] Esc の受け方の指定が足りない。→ `MainShell._unhandled_input` で `event.is_action_pressed("ui_cancel")`（キーリピートは無視）を受け、処理したら `get_viewport().set_input_as_handled()` を呼ぶ、と書く。
- [運用] 「PC では確かめられないもの」の性能の列挙が不正確（NFR-03・NFR-24・NFR-08 ② が抜け、NFR-04 は Play Console で測るもの）。→ 列挙をやめて NFR 側の「Android 基準端末で」と定めたものを参照する形にすれば、二重管理にならない。
- [運用] 仕様書に呼び名（「シャビ決定」）が入る。既存の仕様書の書き方「2026-10-18 決定」に揃える。
- [運用] `screen-common.md` について git が改行コードの変換を警告している。`.gitattributes` の方針を確かめるとよい（実害は小さい）。

### 問題なし
- セキュリティ①: シークレット・キー・URL・エンドポイント・クラウドのアカウント情報・ローカルパス・メールアドレスの混入は無い。コマンド例は `godot --path game` と `emulator ... -gpu host` だけ。
- セキュリティ②〜④・OWASP・性能: 該当なし（文書だけ）。
- 既存の仕様との整合: 配布先（Android、Windows 版は後続）、1280×720・`canvas_items`・`keep_height`（20:9 を 1600×720 で確かめる説明は正しい）、`sensor_landscape`、エミュレーターの参照、NFR-19 を PC で代えないこと、タイトルの既定の動き、はいずれも既存の記述と一致する。
- 入力の二重処理: マウスのイベントと `Button.pressed` だけを受け、`InputEventScreenTouch` を扱わず、`emulate_touch_from_mouse` を有効にしない組み合わせなら、二重に動くことはない。
- 切り戻し: 文書だけなので revert で戻せる。

### 未検証
- `quit_on_go_back` の名前・既定値と、自動で終了する挙動（Godot 4 系の知識にもとづく指摘）。
- Android の戻るキーが、`ui_cancel` のキーイベントを同時に出さないか（出せば handle_back が二重に呼ばれる）。エミュレーターで1回確かめることを勧める。
- Android でハードウェアキーボードの Esc を押したときの挙動。
- 依頼元が確かめた3つの設定の既定値。

### 総合評価
Critical / High なし。コミットしてよい。Medium の1件目（`quit_on_go_back`）は §4.1 の前提に関わるため、今のうちに §4.1 と「セットアップ手順 2」へ追記することを強く勧める。2件目も、実装より先に仕様へ書いておくのがよい。

### 対応
- Medium（`quit_on_go_back`）: 直した。Godot 4.7.2 の ProjectSettings で、名前が `application/config/quit_on_go_back`、既定が `true` であることを確かめた（未検証の1件目は確認済みになった）。§4.1 に「`false` にし、閉じるのは MainShell の `get_tree().quit()` の経路だけ」を書き、`game/project.godot` に `config/quit_on_go_back=false` を入れ、「セットアップ手順 2」の設定の表に載せた。Godot が `false` として読むこと、テスト（69件）が通ること、エディタが `project.godot` を書き換えないことを確かめた。実際の戻る操作でアプリが閉じないことは、メインシーンを作る作業でエミュレーターで確かめる（「動作確認の方法」の PC では確かめられないものに記載）。
- Medium（`AreaCell` の離した位置）: 直した。§4.1 に、離した位置がセルの内側のときだけ選んだとみなすこと、と理由を書いた。単体テストのケースは、`AreaCell` を実装する作業で入れる。
- Low（ホバー）: 直した。テーマの `hover`・`hover_pressed` を `normal`・`pressed` と同じスタイルにする、と書いた。
- Low（Esc の受け方）: 直した。`MainShell._unhandled_input`・`is_action_pressed("ui_cancel")`（リピートを受けない）・`set_input_as_handled()` を書いた。
- Low（性能の列挙）: 直した。列挙をやめ、`non-functional-requirements.md` で「Android 基準端末で」と定めたものを参照する形にした。Android の戻る操作の確認内容（`handle_back()` が1回だけ呼ばれ、閉じないこと）を足した。
- Low（呼び名）: 直した。3か所とも「2026-10-18 決定」にした。
- Low（改行コード）: 直さない。リポジトリは `core.autocrlf=true` の環境で、既存の文書も同じ扱い（`.gitattributes` は kit の複製物と `.ps1` だけを対象にしている）。今回の変更とは関係しない。
- 新たな Critical / High を直したものではないため、再レビューは行わない（スキルの規則）。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: 実際の Android の戻る操作で `handle_back()` が1回だけ呼ばれ、アプリが閉じないことの確認（メインシーンを作る作業で、エミュレーターで確かめる。いまは確かめる手段が無い）。`AreaCell` の「外で離したら選ばれない」の単体テスト（`AreaCell` を作る作業で入れる）

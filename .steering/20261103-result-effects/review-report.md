# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: 結果の演出の作業の hunk。新規の result_effect.gd・result_effect_test.gd、tactics_board / board_shift / board_painter / ball_flight / match_board_panel、presentation_config.gd と .tres、config_repository、match_controller の board_result_sec、関係テスト、docs の該当箇所、`.steering/20261103-result-effects/`。並行セッションの hunk と tools/run-tests.sh は対象外
- レビュー役: general-purpose（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果
対象: 結果の演出の作業。新規の result_effect.gd と result_effect_test.gd、変更した tactics_board.gd・board_shift.gd・board_painter.gd・ball_flight.gd・match_board_panel.gd・presentation_config.gd/.tres・config_repository.gd・match_controller.gd、追加したテスト（tactics_board・ball_flight・panel・config_repository）、docs の該当 hunk。読み取りだけで確認し、ファイルは変更していない。Godot のテストも実行していない。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
**L1【バグ】エリアのキーが読めないと、印が盤面の左上に出る（いまは起きない）**
- `ResultEffect.for_reveal` は、SAVE・WIN_BALL では `ball_after`、OFFSIDE では `compare_area` を検証せずに `area` に入れている。`draws_mark` も kind しか見ていない。
- そのため、キーが空か読めないと `area_rect` が `Rect2()` を返し、輪や旗が盤面の左上（原点）に出る。エラーにはならないので、静かに誤る。
- いまの経路では起きない。view_converter.gd では OFFSIDE のとき必ず judge があり、`compare_area` が入っている。ボールの位置もいつも読めるキーになっている。ただ、`has_detail == false` の OFFSIDE が将来できると表に出る。
- 修正例（result_effect.gd の `_effect`）:
```gdscript
static func _effect(kind: Kind, area: String, is_user: bool) -> Dictionary:
	if kind != Kind.GOAL and PitchArea.from_key(area) == null:
		return {"kind": Kind.NONE, "area": "", "is_user": false, "toward": ""}
	return {"kind": kind, "area": area, "is_user": is_user, "toward": ""}
```
- 先に固定するテストの例: result_effect_test に、`has_detail=false`・`compare_area=""` の OFFSIDE なら kind が NONE になるケースを足す。

**L2【運用・ドキュメント】component-design.md に古い一文が残っている**
- 「テロップ・矢印はすぐ出し」が「2026-11-03 に1拍目の後へ移した」という注記付きで残っている。注記があるので食い違いにはなっていない。ただ、本文を「矢印はすぐ出し」に直すほうが読み違いにくい。任意。

### 問題なし（確認済み項目のリスト、観点ごと）
**セキュリティ**
- ① ハードコーディング: URL・キー・アカウント情報は無い。`.steering` と新規ファイルを grep して確認した。0.8 秒は .tres と `PresentationConfig` の既定値に外出しされている。
- ② 認証・認可: オフラインの単体ゲームで、この差分は保護するリソースに触れない。該当なし。
- ③ インジェクション: 外部入力は無い。区分・エリアのキーはドメインの値から作っている。
- ④ 情報漏洩: 増えたログは push_error 1つで、出すのは設定値だけ。
- A08: 新しい値は既存の `_load_presentation` の検証（`_is_board_sec_valid`）を通る。範囲外・NAN・INF なら初期値に戻ることを、テストで確認している。新しく読み込む経路やデシリアライズは無い。
- A05 設定ミス: 盤面側でも `set_result_sec` が有限でない値を 0（演出なし）に落とす。fail open になる経路ではない。

**バグ**
- 着地の知らせは1回だけ: `_landing_pending` で一度きりにしている。届く時点は3つで、1拍目が取り除かれたとき（`keyframe != 0`。短絡評価で空配列も安全）はすぐ、1拍目の後は Tween の callback、途中で止めたときは `_stop_shift`。
- 状態のリセット:
  - `show_snapshot`・`clear_overlays`・`start_shift` が `_clear_effect` を呼ぶので、前のターンの演出は残らない。
  - 「ターンを始める」は `_reveal = null` を先にしてから `clear_overlays` を呼ぶ。止めたときに届く着地は `_on_play_landed` で捨てられ、前のテロップは出ない。
- 処理の順序:
  - `_on_turn_resolved` は、テロップの中身・`_judge_telop.visible=false`・`State.SHOW_RESULT` を `start_shift` より先に作る。そのため同期で届く着地でも正しく出る。
  - 前のターンの着地が `clear_overlays` の中で届いても、後の `visible=false` で上書きされる。
- 着地の中で受け手が `clear_overlays` を呼んでも壊れない。`start_shift` の後は `is_active()` を見て return する。
- `shape_ball_paths`:
  - beats と keyframes が添字で対応するのは、`start()` で取り除く前だから成り立つ。
  - GOAL の側は `turn_winner` と `is_top` で一致する（利用者は常に上へ攻める）。
  - 2拍目の道筋が空なら作る。始まりのキーが読めなければ何もしない。
  - STALL の `toward` は、利用者側に変換した後の choice の target。
- BOUNCE は終わりに起点へ戻る（sin(π)≈0）。2拍目以降の `_point_on` は from を使うので、ボールは飛ばない。
- チュートリアル（`show_next=false`）では、テロップは着地で出て、`turn_ready_to_leave` はすぐ出る。これまでと変わらない。
- 振り返りなど `bind` しない盤面は `_result_sec=0` になり、演出を出さない。
- テスト: 恒真テストやコピーのテストは見当たらない。
  - 着地の回数、止めたとき、1拍目が無いとき、時間が 0 のとき、消去で消えることを具体的な値で見ている。
  - ゴールの口が上下のゴールの中にあることも確かめている。
  - ball_flight のテストを BOUNCE に合わせて緩めた部分は、別の専用テストで補っている。

**性能**
- 1回の開示で増える Tween は1つ（演出）と callback 1つ。
- 描画は演出の間（≦2 秒）だけで、輪の33点の polyline、または多角形2つ。規模が増える要素は無く、問題にならない。

**運用**
- 新しい設定 `board_result_sec` は外出しされている。.tres に無いときは既定値 0.8 になるので、後方互換がある。範囲外なら push_error を出して初期値に戻る。
- 切り戻しは .tres の値を変えるだけでは演出を消せない（0 は範囲外で初期値に戻る）。コードを戻せば済むので問題ない。
- docs（functional-overview・component-design・screen-common）に API・シグナル・設定値・描く順番（⑤.5）が書かれている。

### 未検証（確認できなかった範囲と理由）
- Godot のテストは実行していない（指示どおり）。パスしたことは依頼元の報告に頼っている。
- 画面での見え方（旗の大きさ・輪の色・奥行き）は確かめていない。
- requirements.md・design.md・tasklist.md と、usecase-sequences.drawio のラベルは、機密情報の grep だけで確認した。内容が実装と合っているかは精読していない。
- `SAVE` のとき `ball_after` が GK のエリアになっているかは、ドメイン側の仕様として前提にした（match_rules の該当箇所までは追っていない）。

### 総合評価
Critical・High は無い。コミットしてよい。L1 は今の経路では起きないが、直すならテストを先に固定してから入れるのを勧める。

### 対応
- L1: 直した。先に `result_effect_test` に「場所が読めない OFFSIDE・LOSS は演出なし（得点はゴールに描くので出す）」のテストを足して落ちることを確かめ、`ResultEffect._effect` で場所が読めなければ NONE を返すようにした。
- L2: 直さない。この一文は 2026-10-22 の経緯の注記（当時の決めごと）で、2026-11-03 に変えたことを同じ文の中と後の注記に書いてある。経緯の本文を書き換えると、いつ何を変えたかが追えなくなる。

## レビュー完了（2026-11-03）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: なし（L1 は直した。L2 は経緯の注記として残す判断）

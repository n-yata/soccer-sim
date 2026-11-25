# コミット前レビューレポート

## 第1回（2026-11-05）
- 対象: piece_motion 作業の hunk（新規の piece_motion.gd・piece_motion_test.gd、board_shift・board_reveal・tactics_board・board_painter・match_board_panel（bind の2行）・presentation_config・config_repository・match_controller の piece_style/board_beat_gap_sec、関係テスト、docs の該当箇所、`.steering/20261105-piece-motion/`）。別セッションの CLOSE_DOWN 関係は対象外
- レビュー役: general-purpose（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 3件

## コミット前レビュー結果
対象: piece_motion 作業の hunk。新規の piece_motion.gd と piece_motion_test.gd、変更の board_shift / board_reveal / tactics_board / board_painter / match_board_panel（bind の2行）/ presentation_config.gd・.tres / config_repository.gd / match_controller.gd（piece_style・board_beat_gap_sec）、関係するテストの hunk、docs の該当 hunk。別セッションの CLOSE_DOWN 関係（game_enums・move_menu・move_rules・open_play_judge など）は対象外。Godot のテストは実行していない。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
**L1【バグ／堅牢性】`TacticsBoard.set_piece_style` が有限かどうかしか見ず、範囲外の値をそのまま受け取る**
- 起きること:
  - hop が負だと `piece_lift` が負になる。hop = -1 のとき、道筋の真ん中で `board_painter._draw_chess_piece` の `shrink = 1.0 / (1.0 + lift)` が 0 除算になり、INF になる。影の大きさと色が壊れる。
  - stagger が負だと `local_t(1.0, 0, s) = 1/(1+|s|) < 1` になり、拍の終わりに駒が着かない。次の拍か停止で rest の位置へ飛ぶ。
- 実害が出る条件: 本番の経路は `ConfigRepository._is_piece_motion_valid` で 0〜上限に絞られている。今の経路では起きず、将来ほかの呼び出し元が値を直接入れたときだけ起きる。
- 修正例（範囲の正本は ConfigRepository の定数）:
```gdscript
func set_piece_style(style: Dictionary) -> void:
	var stagger: float = style.get("stagger", 0.0) as float
	var hop: float = style.get("hop", 0.0) as float
	_reveal.shift.piece_style = {
		"stagger": clampf(stagger, 0.0, ConfigRepository.MAX_PIECE_STAGGER) if is_finite(stagger) else 0.0,
		"hop": clampf(hop, 0.0, ConfigRepository.MAX_PIECE_HOP_HEIGHT) if is_finite(hop) else 0.0,
	}
```
- 先に固めるテスト例: `test_bad_piece_motion_values_mean_no_stagger_or_hop` に `{"stagger": -0.5, "hop": -1.0}` の場合を足す。lift >= 0 であることと、progress = 1 で to に着くことを確かめる。
- 依存の向き（UI → data の定数）が気になるなら、clamp だけ入れて上限は 1.0 未満の固定値にする案でもよい。

**L2【テスト空振り】`_order_by_distance` の「ボールのエリアが読めない拍は全員 0」の分岐を単独で検出するテストがない**
- `test_a_single_moving_piece_has_no_delay` は「1人だけ」と「ボールが X-9」を同時に満たしている。そのため `PitchArea.from_key(ball_key) == null` の判定を消しても、`distances.size() < 2` で order 0 になり、テストは通ってしまう。
- その分岐が誤ったときの症状: ボールが読めない拍で、`_row_point` の (-1,-1) のような値からの距離で順が付く。
- 修正例: 2人以上が別の距離から動き、ball が "X-9" の拍を足して、全員 order 0 を確かめる。

**L3【テスト安定性】`await_millis` の実時間に頼るテストがある**
- tactics_board_test の小休止の2件、bad piece motion、lift の件。match_board_panel_test の 600ms の件。
- 余裕は 200〜300ms 程度あり、今は問題ない。ただし負荷が高いとき（全件実行と重なったとき）に揺れうる。記録だけしておく。

### 問題なし（確認済み項目のリスト、観点ごと）
**セキュリティ**
- ① ハードコーディング: 差分に URL・キー・アカウント情報はない。docs の hunk にも機密はない（piece/小休止/http/key/token で差分を絞って目視した）。
- ② 認証・認可: 対象外。オフラインの単体ゲームで、差分に保護資源がない。
- ③ インジェクション: 外部入力は presentation_config.tres だけ。ResourceLoader の既存経路で読み、新しい3つの値は `is_finite` と 0〜上限で検証している。NaN と INF は不合格になり初期値に戻る（テストで固定されている）。
- ④ 情報漏洩: push_error に出るのは設定値3つだけで、機密はない。
- OWASP: 新しい読み込み方式（ConfigFile.parse など）は加えていない。A08 の観点で後退はない。

**バグ**
- `local_t`: span <= 0 のゼロ除算を避けている。progress = 1 では order ≤ 1 なら必ず 1 になる。範囲外の progress も clamp している。
- `smooth` / `hop`: どちらも clamp しており、端の値は 0 と 1。
- `_order_by_distance`: 同じ距離を同じ順にしている（snappedf の値を同じ計算で比べるので find が一致する）。0件、1件、全員同じ距離のとき、割り算 `(size-1)` が 0 にならない（size < 2 で先に return している）。
- 小休止の順序: `_land` は interval より前に積まれており、着地は小休止を待たない。最後の拍の後には interval を置かない。小休止の間は progress = 1 のまま前の拍に残り、駒は to に止まっている。
- 状態のリセット: piece_style と beat_gap は bind で入る設定値で、開示ごとの状態ではない。`stop()` の `shift.clear()` で拍が消え、lift は 0 に戻る（テストあり）。bind しない盤面（振り返りなど）は空の dict と 0 なので、ずらし・弾み・小休止はない。
- 描画: preview の駒は "lift" を持たないが、`thing.get("lift", 0.0)` で安全に読める。影は地面の足元に残る。
- 有限でない gap（NaN・INF・負）は 0 として扱う（テストあり）。

**性能**
- `piece_lift` は描画のたびに、駒1つごとにいまの拍の道筋をなめる。O(P²) で P ≤ 22 なので、1フレームあたり数百回の dict 参照で済む。問題になるのは駒が数百規模になってからで、このゲームでは起きない。
- `_order_by_distance` は拍の組み立て時に1回だけ動く。`distances.has` / `find` で O(P²) だが P ≤ 22 なので問題ない。

**運用**
- 新しい3つの値は .tres に外に出しており、範囲外なら push_error を出して初期値へ戻す。
- 古い .tres でキーが無い場合は `@export` の既定値が入り、後方互換がある。
- docs と実装の範囲・初期値（0.35 / 0.35 / 0.12、上限 0.8 / 1.5 / 0.5）は一致している。
- 切り戻しは、値を 0 にすれば旧来の挙動に近づく。ただしイージングは常にかかる。

### 未検証（確認できなかった範囲と理由）
- Godot のテストは実行していない（指示どおり）。成否は依頼元の報告による。
- `ResultEffect.shape_ball_paths` が piece_paths の "order" を保つかは読んでいない。`path.get("order", 0.0)` で既定値があるので、失われても壊れはせず、ずらしが消えるだけ。
- .steering の3ファイルは一覧を確かめただけで、本文は読んでいない。
- `standing_order` の並べ替えの基準（lift を入れても奥から手前の順が崩れないか）は、差分の外なので見ていない。

### 総合評価
**Critical / High の指摘はなし。コミットしてよい。** Low は3件。L1（範囲外の値への防御）は今の経路では起きないので、先送りしてよい。ただし先送りするなら、上のテストを先に固めることを勧める。

### 対応
- L1: 直した。先に `test_bad_piece_motion_values_mean_no_stagger_or_hop` へ負の値の場合を足し、`set_piece_style` で負の値を 0 に、ずらしの幅を 0.95 以下に押さえた（UI から data の定数を読まないよう、上限は「拍の終わりに着く」ための固定の値にした）。
- L2: 直した。2人以上が別の距離から動き、ボールが読めない拍で、全員の順が 0 になるテストを足した。
- L3: 直さない。余裕は 200〜300ms あり、全件実行と重ねて流さない運用で揺れを避ける。

## レビュー完了（2026-11-05）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: L3（実時間待ちのテスト）。いまの余裕で足りている

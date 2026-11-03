# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: ボールの軌道（ball_flight）の作業の hunk。新規の ball_flight.gd・ball_flight_test.gd・board_shift_test.gd、board_shift / tactics_board / board_painter / match_board_panel、presentation_config.gd と .tres、config_repository、match_controller の ball_style、関係テスト、docs の該当箇所、`.steering/20261103-ball-flight/`。並行セッションの hunk と tools/run-tests.sh は対象外
- レビュー役: general-purpose（opus）
- 結果: Critical 0件 / High 0件 / Medium 1件 / Low 4件

## コミット前レビュー結果
対象: ボール軌道の作業（ball_flight）のファイルのうち、この作業の hunk。新規の ball_flight.gd・ball_flight_test.gd・board_shift_test.gd（.uid を含む）、board_shift / tactics_board / board_painter / match_board_panel、presentation_config.gd と .tres、config_repository、match_controller の ball_style、関係テストの差分、docs の該当箇所、.steering/20261103-ball-flight/。読み取りだけで検査し、Godot は起動していない。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
**M-1 [バグ／テストの空振り] パネルの bind で高さを渡す1行を、どのテストも確かめていない**
- 場所: `game/ui/board2d/match_board_panel.gd:79` の `_board.set_ball_style(_controller.ball_style())`
- この行が消えても `ball_style` は `{}` のままになるだけです。浮き球もドリブルも高さ 0 で動き、エラーも警告も出ません。
- tactics_board_test は `set_ball_style` を直接呼んでいます。match_board_panel_test が見ているのは `ball_path["flight"]` だけです。つまり実際の試合画面で浮くかどうかは、どのテストでも捕まりません。変異18個の中にもこの行を消す変異は無かったはずです。
- 対策（テスト案。match_board_panel_test の既存シナリオ、CPU の攻撃の場面に足す）:
```gdscript
# bind で入れた軌道の値で浮く（bind の set_ball_style を消すと高さが 0 のままになる）
var flight: int = ball_path["flight"] as int
if flight == BallFlight.Kind.LOFTED or flight == BallFlight.Kind.CARRIED:
    await await_millis(int(_controller.board_play_sec() * 1000 * 0.4))
    assert_float(board.ball_lift()).is_greater(0.0)
```
- 場面に決まった手が出ない場合は、bind の直後に浮き球の keyframe を `start_shift` に渡し、途中の `ball_lift()` が 0 より大きいことを確かめる形でも足ります。

### Low / 改善提案
**L-1 [バグ／テストの空振り] `board_shift_test.gd` の `test_the_ball_is_on_the_ground_when_it_does_not_move_in_this_beat` が、コメントの場面を試していない**
- `_shift(Kind.LOFTED, false)` の2拍目は、駒の道筋もボールの道筋も空です。そのため `BoardShift.start()` で取り除かれ、`beats.size()` は 1 になります。
- 結果として `begin_beat(1)` は範囲外の添字を確かめているだけです。「2拍目（駒は動くがボールは動かない拍）の間は高さ 0」という場面は通っていません。
- 対策: 2拍目に駒の道筋を1本入れて、拍が残るようにする。
```gdscript
func _shift(first_flight: int, second_ball: bool = true) -> BoardShift:
    ...
    var second_pieces: Array[Dictionary] = [{"player_id": "p1", "is_user": true, "from": TO, "to": Vector2(10, 0)}]
    shift.start([
        {"piece_paths": [] as Array[Dictionary], "ball_path": {...}, "sec": 1.0},
        {"piece_paths": second_pieces, "ball_path": second_path, "sec": 1.0},
    ])
# テスト側で拍が2つ残っていることも確かめる
assert_int(shift.beats.size()).is_equal(2)
```

**L-2 [バグ／テスト] 描画で `lift` を使っていることがテストされていない**
- 場所: `board_painter.gd` の `_draw_lifted_ball`
- tactics_board_test が確かめているのは `standing_order()` の `"lift"` までです。painter が `lift` を捨てても（`-r * 1.6` に戻しても）テストは通ります。
- 見た目だけの話で実害は小さいです。直すなら、中心を出す小さな純関数（例 `static func lifted_ball_center(foot, r, lift) -> Vector2`）に切り出して単体で確かめる方法があります。

**L-3 [運用] 全体テストがまだ流れていない**
- tasklist の36行目（`run-tests.sh` の全体実行、3分以内）がまだ未チェックです。
- 関係スイートと変異の結果は出ていますが、コミットの前に全体を流す手順が残っています。並行セッションの run-tests.sh の短縮が入るのを待っている状態です。

**L-4 [運用／見た目] 浮き球の上限 20 は、奥の行で盤面の上にはみ出しうる**
- 上限 20 は `BALL_RADIUS` が 11 なので、およそ 236px 持ち上がる計算です。初期値 6 なら約 84px なので問題ありません。
- 文書は「高すぎると盤面の上へはみ出す」と上限の理由を書いていますが、20 で収まるかは確かめていません。設定を変える人向けの注意として残す程度で十分です。

### 問題なし（確認済み項目、観点ごと）
**セキュリティ**
- ① ハードコーディング: 差分に URL・キー・トークン・アカウント情報は無い。追加した値は描画の係数（6.0／1.0／3、上限 20／5／8）だけ。.steering と docs にも機密は無い（http・token 等で検索した）。
- ② 認証・認可: オフラインの単体ゲームで、差分に保護リソースは無い。対象外。
- ③ インジェクション: 外から入る値は `presentation_config.tres` の数値3つだけ。`_is_ball_style_valid` が肯定形の範囲チェックで NaN と INF を弾いている。範囲外ならファイル全体を初期値に戻す。テストで下限・上限・NaN・INF・回数 0 と 9 を確かめている。
- ④ 情報漏洩: `push_error` に出るのは設定値とファイル名だけ。
- A08: `.tres` の読み込みは既存の `_load`（`res://config` の同梱ファイル）のままで、新しい取り込み経路は無い。接続先（読み込むファイル）の検証は既存のまま。取得した値の検証はこの差分で新しく足された。

**バグ**
- 退化した入力: `along` と `lift` は t を [0,1] に押さえている。t=0 と 1 で高さは 0（CARRIED の sin(nπ) は浮動小数の誤差程度）。高さは style が `{}` なら 0、手が null なら STRAIGHT。
- ball_style が空のときの bind しない利用者（振り返り画面など）: `{}` の `.get` 既定値 0.0 で高さは 0。flight が無ければ STRAIGHT で、以前の等速と同じ動き。
- 状態のリセット: `_stop_shift` から `clear()` で beats が空になり、`ball_path_of` が `{}` を返すので高さは 0。2拍目は flight を持たないので高さ 0。`start()` が拍を取り除いても、flight は ball_path の中にあるのでずれない。
- 型キャスト: `.get(...) as float` と `as int` の既定値は型が合っている。`PLAY_KINDS.get(..., Kind.STRAIGHT) as Kind` も正しい。
- 持つ側の選び方: 攻撃と守備、奪取（POS_TRANS）と喪失（NEG_TRANS）の組み合わせを、利用者と CPU の両方の向きでテストしている。手を追加すると `PlayType.size()` の照合で気づける。
- start_shift の組み立てを `build_beats` に移した点: 前の実装と同じ（最後の拍はいまの盤面へ、ボールはエリアが違うときだけ動く）。`build_beats` のテストがこれを確かめている。

**性能**
- 1フレームあたりに増えたのは、ボール1個分の `pow` と `sin`、Dictionary の `.get` 数回、描画の加算1回だけ。O(1) で、どんな規模でも問題にならない。
- `build_beats` は開示のときに1回だけ呼ばれ、計算量は以前のインライン実装と同じ。

**運用**
- 設定: 3つの値は `presentation_config.tres` に外出ししてあり、`@export` に既定値がある。古い .tres でキーが無ければ既定値が使われるので、後方互換がある。範囲外なら `push_error` を出し、初期値に戻す。fail open にはならない。
- 切り戻し: 設定の追加だけで、保存データの形は変えていない。
- ドキュメント: functional-overview（値と範囲）、component-design（ball_style・値の範囲・2026-11-03 の注記）、screen-design、screen-common（TacticsBoard の flight・set_ball_style・ball_lift・描き方）、screen-03-match、repository-structure に反映されている。

### 未検証（確認できなかった範囲と理由）
- Godot のテストは指示どおり実行していない。「80件パス・変異18個検出」は依頼元の報告として受け取っただけで、再現していない。
- 実際の画面での見え方（浮き球が盤面からはみ出すか、ドリブルの弾みが震えて見えないか）は、描画していないので確かめていない。
- docs の hunk は検索で該当行を読んだだけで、並行セッションの hunk との切り分けまではしていない。

### 総合評価
Critical も High も無いので、コミットしてよいです。ただし、コミットの前に次の2点をやってください。
1. 全体テストが3分以内に通ることを確かめる（L-3。tasklist の未チェック項目）。
2. M-1（bind で高さを渡しているかのテスト）を足す。後回しにする場合も、静かに誤る経路なのでテストを先に固定してから申し送る。

L-1 は、このテストが確かめているつもりの場面を実際に通すための小さな修正なので、M-1 と一緒に直すのがおすすめです。

### 対応
- M-1: 直した。`match_board_panel_test` に、bind の後の盤面で浮き球の途中の高さが 0 より大きく、設定の高さ以下であることを確かめるテストを足した。bind の `set_ball_style` を消す変異で落ちることを確かめた。
- L-1: 直した。`board_shift_test` の `_shift` の2拍目に駒の道筋を1本入れ、拍が2つ残ることを確かめてから「ボールが動かない2拍目の高さ 0」を見る形にした。
- L-2: 直さない。描画の座標は見た目だけで、シャビが遊んで浮き球が上がることを確かめている。描画の関数を純関数に切り出すのは、描画のテストの方針を決めるときにまとめて扱う。
- L-3: 全体テストは、並行セッションのテスト時間の短縮（3分以内）が入ってから流す（シャビの判断。tasklist に記録）。
- L-4: 直さない。初期値 6 で収まることはシャビが確かめた。上限 20 は設定を変える人向けの上限で、超える調整をするときに見る。

## レビュー完了（2026-11-03）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: L-2（描画のテストの方針）・L-4（上限 20 の見え方）。どちらも見た目だけで、実害は無い

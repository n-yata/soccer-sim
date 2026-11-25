# コミット前レビューレポート

## 第1回（2026-11-03）
- 対象: 2拍の開示（`board_shift_sec` → `board_settle_sec` の改名、`board_play_sec` の追加）。コード7本・テスト4本・docs/specs の該当 hunk・`.steering/20261103-two-beat-reveal/`。並行セッション（tactics-notes）の hunk は対象外
- レビュー役: general-purpose（opus）
- 結果: Critical 0件 / High 0件 / Medium 0件 / Low 2件

## コミット前レビュー結果
対象: 2拍の開示（board_shift_sec を board_settle_sec に改名し、board_play_sec を追加）の差分。コード7本、テスト4本、docs/specs の該当 hunk（2拍・start_shift・board_play_sec・board_settle_sec に関するものだけ。drawio も含む）、.steering/20261103-two-beat-reveal/。並行セッションの hunk は対象外。ファイルへの書き込みとテストの実行はしていない。

### Critical（即時対応必須）
指摘なし

### High（優先対応）
指摘なし

### Medium（対応推奨）
指摘なし

### Low / 改善提案
1. **[運用/バグ] 同梱の .tres でキーの改名を取りこぼしても、テストが気づけない**
   - Godot は .tres の知らないプロパティ（古い `board_shift_sec = ...`）をエラーにせず無視する。その場合、新しいキーは既定値で読まれる。
   - 同梱値の確認テストは、同梱値と既定値を比べている。どちらも 0.6 なので、キーが欠けても通ってしまう（`test_bundled_presentation_matches_the_initial_value`・`test_bundled_board_play_matches_the_initial_value`）。
   - 今回の .tres は正しく改名されていて、値も既定値と同じ。読み込むのは res://config の同梱ファイルだけなので、実害はない。ただ、今後同梱値を既定値と違う値に調整したとき、取りこぼしが静かに起きうる。
   - 修正例（テキストとして確かめる。ConfigFile.parse は使わない）:
     ```gdscript
     func test_bundled_presentation_file_uses_the_current_keys() -> void:
     	var text: String = FileAccess.get_file_as_string("res://config/presentation_config.tres")
     	assert_str(text).contains("board_play_sec = ")
     	assert_str(text).contains("board_settle_sec = ")
     	assert_str(text).not_contains("board_shift_sec")
     ```
2. **[運用] ステアリングの design.md が改名前のまま**
   - `.steering/20261103-two-beat-reveal/design.md` の33行目に「`PresentationConfig.board_shift_sec` を2拍目の長さとして残し」、57行目に「`board_shift_sec` の説明」とある。tasklist.md には改名が記録されているが、design.md は実装と食い違っている。
   - 修正例: 「`board_shift_sec` は意味が2拍目の時間に変わるので `board_settle_sec` に改名し（実装レビューの指摘で変更）、`board_play_sec`（1拍目）を足す」。

### 問題なし（確認済み項目のリスト、観点ごと）
**セキュリティ**
- ① ハードコーディング: 差分に URL、キー、アカウント情報、ドキュメント内の機密情報は無い。`MAX_BOARD_BEAT_SEC = 2.0` は秘匿値ではない。
- ②（認証・認可）、A01、A07: 対象外（オフラインの単体ゲーム）。
- ③ インジェクション / A03: 外部からの入力がシェルやクエリに渡る経路は無い。
- ④ 情報漏洩: push_error の内容は設定ファイル名と値だけ。
- A08: 読み込むのは `res://config` の同梱 .tres だけで、利用者が書き換えられる場所（user://）からは読まない。読み込みの仕組みは変わっていない。
- A10: 外部への通信は無い。

**バグ・正しさ**
- `board_play_sec` と `board_settle_sec` の両方を、`_is_board_sec_valid` で検証している（有限、0 より大きい、2 以下。NaN でも偽になる肯定形）。片方が範囲外ならファイル全体を初期値に戻す。これはほかの値と同じ扱いで、テストで固定されている。
- `BoardShift.start`: 動きの無い拍と、時間が 0 以下・NaN の拍を取り除いてから `beat_index` と `progress` を初期化している。前回の状態は `beats.clear()` で消え、深いコピーを取るので呼び出し元と共有しない。
- Tween の順序: 拍ごとに `tween_callback(begin_beat)` を置いてから `tween_method(progress)` を置いており、順に実行される。新しい開示の前には `_stop_shift` が前の tween を kill するので、古い callback が後から走ることはない。
- `piece_position` の決め方:
  - 後の拍だけで動く駒は、その拍の `from`（＝判定時の位置。1拍目に動いていないので判定前と同じ）に描く。
  - 動き終えた駒は rest に描く。列の位置だけ変わる駒も `paths` に入るので、rest とずれない。
  - 1拍目を飛ばした場合は、2拍目の `from` に描く。前後で矛盾は無い。
- ボール: `ball_after`（判定時、攻撃側の視点）と、次のターン開始時の `ball_area` は、どちらも利用者の視点へ変換している。攻守が替わったときの mirrored も整合する。得点後のキックオフで置き直されるときは、2拍目で中央へ動く（テストあり）。
- `pair_at_judgement` は `_record` で必ず入るので、判定時の配置が空になって駒が動かなくなる経路は無い。
- 改名の取りこぼし: コード、テスト、docs/specs、drawio に `board_shift_sec` は残っていない。docs に残っているのは改名の経緯の注記だけ。
- テストについて:
  - play 0.9 と settle 1.5 という別々の値で取り違えを見分けている。
  - パネルのテストは、固定シードで2拍とも動きがあることを先に確かめており、空振りしない。
  - 期待値は、道筋の計算をコピーしたものではなく、エリアの差から作っている。恒真テストは無い。

**性能**
- 描画1回あたりの探索は、駒の数（22）× 拍の数（2）× 道筋の数（22 以下）、つまり約1000回の辞書参照。上限が固定なので問題にならない。I/O の増加は無い（設定は初回だけ読み込んでキャッシュする）。

**運用**
- 新しい設定値は .tres に外出しされている。未設定や範囲外のときの挙動（初期値 0.6 と push_error）も定義され、テストがある。
- 仕様書（functional-overview の設定表、NFR-18、component-design、screen-common、screen-03、usecase、drawio など）に、2拍化と改名が反映されている。
- revert はコミット単位で戻せる（データの移行は無い）。

### 未検証（確認できなかった範囲と理由）
- Godot のテストは指示に従って実行していない（123件パスは依頼元の申告）。
- 時間に依存するテスト（`await_millis(300)` で1拍目 0.05 秒を待つものなど）のフレーキーさは、余裕が十分あると読んだだけで、負荷をかけた実行はしていない。
- 古いキーを持つ .tres を Godot が黙って無視することは Godot 4 の一般的な挙動として判断した。この環境で実際に試してはいない。
- docs の diff は並行セッションの hunk と混ざっているため、キーワード（拍・settle・play_sec・start_shift・詰め直し・board_）で抜き出した行だけを見た。

### 総合評価
Critical・High の指摘なし。コミットしてよい。Low 2件はコミット後の対応でも構わない。ただし1は、同梱値を初期値と違う値に調整するより前に、取りこぼしを検出するテストを入れておくことを勧める。

### 対応
- Low 1: 直した。`config_repository_test` に、同梱の `presentation_config.tres` を文字列として読み、`board_play_sec = `・`board_settle_sec = ` があり `board_shift_sec` が無いことを確かめるテストを足した（ConfigFile.parse は使わない）。
- Low 2: 直した。design.md の調整値の節と、変更するドキュメントの節を、改名後の形に書き換えた（改名の理由と、実装レビューで変えた経緯を残した）。

## レビュー完了（2026-11-03）
- 最終ラウンド: 第1回
- 新たな Critical / High: なし
- 積み残し: なし（Low 2件は直した。Medium / Low の修正なので再レビューは不要）
